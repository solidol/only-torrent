param(
  [Parameter(Mandatory=$true)][string]$EnginePackage,
  [Parameter(Mandatory=$true)][string]$SqliteDll,
  [string]$SqliteVersion = '3.54.1'
)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
$sourcePath = [IO.Path]::GetFullPath((Join-Path $workspacePath $EnginePackage))
$sqlitePath = [IO.Path]::GetFullPath((Join-Path $workspacePath $SqliteDll))
$engineManifest = Get-Content -Raw -Encoding UTF8 (Join-Path $sourcePath 'engine-build.json') | ConvertFrom-Json
if ($engineManifest.platform -ne 'Win64' -or $engineManifest.bridgeAbi -ne 2) { throw 'Unsupported runtime ABI/platform' }
foreach ($fileName in @('ltbridge.dll','torrent-rasterbar.dll')) {
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $sourcePath $fileName)).Hash.ToLowerInvariant()
  if ($actual -ne $engineManifest.files.$fileName) { throw "Engine package checksum mismatch: $fileName" }
}
if (-not (Test-Path -LiteralPath $sqlitePath)) { throw "Missing SQLite DLL: $sqlitePath" }
$runtimePath = Join-Path $workspacePath 'third_party/bin/Win64'
New-Item -ItemType Directory -Force $runtimePath,(Join-Path $runtimePath 'licenses') | Out-Null
foreach ($fileName in @('ltbridge.dll','torrent-rasterbar.dll','engine-build.json')) {
  Copy-Item -LiteralPath (Join-Path $sourcePath $fileName) -Destination (Join-Path $runtimePath $fileName)
}
Copy-Item -LiteralPath $sqlitePath -Destination (Join-Path $runtimePath 'sqlite3.dll')
Get-ChildItem -LiteralPath (Join-Path $sourcePath 'licenses') -File | Copy-Item -Destination (Join-Path $runtimePath 'licenses')
Copy-Item -LiteralPath (Join-Path $workspacePath 'LICENSE'),(Join-Path $workspacePath 'THIRD_PARTY.md') -Destination (Join-Path $runtimePath 'licenses')
$manifest = @{
  format = 1; platform = 'Win64'; bridgeAbi = 2
  versions = @{ libtorrent = $engineManifest.libtorrent; boost = $engineManifest.boost; sqlite = $SqliteVersion }
  compiler = @{ toolset = $engineManifest.toolset; runtime = $engineManifest.runtime }
  files = @{}
}
foreach ($file in Get-ChildItem -LiteralPath $runtimePath -Recurse -File) {
  if ($file.Name -eq 'runtime.json') { continue }
  $relativePath = $file.FullName.Substring(([IO.Path]::GetFullPath($runtimePath)).Length + 1).Replace('\','/')
  $manifest.files[$relativePath] = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $runtimePath 'runtime.json')
Write-Output "Pinned runtime published: $runtimePath"
