@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: Flutter SDK is not on PATH.
  echo Install Flutter and Visual Studio C++ Desktop Development tools first.
  pause
  exit /b 1
)
call flutter --version || goto :bad
call flutter create --platforms=windows --project-name shopdesk_flutter --no-pub . || goto :bad
if exist "test\widget_test.dart" (
  del /f /q "test\widget_test.dart"
  echo Removed invalid auto-generated widget_test.dart
)
call flutter pub get || goto :bad
call flutter analyze --no-fatal-infos --no-fatal-warnings || goto :bad
call flutter test test/store_test.dart || goto :bad
call flutter build windows --release || goto :bad
set "RELEASE=build\windows\x64\runner\Release"
if not exist "%RELEASE%" set "RELEASE=build\windows\runner\Release"
if not exist "%RELEASE%" goto :bad
if not exist "%RELEASE%\*.exe" goto :bad
 echo.
 echo SUCCESS: Windows build completed.
 echo Copy the ENTIRE Release folder (including DLL and data folder), NOT ONLY THE EXE.
 explorer "%RELEASE%"
 exit /b 0
:bad
 echo.
 echo ERROR: Build failed. Scroll up to the FIRST red 'error' message.
 pause
 exit /b 1
