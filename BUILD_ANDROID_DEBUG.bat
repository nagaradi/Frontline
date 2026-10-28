@echo off
setlocal
title Frontline Android Debug APK Export
set "GODOT_EXE=godot"
set "PROJECT_DIR=%~dp0"
set "APK_PATH=%PROJECT_DIR%Frontline-debug.apk"

if not exist "%PROJECT_DIR%project.godot" (
  echo ERROR: project.godot is not in this folder.
  echo Extract this ZIP and run this file from the extracted project folder.
  pause
  exit /b 1
)

if not exist "%PROJECT_DIR%export_presets.cfg" (
  echo Android export preset is not configured yet.
  echo Open this project in Godot, go to Project ^> Export, add an Android preset named Android,
  echo configure export templates and Android SDK/JDK, then save the project.
  echo Then run this script again.
  pause
  exit /b 2
)

where godot >nul 2>nul
if errorlevel 1 (
  echo Godot command was not found in PATH.
  echo Edit this BAT file and set GODOT_EXE to the full path of Godot_v4.7.2-stable_win64_console.exe
  echo Example: set "GODOT_EXE=C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
  pause
  exit /b 3
)

echo Exporting Android debug APK...
"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --export-debug "Android" "%APK_PATH%"
if errorlevel 1 (
  echo.
  echo EXPORT FAILED. Copy the first error shown above and send it for help.
  pause
  exit /b 4
)

echo.
echo Export complete: "%APK_PATH%"
echo Transfer this APK to your Android phone and install it for testing.
pause
