# wf-themes — Windows installer.
#
# Registers the native messaging host with Windows Firefox by:
#   1. Copying windows/wf-themes-host.exe (checked into the repo) to
#      %LOCALAPPDATA%\wf-themes\.
#   2. Writing %LOCALAPPDATA%\wf-themes\com.yannick.wf_themes.json (the NM
#      manifest) with the absolute .exe path.
#   3. Creating HKCU\Software\Mozilla\NativeMessagingHosts\com.yannick.wf_themes
#      whose default value is the absolute path to that JSON file.
#
# Prerequisite: nothing — the .exe ships in the repo, pre-built.
#
# Usage (PowerShell):
#   .\windows\install.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Fail($msg) {
    Write-Host "[wf-themes] error: $msg" -ForegroundColor Red
    exit 1
}

# ---- 1. Locate the bundled binary ------------------------------------------

$SourceExe = Join-Path $ScriptDir "wf-themes-host.exe"
if (-not (Test-Path $SourceExe)) {
    Fail "windows\wf-themes-host.exe not found. Run scripts/build-windows.sh from WSL first, or pull the latest from git."
}

# ---- 2. Copy the .exe to %LOCALAPPDATA%\wf-themes\ -------------------------

$InstallDir = Join-Path $env:LOCALAPPDATA "wf-themes"
$null = New-Item -ItemType Directory -Force -Path $InstallDir

$InstalledExe = Join-Path $InstallDir "wf-themes-host.exe"
Copy-Item -Path $SourceExe -Destination $InstalledExe -Force
Write-Host "[wf-themes] installed $InstalledExe"

# ---- 3. Render the NM manifest --------------------------------------------

# Firefox accepts forward slashes in the manifest "path" on Windows; this
# sidesteps JSON backslash-escaping.
$ExePathFwd = $InstalledExe -replace "\\", "/"

$ManifestPath = Join-Path $InstallDir "com.yannick.wf_themes.json"
$ManifestTpl = Join-Path $ScriptDir "com.yannick.wf_themes.json.tpl"
(Get-Content $ManifestTpl -Raw) -replace "__HOST_PATH__", $ExePathFwd | Set-Content -Path $ManifestPath -Encoding UTF8

Write-Host "[wf-themes] wrote $ManifestPath"

# ---- 4. Register with Firefox via HKCU -------------------------------------

$RegKey = "HKCU:\Software\Mozilla\NativeMessagingHosts\com.yannick.wf_themes"
$null = New-Item -Path $RegKey -Force
Set-Item -Path $RegKey -Value $ManifestPath

Write-Host "[wf-themes] registered $RegKey -> $ManifestPath"
Write-Host ""
Write-Host "[wf-themes] done. Restart Firefox (or disable + re-enable the extension)"
Write-Host "            to force a reconnect to the native host."
