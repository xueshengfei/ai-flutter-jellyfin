# 四、三方库鸿蒙化适配全流程

以适配 `path_provider 2.1.0` 为完整示例。

## 整体流程

```
创建 ohos 模块 → 编写 Dart 接口 → 配置 pubspec.yaml
→ 编写 ETS 原生代码 → 打 HAR 包 → 修改主包配置 → 编写 Example 验证
```

---

## 4.1 创建 ohos 模块

```bash
cd <plugin_root>
flutter create --platforms ohos path_provider_ohos
```

创建后可删除 `.dart_tool` 和 `.idea` 文件。

目录结构变化：
```
path_provider/              # 原始插件
├── lib/
├── android/
├── ios/
├── path_provider_android/
├── path_provider_ohos/     # ← 新增
│   ├── lib/
│   ├── ohos/
│   └── pubspec.yaml
└── pubspec.yaml
```

---

## 4.2 编写 Dart 接口

复制 `path_provider_android/lib/` 下的代码，将所有 `android` 替换为 `ohos`。

示例（`lib/path_provider_ohos.dart`）：

```dart
import 'package:flutter/foundation.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// ohos 平台的 path_provider 实现
class PathProviderOhos extends PathProviderPlatform {
  /// 注册此实现
  static void registerWith() {
    PathProviderPlatform.instance = PathProviderOhos();
  }

  @override
  Future<String?> getTemporaryPath() async {
    // 通过 MethodChannel 调用原生方法
    // ...
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    // ...
  }

  @override
  Future<String?> getDownloadsPath() async {
    // ...
  }
}
```

---

## 4.3 配置 ohos 子包 pubspec.yaml

```yaml
name: path_provider_ohos
description: Ohos implementation of the path_provider plugin.
repository: https://gitcode.com/openharmony-tpc/flutter_packages/tree/master/packages/path_provider/path_provider_ohos
version: 2.2.1

environment:
  sdk: ">=2.18.0 <4.0.0"
  flutter: ">=3.3.0"

flutter:
  plugin:
    implements: path_provider
    platforms:
      ohos:
        package: io.flutter.plugins.pathprovider
        pluginClass: PathProviderPlugin
        dartPluginClass: PathProviderOhos

dependencies:
  flutter:
    sdk: flutter
  path_provider_platform_interface: ^2.0.1
```

**关键字段说明：**
- `implements: path_provider` — 声明实现的 federated plugin 接口
- `platforms.ohos.pluginClass` — ETS 端的插件类名
- `platforms.ohos.dartPluginClass` — Dart 端的平台实现类

---

## 4.4 创建 ETS 原生模块

### 步骤 1：用 DevEco Studio 打开 ohos 项目

打开 `path_provider_ohos/ohos` 目录。

### 步骤 2：创建 Static Library 模块

`File > New > Module > Static Library > Next`
- Module name: `path_provider`
- 其他默认，点击 Finish

### 步骤 3：删除不需要的目录

- 删除 `entry/` 目录（插件不需要 entry 模块）
- 清空 `path_provider/src/main/ets/` 下的模板代码

### 步骤 4：配置依赖

`path_provider/oh-package.json5`（插件模块内）：
```json5
{
  "name": "path_provider",
  "version": "1.0.0",
  "description": "path_provider plugin for ohos",
  "main": "Index.ets",
  "author": "",
  "license": "Apache-2.0",
  "dependencies": {
    "@ohos/flutter_ohos": "file:libs/flutter.har"
  }
}
```

外层 `oh-package.json5`（删除 flutter.har 依赖）：
```json5
{
  "name": "path_provider_ohos",
  "version": "1.0.0",
  "main": "",
  "dependencies": {},
  "devDependencies": {
    "@ohos/hypium": "1.0.6"
  }
}
```

在 `path_provider/libs/` 下放入 `flutter.har` 文件。

---

## 4.5 编写 ETS 原生代码

参考 Android/iOS 实现逻辑，使用 ArkTS 编写 ohos 端代码。

示例：`path_provider/src/main/ets/io/flutter/plugins/pathprovider/PathProviderPlugin.ets`

```typescript
import { FlutterPlugin, FlutterPluginBinding, MethodCall, MethodChannel, MethodResult }
  from '@ohos/flutter_ohos';

const CHANNEL_NAME = 'plugins.flutter.io/path_provider';

export default class PathProviderPlugin implements FlutterPlugin {
  private channel?: MethodChannel;

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);

    this.channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult) {
        switch (call.method) {
          case 'getTemporaryDirectory':
            // 获取临时目录路径
            const tempDir = getContext().tempDir;
            result.success(tempDir);
            break;
          case 'getApplicationSupportDirectory':
            // 获取应用支持目录
            const filesDir = getContext().filesDir;
            result.success(filesDir);
            break;
          case 'getDownloadsDirectory':
            // 获取下载目录
            result.success('/storage/Documents');
            break;
          default:
            result.notImplemented();
            break;
        }
      }
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
  }

  getUniqueClassName(): string {
    return 'PathProviderPlugin';
  }
}
```

---

## 4.6 修改 Index 导出

`path_provider/Index.ets`：

```typescript
import PathProviderPlugin from './src/main/ets/io/flutter/plugins/pathprovider/PathProviderPlugin'

export default PathProviderPlugin
```

---

## 4.7 打 HAR 包

在 DevEco Studio 中：
1. 右键选中 `path_provider` 模块
2. `Build > Make Module 'path_provider'`
3. 产物在 `path_provider/build/default/outputs/` 下生成 `.har` 文件

---

## 4.8 修改主包 pubspec.yaml

在原始插件的 `pubspec.yaml` 中添加 ohos 平台和依赖：

```yaml
name: path_provider
version: 2.1.0

environment:
  sdk: ">=2.18.0 <4.0.0"
  flutter: ">=3.3.0"

flutter:
  plugin:
    platforms:
      android:
        default_package: path_provider_android
      ios:
        default_package: path_provider_foundation
      linux:
        default_package: path_provider_linux
      macos:
        default_package: path_provider_foundation
      windows:
        default_package: path_provider_windows
      ohos:                              # ← 新增
        default_package: path_provider_ohos

dependencies:
  flutter:
    sdk: flutter
  path_provider_android: ^2.1.0
  path_provider_foundation: ^2.3.0
  path_provider_linux: ^2.2.0
  path_provider_platform_interface: ^2.1.0
  path_provider_windows: ^2.2.0
  path_provider_ohos:                   # ← 新增
    path: ../path_provider_ohos
```

---

## 4.9 创建 Example 验证

```bash
cd path_provider_ohos
flutter create --platforms ohos example
```

复制 Android example 的 `main.dart` 到 `example/lib/`。

`example/pubspec.yaml`：
```yaml
name: path_provider_example
publish_to: none

environment:
  sdk: ">=2.18.0 <4.0.0"
  flutter: ">=3.3.0"

dependencies:
  flutter:
    sdk: flutter
  path_provider:
    path: ../../path_provider          # 指向原始插件
  path_provider_platform_interface: ^2.0.0

flutter:
  uses-material-design: true
```

运行验证：
```bash
cd example
flutter pub get
flutter run -d <deviceId>
```
