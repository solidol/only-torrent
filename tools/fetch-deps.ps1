$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$workspacePath = Split-Path $PSScriptRoot -Parent
Set-Location $workspacePath
$config = Get-Content -Raw -Encoding UTF8 native/dependencies.json | ConvertFrom-Json
New-Item -ItemType Directory -Force deps | Out-Null
$depsRoot = [IO.Path]::GetFullPath((Join-Path $workspacePath 'deps')) + [IO.Path]::DirectorySeparatorChar
foreach ($package in @($config.libtorrent, $config.boost)) {
  $archivePath = [IO.Path]::GetFullPath((Join-Path $workspacePath $package.archive))
  $sourcePath = [IO.Path]::GetFullPath((Join-Path $workspacePath $package.source))
  if (-not $archivePath.StartsWith($depsRoot, [StringComparison]::OrdinalIgnoreCase) -or
      -not $sourcePath.StartsWith($depsRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Dependencies must stay inside workspace deps' }
  if (-not (Test-Path -LiteralPath $archivePath)) {
    Invoke-WebRequest -UseBasicParsing $package.url -OutFile $archivePath
  }
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash -ne $package.sha256) {
    throw "SHA-256 mismatch: $archivePath"
  }
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    & tar.exe -xzf $archivePath -C deps
    if ($LASTEXITCODE -ne 0) { throw "Archive extraction failed: $archivePath" }
    if ($package -eq $config.libtorrent) { $extractedName = 'libtorrent-' + $package.version }
    else { $extractedName = 'boost_' + $package.version.Replace('.','_') }
    $extractedPath = [IO.Path]::GetFullPath((Join-Path (Join-Path $workspacePath 'deps') $extractedName))
    if (-not $extractedPath.StartsWith($depsRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid extraction path' }
    if ($extractedPath -ne $sourcePath) { Move-Item -LiteralPath $extractedPath -Destination $sourcePath }
  }
}
python tests/upstream_integrity.py
if ($LASTEXITCODE -ne 0) { throw 'Original libtorrent source verification failed' }
Write-Output 'Pinned upstream dependencies are ready.'
