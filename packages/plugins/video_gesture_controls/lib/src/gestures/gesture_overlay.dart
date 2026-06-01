import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/gesture_state_controller.dart';
import '../models/gesture_callbacks.dart';
import '../widgets/brightness_indicator.dart';
import '../widgets/control_bar.dart';
import '../widgets/play_pause_flash.dart';
import '../widgets/seek_indicator.dart';
import '../widgets/speed_indicator.dart';
import '../widgets/volume_indicator.dart';

/// 视频手势叠加层（主入口）
///
/// 用法：
/// ```dart
/// VideoGestureOverlay(
///   controller: myController,
///   callbacks: myCallbacks,
///   isPlaying: true,
///   position: Duration(seconds: 30),
///   duration: Duration(minutes: 5),
///   child: VideoPlayer(...),
/// )
/// ```
class VideoGestureOverlay extends StatefulWidget {
  /// 状态控制器
  final GestureOverlayController controller;

  /// 回调集合
  final VideoGestureCallbacks callbacks;

  /// 播放器子 Widget（视频画面）
  final Widget child;

  /// 是否正在播放
  final bool isPlaying;

  /// 当前播放位置
  final Duration position;

  /// 视频总时长
  final Duration duration;

  /// 是否全屏
  final bool isFullScreen;

  const VideoGestureOverlay({
    super.key,
    required this.controller,
    required this.callbacks,
    required this.child,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isFullScreen = false,
  });

  @override
  State<VideoGestureOverlay> createState() => _VideoGestureOverlayState();
}

class _VideoGestureOverlayState extends State<VideoGestureOverlay> {
  bool _showPlayPauseFlash = false;
  bool _flashIsPlaying = false;
  Timer? _flashTimer;

  // 拖拽状态
  Offset _dragStart = Offset.zero;
  Offset _dragLast = Offset.zero;
  _DragAxis _dragAxis = _DragAxis.undecided;
  bool _isDragging = false;
  double _seekDelta = 0;
  bool _isLeftHalf = true;

  // 长按状态
  bool _isLongPressing = false;
  Timer? _longPressTimer;

