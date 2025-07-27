@echo off
setlocal enabledelayedexpansion

echo ========================================
echo 🚨 URGENT: Building AAB for Google Play
echo Version: 1.0.7+11
echo ========================================

echo.
echo Current directory: %CD%
echo.

echo ========================================
echo Step 1: Checking Flutter installation
echo ========================================
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ ERROR: Flutter not found in PATH
    echo.
    echo Please run these commands manually:
    echo 1. flutter clean
    echo 2. flutter pub get
    echo 3. flutter build appbundle --release
    echo.
    echo Or install Flutter from: https://flutter.dev/docs/get-started/install/windows
    echo.
    pause
    exit /b 1
)

echo ✅ Flutter found
echo.

echo ========================================
echo Step 2: Cleaning project
echo ========================================
flutter clean
if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to clean
    echo Please run: flutter clean
    pause
    exit /b 1
)
echo ✅ Clean completed
echo.

echo ========================================
echo Step 3: Getting dependencies
echo ========================================
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to get dependencies
    echo Please run: flutter pub get
    pause
    exit /b 1
)
echo ✅ Dependencies installed
echo.

echo ========================================
echo Step 4: Building AAB file
echo ========================================
echo This may take 5-10 minutes...
echo.
flutter build appbundle --release
if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to build AAB
    echo.
    echo Common solutions:
    echo 1. Check android/key.properties exists
    echo 2. Check signing configuration
    echo 3. Run: flutter doctor
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ SUCCESS: AAB file created!
echo ========================================
echo.
echo 📁 File location: build\app\outputs\bundle\release\app-release.aab
echo 📱 Version: 1.0.7+10
echo.
echo 🚀 Next steps:
echo 1. Go to Google Play Console
echo 2. Upload the AAB file
echo 3. Create production release
echo.
echo Press any key to open the file location...
pause >nul

explorer "build\app\outputs\bundle\release"

echo.
echo ✅ Done! Check the folder that opened.
pause 