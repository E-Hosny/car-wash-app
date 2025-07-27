Write-Host "========================================" -ForegroundColor Green
Write-Host "Building Car Wash App AAB File" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host ""
Write-Host "1. Cleaning previous build..." -ForegroundColor Yellow
flutter clean

Write-Host ""
Write-Host "2. Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host ""
Write-Host "3. Building AAB file..." -ForegroundColor Yellow
flutter build appbundle --release

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "AAB file location:" -ForegroundColor Cyan
Write-Host "build/app/outputs/bundle/release/app-release.aab" -ForegroundColor White
Write-Host ""
Write-Host "Version: 1.0.5+7" -ForegroundColor Cyan
Write-Host ""

# Check if file exists
$filePath = "build/app/outputs/bundle/release/app-release.aab"
if (Test-Path $filePath) {
    $fileSize = (Get-Item $filePath).Length / 1MB
    Write-Host "✅ AAB file created successfully!" -ForegroundColor Green
    Write-Host "📁 File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
} else {
    Write-Host "❌ AAB file not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 