import 'dart:async';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 播放服务
///
/// 负责获取播放 URL、创建播放会话、同步播放进度
/// 对齐 jellyfin-web playbackmanager.js 的播放流程
class PlaybackService {
  final JellyfinClient client;

  // 播放会话 ID
  String? _playSessionId;

  // 进度上报定时器
  Timer? _progressTimer;

  // 当前播放的媒体项
  MediaItem? _currentItem;

  // 是否正在播放
  bool _isPlaying = false;

  // 当前播放方式："DirectPlay" | "DirectStream" | "Transcode"
  String? _playMethod;

  PlaybackService({required this.client});

  /// 构建 Flutter 客户端的 DeviceProfile
  ///
  /// 告诉服务端：客户端能直接播放什么格式，需要转码成什么格式
  /// 参照 jellyfin-web 的 deviceProfile 配置
  jellyfin_dart.DeviceProfile _buildDeviceProfile() {
    return jellyfin_dart.DeviceProfile(
      name: 'Flutter Video Player',
      maxStreamingBitrate: 120000000,
      maxStaticBitrate: 100000000,
      musicStreamingTranscodingBitrate: 384000,
      // 客户端能直接播放的格式
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
      // 转码目标格式：HLS (ts) + h264 + aac，兼容性最好
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

  /// 获取播放流 URL
  ///
  /// [itemId] 媒体项 ID
  /// [startTimeTicks] 开始时间（用于断点续播）
  /// [maxStreamingBitrate] 最大流码率 (bps)，null=直连，有值=请求转码
  Future<PlaybackInfo> getPlaybackUrl({
    required String itemId,
    int? startTimeTicks,
    int? maxStreamingBitrate,
  }) async {
    try {
      final accessToken = client.configuration.accessToken;
      if (accessToken == null) {
        throw Exception('访问令牌为空，无法播放');
      }

      // 调用 PlaybackInfo API（核心请求）
      final mediaInfoApi = client.apiClient.jellyfinClient.getMediaInfoApi();
      final response = await mediaInfoApi.getPostedPlaybackInfo(
        itemId: itemId,
        playbackInfoDto: jellyfin_dart.PlaybackInfoDto(
          userId: client.configuration.userId,
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

      // 使用服务端返回的 playSessionId
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
      final serverUrl = client.configuration.serverUrl;

      // 按优先级判断播放方式（对齐 jellyfin-web createStreamInfo 逻辑）
      // 1. DirectPlay: 客户端完全支持源格式
      // 2. Transcode: 使用服务端返回的 TranscodingUrl
      if (source.supportsDirectPlay == true && maxStreamingBitrate == null) {
        // 直连模式：不需要转码
        _playMethod = 'DirectPlay';
        final container = source.container ?? 'mp4';
        final directUrl = '$serverUrl/Videos/$itemId/stream.$container'
            '?Static=true'
            '&MediaSourceId=${source.id ?? itemId}'
            '&api_key=$accessToken';
        print('🎬 DirectPlay URL: $directUrl');
        return PlaybackInfo(
          url: directUrl,
          playSessionId: _playSessionId!,
          isTranscoded: false,
        );
      }

      // 转码模式：使用服务端返回的 TranscodingUrl（不需要自己构造）
      if (source.transcodingUrl != null && source.transcodingUrl!.isNotEmpty) {
        String transcodingUrl = source.transcodingUrl!;
        if (transcodingUrl.startsWith('/')) {
          transcodingUrl = '$serverUrl$transcodingUrl';
        }
        _playMethod = 'Transcode';
        print('🎬 Transcode URL: $transcodingUrl');
        print('   目标码率: $maxStreamingBitrate bps');
        return PlaybackInfo(
          url: transcodingUrl,
          playSessionId: _playSessionId!,
          isTranscoded: true,
          actualBitrate: maxStreamingBitrate,
        );
      }

      // 支持 DirectPlay 但源码率低于目标 → 直接播放
      if (source.supportsDirectPlay == true) {
        _playMethod = 'DirectPlay';
        final container = source.container ?? 'mp4';
        final directUrl = '$serverUrl/Videos/$itemId/stream.$container'
            '?Static=true'
            '&MediaSourceId=${source.id ?? itemId}'
            '&api_key=$accessToken';
        print('🎬 DirectPlay (源码率够低): $directUrl');
        return PlaybackInfo(
          url: directUrl,
          playSessionId: _playSessionId!,
          isTranscoded: false,
        );
      }

      throw Exception('服务器无法提供播放流');
    } catch (e) {
      print('❌ 获取播放 URL 失败: $e');
      rethrow;
    }
  }

  /// 停止服务端转码任务
  ///
  /// 切换画质或停止播放时必须调用，否则服务端转码进程不会自动停止
  /// 对应 jellyfin-web: DELETE /Videos/ActiveEncodings
  Future<void> stopActiveEncodings(String playSessionId) async {
    try {
      final hlsApi = client.apiClient.jellyfinClient.getHlsSegmentApi();
      final deviceId = client.configuration.deviceId ?? 'unknown';
      await hlsApi.stopEncodingProcess(
        deviceId: deviceId,
        playSessionId: playSessionId,
      );
      print('🛑 已停止转码: $playSessionId');
    } catch (e) {
      print('⚠️ 停止转码失败（可能不是转码流）: $e');
    }
  }

  /// 切换画质
  ///
  /// 对齐 jellyfin-web changeStream() 流程：
  /// 1. 记录当前位置
  /// 2. 请求新的 PlaybackInfo
  /// 3. 停止旧转码
  /// 4. 返回新 URL
  Future<PlaybackInfo> switchQuality({
    required String itemId,
    required VideoQuality quality,
    required Duration currentPosition,
    NetworkQualityMonitor? monitor,
  }) async {
    final bitrate = quality.bitrate ?? monitor?.currentBitrate ?? 5000000;
    final ticks = currentPosition.inMilliseconds * 10000;

    // 保存旧的 playSessionId，稍后停止旧转码
    final oldPlaySessionId = _playSessionId;

    // 请求新的 PlaybackInfo（新的码率）
    final newPlaybackInfo = await getPlaybackUrl(
      itemId: itemId,
      startTimeTicks: ticks,
      maxStreamingBitrate: bitrate,
    );

    // 停止旧的转码任务
    if (oldPlaySessionId != null) {
      await stopActiveEncodings(oldPlaySessionId);
    }

    return newPlaybackInfo;
  }

  /// 开始播放会话
  Future<void> startPlaybackSession({
    required String itemId,
    required List<String> sessionIds,
    int? startTimeTicks,
  }) async {
    try {
      print('🎬 开始播放: $itemId');

      _isPlaying = true;

      // 立即上报一次播放开始
      await _reportProgress();

      // 启动进度上报定时器
      _startProgressReporting(itemId);

      print('✅ 播放会话已启动');
    } catch (e) {
      print('❌ 开始播放会话失败: $e');
      rethrow;
    }
  }

  /// 停止播放会话
  Future<void> stopPlaybackSession() async {
    if (!_isPlaying || _currentItem == null) return;

    try {
      print('🎬 停止播放: ${_currentItem!.name}');

      // 取消定时器
      _progressTimer?.cancel();
      _progressTimer = null;

      // 上报最终进度
      if (_currentItem != null && _playSessionId != null) {
        await _reportProgress();
      }

      // 如果是转码播放，停止服务端转码任务
      if (_playMethod == 'Transcode' && _playSessionId != null) {
        await stopActiveEncodings(_playSessionId!);
      }

      // 重置状态
      _isPlaying = false;
      _currentItem = null;
      _playSessionId = null;
      _playMethod = null;

      print('✅ 播放已停止');
    } catch (e) {
      print('❌ 停止播放会话失败: $e');
    }
  }

  /// 暂停播放
  Future<void> pausePlayback() async {
    if (!_isPlaying) return;

    try {
      _progressTimer?.cancel();
      _progressTimer = null;

      _isPlaying = false;

      if (_currentItem != null) {
        await _reportProgress();
      }

      print('⏸️ 播放已暂停');
    } catch (e) {
      print('❌ 暂停播放失败: $e');
    }
  }

  /// 恢复播放
  Future<void> resumePlayback() async {
    if (_isPlaying) return;

    try {
      _isPlaying = true;

      if (_currentItem != null) {
        _startProgressReporting(_currentItem!.id);
      }

      await _reportProgress();

      print('▶️ 播放已恢复');
    } catch (e) {
      print('❌ 恢复播放失败: $e');
    }
  }

  /// 设置当前播放的媒体项
  void setCurrentItem(MediaItem item) {
    _currentItem = item;
  }

  /// 启动进度上报定时器
  void _startProgressReporting(String itemId) {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _reportProgress();
    });
  }

  /// 上报播放进度
  Future<void> _reportProgress({int? positionTicks}) async {
    if (_currentItem == null || _playSessionId == null) return;

    try {
      final playstateApi = client.apiClient.jellyfinClient.getPlaystateApi();

      final progressInfo = jellyfin_dart.PlaybackProgressInfo(
        itemId: _currentItem!.id,
        sessionId: _playSessionId!,
        positionTicks: positionTicks,
        isPaused: !_isPlaying,
      );

      await playstateApi.reportPlaybackProgress(
        playbackProgressInfo: progressInfo,
      );

      print('📊 播放进度已上报: ${_currentItem!.name}');
    } catch (e) {
      print('❌ 上报播放进度失败: $e');
    }
  }

  /// 生成播放会话 ID
  String _generatePlaySessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return '${timestamp}_$random';
  }

  /// 清理资源
  void dispose() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// 获取当前播放状态
  bool get isPlaying => _isPlaying;

  /// 获取播放会话 ID
  String? get playSessionId => _playSessionId;

  /// 获取当前播放方式
  String? get playMethod => _playMethod;
}

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
