<#
.SYNOPSIS
    gequhai skill 压力测试脚本
.DESCRIPTION
    包含并发测试、高频调用、Rate Limit 验证、稳定性测试等
.PARAMETER TestType
    测试类型: all, smoke, concurrency, ratelimit, stability, boundary
.PARAMETER OpenCliCommand
    opencli 命令路径
.PARAMETER OutputDir
    测试结果输出目录
#>
[CmdletBinding()]
param(
    [ValidateSet('all', 'smoke', 'concurrency', 'ratelimit', 'stability', 'boundary')]
    [string]$TestType = 'all',
    [string]$OpenCliCommand = 'opencli',
    [string]$OutputDir = './test-results',
    [switch]$KeepDownloads
)

$ErrorActionPreference = 'Stop'
$global:TestResults = @()
$global:StartTime = Get-Date

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $color = switch ($Level) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'WARN' { 'Yellow' }
        'INFO' { 'White' }
        default { 'White' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Record-Result {
    param(
        [string]$TestName,
        [string]$Command,
        [bool]$Success,
        [int]$DurationMs,
        [string]$ErrorMessage = '',
        [hashtable]$Metrics = @{}
    )
    $global:TestResults += [PSCustomObject]@{
        TestName     = $TestName
        Command      = $Command
        Success      = $Success
        DurationMs   = $DurationMs
        ErrorMessage = $ErrorMessage
        Metrics      = $Metrics
        Timestamp    = Get-Date
    }
}

function Invoke-CommandWithTiming {
    param(
        [string]$TestName,
        [string]$Command
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $output = & pwsh -NoProfile -Command $Command 2>&1
        $sw.Stop()
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ $TestName (${sw.ElapsedMilliseconds}ms)" 'PASS'
            Record-Result -TestName $TestName -Command $Command -Success $true -DurationMs $sw.ElapsedMilliseconds
            return $true, $output
        } else {
            $err = ($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) -join '; '
            Write-Log "✗ $TestName (${sw.ElapsedMilliseconds}ms): $err" 'FAIL'
            Record-Result -TestName $TestName -Command $Command -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorMessage $err
            return $false, $output
        }
    } catch {
        $sw.Stop()
        Write-Log "✗ $TestName (${sw.ElapsedMilliseconds}ms): $($_.Exception.Message)" 'FAIL'
        Record-Result -TestName $TestName -Command $Command -Success $false -DurationMs $sw.ElapsedMilliseconds -ErrorMessage $_.Exception.Message
        return $false, $null
    }
}

# ============================================================
# 1. 基础冒烟测试
# ============================================================
function Test-Smoke {
    Write-Log '=== 基础冒烟测试 ===' 'INFO'
    
    # 搜索测试 - 多个关键词
    $keywords = @('周杰伦', '林俊杰', '薛之谦', '陈奕迅', '五月天')
    foreach ($kw in $keywords) {
        Invoke-CommandWithTiming -TestName "搜索-$kw" -Command "$OpenCliCommand gequhai search '$kw' -f json --limit 3"
    }
    
    # 新歌榜
    Invoke-CommandWithTiming -TestName '新歌榜' -Command "$OpenCliCommand gequhai new --limit 5 -f json"
    
    # 歌手榜
    Invoke-CommandWithTiming -TestName '歌手榜' -Command "$OpenCliCommand gequhai singers --limit 5 -f json"
    
    # 热门榜（已知结构可能不同）
    $success, $output = Invoke-CommandWithTiming -TestName '热门榜' -Command "$OpenCliCommand gequhai hot --limit 5 -f json"
    
    # 等待避免触发 rate limit
    Write-Log '等待 25 秒避免触发 rate limit...' 'WARN'
    Start-Sleep -Seconds 25
    
    # 详情测试
    $testIds = @('5863066', '553', '326')
    foreach ($id in $testIds) {
        Invoke-CommandWithTiming -TestName "详情-$id" -Command "$OpenCliCommand gequhai detail $id -f json"
        Start-Sleep -Seconds 22
    }
    
    # 夸克链接测试
    Invoke-CommandWithTiming -TestName '夸克链接-553' -Command "$OpenCliCommand gequhai quark 553"
}

