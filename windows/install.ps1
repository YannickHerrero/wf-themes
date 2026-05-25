# wf-themes — Windows-side installer.
#
# Registers the WSL-resident wf-themes-host with Windows Firefox by:
#   1. Resolving the WSL absolute path to the binary (defaults to
#      /home/<wsl-user>/.local/bin/wf-themes-host).
#   2. Writing %LOCALAPPDATA%\wf-themes\wf-themes-host.bat (the wsl.exe wrapper).
#   3. Writing %LOCALAPPDATA%\wf-themes\com.yannick.wf_themes.json (the NM manifest).
#   4. Creating HKCU\Software\Mozilla\NativeMessagingHosts\com.yannick.wf_themes
#      whose default value is the absolute path to that JSON file.
#
# Prerequisites: WSL distro installed, and the host already built inside WSL
# (see ../scripts/install-native-host.sh).
#
# Usage (PowerShell):
#   .\windows\install.ps1
#
# Optional: pass -BinPath to override the WSL binary location.
#   .\windows\install.ps1 -BinPath "/home/yherrero/.local/bin/wf-themes-host"

param(
    [string]$BinPath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Fail($msg) {
    Write-Host "[wf-themes] error: $msg" -ForegroundColor Red
    exit 1
}

# ---- 1. Resolve the WSL binary path ----------------------------------------

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Fail "wsl.exe not found on PATH. Install WSL2 from the Microsoft Store and try again."
}

if (-not $BinPath) {
    $wslUser = (wsl.exe -e whoami).Trim()
    if (-not $wslUser) { Fail "Could not determine WSL username via 'wsl.exe -e whoami'." }
    $BinPath = "/home/$wslUser/.local/bin/wf-themes-host"
}

Write-Host "[wf-themes] checking WSL binary at $BinPath"
wsl.exe -e test -x $BinPath
if ($LASTEXITCODE -ne 0) {
    Fail "WSL binary not found or not executable at $BinPath. Inside WSL, run: bash scripts/install-native-host.sh"
}

# ---- 2. Render the .bat wrapper --------------------------------------------

$InstallDir = Join-Path $env:LOCALAPPDATA "wf-themes"
$null = New-Item -ItemType Directory -Force -Path $InstallDir

$BatPath = Join-Path $InstallDir "wf-themes-host.bat"
$BatTpl = Join-Path $ScriptDir "wf-themes-host.bat.tpl"
(Get-Content $BatTpl -Raw) -replace "__WSL_BIN_PATH__", $BinPath | Set-Content -Path $BatPath -Encoding ASCII

Write-Host "[wf-themes] wrote $BatPath"

# ---- 3. Render the NM manifest ---------------------------------------------

# Firefox accepts forward slashes in the manifest's "path" field on Windows;
# this dodges the JSON-escape gymnastics for backslashes.
$BatPathFwd = $BatPath -replace "\\", "/"

$ManifestPath = Join-Path $InstallDir "com.yannick.wf_themes.json"
$ManifestTpl = Join-Path $ScriptDir "com.yannick.wf_themes.json.tpl"
(Get-Content $ManifestTpl -Raw) -replace "__HOST_PATH__", $BatPathFwd | Set-Content -Path $ManifestPath -Encoding UTF8

Write-Host "[wf-themes] wrote $ManifestPath"

# ---- 4. Register with Firefox via HKCU -------------------------------------

$RegKey = "HKCU:\Software\Mozilla\NativeMessagingHosts\com.yannick.wf_themes"
$null = New-Item -Path $RegKey -Force
Set-Item -Path $RegKey -Value $ManifestPath

Write-Host "[wf-themes] registered $RegKey -> $ManifestPath"
Write-Host ""
Write-Host "[wf-themes] done. Restart Firefox (or disable + re-enable the extension)"
Write-Host "            to force a reconnect to the native host."
