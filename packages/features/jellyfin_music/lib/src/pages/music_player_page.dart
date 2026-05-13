import 'package:flutter/material.dart';
import 'package:jellyfin_music/src/services/audio_playback_port.dart';

/// 音乐播放详情页
///
/// 移动端布局：唱片旋转 + 歌名/歌手 + 进度条 + 控制栏
/// 宽屏布局：唱片 + 右侧预留歌词面板区域
/// 只依赖 [AudioPlaybackPort] 接口，不依赖旧 jellyfin_service。
class MusicPlayerPage extends StatefulWidget {
  final AudioPlaybackPort playbackPort;
  final VoidCallback? onOpenLyrics;

  const MusicPlayerPage({super.key, required this.playbackPort, this.onOpenLyrics});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vinylController;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void dispose() {
    _vinylController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.playbackPort,
      builder: (context, _) {
        final port = widget.playbackPort;
        final track = port.currentTrack;

        // 同步唱片旋转状态
        if (port.isPlaying) {
          if (!_vinylController.isAnimating) _vinylController.repeat();
        } else {
          _vinylController.stop();
        }

        if (track == null) {
          return const Scaffold(body: Center(child: Text('没有正在播放的歌曲')));
        }

        final isWide = MediaQuery.of(context).size.width > 700;

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const fixedHeight = 200.0;
                  final maxVinyl =
                      (constraints.maxHeight - fixedHeight).clamp(120.0, 240.0);
                  return isWide
                      ? _buildWideLayout(port, track, maxVinyl)
                      : _buildNarrowLayout(port, track, maxVinyl);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── 移动端布局（窄屏） ───

  Widget _buildNarrowLayout(
    AudioPlaybackPort port,
    AudioTrack track,
    double vinylSize,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildVinyl(track, vinylSize),
        const SizedBox(height: 12),
        _buildSongInfo(track),
        const SizedBox(height: 16),
        _buildProgressBar(port),
        const SizedBox(height: 8),
        _buildControls(port, track),
        if (port.error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(port.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ),
        const SizedBox(height: 2),
        Text('${port.currentIndex + 1} / ${port.playlistLength}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  // ─── Web/桌面端布局（宽屏） ───

  Widget _buildWideLayout(
    AudioPlaybackPort port,
    AudioTrack track,
    double vinylSize,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildVinyl(track, vinylSize),
            // 宽屏右侧预留歌词面板区域（后续 Milestone 实现）
            const SizedBox(width: 32),
          ],
        ),
        const SizedBox(height: 12),
        _buildSongInfo(track),
        const SizedBox(height: 16),
        _buildProgressBar(port),
        const SizedBox(height: 8),
        _buildControls(port, track),
        if (port.error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(port.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ),
        const SizedBox(height: 2),
        Text('${port.currentIndex + 1} / ${port.playlistLength}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  // ─── 黑胶唱片 ───

  Widget _buildVinyl(AudioTrack track, double size) {
    final coverUrl = track.coverUrl;
    final vinylContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
        gradient: coverUrl != null
            ? null
            : LinearGradient(
                colors: [Colors.grey.shade700, Colors.grey.shade900],
                stops: const [0.6, 1.0],
              ),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.067),
        child: ClipOval(
          child: coverUrl != null
              ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  width: size * 0.867,
                  height: size * 0.867,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _vinylController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _vinylController.value * 2 * 3.14159265,
          child: child,
        );
      },
      child: vinylContent,
    );
  }

  Widget _placeholder() => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
            child: Icon(Icons.music_note, size: 80, color: Colors.white54)),
      );

  // ─── 歌曲信息 ───

  Widget _buildSongInfo(AudioTrack track) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(track.name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        if (track.artistText != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('·',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ),
          Flexible(
            child: Text(track.artistText ?? '',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );
  }

  // ─── 进度条 ───

  Widget _buildProgressBar(AudioPlaybackPort port) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Slider(
          value: port.duration.inMilliseconds > 0
              ? (port.position.inMilliseconds / port.duration.inMilliseconds)
                  .clamp(0, 1)
              : 0,
          onChanged: (v) => port.seek(Duration(
              milliseconds: (port.duration.inMilliseconds * v).round())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(port.position),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text(_fmt(port.duration),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ]),
    );
  }

  // ─── 控制栏 ───

  Widget _buildControls(AudioPlaybackPort port, AudioTrack track) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      // 播放模式
      IconButton(
        onPressed: () => port.cyclePlayMode(),
        icon: Icon(
          switch (port.playMode) {
            PlayMode.sequential => Icons.trending_flat,
            PlayMode.shuffle => Icons.shuffle,
            PlayMode.repeatOne => Icons.repeat_one,
          },
          size: 28,
        ),
        color: port.playMode != PlayMode.sequential
            ? Theme.of(context).colorScheme.primary
            : null,
        tooltip: switch (port.playMode) {
          PlayMode.sequential => '顺序播放',
          PlayMode.shuffle => '随机播放',
          PlayMode.repeatOne => '单曲循环',
        },
      ),
      const SizedBox(width: 8),
      // Previous
      IconButton(
        onPressed: () => port.playPrevious(),
        icon: const Icon(Icons.skip_previous, size: 40),
      ),
      const SizedBox(width: 12),
      // Play/Pause
      port.isLoading
          ? const SizedBox(
              width: 56, height: 56, child: CircularProgressIndicator())
          : IconButton.filled(
              onPressed: () =>
                  port.isPlaying ? port.pause() : port.resume(),
              icon: Icon(port.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 40),
              style: IconButton.styleFrom(minimumSize: const Size(64, 64)),
            ),
      const SizedBox(width: 12),
      // Next
      IconButton(
        onPressed: () => port.playNext(),
        icon: const Icon(Icons.skip_next, size: 40),
      ),
      const SizedBox(width: 8),
      // 歌词
      if (widget.onOpenLyrics != null)
        IconButton(
          onPressed: widget.onOpenLyrics,
          icon: const Icon(Icons.lyrics, size: 28),
          tooltip: '歌词',
        ),
    ]);
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
