# 三、判断三方库是否需要鸿蒙化

## 核心原则

**有原生代码的需要适配，纯 Dart 代码的不需要。**

## 快速识别表

| 库类型 | 是否需要适配 | 特征 |
|--------|-------------|------|
| 纯 Dart 库 | 不需要 | 只依赖 `sdk: dart`，无 `flutter.plugin` |
| Flutter Plugin | 需要 | 有 `android/` 或 `ios/`，有 `flutter.plugin` |

---

## 方法一：查看 pubspec.yaml

### 不需要适配的纯 Dart 库

```yaml
# 例：cross_file
# 只声明 Dart SDK 依赖 → 无需鸿蒙化
name: cross_file

environment:
  sdk: ^3.9.0
```

### 需要适配的 Flutter Plugin

```yaml
# 例：shared_preferences
# 有 flutter.plugin 配置 → 需要鸿蒙化
name: shared_preferences

environment:
  sdk: ^3.9.0
  flutter: ">=3.35.0"

flutter:
  plugin:
    platforms:
      android:
        default_package: shared_preferences_android
      ios:
        default_package: shared_preferences_foundation
      linux:
        default_package: shared_preferences_linux
      # ... 有多平台实现
```

**判断要点：**
- 只依赖 `sdk: dart` → **不需要**
- 有 `flutter.plugin` → **需要**

---

## 方法二：查看目录结构

```
library_name/
├── lib/              # Dart 代码（所有库都有）
├── android/          # 有此目录 → 需要适配
├── ios/              # 有此目录 → 需要适配
├── windows/
├── macos/
├── linux/
└── pubspec.yaml
```

- 只有 `lib/` → **不需要**
- 有 `android/` 或 `ios/` → **需要**

---

## 方法三：查看 pub.dev 标签

- 标签有 `DART` → 纯 Dart 库，不需要
- 标签只有 `FLUTTER` → 插件，需要适配

---

## 特别注意：纯 Dart 库中的平台判断

即使纯 Dart 库，若代码中有平台判断，仍需添加 ohos 分支：

### 错误写法

```dart
// 鸿蒙会错误走到 else 分支
if (Platform.isAndroid) {
  return androidStyle();
} else {
  return iosStyle();
}
```

### 正确写法

```dart
if (Platform.isAndroid) {
  return androidStyle();
} else if (Platform.isOhos) {
  return ohosStyle(); // 或复用 androidStyle()
} else {
  return iosStyle();
}
```

### defaultTargetPlatform 也需要处理

```dart
// 错误
switch (defaultTargetPlatform) {
  case TargetPlatform.android:
    return androidWidget();
  case TargetPlatform.iOS:
    return iosWidget();
  // ohos 会走到 default，可能抛异常
}

// 正确
switch (defaultTargetPlatform) {
  case TargetPlatform.android:
    return androidWidget();
  case TargetPlatform.iOS:
    return iosWidget();
  case TargetPlatform.fuchsia: // ohos 使用 fuchsia 或单独处理
    return ohosWidget();
}
```

### 条件导入也需要注意

```dart
// 如果库使用了条件导入
export 'src/implementation_stub.dart'
  if (dart.library.io) 'src/implementation_io.dart';
// 需要确认 io 实现是否兼容 ohos
```
