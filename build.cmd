@echo off
setlocal
if not defined BDS set "BDS=C:\Program Files (x86)\Embarcadero\Studio\37.0"
if not exist build\dcu mkdir build\dcu
if not exist bin\Win64 mkdir bin\Win64
"%BDS%\bin\brcc32.exe" -foqstorrent.res resources\qstorrent.rc
if errorlevel 1 exit /b 1
"%BDS%\bin\dcc64.exe" -B -Q -TX.exe -$O+ -$D- -$L- -$Y- -NSSystem;Winapi;Vcl;System.Win -U"%BDS%\lib\win64\release;src\ui;src\engine;src\core" -I"%BDS%\include" -Ebin\Win64 -N0build\dcu qstorrent.dpr
if errorlevel 1 exit /b 1
if not exist bin\Win64\qstorrent.exe (
  echo No executable produced. Community Edition may require building in the IDE.
  exit /b 2
)
exit /b 0
