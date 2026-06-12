import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_playback/src/models/video_quality_models.dart';
import 'package:jellyfin_playback/src/models/playback_models.dart';

/// 视频播放 ViewModel
///
/// 持有全部播放状态和业务逻辑，通过 [ChangeNotifier] 驱动 View 刷新。
/// View 层只需用 ListenableBuilder 监听即可。
class VideoPlayerViewModel extends ChangeNotifier {
  /// 媒体项
  final MediaItem item;

  /// 播放委托（API 操作）
  final PlaybackDelegate playback;

  // ─── UI 状态 ───

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  double _currentSpeed = 1.0;
  double get currentSpeed => _currentSpeed;

  VideoQuality _currentQuality = VideoQuality.auto;
  VideoQuality get currentQuality => _currentQuality;

  bool _isQualitySwitching = false;
  bool get isQualitySwitching => _isQualitySwitching;

  PlaybackInfo? _currentPlaybackInfo;
  PlaybackInfo? get currentPlaybackInfo => _currentPlaybackInfo;

  // ─── 视频控制器 ───

  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  ChewieController? _chewieController;
  ChewieController? get chewieController => _chewieController;

  // ─── 倍速选项 ───

  static const List<double> playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // ─── 网络质量检测 ───

  final NetworkQualityMonitor _networkMonitor = NetworkQualityMonitor();
  final AutoQualityDecider _autoDecider = AutoQualityDecider();
  DateTime? _lastAutoCheckTime;
  DateTime? _bufferingStartTime;
  static const Duration _autoCheckInterval = Duration(seconds: 15);

  VideoPlayerViewModel({
    required this.item,
    required this.playback,
  });

  /// 初始化播放器
  Future<void> initialize() async {
    _setLoading(true, clearError: true);

    try {
      // 计算续播位置
      int? resumeTicks;
      if (item.playedPercentage != null &&
          item.playedPercentage! > 0 &&
          item.runTimeTicks != null) {
        resumeTicks =
            (item.runTimeTicks! * item.playedPercentage! / 100).round();
      }

      final playbackInfo = await playback.getPlaybackUrl(
        itemId: item.id,
        startTimeTicks: resumeTicks,
      );
      _currentPlaybackInfo = playbackInfo;

      await _setupVideoController(playbackInfo, resumeTicks: resumeTicks);

      // 开始播放会话
      await playback.startSession(
        itemId: item.id,
        sessionIds: [playbackInfo.playSessionId],
      );

      _videoController!.addListener(_onVideoProgressChanged);

      _isLoading = false;
      _lastAutoCheckTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = '播放失败: $e';
      notifyListeners();
    }
  }

  /// 切换画质
  Future<void> switchQuality(VideoQuality quality) async {
    if (_isQualitySwitching || quality == _currentQuality) return;
    if (_videoController == null) return;

    final currentPosition = _videoController!.value.position;
    final wasPlaying = _videoController!.value.isPlaying;

    _isQualitySwitching = true;
    notifyListeners();

    try {
      final newPlaybackInfo = await playback.switchQuality(
        itemId: item.id,
        quality: quality,
        currentPosition: currentPosition,
      );

      // 释放旧控制器
      _videoController!.removeListener(_onVideoProgressChanged);
      _chewieController?.dispose();
      _videoController?.dispose();
      _chewieController = null;
      _videoController = null;

      _currentPlaybackInfo = newPlaybackInfo;

      await _setupVideoController(newPlaybackInfo,
          seekPosition: currentPosition);
      _videoController!.addListener(_onVideoProgressChanged);

      if (!wasPlaying) {
        await _videoController!.pause();
      }

      // 停止旧转码
      playback.stopEncoding(newPlaybackInfo.playSessionId);

      _currentQuality = quality;
      _isQualitySwitching = false;
      notifyListeners();

      if (newPlaybackInfo.actualBitrate != null) {
        _networkMonitor.currentBitrate = newPlaybackInfo.actualBitrate!;
      }
    } catch (e) {
      _isQualitySwitching = false;
      notifyListeners();
      // 错误由 View 层展示 SnackBar
      _lastError = '切换画质失败，保持当前播放';
      notifyListeners();
    }
  }

  /// 最近一次操作错误（用于 View 展示 SnackBar，阅后即焚）
  String? _lastError;
  String? consumeLastError() {
    final err = _lastError;
    _lastError = null;
    return err;
  }

  /// 获取当前播放位置（秒）
  int get currentPositionSeconds =>
      _videoController?.value.position.inSeconds ?? 0;

  // ─── 生命周期 ───

  @override
  void dispose() {
    playback.stopSession();
    playback.dispose();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ─── 内部方法 ───

  void _setLoading(bool value, {bool clearError = false}) {
    _isLoading = value;
    if (clearError) _errorMessage = null;
    notifyListeners();
  }

  Future<void> _setupVideoController(
    PlaybackInfo playbackInfo, {
    int? resumeTicks,
    Duration? seekPosition,
  }) async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(playbackInfo.url),
    );

    await _videoController!.initialize();

    if (seekPosition != null) {
      await _videoController!.seekTo(seekPosition);
    } else if (resumeTicks != null && resumeTicks > 0) {
      final resumeSeconds = resumeTicks / 10000000;
      await _videoController!.seekTo(Duration(seconds: resumeSeconds.round()));
    }

    if (_currentSpeed != 1.0) {
      await _videoController!.setPlaybackSpeed(_currentSpeed);
    }

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      showControls: true,
      aspectRatio: _videoController!.value.aspectRatio,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      playbackSpeeds: playbackSpeeds,
    );
  }

  void _onVideoProgressChanged() {
    if (_videoController == null || _isQualitySwitching) return;

    final value = _videoController!.value;
    _handleBufferingState(value);

    if (_currentQuality == VideoQuality.auto) {
      _checkAutoQuality();
    }
  }

  void _handleBufferingState(VideoPlayerValue value) {
    if (value.isBuffering) {
      _bufferingStartTime = DateTime.now();
    } else if (_bufferingStartTime != null) {
      final bufferDuration = DateTime.now().difference(_bufferingStartTime!);
      _bufferingStartTime = null;

      if (bufferDuration.inMilliseconds > 100) {
        final currentBitrate = _currentPlaybackInfo?.actualBitrate ?? 5000000;
        final estimatedBytes = (currentBitrate * 2 / 8).round();

        _networkMonitor.recordFromBuffering(
          bufferedBytes: estimatedBytes,
          bufferDuration: bufferDuration,
        );
      }
    }
  }

  void _checkAutoQuality() {
    final now = DateTime.now();
    if (_lastAutoCheckTime != null &&
        now.difference(_lastAutoCheckTime!) < _autoCheckInterval) {
      return;
    }
    _lastAutoCheckTime = now;

    final recommended = _networkMonitor.recommendQuality();
    final target = _autoDecider.shouldSwitch(recommended, _currentQuality);

    if (target != null) {
      _autoDecider.reset();
      switchQuality(target);
    }
  }
}