  // 单击/双击状态
  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(VideoGestureOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _flashTimer?.cancel();
    _longPressTimer?.cancel();
    _tapTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // --- 指针事件处理 ---

  void _onPointerDown(PointerDownEvent event) {
    _dragStart = event.position;
    _dragLast = event.position;
    _dragAxis = _DragAxis.undecided;
    _isDragging = false;
    _isLeftHalf = event.position.dx < (context.size?.width ?? 0) / 2;

    // 启动长按计时器
    _cancelLongPressTimer();
    _longPressTimer = Timer(
      Duration(milliseconds: widget.controller.config.longPressDelayMs),
      () {
        if (!_isDragging) {
          _isLongPressing = true;
          widget.controller.startLongPress();
          widget.callbacks.onSetSpeed
              ?.call(widget.controller.config.longPressSpeed);
        }
      },
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isLongPressing) {
      // 长按中移动取消长按
      _cancelLongPress();
      return;
    }

    final delta = event.position - _dragStart;
    final config = widget.controller.config;

    // 判定轴向
    if (_dragAxis == _DragAxis.undecided) {
      if (delta.distance > config.gestureThreshold) {
        _dragAxis =
            delta.dx.abs() > delta.dy.abs()
                ? _DragAxis.horizontal
                : _DragAxis.vertical;
        _isDragging = true;
        _cancelLongPressTimer();
      }
    }

    if (!_isDragging) return;

    final moveDelta = event.position - _dragLast;
    final ctrl = widget.controller;

    if (_dragAxis == _DragAxis.horizontal) {
      // 快进/快退
      final deltaSeconds = moveDelta.dx * config.seekSensitivity;
      _seekDelta += deltaSeconds;
      ctrl.updateSeekDelta(deltaSeconds);
    } else if (_dragAxis == _DragAxis.vertical) {
      // 亮度或音量
      final verticalDelta = -moveDelta.dy * config.verticalSensitivity;
      if (_isLeftHalf) {
        final value = ctrl.adjustBrightness(verticalDelta);
        widget.callbacks.onBrightnessChanged?.call(value);
      } else {
        final value = ctrl.adjustVolume(verticalDelta);
        widget.callbacks.onVolumeChanged?.call(value);
      }
    }

    _dragLast = event.position;
  }

  void _onPointerUp(PointerUpEvent event) {
    _cancelLongPressTimer();

    if (_isLongPressing) {
      _cancelLongPress();
      return;
    }

    if (_isDragging) {
      _commitDrag();
    }
  }

  void _commitDrag() {
    final ctrl = widget.controller;
    if (_dragAxis == _DragAxis.horizontal && _seekDelta != 0) {
      final totalMs = (_seekDelta * 1000).round();
      if (totalMs != 0) {
        widget.callbacks.onSeek?.call(Duration(milliseconds: totalMs));
      }
      ctrl.commitSeek();
    } else if (_dragAxis == _DragAxis.vertical && _isLeftHalf) {
      ctrl.commitBrightness();
    } else if (_dragAxis == _DragAxis.vertical && !_isLeftHalf) {
      ctrl.commitVolume();
    }

    _seekDelta = 0;
    _isDragging = false;
    _dragAxis = _DragAxis.undecided;
  }

  void _cancelLongPress() {
    _isLongPressing = false;
    _cancelLongPressTimer();
    widget.controller.endLongPress();
    widget.callbacks.onSetSpeed?.call(1.0);
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  // --- 单击/双击 ---

  void _onTap() {
    if (widget.controller.mode != GestureMode.idle) return;

    _tapCount++;
    if (_tapCount == 1) {
      _tapTimer = Timer(
        Duration(milliseconds: widget.controller.config.doubleTapIntervalMs),
        () {
          // 单击：切换控制栏
          _tapCount = 0;
          widget.controller.toggleControlBar();
          widget.callbacks.onToggleControlBar?.call();
        },
      );
    } else if (_tapCount >= 2) {
      _tapTimer?.cancel();
      _tapCount = 0;
      // 双击：播放/暂停
      _triggerPlayPauseFlash();
      widget.callbacks.onTogglePlayPause?.call();
    }
  }

  void _triggerPlayPauseFlash() {
    _flashTimer?.cancel();
    setState(() {
      _showPlayPauseFlash = true;
      _flashIsPlaying = widget.isPlaying;
    });
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showPlayPauseFlash = false;
        });
      }
    });
  }

  // --- 构建 ---

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return Stack(
      children: [
        // 视频画面
        widget.child,

        // 手势层：Listener 捕获拖拽/长按，GestureDetector 捕获点击
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onTap,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // 快进/快退指示器
        if (ctrl.isSeekingVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: SeekIndicator(deltaSeconds: ctrl.seekDelta),
            ),
          ),

        // 亮度指示器
        if (ctrl.isBrightnessVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: BrightnessIndicator(brightness: ctrl.brightness),
            ),
          ),

        // 音量指示器
        if (ctrl.isVolumeVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: VolumeIndicator(volume: ctrl.volume),
            ),
          ),

        // 长按速度指示器
        if (ctrl.isLongPressVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: SpeedIndicator.fromConfig(ctrl.config),
            ),
          ),

        // 播放/暂停闪烁
        if (_showPlayPauseFlash)
          Positioned.fill(
            child: IgnorePointer(
              child: PlayPauseFlash(isPlaying: _flashIsPlaying),
            ),
          ),

        // 底部控制栏
        if (ctrl.controlBarVisible)
          ControlBar(
            isPlaying: widget.isPlaying,
            position: widget.position,
            duration: widget.duration,
            isFullScreen: widget.isFullScreen,
            onPlayPause: () {
              widget.callbacks.onTogglePlayPause?.call();
              ctrl.resetControlBarTimer();
            },
            onSeekTo: (pos) {
              widget.callbacks.onSeekTo?.call(pos);
              ctrl.resetControlBarTimer();
            },
            onPositionChanged: (pos) {
              ctrl.resetControlBarTimer();
            },
            onFullScreen: () {
              if (widget.isFullScreen) {
                widget.callbacks.onExitFullScreen?.call();
              } else {
                widget.callbacks.onEnterFullScreen?.call();
              }
              ctrl.resetControlBarTimer();
            },
          ),
      ],
    );
  }
}

/// 拖拽轴向
enum _DragAxis {
  undecided,
  horizontal,
  vertical,
}
