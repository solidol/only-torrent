param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$target=Join-Path $root 'build/update-client-fixture'
New-Item -ItemType Directory -Force $target | Out-Null
$dev='C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat'
$source=Join-Path $root 'tests/update-client-fixture.cpp'
$batch=Join-Path $target 'build-fixture.cmd'
$lines=@('@echo off',('call "'+$dev+'" -arch=x64 -host_arch=x64 >nul'),'if errorlevel 1 exit /b 1',('cl.exe /nologo /O1 /MT /EHsc /utf-8 /DUNICODE /D_UNICODE "'+$source+'" /Fo"'+$target+'\fixture.obj" /Fe"'+$target+'\fixture.exe" /link /SUBSYSTEM:WINDOWS user32.lib advapi32.lib'))
[IO.File]::WriteAllLines($batch,$lines,[Text.Encoding]::Default)
& cmd.exe /d /c $batch
if($LASTEXITCODE -ne 0){throw 'Update fixture build failed'}
