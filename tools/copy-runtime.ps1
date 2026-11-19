param([string]$Destination = 'bin/Win64', [switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
$runtimePath = [IO.Path]::GetFullPath((Join-Path $workspacePath 'third_party/bin/Win64'))
$manifestPath = Join-Path $runtimePath 'runtime.json'
$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
if ($manifest.format -ne 1 -or $manifest.platform -ne 'Win64' -or $manifest.bridgeAbi -ne 2) { throw 'Unsupported bundled runtime' }
foreach ($required in @('ltbridge.dll','torrent-rasterbar.dll','engine-build.json','licenses/libtorrent-LICENSE.txt','licenses/boost-LICENSE.txt','licenses/THIRD_PARTY.md')) {
  if ($null -eq $manifest.files.PSObject.Properties[$required]) { throw "Missing runtime manifest entry: $required" }
}
# Validate the COMPLETE bundle before copying any file. No source trees, SDKs,
# downloads, CMake, Python or C++ toolchains participate in this operation.
foreach ($entry in $manifest.files.PSObject.Properties) {
  $source = [IO.Path]::GetFullPath((Join-Path $runtimePath $entry.Name))
  if (-not $source.StartsWith($runtimePath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid runtime path' }
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ne $entry.Value) { throw "Runtime SHA-256 mismatch: $($entry.Name)" }
}
if ($VerifyOnly) { Write-Output 'PASS: pinned runtime files and SHA-256'; return }
if ([IO.Path]::IsPathRooted($Destination)) { $targetPath = [IO.Path]::GetFullPath($Destination) }
else { $targetPath = [IO.Path]::GetFullPath((Join-Path $workspacePath $Destination)) }
if ($targetPath -eq $runtimePath) { throw 'Build output must differ from the pinned runtime folder' }
foreach ($entry in $manifest.files.PSObject.Properties) {
  $target = Join-Path $targetPath $entry.Name
  if ((Test-Path -LiteralPath $target) -and (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash -eq $entry.Value) { continue }
  New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
  Copy-Item -LiteralPath (Join-Path $runtimePath $entry.Name) -Destination $target
}
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $targetPath 'runtime.json')
$languageFolder = Join-Path $targetPath 'Languages'
New-Item -ItemType Directory -Force $languageFolder | Out-Null
Get-ChildItem -LiteralPath (Join-Path $workspacePath 'Languages') -Filter '*.json' -File | Copy-Item -Destination $languageFolder
# Keep the existing runtime filename so previously released updaters can still
# install this package. The editable source is the separate bilingual ABOUT.md.
Copy-Item -LiteralPath (Join-Path $workspacePath 'ABOUT.md') -Destination (Join-Path $targetPath 'README.md')
Write-Output "Runtime ready: $targetPath"
