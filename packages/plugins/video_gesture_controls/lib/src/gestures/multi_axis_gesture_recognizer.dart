import 'dart:async';

import 'package:flutter/gestures.dart';

import '../models/gesture_config.dart';

/// 拖拽轴向
enum _DragAxis {
  undecided,
  horizontal,
  vertical,
}

/// 多轴手势识别器
///
/// 继承 OneSequenceGestureRecognizer，参与手势竞技场。
/// 状态机：IDLE → TRACKING → DECIDED(horizontal/brightness/volume)
/// 或 LONG_PRESS
///
/// 判定逻辑：
/// - 移动超过 [VideoGestureConfig.gestureThreshold] 后锁定轴向
/// - 垂直方向根据 startX 判断左半（亮度）/右半（音量）
/// - 长按检测：[VideoGestureConfig.longPressDelayMs] 无移动触发
class MultiAxisGestureRecognizer extends OneSequenceGestureRecognizer {
  VideoGestureConfig config;

  // 回调
  GestureDragStartCallback? onStart;
  GestureDragUpdateCallback? onUpdate;
  GestureDragEndCallback? onEnd;
  GestureLongPressStartCallback? onLongPressStart;
  GestureLongPressEndCallback? onLongPressEnd;

  // 状态
  _DragAxis _axis = _DragAxis.undecided;
  Offset _startPosition = Offset.zero;
  Offset _lastPosition = Offset.zero;
  bool _isLongPress = false;
  Timer? _longPressTimer;
  double _screenWidth = 0;

  MultiAxisGestureRecognizer({
    this.config = const VideoGestureConfig(),
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onLongPressStart,
    this.onLongPressEnd,
    super.debugOwner,
  });

  @override
  String get debugDescription => 'multiAxisGesture';

  /// 设置屏幕宽度，用于判断左/右半屏
  void setScreenWidth(double width) {
    _screenWidth = width;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _startPosition = event.position;
    _lastPosition = event.position;
    _axis = _DragAxis.undecided;
    _isLongPress = false;
    _startLongPressTimer(event.pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _handleMove(event);
    } else if (event is PointerUpEvent) {
      _handleUp(event);
    } else if (event is PointerCancelEvent) {
      _handleCancel();
    }
  }

  void _handleMove(PointerMoveEvent event) {
    _cancelLongPressTimer();

    if (_isLongPress) {
      // 长按后移动则取消
      _isLongPress = false;
      onLongPressEnd?.call(LongPressEndDetails(
        globalPosition: event.position,
      ));
      resolve(GestureDisposition.rejected);
      return;
    }

    final delta = event.position - _startPosition;

    // 判定轴向
    if (_axis == _DragAxis.undecided) {
      final distance = delta.distance;
      if (distance > config.gestureThreshold) {
        // 锁定轴向
        if (delta.dx.abs() > delta.dy.abs()) {
          _axis = _DragAxis.horizontal;
        } else {
          _axis = _DragAxis.vertical;
        }
        resolve(GestureDisposition.accepted);
        onStart?.call(DragStartDetails(
          globalPosition: _startPosition,
          localPosition: _startPosition,
        ));
      }
    }

    // 发送更新
    if (_axis != _DragAxis.undecided) {
      final updateDelta = event.position - _lastPosition;
      onUpdate?.call(DragUpdateDetails(
        globalPosition: event.position,
        localPosition: event.position,
        delta: updateDelta,
        primaryDelta: _axis == _DragAxis.horizontal
            ? updateDelta.dx
            : updateDelta.dy,
      ));
      _lastPosition = event.position;
    }
  }

  void _handleUp(PointerUpEvent event) {
    _cancelLongPressTimer();
    if (_isLongPress) {
      onLongPressEnd?.call(LongPressEndDetails(
        globalPosition: event.position,
      ));
      _isLongPress = false;
    } else if (_axis != _DragAxis.undecided) {
      onEnd?.call(DragEndDetails(
        globalPosition: event.position,
        velocity: Velocity.zero,
      ));
    }
    _reset();
    stopTrackingPointer(event.pointer);
  }

  void _handleCancel() {
    _cancelLongPressTimer();
    if (_isLongPress) {
      onLongPressEnd?.call(LongPressEndDetails(
        globalPosition: _lastPosition,
      ));
    }
    _reset();
  }

  void _startLongPressTimer(int pointer) {
    _longPressTimer = Timer(
      Duration(milliseconds: config.longPressDelayMs),
      () {
        _isLongPress = true;
        resolve(GestureDisposition.accepted);
        onLongPressStart?.call(LongPressStartDetails(
          globalPosition: _startPosition,
        ));
      },
    );
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _reset() {
    _axis = _DragAxis.undecided;
    _isLongPress = false;
    _startPosition = Offset.zero;
    _lastPosition = Offset.zero;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _cancelLongPressTimer();
    _reset();
  }

  @override
  void dispose() {
    _cancelLongPressTimer();
    super.dispose();
  }

  // --- 辅助方法 ---

  /// 起始位置是否在左半屏
  bool isStartOnLeftHalf() {
    if (_screenWidth <= 0) return true;
    return _startPosition.dx < _screenWidth / 2;
  }

  /// 获取起始位置
  Offset get startPosition => _startPosition;
}
