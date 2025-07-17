@echo off
echo Running Package Migrations...
cd car-wash-api
php artisan migrate
echo.
echo Running Package Seeder...
php artisan db:seed --class=PackageSeeder
echo.
echo Package system setup completed!
pause 