# ============================================================
# 2. 并发测试
# ============================================================
function Test-Concurrency {
    Write-Log '=== 并发测试 ===' 'INFO'
    
    # 并发搜索
    Write-Log '--- 并发搜索测试 (5个同时) ---' 'INFO'
    $jobs = @()
    $keywords = @('周杰伦', '林俊杰', '薛之谦', '陈奕迅', '五月天')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    foreach ($kw in $keywords) {
        $jobs += Start-ThreadJob -ScriptBlock {
            param($kw, $cmd)
            & pwsh -NoProfile -Command "$cmd gequhai search '$kw' -f json --limit 3" 2>&1
        } -ArgumentList $kw, $OpenCliCommand
    }
    
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
    $sw.Stop()
    
    $successCount = 0
    foreach ($r in $results) {
        if ($r -isnot [System.Management.Automation.ErrorRecord]) { $successCount++ }
    }
    Write-Log "并发搜索完成: $successCount/5 成功, 总耗时: ${sw.ElapsedMilliseconds}ms" 'INFO'
    Record-Result -TestName '并发搜索' -Command '5x search' -Success ($successCount -ge 3) -DurationMs $sw.ElapsedMilliseconds -Metrics @{SuccessCount = $successCount; Total = 5}
    
    # 并发详情
    Write-Log '--- 并发详情测试 (3个同时) ---' 'INFO'
    $jobs = @()
    $ids = @('5863066', '553', '326')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    foreach ($id in $ids) {
        $jobs += Start-ThreadJob -ScriptBlock {
            param($id, $cmd)
            & pwsh -NoProfile -Command "$cmd gequhai detail $id -f json" 2>&1
        } -ArgumentList $id, $OpenCliCommand
    }
    
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
    $sw.Stop()
    
    $successCount = 0
    foreach ($r in $results) {
        if ($r -isnot [System.Management.Automation.ErrorRecord]) { $successCount++ }
    }
    Write-Log "并发详情完成: $successCount/3 成功, 总耗时: ${sw.ElapsedMilliseconds}ms" 'INFO'
    Record-Result -TestName '并发详情' -Command '3x detail' -Success ($successCount -ge 2) -DurationMs $sw.ElapsedMilliseconds -Metrics @{SuccessCount = $successCount; Total = 3}
}

# ============================================================
# 3. Rate Limit 测试
# ============================================================
function Test-RateLimit {
    Write-Log '=== Rate Limit 测试 ===' 'INFO'
    
    # 快速连续调用 detail 接口触发 429
    Write-Log '--- 快速连续调用 detail (触发 rate limit) ---' 'INFO'
    $rateLimitTriggered = $false
    $successCount = 0
    $failCount = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    for ($i = 0; $i -lt 8; $i++) {
        $output = & pwsh -NoProfile -Command "$OpenCliCommand gequhai detail 553 -f json" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $successCount++
        } else {
            $failCount++
            $errText = ($output | Out-String)
            if ($errText -match '429|请.*秒后再试|rate limit') {
                $rateLimitTriggered = $true
                Write-Log "第 $($i+1) 次触发 rate limit!" 'WARN'
                break
            }
        }
        Start-Sleep -Milliseconds 500
    }
    $sw.Stop()
    
    Write-Log "Rate Limit 测试: 成功 $successCount 次, 失败 $failCount 次, 总耗时 ${sw.ElapsedMilliseconds}ms" 'INFO'
    Record-Result -TestName 'RateLimit-detail' -Command '8x detail rapid' -Success $rateLimitTriggered -DurationMs $sw.ElapsedMilliseconds -Metrics @{SuccessCount = $successCount; FailCount = $failCount; Triggered = $rateLimitTriggered}
    
    # 等待恢复
    Write-Log '等待 30 秒恢复...' 'WARN'
    Start-Sleep -Seconds 30
    
    # 验证恢复后能正常访问
    $success, $output = Invoke-CommandWithTiming -TestName '恢复验证-search' -Command "$OpenCliCommand gequhai search '测试' -f json --limit 3"
}

