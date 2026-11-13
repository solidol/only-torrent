param([switch]$RebuildLibtorrent, [string]$SdkPath, [switch]$CleanBridge, [switch]$NoDeploy)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
Set-Location $workspacePath
$config = Get-Content -Raw -Encoding UTF8 native/dependencies.json | ConvertFrom-Json
if (-not $SdkPath) { $SdkPath = Join-Path $workspacePath ('deps/libtorrent-sdk/' + $config.libtorrent.version) }
if ($RebuildLibtorrent -or -not (Test-Path -LiteralPath (Join-Path $SdkPath 'lib/cmake/LibtorrentRasterbar/LibtorrentRasterbarConfig.cmake'))) {
  & (Join-Path $PSScriptRoot 'build-libtorrent.ps1') -SdkPath $SdkPath
  if ($LASTEXITCODE -ne 0) { throw 'libtorrent SDK build failed' }
}
$cmake = Get-Command cmake.exe -ErrorAction SilentlyContinue
if ($cmake) { $cmakePath = $cmake.Source } else {
  $cmakePath = 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
}
& $cmakePath -S native -B build/bridge -A x64 -T $config.toolset "-DCMAKE_PREFIX_PATH=$SdkPath"
if ($LASTEXITCODE -ne 0) { throw 'Bridge configure failed' }
$buildArguments = @('--build','build/bridge','--config','Release','--parallel','4')
if ($CleanBridge) { $buildArguments += '--clean-first' }
& $cmakePath @buildArguments
if ($LASTEXITCODE -ne 0) { throw 'Bridge build failed' }
$packagePath = Join-Path $workspacePath ('build/engine-package/' + $config.libtorrent.version + '-Win64')
New-Item -ItemType Directory -Force $packagePath | Out-Null
$vendorDll = Join-Path $SdkPath 'bin/torrent-rasterbar.dll'
if (-not (Test-Path -LiteralPath $vendorDll)) { throw "Missing original DLL: $vendorDll" }
Copy-Item -LiteralPath build/bridge/package/qsbridge.dll -Destination (Join-Path $packagePath 'qsbridge.dll')
Copy-Item -LiteralPath $vendorDll -Destination (Join-Path $packagePath 'torrent-rasterbar.dll')
$licensePath = Join-Path $packagePath 'licenses'
New-Item -ItemType Directory -Force $licensePath | Out-Null
Copy-Item -LiteralPath (Join-Path $config.libtorrent.source 'LICENSE') -Destination (Join-Path $licensePath 'libtorrent-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $config.libtorrent.source 'COPYING') -Destination (Join-Path $licensePath 'libtorrent-COPYING.txt')
Copy-Item -LiteralPath (Join-Path $config.boost.source 'LICENSE_1_0.txt') -Destination (Join-Path $licensePath 'boost-LICENSE.txt')
Copy-Item -LiteralPath LICENSE,THIRD_PARTY.md -Destination $licensePath
$manifest = @{
  bridgeAbi = $config.bridge_abi
  libtorrent = $config.libtorrent.version
  boost = $config.boost.version
  upstreamArchiveSha256 = $config.libtorrent.sha256
  toolset = $config.toolset
  runtime = $config.runtime
  platform = 'Win64'
  files = @{}
}
foreach ($fileName in @('qsbridge.dll','torrent-rasterbar.dll')) {
  $manifest.files[$fileName] = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $packagePath $fileName)).Hash.ToLowerInvariant()
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $packagePath 'engine-build.json')
Write-Output "Engine package ready: $packagePath"
if (-not $NoDeploy) {
  $clientPath = [IO.Path]::GetFullPath((Join-Path $workspacePath 'bin/Win64/qstorrent.exe'))
  $runningClient = Get-Process -Name qstorrent -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $clientPath }
  if ($runningClient) { throw "Close qsTorrent before replacing engine DLLs. Package is ready at $packagePath" }
  New-Item -ItemType Directory -Force bin/Win64/licenses | Out-Null
  foreach ($fileName in @('qsbridge.dll','torrent-rasterbar.dll','engine-build.json')) {
    Copy-Item -LiteralPath (Join-Path $packagePath $fileName) -Destination (Join-Path 'bin/Win64' $fileName)
  }
  Get-ChildItem -LiteralPath $licensePath -File | Copy-Item -Destination bin/Win64/licenses
  Write-Output 'Deployed engine package. Delphi EXE was not rebuilt.'
}
