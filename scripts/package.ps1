[CmdletBinding()]
param(
    [string]$Version = '0.1.0',
    [string]$RepoRoot,
    [string]$DistDir,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[gequhai-package] $Message"
}

function Get-DefaultRepoRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

if (-not $RepoRoot) {
    $RepoRoot = Get-DefaultRepoRoot
}

if (-not $DistDir) {
    $DistDir = Join-Path $RepoRoot 'dist'
}

$PackageName = "gequhai-skill-v$Version"
$StageDir = Join-Path $DistDir $PackageName
$ZipPath = Join-Path $DistDir ($PackageName + '.zip')

$RequiredPaths = @(
    'SKILL.md',
    'README.md',
    'LICENSE',
    'AGENTS.md',
    'opencli/clis/gequhai',
    'scripts/install.ps1',
    'scripts/sync-opencli.ps1',
    'scripts/sync-opencli.bat',
    'scripts/sync-opencli.sh',
    'tests/smoke.ps1'
)

Write-Step "仓库根目录：$RepoRoot"
Write-Step "输出目录：$DistDir"
Write-Step "版本号：$Version"

foreach ($relativePath in $RequiredPaths) {
    $fullPath = Join-Path $RepoRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "缺少发布所需文件：$relativePath"
    }
}

if (-not (Test-Path -LiteralPath $DistDir)) {
    New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
}

if ($Clean) {
    if (Test-Path -LiteralPath $StageDir) {
        Remove-Item -LiteralPath $StageDir -Force -Recurse
    }
    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }
}

if (Test-Path -LiteralPath $StageDir) {
    Remove-Item -LiteralPath $StageDir -Force -Recurse
}

New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'opencli/clis') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'scripts') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'tests') | Out-Null

Copy-Item -LiteralPath (Join-Path $RepoRoot 'SKILL.md') -Destination (Join-Path $StageDir 'SKILL.md') -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'README.md') -Destination (Join-Path $StageDir 'README.md') -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'LICENSE') -Destination (Join-Path $StageDir 'LICENSE') -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'AGENTS.md') -Destination (Join-Path $StageDir 'AGENTS.md') -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'opencli/clis/gequhai') -Destination (Join-Path $StageDir 'opencli/clis') -Force -Recurse
Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts/install.ps1') -Destination (Join-Path $StageDir 'scripts/install.ps1') -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts/sync-opencli.ps1') -Destination (Join-Path $StageDir 'scripts/sync-opencli.ps1') -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts/sync-opencli.bat') -Destination (Join-Path $StageDir 'scripts/sync-opencli.bat') -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts/sync-opencli.sh') -Destination (Join-Path $StageDir 'scripts/sync-opencli.sh') -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'tests/smoke.ps1') -Destination (Join-Path $StageDir 'tests/smoke.ps1') -Force

if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}

Compress-Archive -Path (Join-Path $StageDir '*') -DestinationPath $ZipPath -CompressionLevel Optimal

Write-Step "打包完成：$ZipPath"
Write-Step "发布目录：$StageDir"
Write-Host ''
Write-Host '建议下一步：'
Write-Host '  pwsh -File ./tests/smoke.ps1'
Write-Host '  pwsh -File ./scripts/package.ps1 -Version 0.1.0 -Clean'
