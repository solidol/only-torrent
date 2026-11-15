param([Parameter(Mandatory=$true)][string]$Installer)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$installerPath = (Resolve-Path -LiteralPath $Installer).Path
if (Test-Path 'HKLM:\Software\Only Torrent') { throw 'An installed Only Torrent exists; refusing to replace it in tests.' }
$run = Join-Path $root ('build/msi-test-' + [Guid]::NewGuid().ToString('N'))
$target = Join-Path $run 'Custom folder/Only Torrent'
$profile = Join-Path $run 'profile'
New-Item -ItemType Directory -Force $profile | Out-Null
$service = New-Object -ComObject WindowsInstaller.Installer
$db = $service.OpenDatabase($installerPath, 0)
function Query([string]$sql) {
  $view = $db.OpenView($sql); [void]$view.Execute(); $record = $view.Fetch()
  try { if ($record) { $record.StringData(1) } }
  finally { [void]$view.Close() }
}
$product = Query "SELECT ``Value`` FROM ``Property`` WHERE ``Property``='ProductCode'"
if (((Query "SELECT ``DefaultDir`` FROM ``Directory`` WHERE ``Directory``='INSTALLFOLDER'") -split '\|')[-1] -ne 'Only Torrent') { throw 'Wrong default install folder' }
if ((Query "SELECT ``Directory_Parent`` FROM ``Directory`` WHERE ``Directory``='INSTALLFOLDER'") -ne 'ProgramFiles64Folder') { throw 'Default install directory is not Program Files x64' }
function Msi([string]$arguments, [string]$log) {
  $process = Start-Process msiexec.exe -ArgumentList ($arguments + ' /qn /norestart /l*v "' + (Join-Path $run $log) + '"') -WindowStyle Hidden -PassThru
  if (-not $process.WaitForExit(120000)) { throw 'Windows Installer test timed out; see logs' }
  if ($process.ExitCode -notin @(0,3010)) { throw "MSI exit $($process.ExitCode): $log" }
}
function ProfileSnapshot {
  $result = @{}
  foreach ($file in Get-ChildItem -LiteralPath $profile -File -Recurse) { $result[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
  $result
}
function AssertProfile($snapshot) {
  foreach ($name in $snapshot.Keys) { if (-not (Test-Path -LiteralPath $name) -or (Get-FileHash -LiteralPath $name -Algorithm SHA256).Hash -ne $snapshot[$name]) { throw "Profile changed during MSI operation: $name" } }
}
$installed = $false
try {
  Msi ('/i "' + $installerPath + '" INSTALLFOLDER="' + $target + '"') 'install.log'
  $installed = $true
  if (-not (Test-Path -LiteralPath (Join-Path $target 'otorrent.exe'))) { throw 'Custom installation folder ignored' }
  $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $target 'release.json') | ConvertFrom-Json
  foreach ($pair in $manifest.packageFiles.PSObject.Properties) {
    if ((Get-FileHash -LiteralPath (Join-Path $target $pair.Name) -Algorithm SHA256).Hash -ne $pair.Value) { throw "Installed file mismatch: $($pair.Name)" }
  }
  # Launch the real installed client from an unrelated working directory.
  $env:OT_PROFILE_DIR = $profile
  $client = Start-Process -FilePath (Join-Path $target 'otorrent.exe') -WorkingDirectory $env:TEMP -WindowStyle Hidden -PassThru
  try {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do { Start-Sleep -Milliseconds 200; $client.Refresh() } until ($client.HasExited -or $client.MainWindowHandle -ne 0 -or [DateTime]::UtcNow -gt $deadline)
    if ($client.HasExited -or $client.MainWindowHandle -eq 0) { throw 'Installed client failed to start from a different working directory' }
    [void]$client.CloseMainWindow()
    if (-not $client.WaitForExit(20000)) { throw 'Installed client did not shut down' }
  } finally { if (-not $client.HasExited) { $client.Kill() } }
  if (-not (Test-Path -LiteralPath (Join-Path $profile 'tasks.db'))) { throw 'Client did not create its user-profile database' }
  New-Item -ItemType Directory -Force (Join-Path $profile 'Torrents') | Out-Null
  [IO.File]::WriteAllText((Join-Path $profile 'Torrents/preserve.torrent'), 'managed torrent preservation marker')
  $before = ProfileSnapshot
  Msi ('/i "' + $installerPath + '" REINSTALL=ALL REINSTALLMODE=vomus') 'reinstall.log'
  AssertProfile $before
  Msi ('/x ' + $product) 'uninstall.log'
  $installed = $false
  AssertProfile $before
  if (Test-Path -LiteralPath (Join-Path $target 'otorrent.exe')) { throw 'Client executable remains after uninstall' }
  Msi ('/i "' + $installerPath + '" INSTALLFOLDER="' + $target + '"') 'install-again.log'
  $installed = $true
  AssertProfile $before
  Write-Output 'PASS: MSI default Program Files folder, custom install, all payload hashes, client startup from unrelated CWD, reinstall/uninstall/install preserve INI, SQLite and managed torrent data'
} finally {
  if ($installed) { Msi ('/x ' + $product) 'cleanup.log' }
  Remove-Item Env:OT_PROFILE_DIR -ErrorAction SilentlyContinue
}
