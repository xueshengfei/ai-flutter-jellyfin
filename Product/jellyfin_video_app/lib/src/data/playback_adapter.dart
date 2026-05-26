import 'dart:async';
import 'package:jellyfin_api/jellyfin_api.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;
import 'package:jellyfin_playback/jellyfin_playback.dart';

/// 播放适配器
///
/// 基于 jellyfin_api 直接创建 PlaybackDelegate。
class PlaybackAdapter {
  final ApiClient _apiClient;

  String? _playSessionId;
  Timer? _progressTimer;
  String? _currentItemId;
  bool _isPlaying = false;
  String? _playMethod;

  PlaybackAdapter(this._apiClient);

  /// 创建 PlaybackDelegate 供 VideoPlayerPage 使用
  PlaybackDelegate createDelegate() {
    return PlaybackDelegate(
      getPlaybackUrl: _getPlaybackUrl,
      startSession: _startSession,
      switchQuality: _switchQuality,
      stopEncoding: _stopEncoding,
      stopSession: _stopSession,
      dispose: _dispose,
    );
  }

  Future<PlaybackInfo> _getPlaybackUrl({
    required String itemId,
    int? startTimeTicks,
    int? maxStreamingBitrate,
  }) async {
    final config = _apiClient.config;
    final accessToken = config.accessToken;
    if (accessToken == null) {
      throw Exception('访问令牌为空，无法播放');
    }

    final response = await _apiClient.jellyfinClient.getMediaInfoApi()
        .getPostedPlaybackInfo(
      itemId: itemId,
      playbackInfoDto: jellyfin_dart.PlaybackInfoDto(
        userId: config.userId,
        startTimeTicks: startTimeTicks ?? 0,
        maxStreamingBitrate: maxStreamingBitrate ?? 120000000,
        enableDirectPlay: true,
        enableDirectStream: true,
        enableTranscoding: true,
        allowVideoStreamCopy: true,
        allowAudioStreamCopy: true,
        mediaSourceId: itemId,
        autoOpenLiveStream: true,
        deviceProfile: _buildDeviceProfile(),
      ),
    );

    final playbackResponse = response.data;
    if (playbackResponse == null) {
      throw Exception('PlaybackInfo 响应为空');
    }

    if (playbackResponse.playSessionId != null) {
      _playSessionId = playbackResponse.playSessionId!;
    } else {
      _playSessionId = _generatePlaySessionId();
    }

    final mediaSources = playbackResponse.mediaSources;
    if (mediaSources == null || mediaSources.isEmpty) {
      throw Exception('无可用的媒体源');
    }

    final source = mediaSources.first;
    final serverUrl = config.serverUrl;

    if (source.supportsDirectPlay == true && maxStreamingBitrate == null) {
      _playMethod = 'DirectPlay';
      final container = source.container ?? 'mp4';
      final directUrl = '$serverUrl/Videos/$itemId/stream.$container'
          '?Static=true'
          '&MediaSourceId=${source.id ?? itemId}'
          '&api_key=$accessToken';
      return PlaybackInfo(
        url: directUrl,
        playSessionId: _playSessionId!,
        isTranscoded: false,
      );
    }

    if (source.transcodingUrl != null && source.transcodingUrl!.isNotEmpty) {
      String transcodingUrl = source.transcodingUrl!;
      if (transcodingUrl.startsWith('/')) {
        transcodingUrl = '$serverUrl$transcodingUrl';
      }
      _playMethod = 'Transcode';
      return PlaybackInfo(
        url: transcodingUrl,
        playSessionId: _playSessionId!,
        isTranscoded: true,
        actualBitrate: maxStreamingBitrate,
      );
    }

    if (source.supportsDirectPlay == true) {
      _playMethod = 'DirectPlay';
      final container = source.container ?? 'mp4';
      final directUrl = '$serverUrl/Videos/$itemId/stream.$container'
          '?Static=true'
          '&MediaSourceId=${source.id ?? itemId}'
          '&api_key=$accessToken';
      return PlaybackInfo(
        url: directUrl,
        playSessionId: _playSessionId!,
        isTranscoded: false,
      );
    }

    throw Exception('服务器无法提供播放流');
  }

  Future<void> _startSession({
    required String itemId,
    required List<String> sessionIds,
  }) async {
    _currentItemId = itemId;
    _isPlaying = true;
    await _reportProgress();
    _startProgressReporting();
  }

