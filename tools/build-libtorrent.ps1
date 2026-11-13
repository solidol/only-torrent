# No source edits or injected functions are permitted in libtorrent.
param([string]$SourcePath, [string]$SdkPath)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
Set-Location $workspacePath
$dependencyConfig = Get-Content -Raw -Encoding UTF8 native/dependencies.json | ConvertFrom-Json
if (-not $SourcePath) { $SourcePath = Join-Path $workspacePath $dependencyConfig.libtorrent.source }
if (-not $SdkPath) { $SdkPath = Join-Path $workspacePath ('deps/libtorrent-sdk/' + $dependencyConfig.libtorrent.version) }
python tests/upstream_integrity.py $SourcePath
if ($LASTEXITCODE -ne 0) { throw 'libtorrent must match its original pinned archive' }
$cmake = Get-Command cmake.exe -ErrorAction SilentlyContinue
if ($cmake) { $cmakePath = $cmake.Source } else {
  $cmakePath = 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
}
$boostRoot = Join-Path $workspacePath $dependencyConfig.boost.source
$nativeBuild = Join-Path $workspacePath ('build/libtorrent-' + $dependencyConfig.libtorrent.version)
# Configure the upstream project DIRECTLY. The SDK contains its original CMake exports.
& $cmakePath -S $SourcePath -B $nativeBuild -A x64 -T $dependencyConfig.toolset `
  '-DBUILD_SHARED_LIBS=ON' '-Dstatic_runtime=OFF' `
  '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL' "-DBOOST_ROOT=$boostRoot" `
  "-DBOOST_INCLUDEDIR=$boostRoot" '-DBoost_NO_SYSTEM_PATHS=ON' `
  '-Dbuild_tests=OFF' '-Dbuild_examples=OFF' '-Dbuild_tools=OFF' '-Dpython-bindings=OFF' `
  '-Dencryption=ON' '-Ddeprecated-functions=ON' '-DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON' `
  '-DCMAKE_DISABLE_FIND_PACKAGE_LibGcrypt=ON' '-DCMAKE_DISABLE_FIND_PACKAGE_Iconv=ON' `
  "-DCMAKE_INSTALL_PREFIX=$SdkPath"
if ($LASTEXITCODE -ne 0) { throw 'Upstream libtorrent configure failed' }
& $cmakePath --build $nativeBuild --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Upstream libtorrent build failed' }
& $cmakePath --install $nativeBuild --config Release
if ($LASTEXITCODE -ne 0) { throw 'Upstream libtorrent SDK install failed' }
Write-Output "Original libtorrent SDK: $SdkPath"
