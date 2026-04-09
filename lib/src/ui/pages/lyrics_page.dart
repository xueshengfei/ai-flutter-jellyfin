import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:jellyfin_service/src/ui/services/audio_playback_manager.dart';

/// 歌词页面（QQ 音乐 / Spotify 风格）
class LyricsPage extends StatefulWidget {
  final JellyfinClient client;
  final MusicSong currentSong;
  final String? albumCoverUrl;

  const LyricsPage({
    super.key,
    required this.client,
    required this.currentSong,
    this.albumCoverUrl,
  });

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  LyricsData? _lyricsData;
  bool _isLoading = true;

  int _currentLineIndex = -1;
  bool _isUserScrolling = false;
  Timer? _scrollResumeTimer;

  final ScrollController _scrollController = ScrollController();
  static const double _itemHeight = 56.0;

  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  void _startPositionTracking() {
    _positionSub?.cancel();
    _positionSub = AudioPlaybackManager.instance.onPositionChanged.listen((p) {
      if (!mounted) return;
      _updateCurrentLine(p);
    });
  }

  Future<void> _loadLyrics() async {
    setState(() { _isLoading = true; });
    try {
      final data = await widget.client.music.getLyrics(widget.currentSong.id);
      if (mounted) {
        setState(() {
          _lyricsData = data;
          _isLoading = false;
        });
        // 歌词加载完成后开始监听位置
        _startPositionTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _updateCurrentLine(Duration position) {
    final lines = _lyricsData?.lines;
    if (lines == null || lines.isEmpty || !_lyricsData!.isSynced) return;

    final positionTicks = position.inMicroseconds * 10;

    // 找到 startTicks <= currentPosition 的最后一行
    int newIndex = -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].startTicks != null && lines[i].startTicks! <= positionTicks) {
        newIndex = i;
        break;
      }
    }

    if (newIndex != _currentLineIndex) {
      setState(() {
        _currentLineIndex = newIndex;
      });
      if (!_isUserScrolling) {
        _scrollToLine(newIndex);
      }
    }
  }

  void _scrollToLine(int index) {
    if (!_scrollController.hasClients || index < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = (index * _itemHeight) - (viewportHeight / 2) + (_itemHeight / 2);
      final maxOffset = _scrollController.position.maxScrollExtent;
      final clampedOffset = targetOffset.clamp(0.0, maxOffset);

      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _onUserScroll() {
    _isUserScrolling = true;
    _scrollResumeTimer?.cancel();
    _scrollResumeTimer = Timer(const Duration(seconds: 3), () {
      _isUserScrolling = false;
    });
  }

  Future<void> _onLineTap(int index) async {
    final lines = _lyricsData?.lines;
    if (lines == null || index >= lines.length) return;
    final startTime = lines[index].startTime;
    if (startTime != null) {
      await AudioPlaybackManager.instance.seek(startTime);
    }
  }

  Future<void> _searchRemoteLyrics() async {
    try {
      final results = await widget.client.music.searchRemoteLyrics(widget.currentSong.id);
      if (!mounted) return;

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到在线歌词')),
        );
        return;
      }

      final selected = await showModalBottomSheet<RemoteLyricsInfo>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('在线歌词搜索结果',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final info = results[i];
                    final lineCount = info.lyrics?.lines.length ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.lyrics),
                      title: Text(info.providerName ?? '未知来源'),
                      subtitle: Text('$lineCount 行歌词'),
                      trailing: const Icon(Icons.download),
                      onTap: () => Navigator.pop(ctx, info),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (selected != null && selected.id != null && mounted) {
        setState(() => _isLoading = true);
        _positionSub?.cancel();
        final data = await widget.client.music.downloadRemoteLyrics(
          itemId: widget.currentSong.id,
          lyricId: selected.id!,
        );
        if (mounted) {
          setState(() {
            _lyricsData = data;
            _isLoading = false;
            _currentLineIndex = -1;
          });
          _startPositionTracking();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _scrollResumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = AudioPlaybackManager.instance;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBlurredBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildBody()),
                _buildBottomControls(manager),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredBackground() {
    final coverUrl = widget.albumCoverUrl;
    return Positioned.fill(
      child: coverUrl != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black87),
                ),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(color: Colors.black.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            )
          : Container(color: Colors.black87),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: AudioPlaybackManager.instance,
              builder: (context, _) {
                final song = AudioPlaybackManager.instance.currentSong ?? widget.currentSong;
                return Column(
                  children: [
                    Text(
                      song.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      song.artistText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final lines = _lyricsData?.lines;
    if (lines == null || lines.isEmpty) {
      return _buildNoLyrics();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          _onUserScroll();
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final verticalPadding = constraints.maxHeight / 2;
          return ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(vertical: verticalPadding),
            itemCount: lines.length,
            itemExtent: _itemHeight,
            itemBuilder: (context, index) => _buildLyricLine(lines[index], index),
          );
        },
      ),
    );
  }

  Widget _buildLyricLine(LyricsLine line, int index) {
    final isCurrentLine = index == _currentLineIndex;
    final isPast = _currentLineIndex >= 0 && index < _currentLineIndex;

    double opacity;
    if (isCurrentLine) {
      opacity = 1.0;
    } else if (isPast) {
      opacity = 0.4;
    } else {
      opacity = 0.7;
    }

    return GestureDetector(
      onTap: () => _onLineTap(index),
      behavior: HitTestBehavior.translucent,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: Colors.white.withValues(alpha: opacity),
            fontSize: isCurrentLine ? 20 : 16,
            fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
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
  }

  Widget _buildNoLyrics() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lyrics_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('暂无歌词',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _searchRemoteLyrics,
            icon: const Icon(Icons.search),
            label: const Text('搜索在线歌词'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(AudioPlaybackManager manager) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final position = manager.position;
        final duration = manager.displayDuration;
        final isPlaying = manager.isPlaying;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(_fmtDuration(position),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: duration.inMilliseconds > 0
                            ? (position.inMilliseconds / duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: (v) => manager.seek(
                          Duration(
                              milliseconds:
                                  (duration.inMilliseconds * v).round()),
                        ),
                      ),
                    ),
                  ),
                  Text(_fmtDuration(duration),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                ],
              ),
              IconButton(
                onPressed: () => isPlaying ? manager.pause() : manager.resume(),
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtDuration(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
