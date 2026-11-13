param([switch]$UiTests)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
$idePath = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin64\bds.exe'
if ($UiTests) {
  $workingPath = Join-Path $workspacePath 'tests'
  $mainSource = 'QsUiSmoke.dpr'
  $errorLog = Join-Path $workingPath 'QsUiSmoke.err'
  $binaryPath = Join-Path $workspacePath 'bin\Win64\QsUiSmoke.exe'
} else {
  $workingPath = $workspacePath
  $mainSource = 'qstorrent.dpr'
  $errorLog = Join-Path $workingPath 'qstorrent.err'
  $binaryPath = Join-Path $workspacePath 'bin\Win64\qstorrent.exe'
}
$buildStart = Get-Date
# DPR first: verified with Delphi 13 CE's IDE AutoBuild.
$ideProcess = Start-Process -FilePath $idePath -ArgumentList $mainSource,'-b','-ns' -WorkingDirectory $workingPath -WindowStyle Hidden -PassThru
$ideProcess.WaitForExit()
if (Test-Path -LiteralPath $errorLog) {
  Get-Content -LiteralPath $errorLog | Select-String '\[dcc|Success|Failed|Elapsed'
}
if ($ideProcess.ExitCode -ne 0) { throw "IDE build failed, exit $($ideProcess.ExitCode). See $errorLog" }
if (-not (Test-Path -LiteralPath $binaryPath) -or (Get-Item -LiteralPath $binaryPath).LastWriteTime -lt $buildStart.AddSeconds(-2)) {
  throw "IDE did not produce a fresh executable. See $errorLog"
}
Write-Output "Built: $binaryPath"
