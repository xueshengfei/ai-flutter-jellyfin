# jellyfin_auth

Jellyfin 登录注册 UI 业务组件。提供登录页面与局域网服务器自动发现能力，纯 UI + 回调注入设计，不依赖具体服务端实现。

## 功能清单

- **登录页面**：服务器地址 / 用户名 / 密码表单，支持默认值填充
- **局域网服务器发现**：UDP 广播自动扫描，点击选择后自动填充地址并验证
- **服务器地址验证**：GET `/System/Info/Public` 确认可达性，获取版本等信息
- **手动地址连接**：输入无协议前缀的地址时自动尝试 https / http

## 核心类说明

| 类名 | 类型 | 文件路径 | 说明 |
|------|------|----------|------|
| `LoginPage` | StatefulWidget 页面 | `lib/src/pages/login_page.dart` | 登录页面，纯 UI，认证通过 `onLogin` 回调注入 |
| `DiscoveredServer` | 纯 Dart 模型 | `lib/src/models/discovered_server.dart` | 发现的服务器信息，支持 UDP / PublicInfo / 合并 |
| `ServerDiscoveryService` | 服务类 | `lib/src/services/server_discovery_service.dart` | UDP 广播发现 + 地址验证 + 手动连接 |

## LoginPage 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `onLogin` | `Future<String?> Function({...})` | 是 | 登录回调，返回 `null` 表示成功，返回字符串表示错误信息 |
| `defaultServerUrl` | `String` | 否 | 默认服务器地址，默认 `http://localhost:8096` |
| `defaultUsername` | `String` | 否 | 默认用户名 |
| `defaultPassword` | `String` | 否 | 默认密码 |
| `discoveryService` | `ServerDiscoveryService?` | 否 | 传入后启用局域网服务器自动发现 |

## DiscoveredServer 工厂构造

| 构造器 | 数据源 | 说明 |
|--------|--------|------|
| `fromJson(json)` | UDP 广播响应 | 解析 Id / Name / Address / EndpointAddress |
| `fromPublicInfo(json, address)` | `/System/Info/Public` | 解析 ServerName / Version / LocalAddress / StartupWizardCompleted |
| `mergeWith(other)` | 合并两路结果 | 优先取非空值，用于 UDP + HTTP 验证结果合并 |

## ServerDiscoveryService 方法

| 方法 | 说明 |
|------|------|
| `discoverServers(timeout)` | UDP 广播扫描局域网，返回去重后的服务器列表 |
| `verifyServer(address)` | 调用 `/System/Info/Public` 验证服务器可达性 |
| `connectToAddress(host)` | 手动输入地址连接，自动补全协议前缀 |

## 依赖关系

```
jellyfin_auth
  └── flutter sdk（仅此一项，零业务包依赖）
```

本包不依赖 `jellyfin_api`、`jellyfin_models` 或其他 feature 包。认证能力通过 `onLogin` 回调由调用方注入。

## 使用示例

### 基本登录（无服务器发现）

```dart
import 'package:jellyfin_auth/jellyfin_auth.dart';

LoginPage(
  onLogin: ({required serverUrl, required username, required password}) async {
    // 调用 jellyfin_api 完成认证
    final result = await authGateway.login(serverUrl, username, password);
    if (result == null) return null; // 成功
    return result; // 返回错误信息字符串
  },
);
```

### 启用局域网服务器发现

```dart
import 'package:jellyfin_auth/jellyfin_auth.dart';

LoginPage(
  onLogin: onLoginCallback,
  discoveryService: ServerDiscoveryService(), // 注入即可启用扫描
);
```

### Barrel 导入

```dart
// 导入页面 + 模型 + 服务
import 'package:jellyfin_auth/jellyfin_auth.dart';

// 仅导入页面
import 'package:jellyfin_auth/jellyfin_auth_pages.dart';
```

## 测试说明

测试文件：`test/jellyfin_auth_test.dart`

```bash
cd packages/features/jellyfin_auth && flutter test
```

覆盖范围：

- `DiscoveredServer.fromJson` — UDP 响应解析
- `DiscoveredServer.fromPublicInfo` — PublicInfo 响应解析
- `DiscoveredServer.mergeWith` — 两路结果合并、非空值保留
- `LoginPage` — 无 `discoveryService` 时不显示局域网区域、默认值填充正确
