[CmdletBinding()]
param(
    [string]$OpenCliCommand = 'opencli',
    [switch]$IncludeDownload,
    [int]$SleepSeconds = 20
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[gequhai-smoke] $Message"
}

function Invoke-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$CommandLine
    )

    Write-Step "开始：$Name"
    Write-Host "  $CommandLine"

    & pwsh -NoProfile -Command $CommandLine
    if ($LASTEXITCODE -ne 0) {
        throw "检查失败：$Name"
    }

    Write-Step "通过：$Name"
    Write-Host ''
}

Invoke-Check -Name '搜索测试' -CommandLine "$OpenCliCommand gequhai search '周杰伦' -f json"
Invoke-Check -Name '新歌榜测试' -CommandLine "$OpenCliCommand gequhai new --limit 5 -f json"
Invoke-Check -Name '歌手榜测试' -CommandLine "$OpenCliCommand gequhai singers --limit 5 -f json"

Write-Step "等待 $SleepSeconds 秒后再进行 detail 测试，避免触发受限接口"
Start-Sleep -Seconds $SleepSeconds
Invoke-Check -Name '详情测试' -CommandLine "$OpenCliCommand gequhai detail 5863066 -f json"

Write-Step "等待 $SleepSeconds 秒后再进行 quark 测试"
Start-Sleep -Seconds $SleepSeconds
Invoke-Check -Name '夸克链接测试' -CommandLine "$OpenCliCommand gequhai quark 553"

if ($IncludeDownload) {
    Write-Step "等待 $SleepSeconds 秒后再进行下载测试"
    Start-Sleep -Seconds $SleepSeconds
    Invoke-Check -Name '下载测试' -CommandLine "$OpenCliCommand gequhai download 553 --output ./downloads"
}

Write-Step '所有冒烟测试执行完成'
