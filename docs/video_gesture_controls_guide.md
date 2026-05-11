# Video Gesture Controls 插件开发指南

> 每一步的命令、代码、文件路径都写清楚，照着做就行。

---

## 第一步：创建 Plugin 工程

### 1.1 用 flutter create 创建插件骨架

在项目根目录 `Jellyfin_Service/` 下执行：

```bash
cd D:/claudeProject/flutter_video_project/ai-video-project/Jellyfin_Service

flutter create --template=plugin --platforms=android,ohos packages/video_gesture_controls
```

> 如果 `--platforms=ohos` 不支持，先用 `--platforms=android` 创建，后续手动加 ohos。

### 1.2 修改 pubspec.yaml

打开 `packages/video_gesture_controls/pubspec.yaml`，替换为：

```yaml
name: video_gesture_controls
description: 视频播放器手势控制插件 - 支持滑动快进/快退、亮度/音量调节、双击、长按等手势操作
version: 0.1.0
publish_to: 'none'

environment:
  sdk: '>=3.8.0 <4.0.0'
  flutter: ">=3.32.0"

dependencies:
  flutter:
    sdk: flutter
  video_player: ^2.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  plugin:
    platforms:
      android:
        package: com.example.video_gesture_controls
        pluginClass: VideoGestureControlsPlugin
```

### 1.3 创建目录结构

```bash
cd packages/video_gesture_controls

mkdir -p lib/src/controllers
mkdir -p lib/src/gestures
mkdir -p lib/src/widgets
mkdir -p lib/src/platform
```

最终目录结构：

```
packages/video_gesture_controls/
├── lib/
│   ├── video_gesture_controls.dart           # 主入口
│   └── src/
│       ├── video_player_controls.dart        # 主 Widget
│       ├── controllers/
│       │   └── gesture_controller.dart       # 手势状态管理
│       ├── gestures/
│       │   └── video_gesture_detector.dart   # 手势识别层
│       ├── widgets/
│       │   ├── control_bar.dart              # 底部控制栏
│       │   ├── top_bar.dart                  # 顶部栏
│       │   ├── progress_bar.dart             # 进度条
│       │   ├── speed_selector.dart           # 倍速选择器
│       │   ├── gesture_overlay.dart          # 手势反馈浮层
│       │   └── loading_overlay.dart          # 加载遮罩
│       └── platform/
│           └── brightness_volume.dart        # 亮度/音量平台通道
├── android/
│   └── src/main/java/.../VideoGestureControlsPlugin.java
├── pubspec.yaml
└── README.md
```

### 1.4 写主入口文件

创建 `lib/video_gesture_controls.dart`：

```dart
/// video_gesture_controls - 视频播放器手势控制插件
library video_gesture_controls;

export 'src/video_player_controls.dart';
export 'src/platform/brightness_volume.dart';
```

---

## 第二步：平台桥接（亮度/音量）

> 先写平台层，因为手势层要调用它。

### 2.1 Dart 抽象层

创建 `lib/src/platform/brightness_volume.dart`：

```dart
import 'package:flutter/services.dart';

/// 亮度/音量平台通道
class BrightnessVolumeChannel {
  static const _channel = MethodChannel('video_gesture_controls');

  /// 设置屏幕亮度（0.0 ~ 1.0）
  static Future<void> setBrightness(double value) async {
    await _channel.invokeMethod('setBrightness', {
      'value': value.clamp(0.0, 1.0),
    });
  }

  /// 获取当前屏幕亮度
  static Future<double> getBrightness() async {
    final result = await _channel.invokeMethod<double>('getBrightness');
    return result ?? 0.5;
  }

  /// 设置音量（0.0 ~ 1.0）
  static Future<void> setVolume(double value) async {
    await _channel.invokeMethod('setVolume', {
      'value': value.clamp(0.0, 1.0),
    });
  }

  /// 获取当前音量
  static Future<double> getVolume() async {
    final result = await _channel.invokeMethod<double>('getVolume');
    return result ?? 0.5;
  }
}
```

### 2.2 Android 端

找到 `android/src/main/java/` 下自动生成的 Plugin 文件，替换内容。

文件路径大概是：
`android/src/main/java/com/example/video_gesture_controls/VideoGestureControlsPlugin.java`

