# 🚀 Building Car Wash App AAB File
# Version: 1.1.3+23 (Latest Update)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🚀 Building Car Wash App AAB File" -ForegroundColor Yellow
Write-Host "Version: 1.1.3+23 (Latest Update)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray
Write-Host ""

# Check if Flutter is available
Write-Host "Checking if Flutter is available..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version
    Write-Host "✅ Flutter found in PATH" -ForegroundColor Green
    Write-Host ""
    Write-Host "Flutter version:" -ForegroundColor Gray
    Write-Host $flutterVersion -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ ERROR: Flutter is not found in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure Flutter is installed and added to your PATH" -ForegroundColor Yellow
    Write-Host "You can download Flutter from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Blue
    Write-Host ""
    Write-Host "After installation, add C:\flutter\bin to your PATH environment variable" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 1: Clean previous build
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 1: Cleaning previous build" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
try {
    flutter clean
    Write-Host "✅ Clean completed successfully" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "❌ ERROR: Failed to clean project" -ForegroundColor Red
    Write-Host ""
    Write-Host "This might be due to:" -ForegroundColor Yellow
    Write-Host "- Flutter not properly installed" -ForegroundColor Gray
    Write-Host "- Network connectivity issues" -ForegroundColor Gray
    Write-Host "- Permission problems" -ForegroundColor Gray
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 2: Get dependencies
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 2: Getting dependencies" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
try {
    flutter pub get
    Write-Host "✅ Dependencies installed successfully" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "❌ ERROR: Failed to get dependencies" -ForegroundColor Red
    Write-Host ""
    Write-Host "This might be due to:" -ForegroundColor Yellow
    Write-Host "- Network connectivity issues" -ForegroundColor Gray
    Write-Host "- Invalid pubspec.yaml file" -ForegroundColor Gray
    Write-Host "- Permission problems" -ForegroundColor Gray
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 3: Check Android setup
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 3: Checking Android setup" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Checking Android licenses..." -ForegroundColor Gray
try {
    flutter doctor --android-licenses
    Write-Host "✅ Android licenses checked" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "⚠️ WARNING: Android licenses not accepted, but continuing..." -ForegroundColor Yellow
    Write-Host "This might cause issues during build" -ForegroundColor Gray
    Write-Host ""
}

# Step 4: Build AAB file
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 4: Building AAB file" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "This step may take several minutes..." -ForegroundColor Gray
Write-Host "Building version 1.1.3+23 (Latest Update)..." -ForegroundColor Green
Write-Host ""

try {
    flutter build appbundle --release
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✅ SUCCESS: AAB file created successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📁 File location: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Blue
    Write-Host "📱 Version: 1.1.3+23 (Latest Update)" -ForegroundColor Green
    Write-Host "📊 Expected file size: 15-25 MB" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🚀 Ready for Google Play upload!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Go to https://play.google.com/console" -ForegroundColor White
    Write-Host "2. Select your app" -ForegroundColor White
    Write-Host "3. Go to Production → Create new release" -ForegroundColor White
    Write-Host "4. Upload the AAB file" -ForegroundColor White
    Write-Host "5. Add release notes" -ForegroundColor White
    Write-Host "6. Start review process" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "❌ ERROR: Failed to build AAB" -ForegroundColor Red
    Write-Host ""
    Write-Host "This might be due to:" -ForegroundColor Yellow
    Write-Host "- Missing Android SDK" -ForegroundColor Gray
    Write-Host "- Invalid signing configuration" -ForegroundColor Gray
    Write-Host "- Insufficient disk space" -ForegroundColor Gray
    Write-Host "- Memory issues" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Please check:" -ForegroundColor Yellow
    Write-Host "1. Android SDK is installed" -ForegroundColor Gray
    Write-Host "2. android/key.properties file exists" -ForegroundColor Gray
    Write-Host "3. Signing configuration is correct" -ForegroundColor Gray
    Write-Host "4. Sufficient disk space available" -ForegroundColor Gray
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if AAB file exists
Write-Host "Checking if AAB file exists..." -ForegroundColor Yellow
$aabPath = "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aabPath) {
    Write-Host "✅ AAB file found!" -ForegroundColor Green
    $fileSize = (Get-Item $aabPath).Length
    Write-Host "📊 File size: $fileSize bytes" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Opening file location..." -ForegroundColor Gray
    Invoke-Item "build\app\outputs\bundle\release"
} else {
    Write-Host "❌ ERROR: AAB file not found!" -ForegroundColor Red
    Write-Host "Expected location: $aabPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Please check the build output for errors." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Build process completed!" -ForegroundColor Green
Read-Host "Press Enter to exit"
