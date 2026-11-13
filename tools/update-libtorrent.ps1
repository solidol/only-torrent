param(
  [Parameter(Mandatory=$true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
  [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$Sha256,
  [switch]$BuildPackage
)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
Set-Location $workspacePath
$configPath = Join-Path $workspacePath 'native/dependencies.json'
$previousBytes = [IO.File]::ReadAllBytes($configPath)
$config = Get-Content -Raw -Encoding UTF8 $configPath | ConvertFrom-Json
$config.libtorrent.version = $Version
$config.libtorrent.source = 'deps/libtorrent-' + $Version
$config.libtorrent.archive = 'deps/libtorrent-' + $Version + '.tar.gz'
$config.libtorrent.url = 'https://codeload.github.com/arvidn/libtorrent/tar.gz/refs/tags/v' + $Version
$config.libtorrent.sha256 = $Sha256.ToLowerInvariant()
# Keep a reviewable previous lockfile. No old sources or SDKs are removed.
New-Item -ItemType Directory -Force (Join-Path $workspacePath 'build') | Out-Null
Copy-Item -LiteralPath $configPath -Destination build/dependencies.previous.json
try {
  $config | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $configPath
  & (Join-Path $PSScriptRoot 'fetch-deps.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'Dependency preparation failed' }
} catch {
  [IO.File]::WriteAllBytes($configPath, $previousBytes)
  throw
}
if ($BuildPackage) {
  & (Join-Path $PSScriptRoot 'build-engine.ps1') -NoDeploy
  if ($LASTEXITCODE -ne 0) { throw 'Candidate package build failed' }
}
Write-Output 'Dependency lock updated. Build and test the candidate DLL package; the Delphi EXE is unchanged.'
