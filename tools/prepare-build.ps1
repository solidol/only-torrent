param([Parameter(Mandatory=$true)][string]$ResourceCompiler)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot/version.ps1" -NextBuild
$rc = [IO.File]::ReadAllText((Join-Path $root 'resources/otorrent.rc'))
$start = $rc.IndexOf('1 VERSIONINFO')
if ($start -lt 0) { throw 'Missing VERSIONINFO template' }
$build = Join-Path $root 'build'
New-Item -ItemType Directory -Force $build | Out-Null
$source = Join-Path $build 'Ot.Version.rc'
$theme = (Join-Path $root 'resources/styles/Windows10Dark.vsf').Replace('\', '/')
$themeResource = "`r`nOT_DARK_THEME RCDATA `"$theme`"`r`n"
[IO.File]::WriteAllText($source, $rc.Substring($start) + $themeResource, [Text.Encoding]::ASCII)
& $ResourceCompiler ('-fo' + (Join-Path $build 'Ot.Version.res')) $source
if ($LASTEXITCODE -ne 0) { throw 'Version resource compilation failed' }