```java
package com.example.video_gesture_controls;

import android.app.Activity;
import android.content.Context;
import android.media.AudioManager;
import android.os.Build;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class VideoGestureControlsPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {

  private MethodChannel channel;
  private Activity activity;
  private AudioManager audioManager;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), "video_gesture_controls");
    channel.setMethodCallHandler(this);
    audioManager = (AudioManager) binding.getApplicationContext().getSystemService(Context.AUDIO_SERVICE);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    switch (call.method) {
      case "setBrightness":
        setBrightness(call.<Double>argument("value"), result);
        break;
      case "getBrightness":
        getBrightness(result);
        break;
      case "setVolume":
        setVolume(call.<Double>argument("value"), result);
        break;
      case "getVolume":
        getVolume(result);
        break;
      default:
        result.notImplemented();
    }
  }

  private void setBrightness(double value, MethodChannel.Result result) {
    if (activity == null) { result.error("NO_ACTIVITY", "Activity is null", null); return; }
    WindowManager.LayoutParams params = activity.getWindow().getAttributes();
    params.screenBrightness = (float) value;
    activity.getWindow().setAttributes(params);
    result.success(null);
  }

  private void getBrightness(MethodChannel.Result result) {
    if (activity == null) { result.error("NO_ACTIVITY", "Activity is null", null); return; }
    float brightness = activity.getWindow().getAttributes().screenBrightness;
    // screenBrightness < 0 表示使用系统默认
    if (brightness < 0) brightness = 0.5f;
    result.success((double) brightness);
  }

  private void setVolume(double value, MethodChannel.Result result) {
    if (audioManager == null) { result.error("NO_AUDIO", "AudioManager is null", null); return; }
    int maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
    int targetVolume = (int) Math.round(value * maxVolume);
    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0);
    result.success(null);
  }

  private void getVolume(MethodChannel.Result result) {
    if (audioManager == null) { result.error("NO_AUDIO", "AudioManager is null", null); return; }
    int maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
    int currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
    result.success(maxVolume > 0 ? (double) currentVolume / maxVolume : 0.0);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  // ActivityAware 回调
  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() { activity = null; }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() { activity = null; }
}
```

### 2.3 Android build.gradle

打开 `android/build.gradle`，确保内容为：

```groovy
group 'com.example.video_gesture_controls'
version '0.1.0'

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0'
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply plugin: 'com.android.library'

android {
    namespace 'com.example.video_gesture_controls'
    compileSdk 34

    defaultConfig {
        minSdk 21
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

---

## 第三步：手势状态管理

### 3.1 创建 `lib/src/controllers/gesture_controller.dart`

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// 手势类型
enum GestureType {
  none,       // 无手势
  seek,       // 快进/快退
  brightness, // 亮度调节
  volume,     // 音量调节
}

/// 手势状态管理器
class GestureController extends ChangeNotifier {
  // ============ 手势状态 ============

  /// 当前手势类型
  GestureType _gestureType = GestureType.none;
  GestureType get gestureType => _gestureType;

  /// 手势是否正在进行
  bool get isGestureActive => _gestureType != GestureType.none;

  // ============ 快进/快退 ============

  /// 快进/快退偏移量（秒），正数=快进，负数=快退
  Duration _seekOffset = Duration.zero;
  Duration get seekOffset => _seekOffset;

  // ============ 亮度 ============

  /// 当前亮度值（0.0 ~ 1.0）
  double _brightness = 0.5;
  double get brightness => _brightness;
  set brightness(double value) {
    _brightness = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  // ============ 音量 ============

  /// 当前音量值（0.0 ~ 1.0）
  double _volume = 0.5;
  double get volume => _volume;
  set volume(double value) {
    _volume = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  // ============ 长按倍速 ============

  /// 是否正在长按倍速播放
  bool _isLongPressing = false;
  bool get isLongPressing => _isLongPressing;

  // ============ 方法 ============

  /// 开始快进/快退手势
  void startSeekGesture() {
    _gestureType = GestureType.seek;
    _seekOffset = Duration.zero;
    notifyListeners();
  }

  /// 更新快进/快退偏移
  void updateSeekOffset(Duration offset) {
    _seekOffset = offset;
    notifyListeners();
  }

  /// 开始亮度手势
  void startBrightnessGesture(double initialValue) {
    _gestureType = GestureType.brightness;
    _brightness = initialValue;
    notifyListeners();
  }

  /// 开始音量手势
  void startVolumeGesture(double initialValue) {
    _gestureType = GestureType.volume;
    _volume = initialValue;
    notifyListeners();
  }

  /// 设置长按倍速状态
  void setLongPressing(bool value) {
    _isLongPressing = value;
    notifyListeners();
  }

  /// 结束手势
  void endGesture() {
    _gestureType = GestureType.none;
    _seekOffset = Duration.zero;
    notifyListeners();
  }

  /// 重置所有状态
  void reset() {
    _gestureType = GestureType.none;
    _seekOffset = Duration.zero;
    _isLongPressing = false;
    notifyListeners();
  }
}
```

---

## 第四步：手势识别层

### 4.1 创建 `lib/src/gestures/video_gesture_detector.dart`

