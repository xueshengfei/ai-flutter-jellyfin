# Flutter 鸿蒙(HarmonyOS)平台适配指南

> 本文档记录 Jellyfin Service 项目从标准 Flutter 迁移到鸿蒙平台的全流程，包括环境准备、依赖适配、构建部署、常见问题排查。

---

## 目录

1. [环境准备](#1-环境准备)
2. [FVM 配置](#2-fvm-配置)
3. [添加 ohos 平台](#3-添加-ohos-平台)
4. [依赖适配（核心）](#4-依赖适配核心)
5. [构建 HAP 包](#5-构建-hap-包)
6. [部署到设备](#6-部署到设备)
7. [常见问题与排查](#7-常见问题与排查)
8. [项目依赖清单](#8-项目依赖清单)

---

## 1. 环境准备

### 必需工具

| 工具 | 版本要求 | 说明 |
|------|---------|------|
| DevEco Studio | 5.0+ | 鸿蒙 IDE，提供 SDK 和签名工具 |
| JDK | 17 | 鸿蒙构建要求 |
| Node.js | 18+ | hvigor 构建系统依赖 |
| FVM | 最新 | 管理 Flutter 多版本 |
| Flutter OH SDK | 3.32.4-ohos | 鸿蒙适配的 Flutter SDK |

### 安装 Flutter OH SDK

```bash
# 通过 fvm 安装鸿蒙 Flutter SDK
fvm install flutter_flutter

# 这会安装 3.32.4-ohos-0.0.1 版本
# 仓库地址: https://gitcode.com/openharmony-tpc/flutter_flutter
```

### 配置 ohpm Registry

```bash
# 设置 ohpm 源（如果遇到 SSL 错误）
ohpm config set registry https://ohpm.openharmony.cn/ohpm/
```

### hdc 命令

hdc (HarmonyOS Device Connector) 通常不在系统 PATH 中，位于 DevEco Studio 的 SDK 目录：
```
DevEco Studio安装目录/sdk/openharmony/version/toolchains/hdc.exe
```

可用 `fvm flutter devices` 替代 hdc 查看设备列表。

---

## 2. FVM 配置

项目使用 `.fvmrc` 文件指定 Flutter 版本：

```json
{
  "flutter": "flutter_flutter"
}
```

这意味着：
- **master 分支**：使用标准 Flutter 3.32.0
- **harmony 分支**：使用鸿蒙 Flutter SDK (flutter_flutter)

### 切换 Flutter 版本

```bash
# 切到 harmony 分支后，fvm 自动使用 flutter_flutter 版本
git checkout harmony

# 确认版本
fvm flutter --version
# 应显示: 3.32.4-ohos-0.0.1
```

---

## 3. 添加 ohos 平台

### 为现有 Flutter 项目添加 ohos 支持

```bash
cd example

# 添加 ohos 平台目录
fvm flutter create --platforms ohos .
```

这会生成 `example/ohos/` 目录，包含：
```
ohos/
├── AppScope/              # 应用级配置
├── entry/                 # 入口模块
│   ├── src/main/
│   │   ├── ets/           # 原生 ETS 代码
│   │   ├── module.json5   # 模块配置（权限等）
│   │   └── resources/     # 资源文件
│   ├── build-profile.json5
│   └── hvigorfile.ts
├── hvigor/                # 构建工具
├── build-profile.json5    # 签名配置
├── oh-package.json5       # ohpm 包管理
└── local.properties       # 本地 SDK 路径
```

### 权限配置

编辑 `example/ohos/entry/src/main/module.json5`，添加 `requestPermissions`：

```json5
{
  "module": {
    // ...
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" }
    ]
  }
}
```

---

## 4. 依赖适配（核心）

这是鸿蒙适配的关键步骤。所有包含原生代码的 Flutter 插件都需要使用鸿蒙适配版本。

### 核心原则

1. **纯 Dart 包**（如 dio、logger、json_annotation）无需适配，直接使用 pub.dev 版本
2. **包含原生代码的插件**（如 video_player、shared_preferences）需要鸿蒙适配版本
3. **联邦插件**（federated plugin）需同时替换接口包和平台实现包
4. **必须使用本地路径依赖**，不能用 git 或 pub.dev（hvigor 不接受绝对路径/远程路径）

### 适配策略：本地路径依赖

将鸿蒙适配的第三方库克隆到 `packages/ohos/` 目录：

```
项目根目录/
├── packages/ohos/
│   ├── video_player/video_player/           # 联邦插件接口
│   ├── video_player/video_player_ohos/      # 鸿蒙平台实现
│   ├── fluttertpc_chewie/                   # chewie 鸿蒙版
│   ├── flutter_sound/flutter_sound/         # 音频播放
│   ├── flutter_sound/flutter_sound_platform_interface/
│   ├── flutter_sound/flutter_sound_web/
│   ├── path_provider/path_provider/         # 路径提供
│   ├── path_provider/path_provider_ohos/
│   ├── shared_preferences/shared_preferences/ # 本地存储
│   └── shared_preferences/shared_preferences_ohos/
├── Jellyfin_Service/                       # 主项目
└── jellyfin_dart-0.1.0/                    # Jellyfin API
```

### pubspec.yaml 修改

**主包 (`Jellyfin_Service/pubspec.yaml`)**：

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 纯 Dart 依赖 - 无需适配
  jellyfin_dart:
    path: ..\jellyfin_dart-0.1.0
  dio: ^5.9.0
  logger: ^2.0.2
  json_annotation: ^4.9.0
  equatable: ^2.0.7

  # 视频播放 - 鸿蒙适配（本地路径）
  video_player:
    path: ../packages/ohos/video_player/video_player
  chewie:
    path: ../packages/ohos/fluttertpc_chewie

  # 音频播放 - 鸿蒙适配
  flutter_sound:
    path: ../packages/ohos/flutter_sound/flutter_sound

  # 文件路径 - 鸿蒙适配
  path_provider:
    path: ../packages/ohos/path_provider/path_provider

  # 本地存储 - 鸿蒙适配
  shared_preferences:
    path: ../packages/ohos/shared_preferences/shared_preferences
```

**示例应用 (`example/pubspec.yaml`)**：

```yaml
dependencies:
  flutter:
    sdk: flutter
  jellyfin_service:
    path: ../
  cupertino_icons: ^1.0.6
```

不需要 `dependency_overrides`，主包已统一管理所有源。

### 各子包 pubspec 修改

每个鸿蒙适配包内部也需要修改依赖为本地路径：

**video_player (`packages/ohos/video_player/video_player/pubspec.yaml`)**：
```yaml
video_player_ohos:
  path: ../video_player_ohos   # 改为本地路径
```

**chewie (`packages/ohos/fluttertpc_chewie/pubspec.yaml`)**：
```yaml
video_player:
  path: ../video_player/video_player   # 指向本地 video_player
```

**shared_preferences (`packages/ohos/shared_preferences/shared_preferences/pubspec.yaml`)**：
```yaml
shared_preferences_ohos:
  path: ../shared_preferences_ohos
```

**path_provider (`packages/ohos/path_provider/path_provider/pubspec.yaml`)**：
```yaml
path_provider_ohos:
  path: ../path_provider_ohos
```

**flutter_sound** 相关（3个子包）需调整 SDK 约束和依赖版本：
```yaml
# flutter_sound/pubspec.yaml
environment:
  sdk: '>=3.8.0 <4.0.0'     # 原 <3.0.0 需改

dependencies:
  logger: ^2.0.0              # 原 ^1.1.0 需升级
  uuid: ^4.0.0                # 原 ^3.0.0 需升级
  path_provider:
    path: ../path_provider/path_provider   # 本地路径
  flutter_sound_platform_interface:
    path: ../flutter_sound_platform_interface
  flutter_sound_web:
    path: ../flutter_sound_web
```

---

## 5. 构建 HAP 包

### 获取依赖

```bash
cd example
fvm flutter pub get
```

### 构建 debug HAP

```bash
fvm flutter build hap --debug
```

HAP 产物位置：
```
example/build/ohos/outputs/default/entry-default-signed.hap
```

### 构建 release HAP

```bash
fvm flutter build hap --release
```

### 签名

Debug 签名由 DevEco Studio 自动生成（`~/.ohos/config/` 目录）。
Release 签名需在 DevEco Studio 中配置：

1. 打开 DevEco Studio
2. File → Open → 选择 `example/ohos/` 目录
3. File → Project Structure → Signing Configs
4. 配置证书和 Profile

签名配置在 `example/ohos/build-profile.json5` 中：
```json5
{
  "app": {
    "signingConfigs": [{
      "name": "default",
      "type": "HarmonyOS",
      "material": {
        "certpath": "证书路径",
        "profile": "p7b文件路径",
        "storeFile": "p12密钥库路径"
      }
    }]
  }
}
```

---

## 6. 部署到设备

### 查看已连接设备

```bash
# 方式1：通过 flutter（推荐）
fvm flutter devices

# 方式2：通过 hdc（需在PATH中或使用完整路径）
hdc list targets
```

输出示例：
```
2PN6R24402001061 (mobile) • OpenHarmony-6.1.0.105 (API 23)
```

### 直接运行（debug模式）

```bash
cd example
fvm flutter run --debug -d <设备ID>

# 示例
fvm flutter run --debug -d 2PN6R24402001061
```

### 安装已构建的 HAP

```bash
# 通过 hdc 安装
hdc install entry-default-signed.hap

# 或通过 flutter 运行 release
fvm flutter run --release -d <设备ID>
```

### 查看日志

```bash
# flutter 日志
fvm flutter run --debug -d <设备ID>

# hdc 日志
hdc hilog | grep -i flutter
```

---

## 7. 常见问题与排查

### 7.1 依赖获取失败

**症状**：`fvm flutter pub get` 报错

**排查步骤**：

```bash
# 1. 确认 Flutter 版本正确
fvm flutter --version
# 应为 3.32.4-ohos-0.0.1

# 2. 确认 .fvmrc 配置
cat .fvmrc
# {"flutter": "flutter_flutter"}

# 3. 检查本地路径依赖是否存在
ls ../packages/ohos/video_player/video_player/pubspec.yaml
ls ../packages/ohos/fluttertpc_chewie/pubspec.yaml
ls ../packages/ohos/flutter_sound/flutter_sound/pubspec.yaml

# 4. 清理缓存重试
fvm flutter pub cache clean
fvm flutter pub get
```

**常见错误**：
- `git ref failed`：git 远程仓库不可访问 → 改用本地路径依赖
- `version solving failed`：SDK 约束冲突 → 修改子包的 SDK 约束
- `yaml parse error`：pubspec.yaml 缩进错误 → 检查 YAML 格式

### 7.2 SDK 约束冲突

**症状**：
```
The current Dart SDK version is 3.8.0.
Because xxx requires SDK version >=2.12.0 <3.0.0
```

**解决**：修改子包的 `pubspec.yaml`：
```yaml
environment:
  sdk: '>=3.8.0 <4.0.0'  # 放宽上限
```

**需检查的包**：flutter_sound 的3个子包（flutter_sound, flutter_sound_platform_interface, flutter_sound_web）

### 7.3 依赖版本冲突

**症状**：
```
Because xxx requires logger ^1.1.0 and jellyfin_service requires logger ^2.0.2
```

**解决**：将子包的依赖版本改为与主项目兼容：
```yaml
dependencies:
  logger: ^2.0.0   # 从 ^1.1.0 升级
```

### 7.4 hvigor 构建报绝对路径错误

**症状**：
```
hvigor ERROR: Cannot resolve module path
```

**原因**：hvigor 不接受 git cache 绝对路径（如 `C:/Users/.../Pub/Cache/git/...`）

**解决**：所有 ohos 相关依赖改为本地路径依赖（`path: ../xxx`），不要用 `git:` 来源。

### 7.5 ohpm SSL 错误

**症状**：
```
ohpm SSL error / certificate verify failed
```

**解决**：
```bash
ohpm config set registry https://ohpm.openharmony.cn/ohpm/
```

### 7.6 签名相关错误

**症状**：
```
Error: The signedApp is not available
```

**排查**：
1. 确认 DevEco Studio 已生成 debug 签名（`~/.ohos/config/`）
2. 打开 `example/ohos/` 目录在 DevEco Studio 中，会自动生成签名
3. 检查 `build-profile.json5` 中的路径是否正确

### 7.7 设备检测不到

**排查**：
```bash
# 1. 确认 USB 调试已开启（设备端）
# 2. 确认 hdc 能识别
hdc list targets

# 3. 如果 hdc 不在 PATH
# Windows: DevEco安装目录\sdk\openharmony\<版本>\toolchains\hdc.exe

# 4. 重启 adb/hdc 服务
hdc kill
hdc start
```

### 7.8 YAML 缩进错误

**症状**：
```
Error on line XX, column YY: Unknown yaml parse error
```

**排查**：pubspec.yaml 中的 `git:` 块缩进必须严格：
```yaml
# 错误 ❌
video_player:
  git:
     url: https://...    # 缩进太深
     ref: xxx

# 正确 ✅
video_player:
  git:
    url: https://...
    ref: xxx
```

### 7.9 Gradle Lock 文件超时

**症状**：
```
Timeout of 120000 reached waiting for exclusive access to lock file
```

**解决**：
```bash
# 1. 杀死 Java 进程
taskkill /F /IM java.exe

# 2. 清理锁文件
rm -rf ~/.gradle/caches/*.lck
rm -rf ~/.gradle/caches/*.part

# 3. 重试
fvm flutter pub get
```

---

## 8. 项目依赖清单

### 纯 Dart 依赖（无需适配）

| 包名 | 版本 | 来源 |
|------|------|------|
| dio | ^5.9.0 | pub.dev |
| logger | ^2.0.2 | pub.dev |
| json_annotation | ^4.9.0 | pub.dev |
| equatable | ^2.0.7 | pub.dev |
| cupertino_icons | ^1.0.6 | pub.dev |

### 鸿蒙适配依赖（本地路径）

| 包名 | 本地路径 | 原始来源 |
|------|---------|---------|
| video_player | `../packages/ohos/video_player/video_player` | openharmony-tpc/flutter_packages |
| chewie | `../packages/ohos/fluttertpc_chewie` | openharmony-tpc/fluttertpc_chewie |
| flutter_sound | `../packages/ohos/flutter_sound/flutter_sound` | openharmony-tpc (需确认) |
| path_provider | `../packages/ohos/path_provider/path_provider` | openharmony-tpc/flutter_packages |
| shared_preferences | `../packages/ohos/shared_preferences/shared_preferences` | openharmony-tpc/flutter_packages |

### 鸿蒙适配三方库查找

- 主仓库：https://gitcode.com/openharmony-tpc/
- SIG 仓库：https://gitcode.com/openharmony-sig/
- 搜索关键词：`fluttertpc_` 或 `_ohos` 后缀

---

## 快速命令参考

```bash
# 切换分支
git checkout harmony

# 确认 Flutter 版本
fvm flutter --version

# 获取依赖
cd example && fvm flutter pub get

# 构建 HAP
fvm flutter build hap --debug

# 查看设备
fvm flutter devices

# 运行到设备
fvm flutter run --debug -d <设备ID>

# 查看日志
hdc hilog | grep -i flutter

# 清理构建
fvm flutter clean
```
