param(
  [Parameter(Mandatory=$true)][string]$QtRoot,
  [switch]$Deploy
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$qtPath = (Resolve-Path -LiteralPath $QtRoot).Path
foreach ($required in @('lib/cmake/Qt6/Qt6Config.cmake','lib/Qt6Core.lib','bin/Qt6Core.dll','bin/Qt6Gui.dll','bin/Qt6Widgets.dll')) {
  if (-not (Test-Path -LiteralPath (Join-Path $qtPath $required))) { throw "Choose a shared MSVC x64 Qt 6 kit; missing $required" }
}
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio C++ tools' }
$visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $visualStudio) { throw 'Install Visual Studio C++ tools' }
$cmake = Join-Path $visualStudio 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
if (-not (Test-Path -LiteralPath $cmake)) { $cmake = (Get-Command cmake.exe -ErrorAction Stop).Source }
$build = Join-Path $root 'build/qt-prototype'
& $cmake -S (Join-Path $root 'prototypes/qt') -B $build -G 'Visual Studio 17 2022' -A x64 "-DCMAKE_PREFIX_PATH=$qtPath"
if ($LASTEXITCODE -ne 0) { throw 'Qt prototype configuration failed' }
& $cmake --build $build --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Qt prototype compilation failed' }
$output = Join-Path $build 'Release'
$executable = Join-Path $output 'otorrent-qt-prototype.exe'
if ($Deploy) {
  $deployQt = Join-Path $qtPath 'bin/windeployqt.exe'
  if (-not (Test-Path -LiteralPath $deployQt)) { throw 'Missing windeployqt.exe in this Qt kit' }
  $previousPath = $env:Path
  try {
    $env:Path = (Join-Path $qtPath 'bin') + ';' + $env:Path
    & $deployQt --release --no-translations --no-opengl-sw --compiler-runtime --dir $output $executable
    if ($LASTEXITCODE -ne 0) { throw 'Qt deployment failed' }
  } finally { $env:Path = $previousPath }
  if (Test-Path -LiteralPath (Join-Path $qtPath 'LICENSES')) {
    Copy-Item -LiteralPath (Join-Path $qtPath 'LICENSES') -Destination (Join-Path $output 'Qt-LICENSES') -Recurse -Force
  }
}
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $output 'LICENSE')
$packageBytes = (Get-ChildItem -LiteralPath $output -File -Recurse | Measure-Object Length -Sum).Sum
@{
  kind='Qt Widgets UI prototype - synthetic data, no engine'; platform='x64'; configuration='Release'
  qtRoot=$qtPath; runtimeCopied=[bool]$Deploy; bytes=(Get-Item -LiteralPath $executable).Length
  folderBytes=$packageBytes; sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $executable).Hash.ToLowerInvariant()
} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $output 'prototype-build.json')
Write-Output "Built: $executable"
# No Qt downloads, application launch, tests or changes to the released client.
