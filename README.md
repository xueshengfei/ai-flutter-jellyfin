# Jellyfin Service SDK - 简化版

**版本**: 0.1.0
**状态**: ✅ 可用
**功能**: 用户认证

---

## 📋 简介

这是 Jellyfin Service SDK 的简化版本，只包含核心的**用户认证功能**。移除了所有缓存、状态管理和复杂的业务逻辑，专注于提供简单、可靠的认证服务。

### ✨ 功能特性

- ✅ **用户名密码认证** - 使用用户名和密码登录
- ✅ **会话管理** - 管理访问令牌和会话
- ✅ **错误处理** - 完整的异常处理体系
- ✅ **日志记录** - 可选的调试日志
- ✅ **类型安全** - 完整的 Dart 类型注解

---

## 🚀 快速开始

### 1. 添加依赖

```yaml
dependencies:
  jellyfin_service:
    path: ../Jellyfin_Service
```

### 2. 简单示例

```dart
import 'package:jellyfin_service/jellyfin_service.dart';

void main() async {
  // 创建客户端
  final client = JellyfinClient(
    serverUrl: 'http://localhost:8096',
    enableLogging: true,
  );

  // 登录
  try {
    final result = await client.auth.authenticate(
      username: 'your_username',
      password: 'your_password',
    );

    print('登录成功: ${result.user.name}');
  } on AuthenticationException catch (e) {
    print('认证失败: $e');
  }
}
```

---

## 📖 API 文档

### JellyfinClient

主客户端类，提供统一的API访问入口。

#### 构造函数

```dart
JellyfinClient({
  required String serverUrl,      // 服务器地址
  String applicationName,          // 应用名称
  String applicationVersion,       // 应用版本
  String? deviceName,              // 设备名称
  String? deviceId,                // 设备ID
  String clientName,               // 客户端名称
  bool enableLogging,              // 启用日志
})
```

#### 属性

```dart
// 检查是否已认证
bool get isAuthenticated

// 访问令牌
String? get accessToken

// 用户ID
String? get userId

// 配置
JellyfinConfiguration get configuration
```

#### 方法

```dart
// 更新访问令牌
void updateAccessToken(String? token)

// 清除认证信息
void clearAuth()
```

### AuthService

认证服务，处理用户登录和登出。

#### 方法

**用户名密码认证**

```dart
Future<AuthenticationResult> authenticate({
  required String username,
  required String password,
})
```

**返回值**: `AuthenticationResult` 包含访问令牌和用户信息

**抛出**:
- `AuthenticationException` - 认证失败时

**Quick Connect 认证**

```dart
Future<String> initiateQuickConnect()
```

**检查 Quick Connect 状态**

```dart
Future<AuthenticationResult?> checkQuickConnect(String secret)
```

**登出**

```dart
Future<void> logout()
```

**检查认证状态**

```dart
bool isAuthenticated()
```

### AuthenticationResult

认证结果，包含用户信息和会话数据。

#### 属性

```dart
class AuthenticationResult {
  final String accessToken;          // 访问令牌
  final UserProfile user;             // 用户信息
  final String? serverId;             // 服务器ID
  final SessionInfo? sessionInfo;     // 会话信息
}
```

### UserProfile

用户配置信息。

#### 属性

```dart
class UserProfile {
  final String id;                    // 用户ID
  final String name;                  // 用户名
  final String serverUrl;             // 服务器URL
  final String? primaryImageTag;      // 头像标签
  final DateTime? lastLoginDate;      // 最后登录时间
  final bool isAdmin;                 // 是否管理员
}
```

---

## 🔥 错误处理

### AuthenticationException

认证失败时抛出的异常。

```dart
try {
  await client.auth.authenticate(
    username: 'user',
    password: 'pass',
  );
} on AuthenticationException catch (e) {
  print('错误: ${e.message}');
  print('错误代码: ${e.errorCode}');

  // 常见错误代码:
  // - INVALID_CREDENTIALS: 用户名或密码错误
  // - SERVER_NOT_FOUND: 服务器未找到
  // - TIMEOUT: 连接超时
  // - CONNECTION_ERROR: 连接错误
}
```

---

## 📝 完整示例

查看 `example/main.dart` 获取完整的使用示例。

---

## 🛠️ 技术栈

- **Dart**: >=3.7.0
- **Flutter**: >=3.19.0
- **jellyfin_dart**: 0.1.2 (API SDK)
- **Dio**: 5.9.0 (HTTP客户端)
- **Logger**: 2.0.2 (日志记录)
- **Equatable**: 2.0.7 (值相等)
- **JSON Serializable**: 6.9.3 (序列化)

---

## 📂 项目结构

```
Jellyfin_Service/
├── lib/
│   ├── jellyfin_sdk.dart           # 主导出文件
│   └── src/
│       ├── jellyfin_client.dart     # 主客户端
│       ├── jellyfin_configuration.dart  # 配置
│       ├── core/
│       │   └── api_client.dart      # API客户端
│       ├── services/
│       │   └── auth_service.dart    # 认证服务
│       ├── models/
│       │   └── user_models.dart     # 用户模型
│       └── exceptions/              # 异常类
├── example/
│   └── main.dart                   # 使用示例
└── pubspec.yaml
```

---

## ⚠️ 注意事项

1. **服务器URL**: 确保服务器地址正确，包含协议（http/https）
2. **网络连接**: 确保设备可以访问Jellyfin服务器
3. **用户凭据**: 确保用户名和密码正确
4. **HTTPS证书**: 如果使用HTTPS，确保证书有效

---

## 🎯 下一步

1. **运行示例**:
   ```bash
   cd example
   flutter run -d chrome
   ```

2. **集成到项目**:
   ```yaml
   # 在你的项目的 pubspec.yaml 中
   dependencies:
     jellyfin_service:
       path: ../Jellyfin_Service
   ```

3. **开始使用**:
   ```dart
   final client = JellyfinClient(serverUrl: 'http://localhost:8096');
   final result = await client.auth.authenticate(
     username: 'user',
     password: 'pass',
   );
   ```

---

## 📄 许可证

MIT License

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**状态**: ✅ 简化版完成，可以开始使用认证功能
