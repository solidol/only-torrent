param([Parameter(Mandatory=$true)][string]$Archive, [string]$Repository = 'solidol/only-torrent')
$ErrorActionPreference = 'Stop'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Install GitHub CLI and run gh auth login' }
$Archive = (Resolve-Path -LiteralPath $Archive).Path
if ([IO.Path]::GetFileName($Archive) -notmatch '^Only-Torrent-(\d+\.\d+\.\d+\.\d+)-Win64\.zip$') { throw 'Invalid release archive name' }
$version = $Matches[1]
$root = Split-Path $PSScriptRoot -Parent
$dirty = & git -c "safe.directory=$root" -C $root status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Commit and push the version and source changes first' }
$head = & git -c "safe.directory=$root" -C $root rev-parse HEAD
$remote = & git -c "safe.directory=$root" -C $root ls-remote origin refs/heads/main
if ($LASTEXITCODE -ne 0 -or ($remote -split '\s+')[0] -ne $head) { throw 'HEAD must be pushed to origin/main' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($Archive)
try {
  $entry = $zip.GetEntry('release.json')
  if (-not $entry) { throw 'Missing release manifest' }
  $reader = [IO.StreamReader]::new($entry.Open())
  try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
} finally { $zip.Dispose() }
if ($manifest.version -ne $version -or -not $manifest.sourceFiles) { throw 'Invalid source manifest' }
$tracked = @(& git -c "safe.directory=$root" -c core.quotepath=false -C $root ls-files)
if ($LASTEXITCODE -ne 0 -or $tracked.Count -ne @($manifest.sourceFiles.PSObject.Properties).Count) { throw 'Tracked source set changed; rebuild' }
foreach ($file in $tracked) {
  $record = $manifest.sourceFiles.PSObject.Properties[$file]
  if (-not $record -or (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root $file)).Hash -ne $record.Value) { throw "Source changed since build: $file" }
}
$checksum = $Archive + '.sha256'
if (-not (Test-Path -LiteralPath $checksum)) { throw 'Missing checksum' }
$expected = (Get-Content -Raw $checksum).Split(' ')[0]
if ((Get-FileHash -Algorithm SHA256 $Archive).Hash -ne $expected) { throw 'Archive checksum mismatch' }
$installer = [IO.Path]::ChangeExtension($Archive, '.msi')
$installerChecksum = $installer + '.sha256'
if (-not (Test-Path -LiteralPath $installer) -or -not (Test-Path -LiteralPath $installerChecksum)) { throw 'Missing MSI installer or checksum' }
$expectedInstaller = (Get-Content -Raw $installerChecksum).Split(' ')[0]
if ((Get-FileHash -Algorithm SHA256 $installer).Hash -ne $expectedInstaller) { throw 'Installer checksum mismatch' }
& gh release create "v$version" $Archive $checksum $installer $installerChecksum --repo $Repository --target $head --title "Only Torrent $version" --draft --generate-notes
if ($LASTEXITCODE -ne 0) { throw 'GitHub draft creation failed' }
