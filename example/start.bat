@echo off
REM Jellyfin Service Example 应用快速启动脚本
REM 使用固定端口 9996 进行调试

echo ========================================
echo   Jellyfin Service Example 应用
echo   启动调试服务器...
echo ========================================
echo.

REM 检查是否在正确的目录
if not exist "pubspec.yaml" (
    echo 错误: 请在 example 目录下运行此脚本
    pause
    exit /b 1
)

REM 启动应用
echo 正在启动应用...
echo 端口: http://localhost:9996
echo.
echo 快捷键:
echo   r - 热重载
echo   R - 热重启
echo   q - 退出
echo.
flutter run -d web-server --web-port 9996

pause
