import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 视频播放页面
///
/// 支持嵌入和全屏模式切换，提供自定义控制栏、画质选择
class VideoPlayerPage extends StatefulWidget {
  final JellyfinClient client;
  final MediaItem item;

  const VideoPlayerPage({
    super.key,
    required this.client,
    required this.item,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  // 播放服务
  late PlaybackService _playbackService;

  // 视频控制器
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  // 全屏模式
  bool _isFullscreen = false;

  // 加载状态
  bool _isLoading = true;
  String? _errorMessage;

  // 倍速选项
  final List<double> _playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  double _currentSpeed = 1.0;

  // ============ 画质相关 ============

  /// 当前画质
  VideoQuality _currentQuality = VideoQuality.auto;

  /// 正在切换画质
  bool _isQualitySwitching = false;

  /// 网速监测器
  final NetworkQualityMonitor _networkMonitor = NetworkQualityMonitor();

  /// 自动画质决策器
  final AutoQualityDecider _autoDecider = AutoQualityDecider();

  /// 上次自动检查画质的时间
  DateTime? _lastAutoCheckTime;

  /// 上次 buffering 开始时间（用于估算带宽）
  DateTime? _bufferingStartTime;

  /// 自动检查间隔
  static const Duration _autoCheckInterval = Duration(seconds: 15);

  /// 当前播放信息（用于保存恢复）
  PlaybackInfo? _currentPlaybackInfo;

  @override
  void initState() {
    super.initState();

    print('🎬 VideoPlayerPage 初始化');
    print('   媒体项: ${widget.item.name}');
    print('   ID: ${widget.item.id}');

    _playbackService = PlaybackService(client: widget.client);
    _playbackService.setCurrentItem(widget.item);
    _initializePlayer();
  }

  @override
  void dispose() {
    print('🎬 清理播放器资源');

    // 停止播放会话
    _playbackService.stopPlaybackSession();
    _playbackService.dispose();

    // 释放控制器
    _chewieController?.dispose();
    _videoController?.dispose();

    // 退出全屏
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    super.dispose();
  }

  /// 初始化播放器
  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 获取播放 URL
      print('📡 获取播放 URL...');
      // 计算续播位置：playedPercentage * runTimeTicks
      int? resumeTicks;
      if (widget.item.playedPercentage != null &&
          widget.item.playedPercentage! > 0 &&
          widget.item.runTimeTicks != null) {
        resumeTicks = (widget.item.runTimeTicks! * widget.item.playedPercentage! / 100).round();
      }

      final playbackInfo = await _playbackService.getPlaybackUrl(
        itemId: widget.item.id,
        startTimeTicks: resumeTicks,
      );
      _currentPlaybackInfo = playbackInfo;

      await _setupVideoController(playbackInfo, resumeTicks: resumeTicks);

      // 开始播放会话
      await _playbackService.startPlaybackSession(
        itemId: widget.item.id,
        sessionIds: [playbackInfo.playSessionId],
      );

      // 监听播放进度
      _videoController!.addListener(_onVideoProgressChanged);

      setState(() {
        _isLoading = false;
      });

      _lastAutoCheckTime = DateTime.now();

      print('✅ 播放器初始化成功');
    } catch (e, stackTrace) {
      print('❌ 播放器初始化失败: $e');
      print('   堆栈: $stackTrace');

      setState(() {
        _isLoading = false;
        _errorMessage = '播放失败: $e';
      });
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

    // 续播或跳转到指定位置
    if (seekPosition != null) {
      await _videoController!.seekTo(seekPosition);
    } else if (resumeTicks != null && resumeTicks > 0) {
      final resumeSeconds = resumeTicks / 10000000;
      await _videoController!.seekTo(Duration(seconds: resumeSeconds.round()));
    }

    // 恢复倍速
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

    // 保存当前位置和状态
    final currentPosition = _videoController!.value.position;
    final wasPlaying = _videoController!.value.isPlaying;

    setState(() {
      _isQualitySwitching = true;
    });

    try {
      print('🔄 切换画质至 ${quality.label}...');

      final newPlaybackInfo = await _playbackService.switchQuality(
        itemId: widget.item.id,
        quality: quality,
        currentPosition: currentPosition,
        monitor: _networkMonitor,
      );

      // 释放旧控制器
      _videoController!.removeListener(_onVideoProgressChanged);
      _chewieController?.dispose();
      _videoController?.dispose();
      _chewieController = null;
      _videoController = null;

      _currentPlaybackInfo = newPlaybackInfo;

      // 创建新控制器
      await _setupVideoController(
        newPlaybackInfo,
        seekPosition: currentPosition,
      );

      _videoController!.addListener(_onVideoProgressChanged);

      if (!wasPlaying) {
        await _videoController!.pause();
      }

      // 确保旧转码彻底停止（对齐 jellyfin-web 步骤 F）
      _playbackService.stopActiveEncodings(
        newPlaybackInfo.playSessionId,
      );

      setState(() {
        _currentQuality = quality;
        _isQualitySwitching = false;
      });

      // 更新网速监测器中的当前码率
      if (newPlaybackInfo.actualBitrate != null) {
        _networkMonitor.currentBitrate = newPlaybackInfo.actualBitrate!;
      }

      print('✅ 画质切换成功: ${quality.label}');
    } catch (e) {
      print('❌ 画质切换失败: $e');

      setState(() {
        _isQualitySwitching = false;
      });

      // 回退：保持当前画质继续播放
      if (mounted) {
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

    // 监测 buffering 状态变化，用于网速估算
    _handleBufferingState(value);

    // 自动模式：定期检查是否需要切换画质
    if (_currentQuality == VideoQuality.auto) {
      _checkAutoQuality();
    }
  }

  /// 处理 buffering 状态变化，采集网速样本
  void _handleBufferingState(VideoPlayerValue value) {
    if (value.isBuffering) {
      // buffering 开始
      _bufferingStartTime = DateTime.now();
    } else if (_bufferingStartTime != null) {
      // buffering 结束，估算带宽
      final bufferDuration = DateTime.now().difference(_bufferingStartTime!);
      _bufferingStartTime = null;

      if (bufferDuration.inMilliseconds > 100) {
        // 粗略估算：假设缓冲期间下载了 2 秒的视频数据
        // 码率 × 2 秒 ≈ 下载字节数 × 8
        final currentBitrate = _currentPlaybackInfo?.actualBitrate ?? 5000000;
        final estimatedBytes = (currentBitrate * 2 / 8).round();

        _networkMonitor.recordFromBuffering(
          bufferedBytes: estimatedBytes,
          bufferDuration: bufferDuration,
        );

        print('📊 带宽估算: ${_networkMonitor.estimatedBandwidth} bps');
      }
    }
  }

  /// 自动画质检查
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
      print('🤖 自动切换画质: ${_currentQuality.label} → ${target.label}');
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

  /// 构建画质选项
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主内容区域
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 顶部栏（返回 + 标题）
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

          // 底部画质按钮（和设置/全屏按钮同一行）
          if (!_isLoading && _errorMessage == null)
            Positioned(
              bottom: 0,
              right: 96,
              child: _buildQualityBadge(),
            ),
        ],
      ),
    );
  }

  /// 画质标签按钮（与控制栏图标按钮等高）
  Widget _buildQualityBadge() {
    return SizedBox(
      height: 48, // IconButton 默认高度
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

  /// 加载中
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

  /// 错误提示
  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
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

  /// 播放器
  Widget _buildPlayerWidget() {
    return Chewie(
      controller: _chewieController!,
    );
  }
}
