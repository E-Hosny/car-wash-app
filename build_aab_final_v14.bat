@echo off
setlocal enabledelayedexpansion

echo ========================================
echo 🚀 Building Car Wash App AAB File
echo Version: 1.1.4+24 (Updated Version)
echo ========================================

echo.
echo Current directory: %CD%
echo.

echo Checking if Flutter is available...
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not found in PATH
    echo.
    echo Please ensure Flutter is installed and added to your PATH
    echo You can download Flutter from: https://flutter.dev/docs/get-started/install/windows
    echo.
    echo After installation, add C:\flutter\bin to your PATH environment variable
    echo.
    pause
    exit /b 1
)

echo ✅ Flutter found in PATH
echo.

echo Flutter version:
flutter --version
echo.

echo ========================================
echo Step 1: Cleaning previous build
echo ========================================
flutter clean
if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to clean project
    echo.
    echo This might be due to:
    echo - Flutter not properly installed
    echo - Network connectivity issues
    echo - Permission problems
    echo.
    pause
    exit /b 1
)
echo ✅ Clean completed successfully
echo.

echo ========================================
echo Step 2: Getting dependencies
echo ========================================
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to get dependencies
    echo.
    echo This might be due to:
    echo - Network connectivity issues
    echo - Invalid pubspec.yaml file
    echo - Permission problems
    echo.
    pause
    exit /b 1
)
echo ✅ Dependencies installed successfully
echo.

echo ========================================
echo Step 3: Checking Android setup
echo ========================================
echo Checking Android licenses...
flutter doctor --android-licenses
if %errorlevel% neq 0 (
    echo ⚠️ WARNING: Android licenses not accepted, but continuing...
    echo This might cause issues during build
    echo.
) else (
    echo ✅ Android licenses checked
    echo.
)

echo ========================================
echo Step 4: Building AAB file
echo ========================================
echo This step may take several minutes...
echo Building version 1.1.4+24 (Updated Version)...
echo.
flutter build appbundle --release
if %errorlevel% neq 0 (
    echo ❌ ERROR: Failed to build AAB
    echo.
    echo This might be due to:
    echo - Missing Android SDK
    echo - Invalid signing configuration
    echo - Insufficient disk space
    echo - Memory issues
    echo.
    echo Please check:
    echo 1. Android SDK is installed
    echo 2. android/key.properties file exists
    echo 3. Signing configuration is correct
    echo 4. Sufficient disk space available
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ SUCCESS: AAB file created successfully!
echo ========================================
echo.
echo 📁 File location: build\app\outputs\bundle\release\app-release.aab
echo 📱 Version: 1.1.4+24 (Updated Version)
echo 📊 Expected file size: 15-25 MB
echo.
echo 🚀 Ready for Google Play upload!
echo.
echo Next steps:
echo 1. Go to https://play.google.com/console
echo 2. Select your app
echo 3. Go to Production → Create new release
echo 4. Upload the AAB file
echo 5. Add release notes
echo 6. Start review process
echo.

echo Checking if AAB file exists...
if exist "build\app\outputs\bundle\release\app-release.aab" (
    echo ✅ AAB file found!
    for %%A in ("build\app\outputs\bundle\release\app-release.aab") do (
        echo 📊 File size: %%~zA bytes
    )
    echo.
    echo Opening file location...
    explorer "build\app\outputs\bundle\release"
) else (
    echo ❌ ERROR: AAB file not found!
    echo Expected location: build\app\outputs\bundle\release\app-release.aab
    echo.
    echo Please check the build output for errors.
)

echo.
echo ✅ Build process completed!
pause
