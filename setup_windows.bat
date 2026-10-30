@echo off
chcp 65001 >nul
title Afghan Business Pro Setup
echo ==========================================
echo   Afghan Business Pro - Project Setup
echo ==========================================
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found. Install Flutter and add it to PATH first.
  pause
  exit /b 1
)
echo Creating Android project files...
flutter create --platforms=android --org com.afghanbusinesspro .
if errorlevel 1 (
  echo Project generation failed.
  pause
  exit /b 1
)
echo Installing packages...
flutter pub get
if errorlevel 1 (
  echo Package installation failed.
  pause
  exit /b 1
)
echo Running code analysis...
flutter analyze
echo.
echo Setup finished. To build APK, run:
echo flutter build apk --release
pause
