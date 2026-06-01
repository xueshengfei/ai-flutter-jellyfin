/// 视频手势控制配置
class VideoGestureConfig {
  /// 手势判定阈值（像素），超过此距离才判定为拖拽
  final double gestureThreshold;

  /// 长按触发时间（毫秒）
  final int longPressDelayMs;

  /// 长按加速倍率
  final double longPressSpeed;

  /// 水平滑动灵敏度（每像素对应的快进/快退秒数）
  final double seekSensitivity;

  /// 垂直滑动灵敏度（每像素对应的亮度/音量变化量，0~1）
  final double verticalSensitivity;

  /// 快退/快退的步长（秒），用于显示指示器文本
  final int seekStepSeconds;

  /// 控制栏自动隐藏延迟（毫秒）
  final int controlBarAutoHideMs;

  /// 指示器显示持续时间（毫秒）
  final int indicatorDurationMs;

  /// 双击间隔（毫秒）
  final int doubleTapIntervalMs;

  const VideoGestureConfig({
    this.gestureThreshold = 12.0,
    this.longPressDelayMs = 500,
    this.longPressSpeed = 2.0,
    this.seekSensitivity = 0.5,
    this.verticalSensitivity = 0.003,
    this.seekStepSeconds = 10,
    this.controlBarAutoHideMs = 3000,
    this.indicatorDurationMs = 800,
    this.doubleTapIntervalMs = 300,
  });
}
