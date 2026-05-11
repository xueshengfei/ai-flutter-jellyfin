import 'package:jellyfin_playback/src/models/video_quality_models.dart';

/// 播放信息
class PlaybackInfo {
  final String url;
  final String playSessionId;

  /// 是否为转码流
  final bool isTranscoded;

  /// 实际使用的码率 (bps)
  final int? actualBitrate;

  const PlaybackInfo({
    required this.url,
    required this.playSessionId,
    this.isTranscoded = false,
    this.actualBitrate,
  });
}

/// 播放委托 — 将 PlaybackService 的操作抽象为回调集合
///
/// 调用方（根包）创建 PlaybackService 实例并将其方法包装为 PlaybackDelegate，
/// 传给 VideoPlayerPage。页面通过委托访问播放操作，不直接依赖 JellyfinClient。
class PlaybackDelegate {
  /// 获取播放 URL
  final Future<PlaybackInfo> Function({
    required String itemId,
    int? startTimeTicks,
    int? maxStreamingBitrate,
  }) getPlaybackUrl;

  /// 开始播放会话
  final Future<void> Function({
    required String itemId,
    required List<String> sessionIds,
  }) startSession;

  /// 切换画质
  final Future<PlaybackInfo> Function({
    required String itemId,
    required VideoQuality quality,
    required Duration currentPosition,
  }) switchQuality;

  /// 停止服务端转码任务
  final Future<void> Function(String playSessionId) stopEncoding;

  /// 停止播放会话
  final Future<void> Function() stopSession;

  /// 清理资源（页面 dispose 时调用）
  final void Function() dispose;

  const PlaybackDelegate({
    required this.getPlaybackUrl,
    required this.startSession,
    required this.switchQuality,
    required this.stopEncoding,
    required this.stopSession,
    required this.dispose,
  });
}
