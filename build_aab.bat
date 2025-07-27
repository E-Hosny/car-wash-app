@echo off
echo ========================================
echo Building Car Wash App AAB File
echo ========================================

echo.
echo 1. Cleaning previous build...
flutter clean

echo.
echo 2. Getting dependencies...
flutter pub get

echo.
echo 3. Building AAB file...
flutter build appbundle --release

echo.
echo ========================================
echo Build completed!
echo ========================================
echo.
echo AAB file location:
echo build/app/outputs/bundle/release/app-release.aab
echo.
echo Version: 1.0.5+7
echo.
pause 