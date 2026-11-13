$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$cmake = Get-Command cmake.exe -ErrorAction SilentlyContinue
if ($cmake) { $cmakePath = $cmake.Source }
else { $cmakePath = 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe' }
if (-not (Test-Path -LiteralPath $cmakePath)) { throw 'Install CMake 3.20+ and Visual Studio C++ Build Tools.' }
& $cmakePath -S native -B build/native -A x64
if ($LASTEXITCODE -ne 0) { throw 'CMake configure failed' }
& $cmakePath --build build/native --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Engine build failed' }

New-Item -ItemType Directory -Force bin/Win64/licenses | Out-Null
Copy-Item -LiteralPath deps/libtorrent/LICENSE -Destination bin/Win64/licenses/libtorrent-LICENSE.txt
Copy-Item -LiteralPath deps/libtorrent/COPYING -Destination bin/Win64/licenses/libtorrent-COPYING.txt
Copy-Item -LiteralPath deps/boost_1_78_0/LICENSE_1_0.txt -Destination bin/Win64/licenses/boost-LICENSE.txt
Copy-Item -LiteralPath LICENSE,THIRD_PARTY.md -Destination bin/Win64/licenses
