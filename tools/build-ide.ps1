param([switch]$UiTests, [switch]$CoreTests, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
$idePath = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin64\bds.exe'
. (Join-Path $PSScriptRoot 'wait-ide-build.ps1')
if ($UiTests -and $CoreTests) { throw 'Choose UiTests or CoreTests' }
if ($CoreTests) {
  & python (Join-Path $workspacePath 'tests/prepare_core_fixture.py')
  if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare synthetic test fixture' }
  $workingPath = Join-Path $workspacePath 'tests'
  $mainSource = 'OtCoreTests.dpr'
  $errorLog = Join-Path $workingPath 'OtCoreTests.err'
  $binaryPath = Join-Path $workspacePath 'bin\Win64\OtCoreTests.exe'
} elseif ($UiTests) {
  $workingPath = Join-Path $workspacePath 'tests'
  $mainSource = 'OtUiSmoke.dpr'
  $errorLog = Join-Path $workingPath 'OtUiSmoke.err'
  $binaryPath = Join-Path $workspacePath 'bin\Win64\OtUiSmoke.exe'
} else {
  $workingPath = $workspacePath
  $mainSource = 'otorrent.dpr'
  $errorLog = Join-Path $workingPath 'otorrent.err'
  $binaryPath = Join-Path $workspacePath 'bin\Win64\otorrent.exe'
}
# IDE AutoBuild instances share environment.proj. Serialize across all scripts.
$buildMutex = [Threading.Mutex]::new($false, 'Local\Only Torrent.DelphiAutoBuild')
$ownsBuild = $false
$previousProject = $null
$ideProcess = $null
try {
  try { $ownsBuild = $buildMutex.WaitOne(30000) }
  catch [Threading.AbandonedMutexException] { $ownsBuild = $true }
  if (-not $ownsBuild) { throw 'Another Delphi build is still running. Retry after it finishes.' }
$projectPath = Join-Path $workingPath ([IO.Path]::ChangeExtension($mainSource, '.dproj'))
$previousProject = $null
if ($OutputDirectory) {
  $destinationPath = [IO.Path]::GetFullPath((Join-Path $workspacePath $OutputDirectory))
  New-Item -ItemType Directory -Force $destinationPath | Out-Null
  $previousProject = [IO.File]::ReadAllBytes($projectPath)
  $projectText = [IO.File]::ReadAllText($projectPath)
  $escapedDestination = [System.Security.SecurityElement]::Escape($destinationPath)
  $projectText = [regex]::Replace($projectText, '<DCC_ExeOutput>[^<]*</DCC_ExeOutput>', '<DCC_ExeOutput>' + $escapedDestination + '</DCC_ExeOutput>')
  [IO.File]::WriteAllText($projectPath, $projectText, [Text.UTF8Encoding]::new($true))
  $binaryPath = Join-Path $destinationPath ([IO.Path]::ChangeExtension($mainSource, '.exe'))
}
& (Join-Path $PSScriptRoot 'copy-runtime.ps1') -VerifyOnly
$buildStart = Get-Date
# DPR first: verified with Delphi 13 CE's IDE AutoBuild.
$ideProcess = Start-Process -FilePath $idePath -ArgumentList $mainSource,'-b','-ns' -WorkingDirectory $workingPath -WindowStyle Hidden -PassThru
Wait-OtIdeBuild -Process $ideProcess -ErrorLog $errorLog -BuildStart $buildStart
if (Test-Path -LiteralPath $errorLog) {
  $buildLog = Get-Content -Raw -LiteralPath $errorLog
  $buildLog -split "`r?`n" | Select-String '\[dcc|\[Exec|Success|Failed|Elapsed'
  if ($buildLog -match '(?m)^Failed\s*$|^\[Exec Error\]') { throw "IDE reported a build/event failure. See $errorLog" }
}
if ($ideProcess.ExitCode -ne 0) { throw "IDE build failed, exit $($ideProcess.ExitCode). See $errorLog" }
if (-not (Test-Path -LiteralPath $binaryPath) -or (Get-Item -LiteralPath $binaryPath).LastWriteTime -lt $buildStart.AddSeconds(-2)) {
  throw "IDE did not produce a fresh executable. See $errorLog"
}
Write-Output "Built: $binaryPath"
  & (Join-Path $PSScriptRoot 'copy-runtime.ps1') -Destination (Split-Path $binaryPath -Parent)
} finally {
  try {
    if ($null -ne $ideProcess -and -not $ideProcess.HasExited) {
      # Cleanup only our AutoBuild process if monitoring itself was interrupted.
      $ideProcess.Kill()
      [void]$ideProcess.WaitForExit(5000)
    }
  } finally {
    try {
      if ($null -ne $previousProject) { [IO.File]::WriteAllBytes($projectPath, $previousProject) }
    } finally {
      if ($ownsBuild) { $buildMutex.ReleaseMutex() }
      $buildMutex.Dispose()
    }
  }
}
