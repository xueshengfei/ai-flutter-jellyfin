@echo off
REM Jellyfin Example 应用快速启动脚本

echo.
echo ===============================================
echo  Jellyfin Media Library - Example App
echo ===============================================
echo.
echo 正在启动应用...
echo.

cd example

echo 1️⃣ 检查依赖...
flutter pub get

echo.
echo 2️⃣ 启动应用...
echo.

flutter run

echo.
echo 应用已关闭
pause
