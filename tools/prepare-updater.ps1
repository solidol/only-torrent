param([Parameter(Mandatory=$true)][string]$ResourceCompiler)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
# The updater shares the application version; it does not reserve another build.
$v = Get-Content -Raw (Join-Path $root 'version.json') | ConvertFrom-Json
$version = '{0}.{1}.{2}.{3}' -f $v.major,$v.minor,$v.release,$v.build
$rc = [IO.File]::ReadAllText((Join-Path $root 'resources/otorrent.rc'))
$start = $rc.IndexOf('1 VERSIONINFO')
if ($start -lt 0) { throw 'Missing VERSIONINFO template' }
$rc = $rc.Substring($start).Replace('otorrent.exe','otupdater.exe').Replace('"otorrent\0"','"otupdater\0"')
$rc = $rc.Replace('"FileDescription", "Only Torrent\0"', '"FileDescription", "Only Torrent Updater\0"')
$rc = [regex]::Replace($rc, '(?m)^(FILEVERSION|PRODUCTVERSION) .+$', '${1} ' + $version.Replace('.',','))
$rc = [regex]::Replace($rc, '(VALUE "(?:FileVersion|ProductVersion)", ")[^"\\]+', '${1}' + $version)
$build = Join-Path $root 'build'
New-Item -ItemType Directory -Force $build | Out-Null
$source = Join-Path $build 'Ot.UpdaterVersion.rc'
[IO.File]::WriteAllText($source, $rc, [Text.Encoding]::ASCII)
& $ResourceCompiler ('-fo' + (Join-Path $build 'Ot.UpdaterVersion.res')) $source
if ($LASTEXITCODE -ne 0) { throw 'Updater version resource compilation failed' }
