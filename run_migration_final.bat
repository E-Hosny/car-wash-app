@echo off
echo ========================================
echo Laravel Migration - Car Wash API
echo ========================================
cd /d C:\xampp\htdocs\car-wash-api
echo Current directory: %CD%
echo.
echo Running migrations...
php artisan migrate --seed
echo.
echo ========================================
echo Migration completed!
echo ========================================
pause 