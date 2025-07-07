@echo off
echo Starting Laravel Migration...
cd /d C:\xampp\htdocs\car-wash-api
echo Current directory: %CD%
echo Running migrations...
php artisan migrate --seed
echo Migration completed!
pause 