```dart
import 'package:flutter/material.dart';
import '../controllers/gesture_controller.dart';
import '../platform/brightness_volume.dart';

/// 手势识别参数
class VideoGestureCallbacks {
  /// 快进/快退结束回调（传入目标偏移量）
  final void Function(Duration seekOffset)? onSeekEnd;

  /// 双击左侧回调（快退 10 秒）
  final VoidCallback? onDoubleTapLeft;

  /// 双击右侧回调（快进 10 秒）
  final VoidCallback? onDoubleTapRight;

  /// 双击中间回调（播放/暂停）
  final VoidCallback? onDoubleTapCenter;

  /// 长按开始回调
  final VoidCallback? onLongPressStart;

  /// 长按结束回调
  final VoidCallback? onLongPressEnd;

  /// 单击回调（显示/隐藏控制栏）
  final VoidCallback? onSingleTap;

  const VideoGestureCallbacks({
    this.onSeekEnd,
    this.onDoubleTapLeft,
    this.onDoubleTapRight,
    this.onDoubleTapCenter,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onSingleTap,
  });
}

/// 视频手势识别器
///
/// 手势映射：
/// - 水平滑动 → 快进/快退
/// - 垂直滑动（左半屏）→ 亮度调节
/// - 垂直滑动（右半屏）→ 音量调节
/// - 双击（左 1/3）→ 快退 10 秒
/// - 双击（右 1/3）→ 快进 10 秒
/// - 双击（中间 1/3）→ 播放/暂停
/// - 长按 → 2x 倍速播放
/// - 单击 → 显示/隐藏控制栏
class VideoGestureDetector extends StatefulWidget {
  final Widget child;
  final GestureController gestureController;
  final VideoGestureCallbacks callbacks;

  const VideoGestureDetector({
    super.key,
    required this.child,
    required this.gestureController,
    required this.callbacks,
  });

  @override
  State<VideoGestureDetector> createState() => _VideoGestureDetectorState();
}

class _VideoGestureDetectorState extends State<VideoGestureDetector> {
  // ============ 滑动手势状态 ============

  /// 手势起始位置
  Offset _startPosition = Offset.zero;

  /// 已判断出手势方向
  bool _directionDecided = false;

  /// 容器宽度（用于判断左/右区域）
  double _containerWidth = 0;

  // ============ 双击检测 ============

  /// 上次单击时间
  DateTime? _lastTapTime;

  /// 双击检测间隔
  static const Duration _doubleTapThreshold = Duration(milliseconds: 300);

  // ============ 长按检测 ============

  bool _isLongPressing = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _containerWidth = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // ---- 拖动手势（滑动） ----
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          // ---- 点击手势 ----
          onTapUp: _onTapUp,
          // ---- 长按手势 ----
          onLongPressStart: _onLongPressStart,
          onLongPressEnd: _onLongPressEnd,
          child: widget.child,
        );
      },
    );
  }

  // ============ 拖动手势处理 ============

  void _onPanStart(DragStartDetails details) {
    _startPosition = details.localPosition;
    _directionDecided = false;
    _isLongPressing = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_directionDecided == false) {
      // 判断方向：需要移动至少 10 像素
      final dx = (details.localPosition.dx - _startPosition.dx).abs();
      final dy = (details.localPosition.dy - _startPosition.dy).abs();

      if (dx < 10 && dy < 10) return;

      _directionDecided = true;

      if (dx > dy) {
        // 水平滑动 → 快进/快退
        widget.gestureController.startSeekGesture();
      } else {
        // 垂直滑动，判断左/右区域
        final isLeftHalf = _startPosition.dx < _containerWidth / 2;
        if (isLeftHalf) {
          widget.gestureController.startBrightnessGesture(
            widget.gestureController.brightness,
          );
        } else {
          widget.gestureController.startVolumeGesture(
            widget.gestureController.volume,
          );
        }
      }
    }

    // 根据已确定的手势类型更新
    final controller = widget.gestureController;
    switch (controller.gestureType) {
      case GestureType.seek:
        _updateSeekGesture(details.localPosition);
      case GestureType.brightness:
        _updateBrightnessGesture(details.localPosition);
      case GestureType.volume:
        _updateVolumeGesture(details.localPosition);
      case GestureType.none:
        break;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    final controller = widget.gestureController;

    switch (controller.gestureType) {
      case GestureType.seek:
        // 通知上层 seek 到目标位置
        widget.callbacks.onSeekEnd?.call(controller.seekOffset);
      case GestureType.brightness:
        // 亮度已经实时设置，无需额外操作
        break;
      case GestureType.volume:
        // 音量已经实时设置，无需额外操作
        break;
      case GestureType.none:
        break;
    }

    controller.endGesture();
  }

  // ============ 快进/快退计算 ============

  void _updateSeekGesture(Offset currentPosition) {
    final dx = currentPosition.dx - _startPosition.dx;

    // 非线性映射：滑动距离 → 时间偏移
    // 使用平方根使滑动越远，单位距离对应的时间越长
    final pixelsPerSecond = 50.0; // 基础灵敏度
    final sign = dx >= 0 ? 1 : -1;
    final absDx = dx.abs();
    final seconds = sign * (pixelsPerSecond * (absDx / pixelsPerSecond).sqrt() * (absDx / pixelsPerSecond).sqrt() / (absDx / pixelsPerSecond)).abs();
    // 简化：直接用比例映射
    final offsetSeconds = (dx / _containerWidth * 300).round().clamp(-300, 300);

    widget.gestureController.updateSeekOffset(
      Duration(seconds: offsetSeconds),
    );
  }

  // ============ 亮度计算 ============

  void _updateBrightnessGesture(Offset currentPosition) {
    final dy = _startPosition.dy - currentPosition.dy; // 向上为正
    final containerHeight = MediaQuery.of(context).size.height;
    final delta = (dy / containerHeight).clamp(-1.0, 1.0);

    final newValue = (widget.gestureController.brightness + delta).clamp(0.0, 1.0);
    widget.gestureController.brightness = newValue;

    // 实时设置亮度
    BrightnessVolumeChannel.setBrightness(newValue);
  }

  // ============ 音量计算 ============

  void _updateVolumeGesture(Offset currentPosition) {
    final dy = _startPosition.dy - currentPosition.dy; // 向上为正
    final containerHeight = MediaQuery.of(context).size.height;
    final delta = (dy / containerHeight).clamp(-1.0, 1.0);

    final newValue = (widget.gestureController.volume + delta).clamp(0.0, 1.0);
    widget.gestureController.volume = newValue;

    // 实时设置音量
    BrightnessVolumeChannel.setVolume(newValue);
  }

  // ============ 点击处理（单击 + 双击） ============

  void _onTapUp(TapUpDetails details) {
    final now = DateTime.now();

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapThreshold) {
      // 双击
      _lastTapTime = null;
      _handleDoubleTap(details.localPosition);
    } else {
      // 可能是单击，延迟判断
      _lastTapTime = now;
      Future.delayed(_doubleTapThreshold, () {
        if (_lastTapTime == now && mounted) {
          // 确认是单击
          widget.callbacks.onSingleTap?.call();
        }
      });
    }
  }

  void _handleDoubleTap(Offset position) {
    final third = _containerWidth / 3;

    if (position.dx < third) {
      // 左 1/3：快退 10 秒
      widget.callbacks.onDoubleTapLeft?.call();
    } else if (position.dx > third * 2) {
      // 右 1/3：快进 10 秒
      widget.callbacks.onDoubleTapRight?.call();
    } else {
      // 中间 1/3：播放/暂停
      widget.callbacks.onDoubleTapCenter?.call();
    }
  }

  // ============ 长按处理 ============

  void _onLongPressStart(LongPressStartDetails details) {
    _isLongPressing = true;
    widget.gestureController.setLongPressing(true);
    widget.callbacks.onLongPressStart?.call();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _isLongPressing = false;
    widget.gestureController.setLongPressing(false);
    widget.callbacks.onLongPressEnd?.call();
  }
}
```

