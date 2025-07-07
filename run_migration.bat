@echo off
cd /d C:\xampp\htdocs\car-wash-api
php artisan migrate --seed
pause 