@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Building Car Wash App AAB File
echo ========================================

echo.
echo Checking Flutter installation...
flutter --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter and add it to your PATH
    pause
    exit /b 1
)

echo.
echo Current directory: %CD%
echo Flutter version:
flutter --version

echo.
echo 1. Cleaning previous build...
flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Failed to clean project
    pause
    exit /b 1
)

echo.
echo 2. Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)

echo.
echo 3. Checking Android setup...
flutter doctor --android-licenses
if %errorlevel% neq 0 (
    echo WARNING: Android licenses not accepted, but continuing...
)

echo.
echo 4. Building AAB file...
flutter build appbundle --release
if %errorlevel% neq 0 (
    echo ERROR: Failed to build AAB
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build completed!
echo ========================================
echo.
echo Checking for AAB file...

set "AAB_PATH=build\app\outputs\bundle\release\app-release.aab"
if exist "%AAB_PATH%" (
    echo ✅ AAB file created successfully!
    echo 📁 File location: %AAB_PATH%
    
    for %%A in ("%AAB_PATH%") do (
        set "SIZE=%%~zA"
        set /a "SIZE_MB=!SIZE!/1048576"
        echo 📊 File size: !SIZE_MB! MB
    )
    
    echo.
    echo Version: 1.0.6+8
    echo.
    echo Ready for Google Play upload!
) else (
    echo ❌ AAB file not found at: %AAB_PATH%
    echo.
    echo Checking build directory structure:
    dir build\app\outputs\bundle\release\ /s
)

echo.
pause 