import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_playback/src/models/video_quality_models.dart';
import 'package:jellyfin_playback/src/models/playback_models.dart';
import 'package:jellyfin_playback/src/models/watch_assist_models.dart';
import 'package:jellyfin_playback/src/widgets/watch_assist_button.dart';
import 'package:jellyfin_playback/src/widgets/watch_assist_sheet.dart';

/// 视频播放页面（解耦版）
///
/// 通过 [PlaybackDelegate] 注入播放操作，不依赖 JellyfinClient。
class VideoPlayerPage extends StatefulWidget {
  /// 媒体项信息
  final MediaItem item;

  /// 播放委托（封装所有 PlaybackService 操作）
  final PlaybackDelegate playback;

  /// AI 观影解读请求回调。未注入时不显示 AI 解读入口。
  final WatchAssistFetcher? fetchWatchAssist;

  const VideoPlayerPage({
    super.key,
    required this.item,
    required this.playback,
    this.fetchWatchAssist,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  // 视频控制器
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  // 加载状态
  bool _isLoading = true;
  String? _errorMessage;

  // 倍速选项
  final List<double> _playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  double _currentSpeed = 1.0;

  // ============ 画质相关 ============

  VideoQuality _currentQuality = VideoQuality.auto;
  bool _isQualitySwitching = false;
  final NetworkQualityMonitor _networkMonitor = NetworkQualityMonitor();
  final AutoQualityDecider _autoDecider = AutoQualityDecider();
  DateTime? _lastAutoCheckTime;
  DateTime? _bufferingStartTime;
  static const Duration _autoCheckInterval = Duration(seconds: 15);
  PlaybackInfo? _currentPlaybackInfo;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    // 停止播放会话
    widget.playback.stopSession();
    widget.playback.dispose();

    // 释放控制器
    _chewieController?.dispose();
    _videoController?.dispose();

    super.dispose();
  }

  /// 初始化播放器
  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 计算续播位置
      int? resumeTicks;
      if (widget.item.playedPercentage != null &&
          widget.item.playedPercentage! > 0 &&
          widget.item.runTimeTicks != null) {
        resumeTicks =
            (widget.item.runTimeTicks! * widget.item.playedPercentage! / 100)
                .round();
      }

      final playbackInfo = await widget.playback.getPlaybackUrl(
        itemId: widget.item.id,
        startTimeTicks: resumeTicks,
      );
      _currentPlaybackInfo = playbackInfo;

      await _setupVideoController(playbackInfo, resumeTicks: resumeTicks);

      // 开始播放会话
      await widget.playback.startSession(
        itemId: widget.item.id,
        sessionIds: [playbackInfo.playSessionId],
      );

      _videoController!.addListener(_onVideoProgressChanged);

      setState(() {
        _isLoading = false;
      });

      _lastAutoCheckTime = DateTime.now();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '播放失败: $e';
        });
      }
    }
  }

  /// 创建视频控制器并绑定 Chewie
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
      playbackSpeeds: _playbackSpeeds,
    );
  }

  /// 切换画质
  Future<void> _switchQuality(VideoQuality quality) async {
    if (_isQualitySwitching || quality == _currentQuality) return;
    if (_videoController == null) return;

    final currentPosition = _videoController!.value.position;
    final wasPlaying = _videoController!.value.isPlaying;

    setState(() {
      _isQualitySwitching = true;
    });

    try {
      final newPlaybackInfo = await widget.playback.switchQuality(
        itemId: widget.item.id,
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
      widget.playback.stopEncoding(newPlaybackInfo.playSessionId);

      setState(() {
        _currentQuality = quality;
        _isQualitySwitching = false;
      });

      if (newPlaybackInfo.actualBitrate != null) {
        _networkMonitor.currentBitrate = newPlaybackInfo.actualBitrate!;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isQualitySwitching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('切换画质失败，保持当前播放'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 监听视频播放进度
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
      _switchQuality(target);
    }
  }

  /// 显示画质选择面板
  void _showQualitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '画质选择',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ...VideoQuality.values.map((q) => _buildQualityOption(q)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(VideoQuality quality) {
    final isSelected = quality == _currentQuality;
    final bitrateText = quality.bitrate != null
        ? ' (${(quality.bitrate! / 1000000).toStringAsFixed(1)} Mbps)'
        : '';

    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? Colors.blue : Colors.white38,
        size: 22,
      ),
      title: Text(
        '${quality.label}$bitrateText',
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white,
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (!isSelected) {
          _switchQuality(quality);
        }
      },
    );
  }

  void _showWatchAssistSheet() {
    final fetcher = widget.fetchWatchAssist;
    if (fetcher == null) return;

    final positionSeconds = _videoController?.value.position.inSeconds ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WatchAssistSheet(
        itemId: widget.item.id,
        initialPositionSeconds: positionSeconds,
        fetchWatchAssist: fetcher,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _isLoading
                ? _buildLoadingWidget()
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _buildPlayerWidget(),
          ),

          // 画质切换遮罩
          if (_isQualitySwitching)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '正在切换至 ${_currentQuality == VideoQuality.auto ? "自动" : "更高"}画质...',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // 顶部栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '返回',
                    ),
                    Expanded(
                      child: Text(
                        widget.item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部业务控制按钮
          if (!_isLoading && _errorMessage == null)
            Positioned(
              bottom: 0,
              right: 96,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.fetchWatchAssist != null)
                    WatchAssistButton(onPressed: _showWatchAssistSheet),
                  _buildQualityBadge(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQualityBadge() {
    return SizedBox(
      height: 48,
      child: IconButton(
        onPressed: _showQualitySelector,
        icon: Text(
          _currentQuality.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          _isQualitySwitching ? '正在切换画质...' : '正在加载视频...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            widget.item.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 24),
          Text(
            '播放失败',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerWidget() {
    return Chewie(controller: _chewieController!);
  }
}
