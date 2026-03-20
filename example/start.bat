@echo off
REM Jellyfin Media Library Example 应用启动脚本
REM 包含完整的登录和媒体库展示功能

echo ========================================
echo   Jellyfin Media Library Example
echo   启动调试服务器...
echo ========================================
echo.

REM 检查是否在正确的目录
if not exist "pubspec.yaml" (
    echo 错误: 请在 example 目录下运行此脚本
    pause
    exit /b 1
)

REM 显示应用信息
echo 应用功能：
echo   1. 用户登录页面
echo   2. 媒体库列表页面
echo   3. 媒体库卡片展示（带图片）
echo.
echo 使用流程：
echo   1. 确保Jellyfin服务器正在运行 (http://localhost:8096)
echo   2. 在登录页面输入服务器地址、用户名和密码
echo   3. 点击登录按钮
echo   4. 自动跳转到媒体库页面
echo   5. 查看媒体库卡片和图片
echo.
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
