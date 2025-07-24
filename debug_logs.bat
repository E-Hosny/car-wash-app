@echo off
echo ================================================
echo        Car Wash API Debug Log Viewer
echo ================================================
echo.
echo Latest Laravel Log Entries:
echo.
echo ---- Last 50 lines ----
tail -50 C:\xampp\htdocs\car-wash-api\storage\logs\laravel.log 2>nul || (
    echo Laravel log file not found at expected location.
    echo Please check: C:\xampp\htdocs\car-wash-api\storage\logs\laravel.log
    echo.
    echo Alternative locations to check:
    echo - Check your XAMPP htdocs folder
    echo - Look for 'car-wash-api' folder
    echo - Navigate to storage/logs/laravel.log
)
echo.
echo ================================================
echo To watch logs in real-time, run:
echo   tail -f C:\xampp\htdocs\car-wash-api\storage\logs\laravel.log
echo ================================================
echo.
pause 