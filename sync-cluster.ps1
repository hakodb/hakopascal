#Requires -Version 5.1
<#
.SYNOPSIS
  Populate native/ with the hakocluster shared library (multi-platform).
.EXAMPLE
  .\sync-cluster.ps1 -CoreDir C:\Dev\libs\hakocluster
  .\sync-cluster.ps1 -Tag v0.3.5
  .\sync-cluster.ps1 -Tag v0.3.5 -Platform linux
#>
param(
    [string]$CoreDir = "",
    [string]$Tag = "",
    [string]$Platform = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Native = Join-Path $Root "native"
New-Item -ItemType Directory -Force $Native | Out-Null

if ($CoreDir -ne "") {
    $dll = Join-Path $CoreDir "target\release\hakocluster.dll"
    $so = Join-Path $CoreDir "target\release\libhakocluster.so"
    $found = @($dll, $so) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $found) { throw "no release library under $CoreDir\ttarget\release (cargo build --release first)" }
    Copy-Item $found $Native -Force
    Write-Output "synced from checkout: $CoreDir"
} elseif ($Tag -ne "") {
    if ($Platform -eq "") {
        if ($IsWindows -or $env:OS -eq "Windows_NT") { $Platform = "win32" }
        elseif ($IsLinux) { $Platform = "linux" }
        else { $Platform = "win32" }
    }
    $base = "https://github.com/hakodb/hakocluster/releases/download/$Tag"
    if ($Platform -eq "win32") {
        $zip = Join-Path ([IO.Path]::GetTempPath()) "hakocluster-$Tag-win32.zip"
        Invoke-WebRequest -Uri "$base/hakocluster-$Tag-x86_64-pc-windows-msvc.zip" -OutFile $zip
        $stage = Join-Path ([IO.Path]::GetTempPath()) "hakocluster-$Tag-win32"
        if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
        Expand-Archive $zip $stage -Force
        Copy-Item (Join-Path $stage "hakocluster.dll") $Native -Force
        Copy-Item (Join-Path $stage "hakocluster.h") (Join-Path $Native "hakocluster.h") -Force
    } elseif ($Platform -eq "linux") {
        Invoke-WebRequest -Uri "$base/hakocluster-$Tag-x86_64-unknown-linux-glibc2.28-el8.tar.gz" -OutFile (Join-Path $Native "hc.tgz")
        tar xzf (Join-Path $Native "hc.tgz") -C $Native
        Remove-Item (Join-Path $Native "hc.tgz") -Force
    } else {
        throw "unknown -Platform '$Platform' (win32|linux)"
    }
    Write-Output "synced from release asset: $Tag ($Platform)"
} else {
    throw "pass -CoreDir or -Tag"
}
