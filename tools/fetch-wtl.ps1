$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$dependency = (Get-Content -Raw -Encoding UTF8 (Join-Path $root 'prototypes/wtl/dependencies.json') | ConvertFrom-Json).wtl
$destination = Join-Path $root $dependency.cache
if (-not (Test-Path -LiteralPath (Join-Path $destination '.git'))) {
  if (Test-Path -LiteralPath $destination) { throw "Choose an empty cache path: $destination" }
  & git -c http.sslBackend=schannel clone --no-checkout --depth 1 $dependency.repository $destination
  if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch WTL' }
  & git -C $destination -c http.sslBackend=schannel fetch --depth 1 origin $dependency.commit
  if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch pinned WTL commit' }
  & git -C $destination checkout --detach $dependency.commit
  if ($LASTEXITCODE -ne 0) { throw 'Cannot check out pinned WTL commit' }
}
$revision = & git -C $destination rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision -ne $dependency.commit) { throw 'WTL revision differs from dependencies.json' }
$changes = & git -C $destination status --porcelain
if ($LASTEXITCODE -ne 0 -or $changes) { throw 'WTL source has local changes' }
Write-Output "Original WTL ready: $revision"
