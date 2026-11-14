param([switch]$FetchWtl)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio C++ tools and ATL' }
$visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.ATL -property installationPath
if (-not $visualStudio) { throw 'Install the Visual C++ ATL component in Visual Studio Installer' }
$cmake = Join-Path $visualStudio 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
if (-not (Test-Path -LiteralPath $cmake)) {
  $cmake = (Get-Command cmake.exe -ErrorAction Stop).Source
}
$dependency = (Get-Content -Raw -Encoding UTF8 (Join-Path $root 'prototypes/wtl/dependencies.json') | ConvertFrom-Json).wtl
$cache = Join-Path $root $dependency.cache
if ($FetchWtl) { & (Join-Path $PSScriptRoot 'fetch-wtl.ps1') }
if (-not (Test-Path -LiteralPath (Join-Path $cache 'Include/atlapp.h'))) { throw 'Run tools/fetch-wtl.ps1 or pass -FetchWtl explicitly' }
$revision = & git -C $cache rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision -ne $dependency.commit) { throw 'WTL revision mismatch' }
$changes = & git -C $cache status --porcelain
if ($LASTEXITCODE -ne 0 -or $changes) { throw 'WTL sources must be unmodified' }
$buildPath = Join-Path $root 'build/wtl-prototype'
& $cmake -S (Join-Path $root 'prototypes/wtl') -B $buildPath -G 'Visual Studio 17 2022' -A x64 "-DWTL_ROOT=$cache"
if ($LASTEXITCODE -ne 0) { throw 'WTL prototype configuration failed' }
& $cmake --build $buildPath --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'WTL prototype compilation failed' }
$output = Join-Path $buildPath 'Release'
Copy-Item -LiteralPath (Join-Path $cache 'Notes/MS-PL.txt') -Destination (Join-Path $output 'WTL-MS-PL.txt')
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $output 'LICENSE')
$binary = Join-Path $output 'otorrent-wtl-prototype.exe'
$metadata = @{
  kind = 'UI prototype - synthetic data, no engine'; platform = 'x64'; configuration = 'Release'; crt = 'static (/MT)'
  wtlCommit = $revision; bytes = (Get-Item -LiteralPath $binary).Length
  sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $binary).Hash.ToLowerInvariant()
}
$metadata | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $output 'prototype-build.json')
Write-Output "Built: $binary ($($metadata.bytes) bytes)"
# Building does not start the program or run any tests.
