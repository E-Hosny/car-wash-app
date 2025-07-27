Write-Host "========================================" -ForegroundColor Green
Write-Host "Building Car Wash App AAB File" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host ""
Write-Host "Current Directory: $PWD" -ForegroundColor Cyan

# Check if Flutter is installed
Write-Host ""
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version
    Write-Host "✅ Flutter is installed:" -ForegroundColor Green
    Write-Host $flutterVersion -ForegroundColor White
} catch {
    Write-Host "❌ ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter and add it to your PATH" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "1. Cleaning previous build..." -ForegroundColor Yellow
try {
    flutter clean
    Write-Host "✅ Clean completed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to clean project" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "2. Getting dependencies..." -ForegroundColor Yellow
try {
    flutter pub get
    Write-Host "✅ Dependencies installed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to get dependencies" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "3. Checking Android setup..." -ForegroundColor Yellow
try {
    flutter doctor --android-licenses
    Write-Host "✅ Android licenses checked" -ForegroundColor Green
} catch {
    Write-Host "⚠️ WARNING: Android licenses not accepted, but continuing..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "4. Building AAB file..." -ForegroundColor Yellow
try {
    flutter build appbundle --release
    Write-Host "✅ AAB build completed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to build AAB" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host ""
Write-Host "Checking for AAB file..." -ForegroundColor Yellow

$filePath = "build/app/outputs/bundle/release/app-release.aab"
if (Test-Path $filePath) {
    $fileSize = (Get-Item $filePath).Length / 1MB
    Write-Host "✅ AAB file created successfully!" -ForegroundColor Green
    Write-Host "📁 File location: $filePath" -ForegroundColor Cyan
    Write-Host "📊 File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version: 1.0.6+8" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ready for Google Play upload!" -ForegroundColor Green
} else {
    Write-Host "❌ AAB file not found at: $filePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Checking build directory structure:" -ForegroundColor Yellow
    if (Test-Path "build/app/outputs/bundle/release/") {
        Get-ChildItem "build/app/outputs/bundle/release/" -Recurse | Format-Table Name, Length, LastWriteTime
    } else {
        Write-Host "Build directory not found" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 