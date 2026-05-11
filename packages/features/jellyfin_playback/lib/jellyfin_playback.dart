/// jellyfin_playback - 视频播放业务模块
///
/// 包含：
/// - 画质模型 [VideoQuality] / [NetworkQualityMonitor] / [AutoQualityDecider]
/// - 播放信息 [PlaybackInfo]
/// - 播放委托 [PlaybackDelegate]
/// - 播放器页面 [VideoPlayerPage]
///
/// **导入方式**：
/// ```dart
/// import 'package:jellyfin_playback/jellyfin_playback.dart';        // 模型
/// import 'package:jellyfin_playback/jellyfin_playback_pages.dart';   // 页面
/// ```
library;

export 'src/models/video_quality_models.dart';
export 'src/models/playback_models.dart';