# ============================================================
# 4. 稳定性测试
# ============================================================
function Test-Stability {
    Write-Log '=== 稳定性测试 (持续 5 分钟) ===' 'INFO'
    
    $duration = [TimeSpan]::FromMinutes(5)
    $startTime = Get-Date
    $iteration = 0
    $successCount = 0
    $failCount = 0
    $errors = @{}
    
    while ((Get-Date) - $startTime -lt $duration) {
        $iteration++
        $testType = $iteration % 4
        
        switch ($testType) {
            0 { $cmd = "$OpenCliCommand gequhai search '流行' -f json --limit 3" }
            1 { $cmd = "$OpenCliCommand gequhai new --limit 3 -f json" }
            2 { $cmd = "$OpenCliCommand gequhai singers --limit 3 -f json" }
            3 { $cmd = "$OpenCliCommand gequhai search '经典' -f json --limit 3" }
        }
        
        $output = & pwsh -NoProfile -Command $cmd 2>&1
        if ($LASTEXITCODE -eq 0) {
            $successCount++
        } else {
            $failCount++
            $errText = ($output | Out-String)
            if ($errText -match '429') {
                $errors['429_rate_limit'] = ($errors['429_rate_limit'] | Measure-Object).Count + 1
                Write-Log "迭代 $iteration`: 触发 rate limit，等待 25 秒..." 'WARN'
                Start-Sleep -Seconds 25
            } else {
                $errKey = ($errText -split "`n")[0].Substring(0, [Math]::Min(50, ($errText -split "`n")[0].Length))
                $errors[$errKey] = ($errors[$errKey] | Measure-Object).Count + 1
            }
        }
        
        # 每次请求间隔
        Start-Sleep -Seconds 3
        
        if ($iteration % 10 -eq 0) {
            $elapsed = (Get-Date) - $startTime
            Write-Log "稳定性测试: 迭代 $iteration, 成功 $successCount, 失败 $failCount, 已运行 $($elapsed.TotalSeconds.ToString('0'))s" 'INFO'
        }
    }
    
    $totalTime = (Get-Date) - $startTime
    Write-Log "稳定性测试完成: 总迭代 $iteration 次, 成功 $successCount, 失败 $failCount, 总耗时 $($totalTime.TotalSeconds.ToString('0'))s" 'INFO'
    
    if ($errors.Count -gt 0) {
        Write-Log '错误分布:' 'WARN'
        foreach ($kvp in $errors.GetEnumerator()) {
            Write-Log "  $($kvp.Key): $($kvp.Value) 次" 'WARN'
        }
    }
    
    Record-Result -TestName '稳定性测试' -Command '5min continuous' -Success ($failCount -lt ($successCount * 0.2)) -DurationMs $totalTime.TotalMilliseconds -Metrics @{Iterations = $iteration; Success = $successCount; Fail = $failCount; Errors = $errors}
}

# ============================================================
# 5. 边界条件测试
# ============================================================
function Test-Boundary {
    Write-Log '=== 边界条件测试 ===' 'INFO'
    
    # 极限 limit 值
    Invoke-CommandWithTiming -TestName 'limit=1' -Command "$OpenCliCommand gequhai search '测试' -f json --limit 1"
    Invoke-CommandWithTiming -TestName 'limit=100' -Command "$OpenCliCommand gequhai new --limit 100 -f json"
    
    # 空关键词
    Invoke-CommandWithTiming -TestName '空搜索' -Command "$OpenCliCommand gequhai search '' -f json"
    
    # 特殊字符搜索
    $specialChars = @('123', 'abc', '!', '中文测试', 'a'.PadRight(100, 'a'))
    foreach ($char in $specialChars) {
        Invoke-CommandWithTiming -TestName "特殊搜索-$($char.Substring(0, [Math]::Min(10, $char.Length)))" -Command "$OpenCliCommand gequhai search '$char' -f json --limit 3"
    }
    
    # 不存在的歌曲ID
    Invoke-CommandWithTiming -TestName '不存在的ID-999999999' -Command "$OpenCliCommand gequhai detail 999999999 -f json"
    
    # 负数ID
    Invoke-CommandWithTiming -TestName '负数ID' -Command "$OpenCliCommand gequhai detail -1 -f json"
    
    # 等待避免触发 rate limit
    Start-Sleep -Seconds 25
    
    # 超大 limit
    Invoke-CommandWithTiming -TestName 'limit=1000(应被限制)' -Command "$OpenCliCommand gequhai singers --limit 1000 -f json"
}

