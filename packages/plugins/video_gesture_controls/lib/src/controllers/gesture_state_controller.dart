import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/gesture_config.dart';
import '../services/simulated_brightness_volume.dart';

/// 手势模式
enum GestureMode {
  idle,
  seeking,
  brightness,
  volume,
  longPress,
}

/// 手势叠加层状态控制器
///
/// 管理所有可变状态：当前手势模式、指示器可见性、控制栏显隐、自动隐藏定时器。
class GestureOverlayController extends ChangeNotifier {
  final VideoGestureConfig config;
  final SimulatedBrightnessVolume _sim;

  GestureMode _mode = GestureMode.idle;
  bool _controlBarVisible = false;
  Timer? _controlBarTimer;
  Timer? _indicatorTimer;

  // 快进/快退累计偏移（秒）
  double _seekDelta = 0;

  // 长按标记
  bool _isLongPressing = false;

  GestureOverlayController({
    this.config = const VideoGestureConfig(),
    SimulatedBrightnessVolume? simulated,
  }) : _sim = simulated ?? SimulatedBrightnessVolume();

  // --- Getters ---

  GestureMode get mode => _mode;
  bool get controlBarVisible => _controlBarVisible;
  double get seekDelta => _seekDelta;
  bool get isLongPressing => _isLongPressing;
  double get brightness => _sim.brightness;
  double get volume => _sim.volume;

  // --- 指示器可见性 ---

  bool get isSeekingVisible => _mode == GestureMode.seeking;
  bool get isBrightnessVisible => _mode == GestureMode.brightness;
  bool get isVolumeVisible => _mode == GestureMode.volume;
  bool get isLongPressVisible => _mode == GestureMode.longPress;

  // --- 手势模式切换 ---

  void enterMode(GestureMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    _cancelIndicatorTimer();
    notifyListeners();
  }

  void resetToIdle() {
    _mode = GestureMode.idle;
    _seekDelta = 0;
    _isLongPressing = false;
    _cancelIndicatorTimer();
    notifyListeners();
  }

  // --- 快进/快退 ---

  void updateSeekDelta(double deltaSeconds) {
    _seekDelta += deltaSeconds;
    enterMode(GestureMode.seeking);
  }

  /// 确认快进/快退（手指抬起时调用）
  void commitSeek() {
    _cancelIndicatorTimer();
    // 指示器延迟隐藏
    _indicatorTimer = Timer(
      Duration(milliseconds: config.indicatorDurationMs),
      () {
        _mode = GestureMode.idle;
        _seekDelta = 0;
        notifyListeners();
      },
    );
  }

  // --- 亮度/音量 ---

  double adjustBrightness(double delta) {
    final value = _sim.adjustBrightness(delta);
    enterMode(GestureMode.brightness);
    return value;
  }

  double adjustVolume(double delta) {
    final value = _sim.adjustVolume(delta);
    enterMode(GestureMode.volume);
    return value;
  }

  void commitBrightness() {
    _cancelIndicatorTimer();
    _indicatorTimer = Timer(
      Duration(milliseconds: config.indicatorDurationMs),
      () {
        _mode = GestureMode.idle;
        notifyListeners();
      },
    );
  }

  void commitVolume() {
    _cancelIndicatorTimer();
    _indicatorTimer = Timer(
      Duration(milliseconds: config.indicatorDurationMs),
      () {
        _mode = GestureMode.idle;
        notifyListeners();
      },
    );
  }

  // --- 长按 ---

  void startLongPress() {
    _isLongPressing = true;
    enterMode(GestureMode.longPress);
  }

  void endLongPress() {
    _isLongPressing = false;
    _cancelIndicatorTimer();
    _indicatorTimer = Timer(
      Duration(milliseconds: config.indicatorDurationMs),
      () {
        _mode = GestureMode.idle;
        notifyListeners();
      },
    );
  }

  // --- 控制栏 ---

  void toggleControlBar() {
    if (_controlBarVisible) {
      hideControlBar();
    } else {
      showControlBar();
    }
  }

  void showControlBar() {
    _controlBarVisible = true;
    _cancelControlBarTimer();
    _controlBarTimer = Timer(
      Duration(milliseconds: config.controlBarAutoHideMs),
      () {
        _controlBarVisible = false;
        notifyListeners();
      },
    );
    notifyListeners();
  }

  void hideControlBar() {
    _controlBarVisible = false;
    _cancelControlBarTimer();
    notifyListeners();
  }

  /// 控制栏交互时重置自动隐藏计时器
  void resetControlBarTimer() {
    if (_controlBarVisible) {
      _cancelControlBarTimer();
      _controlBarTimer = Timer(
        Duration(milliseconds: config.controlBarAutoHideMs),
        () {
          _controlBarVisible = false;
          notifyListeners();
        },
      );
    }
  }

  // --- 私有 ---

  void _cancelControlBarTimer() {
    _controlBarTimer?.cancel();
    _controlBarTimer = null;
  }

  void _cancelIndicatorTimer() {
    _indicatorTimer?.cancel();
    _indicatorTimer = null;
  }

  @override
  void dispose() {
    _cancelControlBarTimer();
    _cancelIndicatorTimer();
    super.dispose();
  }
}
