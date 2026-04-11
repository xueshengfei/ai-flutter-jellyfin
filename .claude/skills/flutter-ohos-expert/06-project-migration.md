# 六、已有 Flutter 项目适配 ohos

## 6.1 添加 ohos 平台

```bash
cd <your_flutter_project>
flutter create . --platforms ohos
```

执行后项目新增 `ohos/` 目录：

```
your_project/
├── lib/
├── android/
├── ios/
├── ohos/                    # ← 新增
│   ├── AppScope/
│   │   └── app.json5
│   ├── build-profile.json5
│   ├── oh-package.json5
│   ├── entry/
│   │   ├── build-profile.json5
│   │   ├── oh-package.json5
│   │   └── src/main/
│   │       ├── ets/
│   │       │   ├── entryability/
│   │       │   │   └── EntryAbility.ets
│   │       │   └── pages/
│   │       │       └── Index.ets
│   │       ├── module.json5
│   │       └── resources/
│   └── hvigor/
├── web/
├── pubspec.yaml
└── README.md
```

---

## 6.2 适配依赖

### 情况一：依赖已适配 ohos 的版本

在 `pubspec.yaml` 中将依赖替换为 git 仓库的 ohos 适配版：

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 原始依赖（不支持 ohos）
  # path_provider: ^2.1.0

  # 替换为 git 依赖的 ohos 适配版
  path_provider:
    git:
      url: https://gitcode.com/openharmony-tpc/flutter_packages.git
      path: packages/path_provider/path_provider
      ref: br_path_provider-v2.1.5_ohos
```

### 情况二：依赖尚未适配 ohos

需要自行适配（参见 [04-library-adaptation.md](04-library-adaptation.md)），然后使用本地路径依赖：

```yaml
dependencies:
  path_provider:
    path: ../path_provider_ohos_adapted   # 指向本地适配后的插件
```

### 情况三：纯 Dart 依赖

无需修改，直接使用。但需检查代码中是否有平台判断需要添加 ohos 分支。

---

## 6.3 适配代码中的平台判断

### Platform 判断

```dart
// 修改前
import 'dart:io';
if (Platform.isAndroid) {
  config = AndroidConfig();
} else if (Platform.isIOS) {
  config = IOSConfig();
}

// 修改后
import 'dart:io';
if (Platform.isAndroid) {
  config = AndroidConfig();
} else if (Platform.isOhos) {
  config = OhosConfig();  // 或复用 AndroidConfig()
} else if (Platform.isIOS) {
  config = IOSConfig();
}
```

### defaultTargetPlatform 判断

```dart
// 修改前
final isMaterial = defaultTargetPlatform == TargetPlatform.android;
final isCupertino = defaultTargetPlatform == TargetPlatform.iOS;

// 修改后
final isMaterial = defaultTargetPlatform == TargetPlatform.android
    || defaultTargetPlatform == TargetPlatform.fuchsia; // ohos 通常复用 Material 风格
```

### 条件编译

```dart
// 如果代码中使用了 kIsWeb 等条件判断
if (kIsWeb) {
  // Web 逻辑
} else if (Platform.isAndroid || Platform.isOhos) {
  // Android / ohos 共用逻辑
} else if (Platform.isIOS) {
  // iOS 逻辑
}
```

---

## 6.4 签名与构建

### 签名

1. 用 DevEco Studio 打开 `<project>/ohos` 目录
2. `File > Project Structure > Signing Configs`
3. 勾选 `Support HarmonyOS & Automatically generate signature`
4. 登录华为开发者账号，点击 OK

### 构建

```bash
flutter pub get
flutter build hap --debug
# 或
flutter build hap --release
```

HAP 产物路径：`ohos/entry/build/default/outputs/default/entry-default-signed.hap`

### 运行

```bash
flutter devices                    # 查看设备
flutter run --debug -d <deviceId>  # 运行
```

---

## 6.5 完整迁移检查清单

```
□ flutter create . --platforms ohos 添加 ohos 支持
□ pubspec.yaml 中替换不支持 ohos 的依赖
□ 搜索代码中 Platform.isAndroid / isIOS，添加 isOhos 分支
□ 搜索 defaultTargetPlatform 判断，确认 ohos 行为
□ 搜索条件导入/导出，确认兼容性
□ DevEco Studio 签名
□ flutter build hap --debug 构建验证
□ 真机或模拟器运行验证功能
```
