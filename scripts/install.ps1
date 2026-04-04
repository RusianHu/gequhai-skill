[CmdletBinding()]
param(
    [ValidateSet('copy', 'symlink')]
    [string]$Mode = 'copy',

    [string]$RepoRoot,
    [string]$SkillSource,
    [string]$SkillTarget,
    [string]$CliSource,
    [string]$CliTarget,

    [switch]$SkipSkill,
    [switch]$SkipCli,
    [switch]$CleanCli
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[gequhai-install] $Message"
}

function Get-DefaultRepoRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Remove-PathIfExists {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force -Recurse
    }
}

if (-not $RepoRoot) {
    $RepoRoot = Get-DefaultRepoRoot
}

if (-not $SkillSource) {
    $SkillSource = Join-Path $RepoRoot 'SKILL.md'
}

if (-not $SkillTarget) {
    $SkillTarget = Join-Path $HOME '.roo/skills/gequhai/SKILL.md'
}

if (-not $CliSource) {
    $CliSource = Join-Path $RepoRoot 'opencli/clis/gequhai'
}

if (-not $CliTarget) {
    $CliTarget = Join-Path $HOME '.opencli/clis/gequhai'
}

$SyncScript = Join-Path $PSScriptRoot 'sync-opencli.ps1'

Write-Step "系统：$([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
Write-Step "仓库根目录：$RepoRoot"
Write-Step "安装模式：$Mode"

if (-not $SkipSkill) {
    if (-not (Test-Path -LiteralPath $SkillSource)) {
        throw "未找到 skill 源文件：$SkillSource"
    }

    $SkillParent = Split-Path -Parent $SkillTarget
    if (-not (Test-Path -LiteralPath $SkillParent)) {
        Write-Step "创建 Roo 目标目录：$SkillParent"
        New-Item -ItemType Directory -Force -Path $SkillParent | Out-Null
    }

    Write-Step "安装 skill：$SkillSource -> $SkillTarget"

    switch ($Mode) {
        'copy' {
            Copy-Item -LiteralPath $SkillSource -Destination $SkillTarget -Force
        }
        'symlink' {
            Remove-PathIfExists -Path $SkillTarget
            try {
                New-Item -ItemType SymbolicLink -Path $SkillTarget -Target (Resolve-Path -LiteralPath $SkillSource).Path | Out-Null
            }
            catch {
                throw @"
创建 skill 符号链接失败：$($_.Exception.Message)
可改用复制模式重新执行：
  pwsh -File ./scripts/install.ps1 -Mode copy
Windows 下若要成功创建符号链接，通常需要开启开发者模式或提升权限。
"@
            }
        }
    }
}
else {
    Write-Step '跳过 skill 安装'
}

if (-not $SkipCli) {
    if (-not (Test-Path -LiteralPath $SyncScript)) {
        throw "未找到 CLI 同步脚本：$SyncScript"
    }

    Write-Step '开始安装 opencli gequhai CLI'
    & $SyncScript -Mode $Mode -RepoRoot $RepoRoot -SourceDir $CliSource -TargetDir $CliTarget @($CleanCli ? '-Clean' : @())
}
else {
    Write-Step '跳过 CLI 安装'
}

Write-Host ''
Write-Step '安装完成。建议验证：'
Write-Host '  opencli gequhai search "周杰伦" -f json'
Write-Host '  opencli gequhai new --limit 5 -f json'
Write-Host '  opencli gequhai detail 5863066 -f json'
