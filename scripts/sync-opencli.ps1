[CmdletBinding()]
param(
    [ValidateSet('copy', 'symlink')]
    [string]$Mode = 'copy',

    [string]$RepoRoot,
    [string]$SourceDir,
    [string]$TargetDir,

    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[gequhai-sync] $Message"
}

function Get-DefaultRepoRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Remove-TargetPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Write-Step "删除已有目标：$Path"
        Remove-Item -LiteralPath $Path -Force -Recurse
    }
}

if (-not $RepoRoot) {
    $RepoRoot = Get-DefaultRepoRoot
}

if (-not $SourceDir) {
    $SourceDir = Join-Path $RepoRoot 'opencli/clis/gequhai'
}

if (-not $TargetDir) {
    $TargetDir = Join-Path $HOME '.opencli/clis/gequhai'
}

if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "未找到源目录：$SourceDir"
}

$ResolvedSourceDir = (Resolve-Path -LiteralPath $SourceDir).Path
$TargetParent = Split-Path -Parent $TargetDir

if (-not (Test-Path -LiteralPath $TargetParent)) {
    Write-Step "创建 opencli 目标父目录：$TargetParent"
    New-Item -ItemType Directory -Force -Path $TargetParent | Out-Null
}

Write-Step "系统：$([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
Write-Step "仓库根目录：$RepoRoot"
Write-Step "源目录：$ResolvedSourceDir"
Write-Step "目标目录：$TargetDir"
Write-Step "同步模式：$Mode"

switch ($Mode) {
    'copy' {
        if (-not (Test-Path -LiteralPath $TargetDir)) {
            Write-Step "创建目标目录：$TargetDir"
            New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
        }

        if ($Clean) {
            Write-Step '清空目标目录中的现有文件'
            Get-ChildItem -LiteralPath $TargetDir -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse
        }

        Write-Step '复制 gequhai CLI 文件到 opencli 目录'
        Copy-Item -Path (Join-Path $ResolvedSourceDir '*') -Destination $TargetDir -Force -Recurse
    }

    'symlink' {
        Remove-TargetPath -Path $TargetDir

        Write-Step '创建符号链接模式的目标目录'
        try {
            New-Item -ItemType SymbolicLink -Path $TargetDir -Target $ResolvedSourceDir | Out-Null
        }
        catch {
            throw @"
创建符号链接失败：$($_.Exception.Message)
可改用复制模式重新执行：
  pwsh -File ./scripts/sync-opencli.ps1 -Mode copy -Clean
Windows 下若要成功创建符号链接，通常需要开启开发者模式或提升权限。
"@
        }
    }
}

$Items = Get-ChildItem -LiteralPath $TargetDir -Force | Select-Object Name, Length, LastWriteTime

Write-Step '同步完成。当前目标目录内容：'
$Items | Format-Table -AutoSize

Write-Host ''
Write-Host '可用示例：'
Write-Host '  pwsh -File ./scripts/sync-opencli.ps1'
Write-Host '  pwsh -File ./scripts/sync-opencli.ps1 -Clean'
Write-Host '  pwsh -File ./scripts/sync-opencli.ps1 -Mode symlink'
