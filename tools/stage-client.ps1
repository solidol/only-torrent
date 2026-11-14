param([string]$Folder = 'bin/Win64', [string]$Executable = 'build/persistence-candidate/otorrent.exe')
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
Set-Location $workspacePath
$destinationPath = [IO.Path]::GetFullPath((Join-Path $workspacePath $Folder))
$executablePath = [IO.Path]::GetFullPath((Join-Path $workspacePath $Executable))
$clientPath = [IO.Path]::GetFullPath((Join-Path $destinationPath 'otorrent.exe'))
$runningClient = Get-Process otorrent -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $clientPath }
if ($runningClient) { throw 'Close the client in the destination folder before updating it.' }
if (-not (Test-Path -LiteralPath $executablePath)) { throw "Missing executable: $executablePath" }
& (Join-Path $PSScriptRoot 'copy-runtime.ps1') -VerifyOnly
New-Item -ItemType Directory -Force $destinationPath | Out-Null
if ($executablePath -ne $clientPath) { Copy-Item -LiteralPath $executablePath -Destination $clientPath }
& (Join-Path $PSScriptRoot 'copy-runtime.ps1') -Destination $destinationPath
$runtime = Get-Content -Raw -Encoding UTF8 (Join-Path $destinationPath 'runtime.json') | ConvertFrom-Json
$manifest = @{ bridgeAbi = 2; storageSchema = 1; sqlite = $runtime.versions.sqlite; files = @{} }
if (Test-Path -LiteralPath (Join-Path $destinationPath 'otupdater.exe')) {
  $manifest.files['otupdater.exe'] = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $destinationPath 'otupdater.exe')).Hash.ToLowerInvariant()
}
foreach ($fileName in @('otorrent.exe','ltbridge.dll','torrent-rasterbar.dll','sqlite3.dll','Languages/uk-UA.json','Languages/en-US.json')) {
  $manifest.files[$fileName] = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $destinationPath $fileName)).Hash.ToLowerInvariant()
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $destinationPath 'client-build.json')
Write-Output "Client package ready: $clientPath"
