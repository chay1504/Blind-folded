param([string]$AdbPath)
$ErrorActionPreference = 'Stop'

if (-not $AdbPath) {
    $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($adbCommand) { $AdbPath = $adbCommand.Source }
}
if (-not $AdbPath) {
    $locations = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:TEMP\island-android-toolchain\sdk\platform-tools\adb.exe"
    )
    if ($env:ANDROID_HOME) { $locations = @("$env:ANDROID_HOME\platform-tools\adb.exe") + $locations }
    $AdbPath = $locations | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $AdbPath) { throw 'Install Android SDK Platform-Tools and add adb to PATH.' }

& $AdbPath -d reverse tcp:18763 tcp:18763
if ($LASTEXITCODE -ne 0) { throw 'Connect one Android phone by USB and allow USB debugging on the phone.' }

try {
    & (Join-Path $PSScriptRoot 'Codex-Remote.ps1')
} finally {
    & $AdbPath -d reverse --remove tcp:18763
}
