@echo off
setlocal

set "STEAM_EXE=C:\Program Files (x86)\Steam\steam.exe"
set "STEAM_INSTALLER=C:\DeadlockSetup\SteamSetup.exe"

if exist "%STEAM_EXE%" goto launch

if not exist "%STEAM_INSTALLER%" (
  echo SteamSetup.exe is missing from C:\DeadlockSetup.
  echo Reinstall Deadlock Runner from the original DMG.
  pause
  exit /b 2
)

start /wait "Steam Setup" "%STEAM_INSTALLER%" /S

if not exist "%STEAM_EXE%" (
  echo Steam did not finish installing.
  echo Open Deadlock Runner again to retry setup.
  pause
  exit /b 3
)

:launch
start "Steam" "%STEAM_EXE%"
exit /b 0