# ============================================================
# 6. 下载功能测试（可选）
# ============================================================
function Test-Download {
    Write-Log '=== 下载功能测试 ===' 'INFO'
    
    $testIds = @('553', '326')
    foreach ($id in $testIds) {
        $downloadDir = Join-Path $OutputDir "downloads-$id"
        Invoke-CommandWithTiming -TestName "下载-$id" -Command "$OpenCliCommand gequhai download $id --output '$downloadDir'"
        
        if (-not $KeepDownloads -and (Test-Path $downloadDir)) {
            Remove-Item $downloadDir -Recurse -Force
        }
        
        Start-Sleep -Seconds 25
    }
}

# ============================================================
# 生成测试报告
# ============================================================
function Write-Report {
    $totalTime = (Get-Date) - $global:StartTime
    $totalTests = $global:TestResults.Count
    $passed = ($global:TestResults | Where-Object { $_.Success }).Count
    $failed = $totalTests - $passed
    
    $report = @"
============================================================
         gequhai skill 压力测试报告
============================================================
测试时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
总耗时:   $($totalTime.TotalSeconds.ToString('0.0'))s
测试类型: $TestType

结果汇总:
  总测试数: $totalTests
  通过:     $passed
  失败:     $failed
  通过率:   $(if ($totalTests -gt 0) { "{0:P1}" -f ($passed / $totalTests) } else { "N/A" })

详细结果:
"@

    foreach ($r in $global:TestResults) {
        $status = if ($r.Success) { '✓ PASS' } else { '✗ FAIL' }
        $report += "`n  [$status] $($r.TestName) ($($r.DurationMs)ms)"
        if ($r.ErrorMessage) {
            $report += "`n           错误: $($r.ErrorMessage.Substring(0, [Math]::Min(100, $r.ErrorMessage.Length)))"
        }
    }

    $report += "`n============================================================"
    
    # 保存报告
    $reportPath = Join-Path $OutputDir "stress-test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $report | Out-File -FilePath $reportPath -Encoding utf8
    Write-Log "报告已保存: $reportPath" 'INFO'
    
    # 输出到控制台
    Write-Host ''
    Write-Host $report -ForegroundColor Cyan
}

# ============================================================
# 主入口
# ============================================================
function Main {
    # 创建输出目录
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    Write-Log "gequhai skill 压力测试开始" 'INFO'
    Write-Log "测试类型: $TestType" 'INFO'
    Write-Log "输出目录: $OutputDir" 'INFO'
    
    switch ($TestType) {
        'smoke'       { Test-Smoke }
        'concurrency' { Test-Concurrency }
        'ratelimit'   { Test-RateLimit }
        'stability'   { Test-Stability }
        'boundary'    { Test-Boundary }
        'all' {
            Test-Smoke
            Write-Log '等待 30 秒后继续...' 'WARN'
            Start-Sleep -Seconds 30
            
            Test-Concurrency
            Write-Log '等待 30 秒后继续...' 'WARN'
            Start-Sleep -Seconds 30
            
            Test-RateLimit
            Write-Log '等待 30 秒后继续...' 'WARN'
            Start-Sleep -Seconds 30
            
            Test-Boundary
            Write-Log '等待 30 秒后继续...' 'WARN'
            Start-Sleep -Seconds 30
            
            Test-Stability
        }
    }
    
    Write-Report
}

Main
