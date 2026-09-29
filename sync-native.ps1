#Requires -Version 5.1
<#
.SYNOPSIS
  Populate native/ from a core checkout or a release tag asset (multi-platform).
.EXAMPLE
  .\sync-native.ps1 -CoreDir C:\Dev\libs\hakodb
  .\sync-native.ps1 -Tag v0.9.0
  .\sync-native.ps1 -Tag v0.9.0 -Platform linux
#>
param(
    [string]$CoreDir = "",
    [string]$Tag = "",
    [string]$Platform = "",
    [string]$LibTag = "linux-glibc2.28-el8"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Native = Join-Path $Root "native"
New-Item -ItemType Directory -Force $Native | Out-Null

# No macOS prebuilts (no CI job yet): build from source via -CoreDir on a Mac.

if ($CoreDir -ne "") {
    $dll = Join-Path $CoreDir "target\release\hakodb.dll"
    $so = Join-Path $CoreDir "target\release\libhakodb.so"
    $dylib = Join-Path $CoreDir "target\release\libhakodb.dylib"
    $found = @($dll, $so, $dylib) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $found) { throw "no release library under $CoreDir\target\release (cargo build --release first)" }
    Copy-Item $found $Native -Force
    Write-Output "synced from checkout: $CoreDir"
} elseif ($Tag -ne "") {
    if ($Platform -eq "") {
        if ($IsWindows -or $env:OS -eq "Windows_NT") { $Platform = "win32" }
        elseif ($IsLinux) { $Platform = "linux" }
        elseif ($IsMacOS) { $Platform = "darwin" }
        else { $Platform = "win32" }
    }
    $base = "https://github.com/hakodb/hakodb/releases/download/$Tag"
    if ($Platform -eq "win32") {
        Invoke-WebRequest -Uri "$base/hakodb-x86_64-pc-windows-msvc.dll" -OutFile (Join-Path $Native "hakodb.dll")
    } elseif ($Platform -eq "linux") {
        # el8 build runs on glibc >= 2.28 everywhere; override -LibTag for an exact distro.
        Invoke-WebRequest -Uri "$base/libhakodb-x86_64-unknown-$LibTag.so" -OutFile (Join-Path $Native "libhakodb.so")
    } elseif ($Platform -eq "android") {
        Invoke-WebRequest -Uri "$base/libhakodb-aarch64-linux-android.so" -OutFile (Join-Path $Native "libhakodb.so")
    } elseif ($Platform -eq "darwin") {
        throw "no macOS prebuilt (no CI job yet) - build from source and use -CoreDir on a Mac"
    } else {
        throw "unknown -Platform '$Platform' (win32|linux|android|darwin)"
    }
    Write-Output "synced from release asset: $Tag ($Platform)"
} else {
    throw "pass -CoreDir or -Tag"
}
