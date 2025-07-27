Write-Host "========================================" -ForegroundColor Green
Write-Host "Building Car Wash App AAB File - Version 1.0.7+11" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host ""
Write-Host "Current Directory: $PWD" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is available
Write-Host "Checking if Flutter is available..." -ForegroundColor Yellow
try {
    $flutterPath = Get-Command flutter -ErrorAction Stop
    Write-Host "✅ Flutter found at: $($flutterPath.Source)" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Flutter is not found in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure Flutter is installed and added to your PATH" -ForegroundColor Yellow
    Write-Host "You can download Flutter from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "After installation, add C:\flutter\bin to your PATH environment variable" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Flutter version:" -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version
    Write-Host $flutterVersion -ForegroundColor White
} catch {
    Write-Host "❌ ERROR: Could not get Flutter version" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Step 1: Cleaning previous build" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
try {
    flutter clean
    Write-Host "✅ Clean completed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to clean project" -ForegroundColor Red
    Write-Host ""
    Write-Host "This might be due to:" -ForegroundColor Yellow
    Write-Host "- Flutter not properly installed" -ForegroundColor White
    Write-Host "- Network connectivity issues" -ForegroundColor White
    Write-Host "- Permission problems" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Step 2: Getting dependencies" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
try {
    flutter pub get
    Write-Host "✅ Dependencies installed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to get dependencies" -ForegroundColor Red
    Write-Host ""
    Write-Host "This might be due to:" -ForegroundColor Yellow
    Write-Host "- Network connectivity issues" -ForegroundColor White
    Write-Host "- Invalid pubspec.yaml file" -ForegroundColor White
    Write-Host "- Permission problems" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Step 3: Checking Android setup" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Checking Android licenses..." -ForegroundColor Yellow
try {
    flutter doctor --android-licenses
    Write-Host "✅ Android licenses checked" -ForegroundColor Green
} catch {
    Write-Host "⚠️ WARNING: Android licenses not accepted, but continuing..." -ForegroundColor Yellow
    Write-Host "This might cause issues during build" -ForegroundColor White
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Step 4: Building AAB file" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "This step may take several minutes..." -ForegroundColor Yellow
Write-Host "Building version 1.0.7+11..." -ForegroundColor Cyan
Write-Host ""
try {
    flutter build appbundle --release
    Write-Host "✅ AAB build completed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to build AAB" -ForegroundColor Red
    Write-Host ""
    Write-Host "This might be due to:" -ForegroundColor Yellow
    Write-Host "- Missing Android SDK" -ForegroundColor White
    Write-Host "- Invalid signing configuration" -ForegroundColor White
    Write-Host "- Insufficient disk space" -ForegroundColor White
    Write-Host "- Memory issues" -ForegroundColor White
    Write-Host ""
    Write-Host "Please check:" -ForegroundColor Yellow
    Write-Host "1. Android SDK is installed" -ForegroundColor White
    Write-Host "2. android/key.properties file exists" -ForegroundColor White
    Write-Host "3. Signing configuration is correct" -ForegroundColor White
    Write-Host "4. Sufficient disk space available" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ SUCCESS: AAB file created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "📁 File location: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Cyan
Write-Host "📱 Version: 1.0.7+11" -ForegroundColor Cyan
Write-Host "📊 Expected file size: 15-25 MB" -ForegroundColor Cyan
Write-Host ""
Write-Host "🚀 Ready for Google Play upload!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Go to https://play.google.com/console" -ForegroundColor White
Write-Host "2. Select your app" -ForegroundColor White
Write-Host "3. Go to Production → Create new release" -ForegroundColor White
Write-Host "4. Upload the AAB file" -ForegroundColor White
Write-Host "5. Add release notes" -ForegroundColor White
Write-Host "6. Start review process" -ForegroundColor White
Write-Host ""

# Check if AAB file exists
Write-Host "Checking if AAB file exists..." -ForegroundColor Yellow
$aabPath = "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aabPath) {
    Write-Host "✅ AAB file found!" -ForegroundColor Green
    $fileSize = (Get-Item $aabPath).Length
    Write-Host "📊 File size: $fileSize bytes" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Opening file location..." -ForegroundColor Yellow
    Start-Process "build\app\outputs\bundle\release"
} else {
    Write-Host "❌ ERROR: AAB file not found!" -ForegroundColor Red
    Write-Host "Expected location: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor White
    Write-Host ""
    Write-Host "Please check the build output for errors." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Build process completed!" -ForegroundColor Green
Read-Host "Press Enter to exit" 