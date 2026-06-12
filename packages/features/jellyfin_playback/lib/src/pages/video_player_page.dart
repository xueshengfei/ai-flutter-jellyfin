import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_playback/src/models/video_quality_models.dart';
import 'package:jellyfin_playback/src/models/watch_assist_models.dart';
import 'package:jellyfin_playback/src/viewmodels/video_player_viewmodel.dart';
import 'package:jellyfin_playback/src/widgets/watch_assist_button.dart';
import 'package:jellyfin_playback/src/widgets/watch_assist_sheet.dart';

/// 视频播放页面 — 纯 View
///
/// 通过 [ListenableBuilder] 监听 [VideoPlayerViewModel] 的状态变化来刷新 UI。
/// 所有业务逻辑（初始化、画质切换、网络检测）都在 ViewModel 中。
class VideoPlayerPage extends StatefulWidget {
  /// ViewModel（由外部创建并注入）
  final VideoPlayerViewModel viewModel;

  /// AI 观影解读请求回调。未注入时不显示 AI 解读入口。
  final WatchAssistFetcher? fetchWatchAssist;

  /// 下载按钮回调。未注入时不显示下载入口。
  final void Function(BuildContext context, MediaItem item)? onStartDownload;

  const VideoPlayerPage({
    super.key,
    required this.viewModel,
    this.fetchWatchAssist,
    this.onStartDownload,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  @override
  void initState() {
    super.initState();
    // ViewModel 初始化完成后检查是否有需要展示的错误
    widget.viewModel.addListener(_onViewModelChanged);
    widget.viewModel.initialize();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    widget.viewModel.dispose();
    super.dispose();
  }

  /// 监听 ViewModel 变化，处理 SnackBar 等一次性消息
  void _onViewModelChanged() {
    final error = widget.viewModel.consumeLastError();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          return Stack(
            children: [
              Center(
                child: vm.isLoading
                    ? _buildLoadingWidget(vm)
                    : vm.errorMessage != null
                        ? _buildErrorWidget(vm)
                        : _buildPlayerWidget(vm),
              ),

              // 画质切换遮罩
              if (vm.isQualitySwitching) _buildQualitySwitchingOverlay(vm),

              // 顶部栏
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(context, vm),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── UI 组件 ───

  Widget _buildTopBar(BuildContext context, VideoPlayerViewModel vm) {
    return SafeArea(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '返回',
                ),
                Expanded(
                  child: Text(
                    vm.item.name,
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
            if (!vm.isLoading && vm.errorMessage == null)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.fetchWatchAssist != null)
                      WatchAssistButton(
                        onPressed: () => _showWatchAssistSheet(vm),
                      ),
                    if (widget.onStartDownload != null)
                      _buildDownloadButton(context, vm),
                    _buildQualityBadge(vm),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context, VideoPlayerViewModel vm) {
    return SizedBox(
      height: 48,
      child: TextButton.icon(
        onPressed: () => widget.onStartDownload?.call(context, vm.item),
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('下载'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  Widget _buildQualityBadge(VideoPlayerViewModel vm) {
    return SizedBox(
      height: 48,
      child: IconButton(
        onPressed: () => _showQualitySelector(vm),
        icon: Text(
          vm.currentQuality.label,
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

  Widget _buildQualitySwitchingOverlay(VideoPlayerViewModel vm) {
    return Container(
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
              '正在切换至 ${vm.currentQuality == VideoQuality.auto ? "自动" : "更高"}画质...',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget(VideoPlayerViewModel vm) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          vm.isQualitySwitching ? '正在切换画质...' : '正在加载视频...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            vm.item.name,
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

  Widget _buildErrorWidget(VideoPlayerViewModel vm) {
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
            vm.errorMessage!,
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

  Widget _buildPlayerWidget(VideoPlayerViewModel vm) {
    final chewie = vm.chewieController;
    if (chewie == null) return const SizedBox.shrink();
    return Chewie(controller: chewie);
  }

  // ─── 用户交互（委托给 ViewModel） ───

  void _showQualitySelector(VideoPlayerViewModel vm) {
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
            ...VideoQuality.values.map((q) => _buildQualityOption(q, vm)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(VideoQuality quality, VideoPlayerViewModel vm) {
    final isSelected = quality == vm.currentQuality;
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
          vm.switchQuality(quality);
        }
      },
    );
  }

  void _showWatchAssistSheet(VideoPlayerViewModel vm) {
    final fetcher = widget.fetchWatchAssist;
    if (fetcher == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WatchAssistSheet(
        itemId: vm.item.id,
        initialPositionSeconds: vm.currentPositionSeconds,
        fetchWatchAssist: fetcher,
      ),
    );
  }
}
