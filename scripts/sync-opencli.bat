@echo off
setlocal
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
set "PS1_SCRIPT=%SCRIPT_DIR%sync-opencli.ps1"
set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"

if not exist "%PS1_SCRIPT%" (
    echo [gequhai-sync] 未找到 PowerShell 同步脚本: "%PS1_SCRIPT%"
    exit /b 1
)

if exist "%PWSH%" (
    "%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%PS1_SCRIPT%" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1_SCRIPT%" %*
)

set "EXIT_CODE=%ERRORLEVEL%"
exit /b %EXIT_CODE%
