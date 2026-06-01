import 'package:flutter/foundation.dart';

/// 视频手势控制回调集合
///
/// 播放器无关设计：调用方通过实现这些回调来连接实际播放器。
class VideoGestureCallbacks {
  /// 快进/快退
  final void Function(Duration delta)? onSeek;

  /// 播放/暂停切换
  final VoidCallback? onTogglePlayPause;

  /// 设置播放速度（长按时 2x，松开恢复 1x）
  final void Function(double speed)? onSetSpeed;

  /// 亮度变化（0.0 ~ 1.0）
  final void Function(double brightness)? onBrightnessChanged;

  /// 音量变化（0.0 ~ 1.0）
  final void Function(double volume)? onVolumeChanged;

  /// 控制栏显隐切换
  final VoidCallback? onToggleControlBar;

  /// 进入全屏
  final VoidCallback? onEnterFullScreen;

  /// 退出全屏
  final VoidCallback? onExitFullScreen;

  /// 进度跳转（Slider 拖动）
  final void Function(Duration position)? onSeekTo;

  const VideoGestureCallbacks({
    this.onSeek,
    this.onTogglePlayPause,
    this.onSetSpeed,
    this.onBrightnessChanged,
    this.onVolumeChanged,
    this.onToggleControlBar,
    this.onEnterFullScreen,
    this.onExitFullScreen,
    this.onSeekTo,
  });
}
