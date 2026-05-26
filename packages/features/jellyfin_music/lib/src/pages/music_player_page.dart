import 'dart:async';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:jellyfin_music/src/services/audio_playback_port.dart';
import 'package:jellyfin_music/src/services/lyrics_port.dart';
import 'package:jellyfin_music/src/models/lyrics_models.dart';

/// 音乐播放详情页
///
/// 移动端布局：唱片旋转 + 歌名/歌手/词按钮 + 进度条 + 控制栏
/// 宽屏布局：唱片 + 右侧歌词面板
/// 支持动态取色（从封面提取主题色生成渐变背景）
/// 只依赖 [AudioPlaybackPort] 接口，不依赖旧 jellyfin_service。
class MusicPlayerPage extends StatefulWidget {
  final AudioPlaybackPort playbackPort;
  final VoidCallback? onOpenLyrics;
  final VoidCallback? onOpenRvc;
  final LyricsFetcher? fetchLyrics;

  const MusicPlayerPage({
    super.key,
    required this.playbackPort,
    this.onOpenLyrics,
    this.onOpenRvc,
    this.fetchLyrics,
  });

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vinylController;

  // 动态取色
  ColorScheme? _dynamicColorScheme;
  String? _extractedTrackId;

  // 宽屏歌词
  bool _showWebLyrics = false;
  LyricsData? _lyricsData;
  bool _lyricsLoading = false;
  int _currentLineIndex = -1;
  bool _isUserScrolling = false;
  Timer? _scrollResumeTimer;
  final ScrollController _lyricsScrollController = ScrollController();
  static const double _lyricItemHeight = 40.0;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    // 初始取色
    final track = widget.playbackPort.currentTrack;
    if (track?.coverUrl != null) _extractColors(track!.coverUrl!, track.id);
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _lyricsScrollController.dispose();
    _positionSub?.cancel();
    _scrollResumeTimer?.cancel();
    super.dispose();
  }

  // ─── 动态取色 ───

  Future<void> _extractColors(String imageUrl, String trackId) async {
    if (_extractedTrackId == trackId) return;
    _extractedTrackId = trackId;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 10,
      );
      final color =
          palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.mutedColor?.color;
      if (color != null && mounted) {
        setState(() {
          _dynamicColorScheme = ColorScheme.fromSeed(
            seedColor: color,
            brightness: Brightness.dark,
          );
        });
      }
    } catch (_) {}
  }

  // ─── 歌词（宽屏内嵌） ───

  Future<void> _loadLyrics() async {
    if (_lyricsData != null || _lyricsLoading) return;
    final fetcher = widget.fetchLyrics;
    if (fetcher == null) return;
    final track = widget.playbackPort.currentTrack;
    if (track == null) return;

    setState(() => _lyricsLoading = true);
    try {
      final data = await fetcher(track.id);
      if (mounted) {
        setState(() {
          _lyricsData = data;
          _lyricsLoading = false;
        });
        _startPositionTracking();
      }
    } catch (e) {
      if (mounted) setState(() => _lyricsLoading = false);
    }
  }

  void _startPositionTracking() {
    _positionSub?.cancel();
    _positionSub = widget.playbackPort.onPositionChanged.listen((p) {
      if (!mounted) return;
      _updateCurrentLine(p);
    });
  }

  void _updateCurrentLine(Duration position) {
    final lines = _lyricsData?.lines;
    if (lines == null || lines.isEmpty || !_lyricsData!.isSynced) return;
    final positionTicks = position.inMicroseconds * 10;
    int newIndex = -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].startTicks != null &&
          lines[i].startTicks! <= positionTicks) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _currentLineIndex) {
      setState(() => _currentLineIndex = newIndex);
      if (!_isUserScrolling) _scrollToLine(newIndex);
    }
  }

  void _scrollToLine(int index) {
    if (!_lyricsScrollController.hasClients || index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lyricsScrollController.hasClients) return;
      final target = (index * _lyricItemHeight) + (_lyricItemHeight / 2);
      final max = _lyricsScrollController.position.maxScrollExtent;
      _lyricsScrollController.animateTo(
        target.clamp(0.0, max),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _onUserScroll() {
    _isUserScrolling = true;
    _scrollResumeTimer?.cancel();
    _scrollResumeTimer = Timer(
      const Duration(seconds: 3),
      () => _isUserScrolling = false,
    );
  }

  Future<void> _onLineTap(int index) async {
    final lines = _lyricsData?.lines;
    if (lines == null || index >= lines.length) return;
    final startTime = lines[index].startTime;
    if (startTime != null) await widget.playbackPort.seek(startTime);
  }

  void _onLyricsTap() {
    final isWide = MediaQuery.of(context).size.width > 700;
    if (isWide) {
      setState(() => _showWebLyrics = !_showWebLyrics);
      if (_showWebLyrics) _loadLyrics();
    } else {
      widget.onOpenLyrics?.call();
    }
  }

  // ─── build ───

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

        // 检测歌曲切换：重置歌词 + 取色
        final trackChanged = track.id != _extractedTrackId;
        if (trackChanged) {
          _vinylController.stop();
          _lyricsData = null;
          _lyricsLoading = false;
          _currentLineIndex = -1;
          _positionSub?.cancel();
          if (_showWebLyrics) _loadLyrics();
          if (track.coverUrl != null) _extractColors(track.coverUrl!, track.id);
        }

        final isWide = MediaQuery.of(context).size.width > 700;

        return Theme(
          data: _dynamicColorScheme != null
              ? ThemeData(colorScheme: _dynamicColorScheme)
              : Theme.of(context),
          child: Scaffold(
            body: Container(
              decoration: _dynamicColorScheme != null
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _dynamicColorScheme!.surface,
                          _dynamicColorScheme!.surfaceContainerHighest,
                        ],
                      ),
                    )
                  : null,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const fixedHeight = 200.0;
                      final maxVinyl = (constraints.maxHeight - fixedHeight)
                          .clamp(120.0, 240.0);
                      return isWide
                          ? _buildWideLayout(port, track, maxVinyl)
                          : _buildNarrowLayout(port, track, maxVinyl);
                    },
                  ),
                ),
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
            child: Text(
              port.error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          '${port.currentIndex + 1} / ${port.playlistLength}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  // ─── Web/桌面端布局（宽屏） ───

  Widget _buildWideLayout(
    AudioPlaybackPort port,
    AudioTrack track,
    double vinylSize,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final lyricsWidth = (screenWidth - vinylSize - 32 - 32).clamp(200.0, 600.0);
    final lyricsHeight = vinylSize * 1.3;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildVinyl(track, vinylSize),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: _showWebLyrics ? lyricsWidth : 0,
              height: lyricsHeight,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showWebLyrics ? 1.0 : 0.0,
                curve: Curves.easeIn,
                child: _showWebLyrics
                    ? _buildWebLyricsContent(lyricsWidth, lyricsHeight)
                    : const SizedBox.shrink(),
              ),
            ),
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
            child: Text(
              port.error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          '${port.currentIndex + 1} / ${port.playlistLength}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  // ─── 宽屏歌词内容 ───

  Widget _buildWebLyricsContent(double width, double height) {
    if (_lyricsLoading) {
      return SizedBox(
        width: width,
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final lines = _lyricsData?.lines;
    if (lines == null || lines.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                '暂无歌词',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(left: 32),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is UserScrollNotification) _onUserScroll();
            return false;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final vPadding = constraints.maxHeight / 2;
              return ListView.builder(
                controller: _lyricsScrollController,
                padding: EdgeInsets.symmetric(vertical: vPadding),
                itemCount: lines.length,
                itemExtent: _lyricItemHeight,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final isCurrent = index == _currentLineIndex;
                  final isPast =
                      _currentLineIndex >= 0 && index < _currentLineIndex;
                  return GestureDetector(
                    onTap: () => _onLineTap(index),
                    behavior: HitTestBehavior.translucent,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: isCurrent ? 17 : 13,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : isPast
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          height: 1.4,
                        ),
                        child: Text(
                          line.text ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
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
          ),
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
      child: Icon(Icons.music_note, size: 80, color: Colors.white54),
    ),
  );

  // ─── 歌曲信息：歌名 · 歌手 [词] ───

  Widget _buildSongInfo(AudioTrack track) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            track.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (track.artistText != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '·',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ),
          Flexible(
            child: Text(
              track.artistText ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const SizedBox(width: 6),
        // 歌词小标签
        _LyricsChip(isActive: _showWebLyrics, onTap: _onLyricsTap),
      ],
    );
  }

  // ─── 进度条 ───

  Widget _buildProgressBar(AudioPlaybackPort port) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Slider(
            value: port.duration.inMilliseconds > 0
                ? (port.position.inMilliseconds / port.duration.inMilliseconds)
                      .clamp(0, 1)
                : 0,
            onChanged: (v) => port.seek(
              Duration(
                milliseconds: (port.duration.inMilliseconds * v).round(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(port.position),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              Text(
                _fmt(port.duration),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 控制栏: [PlayMode] [Prev] [Play/Pause] [Next] [收藏] [RVC] ───

  Widget _buildControls(AudioPlaybackPort port, AudioTrack track) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 播放模式
        IconButton(
          onPressed: () => port.cyclePlayMode(),
          icon: Icon(switch (port.playMode) {
            PlayMode.sequential => Icons.trending_flat,
            PlayMode.shuffle => Icons.shuffle,
            PlayMode.repeatOne => Icons.repeat_one,
          }, size: 28),
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
                width: 56,
                height: 56,
                child: CircularProgressIndicator(),
              )
            : IconButton.filled(
                onPressed: () => port.isPlaying ? port.pause() : port.resume(),
                icon: Icon(
                  port.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 40,
                ),
                style: IconButton.styleFrom(minimumSize: const Size(64, 64)),
              ),
        const SizedBox(width: 12),
        // Next
        IconButton(
          onPressed: () => port.playNext(),
          icon: const Icon(Icons.skip_next, size: 40),
        ),
        const SizedBox(width: 8),
        // 收藏按钮
        SizedBox(
          width: 48,
          height: 48,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () =>
                port.updateTrackFavorite(track.id, !(track.isFavorite == true)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  track.isFavorite == true
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: 22,
                  color: track.isFavorite == true ? Colors.red.shade400 : null,
                ),
                Text(
                  '藏',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        // RVC
        if (widget.onOpenRvc != null) _RvcButton(onTap: widget.onOpenRvc!),
      ],
    );
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

// RVC

class _RvcButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RvcButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_fix_high, size: 22, color: cs.primary),
            const SizedBox(height: 2),
            Text(
              'RVC',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 歌词小标签按钮（放在歌手行右侧） ───

class _LyricsChip extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _LyricsChip({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 14,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 3),
            Text(
              '词',
              style: TextStyle(
                fontSize: 11,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
