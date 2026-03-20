# 开发环境配置说明

## 📋 当前环境信息

**项目**: Jellyfin Service SDK (业务 SDK)
**提交**: 340ef17
**分支**: master
**日期**: 2025-03-20

## 🔧 环境要求

### 必需软件
- **Flutter**: >= 3.19.0
- **Dart**: >= 3.9.0
- **Git**: 已安装
- **Jellyfin 服务器**: http://localhost:8096 (用于测试)

### 依赖关系
- **jellyfin_dart**: 0.1.0 (接口 SDK)
  - **本地路径**: `D:\claudeProject\视频剪辑\ai-video-project\jellyfin_dart-0.1.0`
  - **作用**: 提供 Jellyfin API 映射和数据模型

## 🚀 快速启动指南

### 1. 克隆/进入项目目录

```bash
cd D:\claudeProject\视频剪辑\ai-video-project\Jellyfin_Service
```

### 2. 验证环境

```bash
# 检查 Flutter 版本
flutter --version

# 检查依赖
flutter pub get
```

### 3. 运行测试

```bash
# 运行所有单元测试
flutter test

# 应该看到: 00:00 +6: All tests passed!
```

### 4. 启动 Example 应用

```bash
# 进入 example 目录
cd example

# 方式1: 使用启动脚本（推荐）
.\start.bat

# 方式2: 手动启动
flutter run -d web-server --web-port 9996

# 浏览器打开: http://localhost:9996
```

## 📁 关键文件说明

### 配置文件
```
pubspec.yaml                  # 依赖配置（jellyfin_dart 本地路径）
README.md                     # 业务 SDK 架构文档
SETUP_COMPLETE.md             # 配置完成验证文档
example/DEBUG_GUIDE.md        # 调试指南
example/start.bat             # 快速启动脚本
```

### 源码结构
```
lib/
├── jellyfin_service.dart     # 主导出文件
└── src/
    ├── jellyfin_client.dart  # 主客户端
    ├── services/
    │   └── auth_service.dart # 认证服务 ⭐
    ├── models/
    │   └── user_models.dart  # 业务模型 ⭐
    └── exceptions/           # 异常类
```

## 🔐 关键配置

### 1. 本地依赖路径

**文件**: `pubspec.yaml`

```yaml
dependencies:
  jellyfin_dart:
    path: ..\jellyfin_dart-0.1.0  # 相对路径
    # 或绝对路径:
    # path: D:\claudeProject\视频剪辑\ai-video-project\jellyfin_dart-0.1.0
```

**重要**: 如果修改了项目位置，需要更新这个路径！

### 2. 固定调试端口

**文件**: `example/start.bat`

```batch
flutter run -d web-server --web-port 9996
```

**浏览器地址**: http://localhost:9996

## 🧪 验证清单

下次回到这个环境时，按以下顺序验证：

### ✅ 环境检查
- [ ] Flutter 版本 >= 3.19.0
- [ ] Dart 版本 >= 3.9.0
- [ ] jellyfin_dart 依赖路径正确

### ✅ 功能检查
- [ ] `flutter test` 全部通过
- [ ] `flutter analyze` 无错误（警告可忽略）
- [ ] Example 应用可以启动
- [ ] 浏览器可以访问 http://localhost:9996

### ✅ 集成检查
- [ ] 可以连接 Jellyfin 服务器
- [ ] 用户认证功能正常

## 🐛 常见问题

### 问题1: 依赖路径错误

**错误信息**:
```
Could not resolve package
```

**解决方案**:
```bash
# 检查路径是否存在
ls "D:\claudeProject\视频剪辑\ai-video-project\jellyfin_dart-0.1.0"

# 如果路径不存在，更新 pubspec.yaml 中的 path
```

### 问题2: 端口被占用

**错误信息**:
```
Unable to listen on port 9996
```

**解决方案**:
```bash
# 使用其他端口
flutter run -d web-server --web-port 9997
```

### 问题3: 测试失败

**解决方案**:
```bash
# 清理缓存
flutter clean

# 重新获取依赖
flutter pub get

# 运行测试
flutter test
```

## 📚 相关文档

- **业务 SDK 架构**: [README.md](README.md)
- **配置完成验证**: [SETUP_COMPLETE.md](SETUP_COMPLETE.md)
- **调试指南**: [example/DEBUG_GUIDE.md](example/DEBUG_GUIDE.md)

## 🎯 下一步开发

环境就绪后，可以开始开发：

1. **当前功能**: 认证登录 ✅
2. **待开发功能**:
   - 视频播放
   - 音乐播放
   - 媒体元数据
   - 播放历史

## 🔄 环境恢复步骤

如果换电脑或重新设置环境：

```bash
# 1. 克隆仓库
git clone <repository-url>
cd Jellyfin_Service

# 2. 确保接口 SDK 存在
ls ../jellyfin_dart-0.1.0

# 3. 获取依赖
flutter pub get

# 4. 运行测试
flutter test

# 5. 启动应用
cd example
.\start.bat
```

## 📝 重要提示

1. **不要提交敏感信息**: `.claude/settings.local.json` 在 `.gitignore` 中
2. **保持依赖路径同步**: 如果移动项目，记得更新 `pubspec.yaml`
3. **固定调试端口**: 始终使用 9996 端口，方便调试
4. **使用 web-server 模式**: 避免浏览器启动问题

---

**最后更新**: 2025-03-20
**环境状态**: ✅ 已配置完成，可以正常开发
