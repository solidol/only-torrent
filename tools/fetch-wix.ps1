param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$archive = Join-Path $root 'build/wix314-binaries.zip'
$destination = Join-Path $root 'build/wix314'
$expected = '6ac824e1642d6f7277d0ed7ea09411a508f6116ba6fae0aa5f2c7daa2ff43d31'
New-Item -ItemType Directory -Force (Split-Path $archive -Parent) | Out-Null
if (-not (Test-Path -LiteralPath $archive)) {
  Invoke-WebRequest -UseBasicParsing 'https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip' -OutFile $archive
}
if ((Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant() -ne $expected) { throw 'WiX archive checksum mismatch' }
Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
Write-Output "WiX 3.14.1 ready: $destination"
