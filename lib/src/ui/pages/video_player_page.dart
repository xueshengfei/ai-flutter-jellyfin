import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 视频播放页面
///
/// 支持嵌入和全屏模式切换，提供自定义控制栏
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

      // 初始化视频控制器
      print('🎞️ 初始化视频控制器...');
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(playbackInfo.url),
      );

      // 等待控制器初始化
      await _videoController!.initialize();

      // 续播：跳转到上次播放位置
      if (resumeTicks != null && resumeTicks > 0) {
        final resumeSeconds = resumeTicks / 10000000; // ticks → seconds
        await _videoController!.seekTo(Duration(seconds: resumeSeconds.round()));
      }

      // 创建 Chewie 控制器
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

  /// 监听视频播放进度
  void _onVideoProgressChanged() {
    if (_videoController == null) return;

    // 每 10 秒上报一次进度（在 PlaybackService 中通过定时器实现）
    // 这里可以添加其他逻辑，比如更新 UI 显示的当前时间
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

          // 顶部返回按钮（始终显示）
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
        ],
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
          '正在加载视频...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            widget.item.name,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
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
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
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
