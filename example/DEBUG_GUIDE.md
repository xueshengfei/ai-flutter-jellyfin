# Example 应用调试指南

## 🚀 快速启动

### 推荐方式：Web Server 模式（固定端口）

这是最稳定的调试方式，固定使用 `http://localhost:9996` 端口。

```powershell
# 1. 进入 example 目录
cd D:\claudeProject\视频剪辑\ai-video-project\Jellyfin_Service\example

# 2. 启动应用（固定端口）
flutter run -d web-server --web-port 9996
```

**启动成功后：**
- 终端显示：`lib\main.dart is being served at http://localhost:9996`
- 在浏览器中打开：`http://localhost:9996`
- 应用会保持运行，支持热重载

---

## 📱 测试认证功能

### 前置条件

需要先启动 Jellyfin 服务器：
- 本地安装 Jellyfin：https://jellyfin.org/downloads/
- 或使用远程服务器

### 测试步骤

1. **在浏览器中打开应用**
   ```
   http://localhost:9996
   ```

2. **连接服务器**
   - 输入服务器地址：`http://localhost:8096`（或你的服务器地址）
   - 点击"连接"按钮
   - 等待显示"✅ 已连接到服务器"

3. **用户登录**
   - 输入 Jellyfin 用户名
   - 输入密码
   - 点击"登录"按钮
   - 查看登录结果和用户信息

4. **检查状态**
   - 点击"检查登录状态"按钮
   - 查看当前认证状态

---

## 🔧 热重载开发

修改代码后，在运行的终端中按快捷键：

| 快捷键 | 功能 | 说明 |
|--------|------|------|
| `r` + Enter | 热重载 | 快速刷新，保留应用状态 ⭐ 推荐用于UI修改 |
| `R` + Enter | 热重启 | 完全重启应用，清空状态 |
| `o` + Enter | 切换平台 | 在不同浏览器间切换 |
| `q` + Enter | 退出 | 停止应用 |

### 热重载示例

```dart
// 修改 example/lib/main.dart 中的文本
Text('Jellyfin Service 测试') // 改为
Text('Jellyfin Service 测试 v2.0')

// 在终端按 r + Enter
// 浏览器立即更新，无需刷新
```

---

## 🛠️ 常用命令

### 首次运行

```powershell
# 获取依赖
flutter pub get

# 启动应用
flutter run -d web-server --web-port 9996
```

### 日常开发

```powershell
# 直接启动（已获取过依赖）
flutter run -d web-server --web-port 9996
```

### 清理缓存（遇到问题时）

```powershell
# 清理构建缓存
flutter clean

# 重新获取依赖
flutter pub get

# 启动
flutter run -d web-server --web-port 9996
```

### 运行测试

```powershell
# 在项目根目录运行
cd ..
flutter test

# 在 example 目录运行
cd example
flutter test
```

---

## 🐛 故障排除

### 问题1: 端口被占用

```powershell
# 错误信息：Error: Unable to listen on port 9996
# 解决方案1：使用其他端口
flutter run -d web-server --web-port 9997

# 解决方案2：关闭占用端口的进程
netstat -ano | findstr :9996
taskkill /PID <进程ID> /F
```

### 问题2: 浏览器无法连接

```powershell
# 1. 确认终端显示：Serving HTTP on http://localhost:9996
# 2. 检查防火墙设置
# 3. 尝试使用 127.0.0.1 代替 localhost
#    在浏览器打开：http://127.0.0.1:9996
```

### 问题3: 热重载不生效

```powershell
# 按 R + Enter（大写R）进行热重启
# 如果还不行，按 q + Enter 退出，重新启动
```

### 问题4: 依赖问题

```powershell
# 清理并重新获取依赖
flutter clean
flutter pub get
flutter run -d web-server --web-port 9996
```

---

## 📊 调试技巧

### 1. 查看控制台日志

**Flutter 终端：**
- 显示应用日志
- 显示错误信息
- 显示热重载状态

**浏览器开发者工具（F12）：**
- Console 标签：查看前端日志
- Network 标签：查看 API 请求
- Application 标签：查看本地存储

### 2. 查看网络请求

```javascript
// 在浏览器控制台运行
fetch('http://localhost:8096/Users/me')
  .then(r => r.json())
  .then(console.log)
```

### 3. 检查认证状态

在浏览器控制台：
```javascript
// 查看本地存储的 token
localStorage.getItem('jellyfin_token')
```

---

## 🎯 开发工作流

### 典型开发流程

```powershell
# 1. 修改代码
code lib/main.dart

# 2. 在终端按 r + Enter（热重载）
# 浏览器立即更新

# 3. 继续修改...
# 每次修改后按 r + Enter

# 4. 完成开发，按 q + Enter 退出
```

### 调试业务 SDK

```powershell
# 1. 修改业务 SDK 代码
code ../lib/src/services/auth_service.dart

# 2. 在终端按 R + Enter（热重启）
# 业务层修改需要重启

# 3. 测试功能
```

---

## 📝 项目结构

```
example/
├── lib/
│   └── main.dart                 # 示例应用代码
├── pubspec.yaml                  # 依赖配置
├── web/                          # Web 资源
└── DEBUG_GUIDE.md                # 本文档

业务 SDK 位于 ../lib/
- jellyfin_client.dart            # 主客户端
- services/auth_service.dart      # 认证服务
- models/user_models.dart         # 业务模型
```

---

## 🔗 相关文档

- [业务 SDK README](../README.md)
- [配置完成文档](../SETUP_COMPLETE.md)
- [Jellyfin 官方文档](https://jellyfin.org/docs/)

---

## 💡 最佳实践

### ✅ 推荐做法

1. **始终使用固定端口**：`--web-port 9996`
2. **使用 web-server 模式**：避免浏览器启动问题
3. **频繁使用热重载**：修改代码后按 `r`，节省时间
4. **保持终端运行**：不要关闭终端，让应用保持运行
5. **使用浏览器书签**：将 `http://localhost:9996` 加入书签

### ❌ 避免做法

1. ❌ 不要使用 `-d chrome` 或 `-d edge`（会启动多个窗口）
2. ❌ 不要每次都关闭应用（保持运行状态）
3. ❌ 不要在应用运行时修改 pubspec.yaml（需要重启）
4. ❌ 不要忘记保存文件（热重载前先保存）

---

## 🎉 快速参考卡

```powershell
# 启动应用
flutter run -d web-server --web-port 9996

# 热重载
r

# 热重启
R

# 退出
q

# 清理
flutter clean && flutter pub get
```

**浏览器地址：** http://localhost:9996

---

**状态**: ✅ 调试环境已配置完成，可以开始开发！
