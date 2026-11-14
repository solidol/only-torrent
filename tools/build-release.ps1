param([switch]$NextRelease, [switch]$Draft, [string]$Repository = 'solidol/only-torrent')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
  $untracked = & git -c "safe.directory=$root" ls-files --others --exclude-standard
  if ($LASTEXITCODE -ne 0 -or $untracked) { throw 'Add new source files to Git before building a release' }
  # Reserve a release only on explicit request. Build numbers are reserved by the DPROJ target.
  if ($NextRelease) { & "$PSScriptRoot/version.ps1" -NextRelease }
  & "$PSScriptRoot/copy-runtime.ps1" -VerifyOnly
  $package = 'build/release-' + [Guid]::NewGuid().ToString('N')
  & "$PSScriptRoot/build-ide.ps1" -OutputDirectory $package
  $v = Get-Content -Raw version.json | ConvertFrom-Json
  $number = '{0}.{1}.{2}.{3}' -f $v.major,$v.minor,$v.release,$v.build
  $tag = 'v' + $number
  $exe = Join-Path $package 'otorrent.exe'
  if ([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $root $exe)).FileVersion -ne $number) { throw 'Executable version differs from version.json' }
  & "$PSScriptRoot/stage-client.ps1" -Folder $package -Executable $exe
  Copy-Item version.json (Join-Path $package 'version.json')
  foreach ($name in @('README.md','LICENSE')) {
    if (Test-Path -LiteralPath $name) { Copy-Item -LiteralPath $name -Destination $package }
  }
  $commit = & git -c "safe.directory=$root" rev-parse HEAD
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read source commit' }
  $sourceFiles = @{}
  $tracked = & git -c "safe.directory=$root" -c core.quotepath=false ls-files
  if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate source files' }
  foreach ($file in $tracked) { $sourceFiles[$file] = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant() }
  @{version=$number; sourceCommit=$commit; sourceFiles=$sourceFiles; platform='Win64'; builtUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $package 'release.json')
  $archive = Join-Path $root "build/Only-Torrent-$number-Win64.zip"
  if (Test-Path -LiteralPath $archive) { throw "Archive already exists: $archive" }
  Compress-Archive -Path "$package/*" -DestinationPath $archive
  $checksum = $archive + '.sha256'
  ((Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($archive)) | Set-Content -Encoding ASCII $checksum
  Write-Output "Release package: $archive"
  if ($Draft) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Package ready. Install/authenticate GitHub CLI to create a draft.' }
    # Commit the reserved version first, so the tag identifies the exact source version.
    $dirty = & git -c "safe.directory=$root" status --porcelain
    if ($dirty) { throw 'Package ready. Commit and push source/version changes, then use publish-release.ps1.' }
    & "$PSScriptRoot/publish-release.ps1" -Archive $archive -Repository $Repository
  }
} finally { Pop-Location }