  Future<PlaybackInfo> _switchQuality({
    required String itemId,
    required VideoQuality quality,
    required Duration currentPosition,
  }) async {
    final bitrate = quality.bitrate ?? 5000000;
    final ticks = currentPosition.inMilliseconds * 10000;

    final oldPlaySessionId = _playSessionId;

    final newInfo = await _getPlaybackUrl(
      itemId: itemId,
      startTimeTicks: ticks,
      maxStreamingBitrate: bitrate,
    );

    if (oldPlaySessionId != null) {
      await _stopEncoding(oldPlaySessionId);
    }

    return newInfo;
  }

  Future<void> _stopEncoding(String playSessionId) async {
    try {
      final deviceId = _apiClient.config.deviceId ?? 'unknown';
      await _apiClient.jellyfinClient.getHlsSegmentApi()
          .stopEncodingProcess(
        deviceId: deviceId,
        playSessionId: playSessionId,
      );
    } catch (_) {
      // 转码流停止失败可忽略
    }
  }

  Future<void> _stopSession() async {
    if (!_isPlaying) return;

    _progressTimer?.cancel();
    _progressTimer = null;

    if (_currentItemId != null && _playSessionId != null) {
      await _reportProgress();
    }

    if (_playMethod == 'Transcode' && _playSessionId != null) {
      await _stopEncoding(_playSessionId!);
    }

    _isPlaying = false;
    _currentItemId = null;
    _playSessionId = null;
    _playMethod = null;
  }

  void _dispose() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _startProgressReporting() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _reportProgress();
    });
  }

  Future<void> _reportProgress() async {
    if (_currentItemId == null || _playSessionId == null) return;

    try {
      await _apiClient.jellyfinClient.getPlaystateApi()
          .reportPlaybackProgress(
        playbackProgressInfo: jellyfin_dart.PlaybackProgressInfo(
          itemId: _currentItemId!,
          sessionId: _playSessionId!,
          isPaused: !_isPlaying,
        ),
      );
    } catch (_) {
      // 进度上报失败可忽略
    }
  }

  String _generatePlaySessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return '${timestamp}_$random';
  }

  static jellyfin_dart.DeviceProfile _buildDeviceProfile() {
    return jellyfin_dart.DeviceProfile(
      name: 'Flutter Video Player',
      maxStreamingBitrate: 120000000,
      maxStaticBitrate: 100000000,
      musicStreamingTranscodingBitrate: 384000,
      directPlayProfiles: [
        jellyfin_dart.DirectPlayProfile(
          container: 'mp4,m4v,mov',
          videoCodec: 'h264,hevc,vp9',
          audioCodec: 'aac,mp3,ac3,eac3',
          type: jellyfin_dart.DlnaProfileType.video,
        ),
        jellyfin_dart.DirectPlayProfile(
          container: 'mkv,webm,avi',
          videoCodec: 'h264,hevc,vp9',
          audioCodec: 'aac,mp3,ac3,eac3,dts',
          type: jellyfin_dart.DlnaProfileType.video,
        ),
      ],
      transcodingProfiles: [
        jellyfin_dart.TranscodingProfile(
          container: 'ts',
          type: jellyfin_dart.DlnaProfileType.video,
          videoCodec: 'h264',
          audioCodec: 'aac',
          protocol: jellyfin_dart.MediaStreamProtocol.hls,
          context: jellyfin_dart.EncodingContext.streaming,
          maxAudioChannels: '6',
          minSegments: 1,
          segmentLength: 0,
          breakOnNonKeyFrames: true,
        ),
      ],
      containerProfiles: [],
      codecProfiles: [],
      subtitleProfiles: [
        jellyfin_dart.SubtitleProfile(
          format: 'srt',
          method: jellyfin_dart.SubtitleDeliveryMethod.external_,
        ),
        jellyfin_dart.SubtitleProfile(
          format: 'subrip',
          method: jellyfin_dart.SubtitleDeliveryMethod.external_,
        ),
        jellyfin_dart.SubtitleProfile(
          format: 'ass',
          method: jellyfin_dart.SubtitleDeliveryMethod.external_,
        ),
        jellyfin_dart.SubtitleProfile(
          format: 'ssa',
          method: jellyfin_dart.SubtitleDeliveryMethod.external_,
        ),
      ],
    );
  }
}
