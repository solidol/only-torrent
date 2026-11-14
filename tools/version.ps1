param([switch]$NextRelease, [switch]$NextBuild)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$mutex = [Threading.Mutex]::new($false, 'Local\OnlyTorrent.Version')
$owned = $false
try {
  try { $owned = $mutex.WaitOne(30000) } catch [Threading.AbandonedMutexException] { $owned = $true }
  if (-not $owned) { throw 'Version file is busy' }
  $path = Join-Path $root 'version.json'
  $v = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
  foreach ($key in @('major','minor','release','build')) {
    if ($null -eq $v.$key -or "$($v.$key)" -notmatch '^\d+$' -or $v.$key -gt 65535) { throw "Invalid version field: $key" }
  }
  if ($v.release -lt 1 -or $v.release -gt 10) { throw 'Release must be 1..10' }
  if ($NextRelease) {
    if ($v.release -eq 10) { $v.minor++; $v.release = 1 } else { $v.release++ }
  }
  if ($NextBuild) { $v.build++ }
  if ($v.minor -gt 65535 -or $v.build -gt 65535) { throw 'Windows VERSIONINFO field exceeds 65535; no counter was reset' }
  $number = '{0}.{1}.{2}.{3}' -f $v.major,$v.minor,$v.release,$v.build
  $utf8 = [Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllText($path, ($v | ConvertTo-Json) + "`r`n", $utf8)
  $projectPath = Join-Path $root 'otorrent.dproj'
  $project = [IO.File]::ReadAllText($projectPath)
  foreach ($pair in @(@('MajorVer','major'),@('MinorVer','minor'),@('Release','release'),@('Build','build'))) {
    $project = [regex]::Replace($project, '<VerInfo_' + $pair[0] + '>\d+</VerInfo_' + $pair[0] + '>', '<VerInfo_' + $pair[0] + '>' + $v.($pair[1]) + '</VerInfo_' + $pair[0] + '>')
  }
  $project = [regex]::Replace($project, '(FileVersion|ProductVersion)=[^;<]+', '${1}=' + $number)
  [IO.File]::WriteAllText($projectPath, $project, [Text.UTF8Encoding]::new($true))
  $rcPath = Join-Path $root 'resources/otorrent.rc'
  $rc = [IO.File]::ReadAllText($rcPath)
  $rc = [regex]::Replace($rc, '(?m)^(FILEVERSION|PRODUCTVERSION) .+$', '${1} ' + $number.Replace('.',','))
  $rc = [regex]::Replace($rc, '(VALUE "(?:FileVersion|ProductVersion)", ")[^"\\]+', '${1}' + $number)
  [IO.File]::WriteAllText($rcPath, $rc, $utf8)
  Write-Output $number
} finally {
  if ($owned) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
}
