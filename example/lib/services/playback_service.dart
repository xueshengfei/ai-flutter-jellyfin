import 'dart:async';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' as jellyfin_dart;

/// 播放服务
///
/// 负责获取播放 URL、创建播放会话、同步播放进度
class PlaybackService {
  final JellyfinClient client;

  // 播放会话 ID
  String? _playSessionId;

  // 进度上报定时器
  Timer? _progressTimer;

  // 当前播放的媒体项
  MediaItem? _currentItem;

  // 播放开始时间
  DateTime? _playStartTime;

  // 是否正在播放
  bool _isPlaying = false;

  PlaybackService({required this.client});

  /// 获取播放流 URL
  ///
  /// [itemId] 媒体项 ID
  /// [startTimeTicks] 开始时间（用于断点续播）
  ///
  /// 返回播放 URL 和会话 ID
  Future<PlaybackInfo> getPlaybackUrl({
    required String itemId,
    int? startTimeTicks,
  }) async {
    try {
      // 生成播放会话 ID
      _playSessionId = _generatePlaySessionId();

      // 构建播放 URL
      final serverUrl = client.configuration.serverUrl;
      final accessToken = client.configuration.accessToken;

      if (accessToken == null) {
        throw Exception('访问令牌为空，无法播放');
      }

      // 基础 URL
      final url = '$serverUrl/Videos/$itemId/stream';

      // 添加查询参数
      final queryParams = <String, String>{
        'api_key': accessToken,
        'playSessionId': _playSessionId!,
        'static': 'true', // 静态文件，不转码
        'mediaSourceId': itemId,
      };

      // 如果有开始时间，添加到参数
      if (startTimeTicks != null && startTimeTicks > 0) {
        queryParams['startTimeTicks'] = startTimeTicks.toString();
      }

      // 构建完整 URL
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final fullUrl = '$url?$queryString';

      print('🎬 播放 URL: $fullUrl');
      print('   会话 ID: $_playSessionId');

      return PlaybackInfo(
        url: fullUrl,
        playSessionId: _playSessionId!,
      );
    } catch (e) {
      print('❌ 获取播放 URL 失败: $e');
      rethrow;
    }
  }

  /// 开始播放会话
  ///
  /// [itemId] 媒体项 ID
  /// [sessionIds] 会话 ID 列表（未使用）
  /// [startTimeTicks] 开始时间
  Future<void> startPlaybackSession({
    required String itemId,
    required List<String> sessionIds,
    int? startTimeTicks,
  }) async {
    try {
      print('🎬 开始播放: $itemId');

      // 简化版本：直接标记为播放状态，不需要获取会话
      // Jellyfin 会在第一次上报进度时自动创建会话
      _isPlaying = true;
      _playStartTime = DateTime.now();

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

      // 重置状态
      _isPlaying = false;
      _playStartTime = null;
      _currentItem = null;
      _playSessionId = null;

      print('✅ 播放已停止');
    } catch (e) {
      print('❌ 停止播放会话失败: $e');
    }
  }

  /// 暂停播放
  Future<void> pausePlayback() async {
    if (!_isPlaying) return;

    try {
      // 暂停定时器
      _progressTimer?.cancel();
      _progressTimer = null;

      _isPlaying = false;

      // 上报暂停时的进度
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

      // 恢复定时器
      if (_currentItem != null) {
        _startProgressReporting(_currentItem!.id);
      }

      // 上报恢复播放
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
    // 每 10 秒上报一次进度
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _reportProgress();
    });
  }

  /// 上报播放进度
  ///
  /// [positionTicks] 当前播放位置（单位： ticks，1 秒 = 10,000,000 ticks）
  Future<void> _reportProgress({
    int? positionTicks,
  }) async {
    if (_currentItem == null || _playSessionId == null) return;

    try {
      final playstateApi = client.apiClient.jellyfinClient.getPlaystateApi();

      // 构建进度信息
      final progressInfo = jellyfin_dart.PlaybackProgressInfo(
        itemId: _currentItem!.id,
        sessionId: _playSessionId!,
        positionTicks: positionTicks,
        isPaused: !_isPlaying,
      );

      // 上报进度
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
}

/// 播放信息
class PlaybackInfo {
  final String url;
  final String playSessionId;

  const PlaybackInfo({
    required this.url,
    required this.playSessionId,
  });
}
