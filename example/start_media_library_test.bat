@echo off
echo ========================================
echo Jellyfin Service 媒体库功能测试
echo ========================================
echo.
echo 正在启动 Example 应用...
echo 端口: 9996
echo 地址: http://localhost:9996
echo.
echo 测试步骤：
echo 1. 确保Jellyfin服务器正在运行 (http://localhost:8096)
echo 2. 连接服务器
echo 3. 使用用户名和密码登录
echo 4. 点击"获取媒体库列表"按钮
echo 5. 查看媒体库列表展示
echo.
echo 按 Ctrl+C 停止服务器
echo ========================================
echo.

flutter run -d web-server --web-port 9996

pause