---

## 第五步：手势反馈浮层

### 5.1 创建 `lib/src/widgets/gesture_overlay.dart`

```dart
import 'package:flutter/material.dart';
import '../controllers/gesture_controller.dart';

/// 手势反馈浮层
///
/// 根据手势类型显示不同的 UI 反馈：
/// - 快进/快退：中间显示进度条 + 时间变化
/// - 亮度调节：左侧显示太阳图标 + 百分比
/// - 音量调节：右侧显示喇叭图标 + 百分比
/// - 长按倍速：顶部显示 "2x 快进中"
class GestureOverlay extends StatelessWidget {
  final GestureController gestureController;

  const GestureOverlay({
    super.key,
    required this.gestureController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gestureController,
      builder: (context, _) {
        return Stack(
          children: [
            // 快进/快退指示
            if (gestureController.gestureType == GestureType.seek)
              _buildSeekIndicator(context),

            // 亮度指示
            if (gestureController.gestureType == GestureType.brightness)
              _buildBrightnessIndicator(context),

            // 音量指示
            if (gestureController.gestureType == GestureType.volume)
              _buildVolumeIndicator(context),

            // 长按倍速指示
            if (gestureController.isLongPressing)
              _buildLongPressIndicator(context),
          ],
        );
      },
    );
  }

  /// 快进/快退指示
  Widget _buildSeekIndicator(BuildContext context) {
    final offset = gestureController.seekOffset;
    final isForward = offset.inSeconds >= 0;
    final seconds = offset.inSeconds.abs();
    final sign = isForward ? '+' : '-';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForward ? Icons.fast_forward : Icons.fast_rewind,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              '$sign${seconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 亮度指示（左侧竖条）
  Widget _buildBrightnessIndicator(BuildContext context) {
    final value = gestureController.brightness;
    final percent = (value * 100).round();

    return Positioned(
      left: 24,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.brightness_high, color: Colors.white, size: 24),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              // 竖向进度条
              SizedBox(
                height: 100,
                child: VerticalProgressBar(value: value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 音量指示（右侧竖条）
  Widget _buildVolumeIndicator(BuildContext context) {
    final value = gestureController.volume;
    final percent = (value * 100).round();

    return Positioned(
      right: 24,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value == 0 ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: VerticalProgressBar(value: value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 长按倍速指示
  Widget _buildLongPressIndicator(BuildContext context) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fast_forward, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                '2x 快进中',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 竖向进度条
class VerticalProgressBar extends StatelessWidget {
  final double value; // 0.0 ~ 1.0

  const VerticalProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 第六步：进度条组件

### 6.1 创建 `lib/src/widgets/progress_bar.dart`

```dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 视频进度条
///
/// 包含：缓冲进度（灰色）+ 播放进度（主题色）+ 拖拽手柄 + 时间显示
class VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final Color activeColor;
  final Color bufferedColor;
  final Color backgroundColor;
  final double height;
  final double handleRadius;

  const VideoProgressBar({
    super.key,
    required this.controller,
    this.activeColor = const Color(0xFF2196F3),
    this.bufferedColor = Colors.white24,
    this.backgroundColor = Colors.white12,
    this.height = 3.0,
    this.handleRadius = 6.0,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final duration = value.duration.inMilliseconds.toDouble();
        final position = value.position.inMilliseconds.toDouble();

        double progress = duration > 0 ? position / duration : 0.0;

        // 缓冲进度
        double bufferedProgress = 0.0;
        if (duration > 0 && value.buffered.isNotEmpty) {
          final bufferedEnd = value.buffered.last.end.inMilliseconds.toDouble();
          bufferedProgress = (bufferedEnd / duration).clamp(0.0, 1.0);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => setState(() => _isDragging = true),
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox;
            final localX = details.localPosition.dx;
            final ratio = (localX / box.size.width).clamp(0.0, 1.0);
            final targetMs = (ratio * duration).round();
            widget.controller.seekTo(Duration(milliseconds: targetMs));
          },
          onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
          onTapUp: (details) {
            final box = context.findRenderObject() as RenderBox;
            final localX = details.localPosition.dx;
            final ratio = (localX / box.size.width).clamp(0.0, 1.0);
            final targetMs = (ratio * duration).round();
            widget.controller.seekTo(Duration(milliseconds: targetMs));
          },
          child: Container(
            height: _isDragging ? 16 : widget.height + 10,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 背景条
                Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                  ),
                ),
                // 缓冲条
                FractionallySizedBox(
                  widthFactor: bufferedProgress,
                  child: Container(
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: widget.bufferedColor,
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                ),
                // 播放进度条
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: widget.activeColor,
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                ),
                // 拖拽手柄
                Positioned(
                  left: (progress * MediaQuery.of(context).size.width) - widget.handleRadius,
                  top: -(widget.handleRadius - widget.height) / 2,
                  child: Container(
                    width: widget.handleRadius * 2,
                    height: widget.handleRadius * 2,
                    decoration: BoxDecoration(
                      color: widget.activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

---

## 第七步：顶部栏

### 7.1 创建 `lib/src/widgets/top_bar.dart`

```dart
import 'package:flutter/material.dart';

/// 顶部栏（返回 + 标题）
class TopBar extends StatelessWidget {
  final String? title;
  final VoidCallback? onBack;

  const TopBar({
    super.key,
    this.title,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack ?? () => Navigator.of(context).pop(),
                tooltip: '返回',
              ),
              Expanded(
                child: Text(
                  title ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 第八步：底部控制栏

### 8.1 创建 `lib/src/widgets/control_bar.dart`

```dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'progress_bar.dart';

/// 底部控制栏
class ControlBar extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback? onFullscreen;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onSpeedTap;
  final VoidCallback? onQualityTap;
  final bool isMuted;
  final double currentSpeed;
  final String? qualityLabel;
  final bool isFullscreen;

  const ControlBar({
    super.key,
    required this.controller,
    this.onFullscreen,
    this.onMuteToggle,
    this.onSpeedTap,
    this.onQualityTap,
    this.isMuted = false,
    this.currentSpeed = 1.0,
    this.qualityLabel,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: VideoProgressBar(controller: controller),
              ),
              // 按钮行
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // 播放/暂停
                    _PlayPauseButton(controller: controller),

                    // 时间显示
                    _TimeDisplay(controller: controller),

                    const Spacer(),

                    // 静音
                    _IconButton(
                      icon: isMuted ? Icons.volume_off : Icons.volume_up,
                      onTap: onMuteToggle,
                    ),

                    // 倍速
                    _IconButton(
                      icon: Icons.speed,
                      label: '${currentSpeed}x',
                      onTap: onSpeedTap,
                    ),

                    // 画质
                    if (qualityLabel != null)
                      _IconButton(
                        icon: Icons.hd,
                        label: qualityLabel!,
                        onTap: onQualityTap,
                      ),

                    // 全屏
                    _IconButton(
                      icon: isFullscreen
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      onTap: onFullscreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 播放/暂停按钮
class _PlayPauseButton extends StatelessWidget {
  final VideoPlayerController controller;

  const _PlayPauseButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final isPlaying = value.isPlaying;
        return IconButton(
          icon: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 28,
          ),
          onPressed: () {
            if (isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
        );
      },
    );
  }
}

/// 时间显示
class _TimeDisplay extends StatelessWidget {
  final VideoPlayerController controller;

  const _TimeDisplay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final position = _formatDuration(value.position);
        final duration = _formatDuration(value.duration);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '$position / $duration',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

/// 图标按钮（可选文字标签）
class _IconButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  const _IconButton({
    required this.icon,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 2),
              Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 22),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
```

---

## 第九步：倍速选择器

### 9.1 创建 `lib/src/widgets/speed_selector.dart`

```dart
import 'package:flutter/material.dart';

/// 倍速选择面板
class SpeedSelector extends StatelessWidget {
  final List<double> speeds;
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  const SpeedSelector({
    super.key,
    required this.speeds,
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '倍速',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...speeds.map((speed) {
            final isSelected = speed == currentSpeed;
            return ListTile(
              title: Text(
                speed == 1.0 ? '正常' : '${speed}x',
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.white,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onSpeedSelected(speed);
              },
            );
          }),
        ],
      ),
    );
  }

  /// 显示倍速选择器
  static void show(
    BuildContext context, {
    required List<double> speeds,
    required double currentSpeed,
    required ValueChanged<double> onSpeedSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SpeedSelector(
        speeds: speeds,
        currentSpeed: currentSpeed,
        onSpeedSelected: onSpeedSelected,
      ),
    );
  }
}
```

---

## 第十步：加载遮罩

### 10.1 创建 `lib/src/widgets/loading_overlay.dart`

```dart
import 'package:flutter/material.dart';

/// 加载/缓冲遮罩
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final bool isBuffering;

  const LoadingOverlay({
    super.key,
    this.isLoading = false,
    this.isBuffering = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && !isBuffering) return const SizedBox.shrink();

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            SizedBox(height: 12),
            Text(
              '缓冲中...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 第十一步：组装主 Widget

### 11.1 创建 `lib/src/video_player_controls.dart`

这是最核心的文件，整合所有组件。

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'controllers/gesture_controller.dart';
import 'gestures/video_gesture_detector.dart';
import 'widgets/control_bar.dart';
import 'widgets/top_bar.dart';
import 'widgets/gesture_overlay.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/speed_selector.dart';
import 'platform/brightness_volume.dart';

/// 画质选项（由外部传入）
class QualityItem {
  final String label;
  final dynamic data; // 外部自定义数据

  const QualityItem({required this.label, this.data});
}

/// 视频播放器控制组件
///
/// 整合手势操作 + 控制栏 + 视频画面，替代 chewie。
///
/// ```dart
/// VideoPlayerControls(
///   controller: videoPlayerController,
///   title: '电影名称',
///   onBack: () => Navigator.pop(context),
/// )
/// ```
class VideoPlayerControls extends StatefulWidget {
  /// video_player 控制器（必填）
  final VideoPlayerController controller;

  /// 顶部显示的标题
  final String? title;

  /// 返回按钮回调
  final VoidCallback? onBack;

  /// 进度变化回调（用于上报 Jellyfin）
  final void Function(Duration position, Duration duration)? onProgressChanged;

  /// 控制栏自动隐藏时间
  final Duration controlsTimeout;

  /// 可选倍速列表
  final List<double> playbackSpeeds;

  /// 画质选项列表
  final List<QualityItem>? qualities;

  /// 画质切换回调
  final void Function(QualityItem)? onQualitySelected;

  /// 初始亮度（0.0-1.0）
  final double? initialBrightness;

  /// 初始音量（0.0-1.0）
  final double? initialVolume;

  const VideoPlayerControls({
    super.key,
    required this.controller,
    this.title,
    this.onBack,
    this.onProgressChanged,
    this.controlsTimeout = const Duration(seconds: 5),
    this.playbackSpeeds = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    this.qualities,
    this.onQualitySelected,
    this.initialBrightness,
    this.initialVolume,
  });

  @override
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> {
  // ============ 控制栏显隐 ============

  bool _showControls = true;
  Timer? _hideTimer;

  // ============ 手势状态 ============

  final GestureController _gestureController = GestureController();

  // ============ 播放状态 ============

  double _currentSpeed = 1.0;
  bool _isMuted = false;
  bool _isFullscreen = false;

  // ============ 进度回调节流 ============

  Duration _lastReportedPosition = Duration.zero;
  Timer? _progressReportTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _initPlatformValues();
    _startProgressReport();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressReportTimer?.cancel();
    _gestureController.dispose();
    super.dispose();
  }

  /// 初始化平台亮度/音量值
  Future<void> _initPlatformValues() async {
    try {
      if (widget.initialBrightness != null) {
        _gestureController.brightness = widget.initialBrightness!;
      } else {
        final brightness = await BrightnessVolumeChannel.getBrightness();
        _gestureController.brightness = brightness;
      }

      if (widget.initialVolume != null) {
        _gestureController.volume = widget.initialVolume!;
      } else {
        final volume = await BrightnessVolumeChannel.getVolume();
        _gestureController.volume = volume;
      }
    } catch (_) {
      // 平台可能不支持，忽略
    }
  }

  /// 启动进度上报定时器（每秒触发一次回调）
  void _startProgressReport() {
    _progressReportTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.onProgressChanged != null) {
        final value = widget.controller.value;
        widget.onProgressChanged!(value.position, value.duration);
      }
    });
  }

  // ============ 控制栏显隐 ============

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.controlsTimeout, () {
      if (mounted && !_gestureController.isGestureActive) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  void _keepControlsVisible() {
    if (_showControls) {
      _startHideTimer();
    }
  }

  // ============ 手势回调 ============

  void _onSeekEnd(Duration seekOffset) {
    final current = widget.controller.value.position;
    final target = current + seekOffset;
    final duration = widget.controller.value.duration;
    final clampedTarget = Duration(
      milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    widget.controller.seekTo(clampedTarget);
  }

  void _onDoubleTapLeft() {
    final current = widget.controller.value.position;
    final target = current - const Duration(seconds: 10);
    final clamped = Duration(milliseconds: current.inMilliseconds.clamp(0, current.inMilliseconds));
    widget.controller.seekTo(target > Duration.zero ? target : Duration.zero);
    _keepControlsVisible();
  }

  void _onDoubleTapRight() {
    final current = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final target = current + const Duration(seconds: 10);
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    widget.controller.seekTo(clamped);
    _keepControlsVisible();
  }

  void _onDoubleTapCenter() {
    final value = widget.controller.value;
    if (value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _keepControlsVisible();
  }

  void _onLongPressStart() {
    widget.controller.setPlaybackSpeed(2.0);
  }

  void _onLongPressEnd() {
    widget.controller.setPlaybackSpeed(_currentSpeed);
  }

  // ============ 控制栏操作 ============

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      widget.controller.setVolume(0);
    } else {
      widget.controller.setVolume(1.0);
    }
    _keepControlsVisible();
  }

  void _showSpeedSelector() {
    SpeedSelector.show(
      context,
      speeds: widget.playbackSpeeds,
      currentSpeed: _currentSpeed,
      onSpeedSelected: (speed) {
        setState(() => _currentSpeed = speed);
        widget.controller.setPlaybackSpeed(speed);
      },
    );
    _keepControlsVisible();
  }

  void _showQualitySelector() {
    if (widget.qualities == null || widget.qualities!.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '画质选择',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ...widget.qualities!.map((q) {
                return ListTile(
                  title: Text(q.label, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onQualitySelected?.call(q);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFullscreen() async {
    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  // ============ 构建 UI ============

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 视频画面
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),

          // 2. 手势识别层（覆盖整个区域）
          Positioned.fill(
            child: VideoGestureDetector(
              gestureController: _gestureController,
              callbacks: VideoGestureCallbacks(
                onSeekEnd: _onSeekEnd,
                onDoubleTapLeft: _onDoubleTapLeft,
                onDoubleTapRight: _onDoubleTapRight,
                onDoubleTapCenter: _onDoubleTapCenter,
                onLongPressStart: _onLongPressStart,
                onLongPressEnd: _onLongPressEnd,
                onSingleTap: _toggleControls,
              ),
              child: const SizedBox.expand(),
            ),
          ),

          // 3. 手势反馈浮层
          Positioned.fill(
            child: IgnorePointer(
              child: GestureOverlay(gestureController: _gestureController),
            ),
          ),

          // 4. 加载/缓冲遮罩
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: widget.controller,
                builder: (_, value, __) {
                  return LoadingOverlay(
                    isBuffering: value.isBuffering,
                  );
                },
              ),
            ),
          ),

          // 5. 控制栏（顶部 + 底部）
          if (_showControls) ...[
            // 顶部栏
            TopBar(
              title: widget.title,
              onBack: widget.onBack,
            ),

            // 底部控制栏
            ControlBar(
              controller: widget.controller,
              isMuted: _isMuted,
              currentSpeed: _currentSpeed,
              isFullscreen: _isFullscreen,
              qualityLabel: widget.qualities?.isNotEmpty == true
                  ? widget.qualities!.first.label
                  : null,
              onMuteToggle: _toggleMute,
              onSpeedTap: _showSpeedSelector,
              onQualityTap: _showQualitySelector,
              onFullscreen: _toggleFullscreen,
            ),
          ],
        ],
      ),
    );
  }
}
```

---

## 第十二步：集成到项目

### 12.1 在根 pubspec.yaml 添加依赖

打开 `Jellyfin_Service/pubspec.yaml`，修改：

```yaml
dependencies:
  # 视频播放
  video_player: ^2.8.1
  # chewie: ^1.7.5    ← 删除或注释掉
  video_gesture_controls:
    path: packages/video_gesture_controls
```

### 12.2 安装依赖

```bash
cd D:/claudeProject/flutter_video_project/ai-video-project/Jellyfin_Service
flutter pub get
```

### 12.3 修改 video_player_page.dart

打开 `lib/src/ui/pages/video_player_page.dart`，做以下改动：

**1) 替换 import：**
```dart
// 删除这行：
// import 'package:chewie/chewie.dart';

// 添加这行：
import 'package:video_gesture_controls/video_gesture_controls.dart';
```

**2) 删除 ChewieController 字段：**
```dart
// 删除这行：
// ChewieController? _chewieController;
```

**3) 修改 dispose()：**
```dart
// 删除这行：
// _chewieController?.dispose();
```

**4) 修改 _setupVideoController()：**
```dart
// 删除整个 _chewieController = ChewieController(...) 块（第 185-195 行）
// 初始化 video controller 之后的 chewie 绑定代码全部删掉
```

修改后该方法应为：
```dart
Future<void> _setupVideoController(
  PlaybackInfo playbackInfo, {
  int? resumeTicks,
  Duration? seekPosition,
}) async {
  _videoController = VideoPlayerController.networkUrl(
    Uri.parse(playbackInfo.url),
  );

  await _videoController!.initialize();

  // 续播或跳转到指定位置
  if (seekPosition != null) {
    await _videoController!.seekTo(seekPosition);
  } else if (resumeTicks != null && resumeTicks > 0) {
    final resumeSeconds = resumeTicks / 10000000;
    await _videoController!.seekTo(Duration(seconds: resumeSeconds.round()));
  }

  // 恢复倍速
  if (_currentSpeed != 1.0) {
    await _videoController!.setPlaybackSpeed(_currentSpeed);
  }

  // 不再创建 ChewieController
}
```

**5) 修改 _switchQuality()：**
```dart
// 删除这两行：
// _chewieController?.dispose();
// _chewieController = null;
```

**6) 替换 _buildPlayerWidget()：**
```dart
Widget _buildPlayerWidget() {
  return VideoPlayerControls(
    controller: _videoController!,
    title: widget.item.name,
    onBack: () => Navigator.of(context).pop(),
    playbackSpeeds: _playbackSpeeds,
    qualities: VideoQuality.values
        .map((q) => QualityItem(
              label: q.label,
              data: q,
            ))
        .toList(),
    onQualitySelected: (item) {
      _switchQuality(item.data as VideoQuality);
    },
    onProgressChanged: (position, duration) {
      // 这里可以上报进度（保留原有逻辑）
    },
  );
}
```

**7) 删除顶部的自定义顶部栏和画质按钮：**

在 `build()` 方法的 `Stack` 里删除这两段代码：
- 删除 `Positioned(top: 0, ...)` 的顶部栏（第 450-491 行），因为 VideoPlayerControls 自带了
- 删除 `Positioned(bottom: 0, right: 96, ...)` 的画质按钮（第 493-498 行）
- 删除 `_buildQualityBadge()` 方法（第 505-522 行）
- 删除 `_showQualitySelector()` 方法（第 338-378 行）
- 删除 `_buildQualityOption()` 方法（第 381-408 行）

### 12.4 完整的改动后的 video_player_page.dart

改动后的文件关键部分对比：

| 项目 | 改前（chewie） | 改后（video_gesture_controls） |
|------|------|------|
| import | `chewie/chewie.dart` | `video_gesture_controls/video_gesture_controls.dart` |
| 字段 | `ChewieController? _chewieController` | 删除 |
| 初始化 | 创建 `ChewieController(...)` | 不需要，直接用 `VideoPlayerController` |
| UI | `Chewie(controller: _chewieController!)` | `VideoPlayerControls(controller: _videoController!, ...)` |
| 画质UI | 自定义 `_showQualitySelector()` | 通过 `qualities` 参数传入 |
| 顶部栏 | 自定义 Stack Positioned | VideoPlayerControls 内置 |
| dispose | `_chewieController?.dispose()` | 删除 |

---

## 第十三步：验证

```bash
# 1. 检查依赖
cd D:/claudeProject/flutter_video_project/ai-video-project/Jellyfin_Service
flutter pub get

# 2. 分析代码
flutter analyze

# 3. 运行 example app
cd example
flutter run
```

### 验证清单

- [ ] 滑动手势：左右滑动 → 快进/快退指示器
- [ ] 滑动手势：左半屏上下滑动 → 亮度调节
- [ ] 滑动手势：右半屏上下滑动 → 音量调节
- [ ] 双击左侧 → 快退 10 秒
- [ ] 双击右侧 → 快进 10 秒
- [ ] 双击中间 → 播放/暂停
- [ ] 长按 → 2x 倍速
- [ ] 单击 → 控制栏显隐
- [ ] 控制栏 5 秒自动隐藏
- [ ] 进度条拖拽
- [ ] 播放/暂停按钮
- [ ] 静音切换
- [ ] 倍速选择
- [ ] 画质选择
- [ ] 全屏切换
- [ ] 缓冲遮罩

---

## 文件创建顺序速查

按这个顺序一个一个创建文件：

```
1. pubspec.yaml
2. lib/video_gesture_controls.dart
3. lib/src/platform/brightness_volume.dart
4. android/.../VideoGestureControlsPlugin.java
5. lib/src/controllers/gesture_controller.dart
6. lib/src/gestures/video_gesture_detector.dart
7. lib/src/widgets/gesture_overlay.dart
8. lib/src/widgets/progress_bar.dart
9. lib/src/widgets/top_bar.dart
10. lib/src/widgets/control_bar.dart
11. lib/src/widgets/speed_selector.dart
12. lib/src/widgets/loading_overlay.dart
13. lib/src/video_player_controls.dart      ← 最后创建
14. 修改 video_player_page.dart              ← 集成
15. 修改 pubspec.yaml                        ← 添加依赖
```
