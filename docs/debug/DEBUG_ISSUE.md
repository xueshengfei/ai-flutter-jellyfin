# 🐛 调试指南 - 登录和媒体库问题

## 🔍 问题诊断步骤

我已经在代码中添加了详细的调试信息。请按以下步骤操作：

### 1. 启动应用
```bash
cd example
.\start.bat
```

### 2. 打开浏览器开发者工具
- 按 `F12` 或右键选择"检查"
- 切换到 **Console** 标签页

### 3. 执行登录流程
1. 输入服务器地址：`http://localhost:8096`
2. 输入用户名和密码
3. 点击"登录"按钮
4. **观察Console输出**

### 4. 查看调试信息

#### 正常的日志输出应该是：
```
🚀 开始登录流程...
   服务器: http://localhost:8096
   用户名: your_username
✅ 客户端创建成功
🔐 正在认证...
✅ 认证成功!
   用户: your_username
   用户ID: xxx
   访问令牌: xxx...
🔄 开始页面跳转到 /media_libraries...
🔄 MediaLibrariesPage didChangeDependencies 调用
✅ 接收到参数
✅ 参数转换成功
📚 开始加载媒体库...
✅ 媒体库获取成功!
   媒体库数量: X
✅ UI状态更新完成
🎨 _buildBody 被调用
   显示媒体库列表 (X 个)
🎴 MediaLibraryCard.build: XXX
```

## 🚨 常见问题和解决方案

### 问题1: 登录成功但没有跳转
**检查：** Console是否有 "🔄 开始页面跳转到 /media_libraries..."

### 问题2: 跳转成功但页面空白
**检查：** Console是否有 "❌ 没有接收到参数!"

### 问题3: 媒体库数据为空
**检查：** Console显示的媒体库数量

### 问题4: 卡片不显示
**检查：** Console是否有 "🎴 MediaLibraryCard.build" 输出

## 📋 调试检查清单

- [ ] Jellyfin服务器正在运行 (http://localhost:8096)
- [ ] 用户名和密码正确
- [ ] 浏览器Console已打开
- [ ] 可以看到调试日志输出
- [ ] 检查是否有红色的错误信息

## 💡 快速测试

### 测试Jellyfin服务器
直接访问：http://localhost:8096

### 检查API响应
打开浏览器开发者工具 → Network 标签页，查看API请求

请按照这个指南操作，并告诉我你在Console看到了什么输出！
