#Requires -Version 5.1
<#
.SYNOPSIS
  Populate native/ from a core checkout or a release tag asset.
.EXAMPLE
  .\sync-native.ps1 -CoreDir C:\Dev\libs\firelite
  .\sync-native.ps1 -Tag v0.8.20
#>
param(
    [string]$CoreDir = "",
    [string]$Tag = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Native = Join-Path $Root "native"
New-Item -ItemType Directory -Force $Native | Out-Null

if ($CoreDir -ne "") {
    $dll = Join-Path $CoreDir "target\release\firelite.dll"
    if (-not (Test-Path $dll)) { throw "no release DLL at $dll (cargo build --release first)" }
    Copy-Item $dll $Native -Force
    Write-Output "synced from checkout: $CoreDir"
} elseif ($Tag -ne "") {
    $zip = Join-Path $env:TEMP "firelite-$Tag-windows.zip"
    Invoke-WebRequest -Uri "https://github.com/rizaptk/firelite/releases/download/$Tag/firelite-$Tag-x86_64-pc-windows-msvc.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $env:TEMP\firelite-rel -Force
    Copy-Item $env:TEMP\firelite-rel\firelite.dll $Native -Force
    Write-Output "synced from release asset: $Tag"
} else {
    throw "pass -CoreDir or -Tag"
}
