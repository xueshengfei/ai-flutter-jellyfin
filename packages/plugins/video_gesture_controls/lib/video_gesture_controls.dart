/// 视频手势控制插件
///
/// 播放器无关的手势控制面板，支持：
/// - 水平滑动快进/快退
/// - 左半屏垂直滑动调节亮度
/// - 右半屏垂直滑动调节音量
/// - 双击播放/暂停切换
/// - 长按 2x 加速
/// - 单击显示/隐藏控制栏
library video_gesture_controls;

// 模型
export 'src/models/gesture_config.dart';
export 'src/models/gesture_callbacks.dart';

// 控制器
export 'src/controllers/gesture_state_controller.dart';

// 手势
export 'src/gestures/gesture_overlay.dart';
export 'src/gestures/multi_axis_gesture_recognizer.dart';

// Widget
export 'src/widgets/seek_indicator.dart';
export 'src/widgets/brightness_indicator.dart';
export 'src/widgets/volume_indicator.dart';
export 'src/widgets/speed_indicator.dart';
export 'src/widgets/play_pause_flash.dart';
export 'src/widgets/control_bar.dart';

// 服务
export 'src/services/simulated_brightness_volume.dart';

// 保留平台接口兼容
export 'video_gesture_controls_platform_interface.dart';
