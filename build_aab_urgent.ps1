Write-Host "========================================" -ForegroundColor Red
Write-Host "🚨 URGENT: Building AAB for Google Play" -ForegroundColor Red
Write-Host "Version: 1.0.7+11" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

Write-Host ""
Write-Host "Current Directory: $PWD" -ForegroundColor Cyan
Write-Host ""

# Check Flutter
Write-Host "========================================" -ForegroundColor Green
Write-Host "Step 1: Checking Flutter installation" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

try {
    $flutterPath = Get-Command flutter -ErrorAction Stop
    Write-Host "✅ Flutter found at: $($flutterPath.Source)" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Flutter not found in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run these commands manually:" -ForegroundColor Yellow
    Write-Host "1. flutter clean" -ForegroundColor White
    Write-Host "2. flutter pub get" -ForegroundColor White
    Write-Host "3. flutter build appbundle --release" -ForegroundColor White
    Write-Host ""
    Write-Host "Or install Flutter from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""

# Clean
Write-Host "========================================" -ForegroundColor Green
Write-Host "Step 2: Cleaning project" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

try {
    flutter clean
    Write-Host "✅ Clean completed" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to clean" -ForegroundColor Red
    Write-Host "Please run: flutter clean" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""

# Get dependencies
Write-Host "========================================" -ForegroundColor Green
Write-Host "Step 3: Getting dependencies" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

try {
    flutter pub get
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to get dependencies" -ForegroundColor Red
    Write-Host "Please run: flutter pub get" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""

# Build AAB
Write-Host "========================================" -ForegroundColor Green
Write-Host "Step 4: Building AAB file" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "This may take 5-10 minutes..." -ForegroundColor Yellow
Write-Host ""

try {
    flutter build appbundle --release
    Write-Host "✅ AAB build completed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to build AAB" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common solutions:" -ForegroundColor Yellow
    Write-Host "1. Check android/key.properties exists" -ForegroundColor White
    Write-Host "2. Check signing configuration" -ForegroundColor White
    Write-Host "3. Run: flutter doctor" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ SUCCESS: AAB file created!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "📁 File location: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Cyan
Write-Host "📱 Version: 1.0.7+10" -ForegroundColor Cyan
Write-Host ""
Write-Host "🚀 Next steps:" -ForegroundColor Yellow
Write-Host "1. Go to Google Play Console" -ForegroundColor White
Write-Host "2. Upload the AAB file" -ForegroundColor White
Write-Host "3. Create production release" -ForegroundColor White
Write-Host ""

# Open folder
Write-Host "Opening file location..." -ForegroundColor Yellow
Start-Process "build\app\outputs\bundle\release"

Write-Host ""
Write-Host "✅ Done! Check the folder that opened." -ForegroundColor Green
Read-Host "Press Enter to exit" 