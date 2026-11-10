@echo off
setlocal
set "CODEX_REMOTE_LAUNCHER=%~f0"
powershell.exe -NoProfile -MTA -Command "$source = [IO.File]::ReadAllText($env:CODEX_REMOTE_LAUNCHER); $marker = [regex]::Match($source, '(?m)^:CODEX_REMOTE_POWERSHELL\r?$'); if (-not $marker.Success) { throw 'The Codex Remote launcher is incomplete.' }; & ([scriptblock]::Create($source.Substring($marker.Index + $marker.Length)))"
set "CODEX_REMOTE_EXIT_CODE=%ERRORLEVEL%"
pause
exit /b %CODEX_REMOTE_EXIT_CODE%
:CODEX_REMOTE_POWERSHELL
param([string]$AdbPath)
$ErrorActionPreference = 'Stop'

if (-not $AdbPath) {
    $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($adbCommand) { $AdbPath = $adbCommand.Source }
}
if (-not $AdbPath) {
    $locations = @(
        (Join-Path (Split-Path -Parent $env:CODEX_REMOTE_LAUNCHER) 'platform-tools\adb.exe'),
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:TEMP\island-android-toolchain\sdk\platform-tools\adb.exe"
    )
    if ($env:ANDROID_HOME) { $locations = @(
        (Join-Path (Split-Path -Parent $env:CODEX_REMOTE_LAUNCHER) 'platform-tools\adb.exe'),"$env:ANDROID_HOME\platform-tools\adb.exe") + $locations }
    $AdbPath = $locations | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $AdbPath) { throw 'Install Android SDK Platform-Tools and add adb to PATH.' }

& $AdbPath -d reverse tcp:18763 tcp:18763
if ($LASTEXITCODE -ne 0) { throw 'Connect one Android phone by USB and allow USB debugging on the phone.' }

try {
    & {
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RemoteWindow {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
}
'@

$buttonType = [Windows.Automation.PropertyCondition]::new(
    [Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Button)
$names = @{
    '/dictation' = @('Stop dictation', 'Dictate')
    '/voice' = @('End voice chat', 'Stop voice chat', 'End Voice', 'Start voice chat')
}

function Press-CodexButton([string]$route) {
    $handle = [RemoteWindow]::GetForegroundWindow()
    [uint32]$owner = 0
    if (-not $handle) { throw 'The laptop must be unlocked.' }
    $null = [RemoteWindow]::GetWindowThreadProcessId($handle, [ref]$owner)
    $process = Get-Process -Id $owner -ErrorAction SilentlyContinue
    if ($process.ProcessName -notin @('ChatGPT', 'Codex')) {
        throw 'Open the round chat on the laptop and leave Codex in front.'
    }
    $root = [Windows.Automation.AutomationElement]::FromHandle($handle)
    foreach ($label in $names[$route]) {
        $labelCondition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::NameProperty, $label)
        $match = [Windows.Automation.AndCondition]::new($buttonType, $labelCondition)
        $controls = $root.FindAll([Windows.Automation.TreeScope]::Descendants, $match)
        $visible = @($controls | Where-Object { $_.Current.IsEnabled -and -not $_.Current.IsOffscreen })
        if ($visible.Count -gt 1) { throw 'More than one matching button. Leave only the round chat open.' }
        if ($visible.Count -eq 1) {
            if ([RemoteWindow]::GetForegroundWindow() -ne $handle) { throw 'The active window changed. Try again.' }
            $pattern = $null
            if ($visible[0].TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
                $pattern.Invoke()
            } elseif ($visible[0].TryGetCurrentPattern([Windows.Automation.TogglePattern]::Pattern, [ref]$pattern)) {
                $pattern.Toggle()
            } else {
                throw 'Windows cannot press that button. Check the laptop.'
            }
            return $label
        }
    }
    throw 'That button is unavailable in the current Codex chat. Check the laptop.'
}

$random = [Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 4
$random.GetBytes($bytes)
$random.Dispose()
$code = ([BitConverter]::ToUInt32($bytes, 0) % 1000000).ToString('D6')
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 18763)
try {
    $listener.Start()
    Write-Host "Phone pairing code: $code"
    Write-Host 'Open the round chat in Codex and leave it in front on the laptop.'
    Write-Host 'Keep this window open. Close it to stop the remote.'
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $client.ReceiveTimeout = 1500
        $client.SendTimeout = 1500
        $stream = $client.GetStream()
        $reply = "ERROR`n"
        try {
            $line = [Text.StringBuilder]::new()
            for ($i = 0; $i -lt 32; $i++) {
                $next = $stream.ReadByte()
                if ($next -eq 10) { break }
                if ($next -lt 32 -or $next -gt 126) { throw 'Invalid request.' }
                $null = $line.Append([char]$next)
            }
            if ($next -eq 10 -and $line.ToString() -cmatch '^([0-9]{6}) (/(status|dictation|voice))$' -and $Matches[1] -ceq $code) {
                $route = $Matches[2]
                if ($route -ne '/status') {
                    $button = Press-CodexButton $route
                    Write-Host "Pressed: $button"
                }
                $reply = "OK`n"
            }
        } catch {
            Write-Warning $_.Exception.Message
        } finally {
            try {
                $outbound = [Text.Encoding]::ASCII.GetBytes($reply)
                $stream.Write($outbound, 0, $outbound.Length)
            } catch [System.IO.IOException] {
                # The phone disconnected before the acknowledgment.
            } finally {
                $client.Close()
            }
        }
    }
} finally {
    $listener.Stop()
}
    }
} finally {
    & $AdbPath -d reverse --remove tcp:18763
}
