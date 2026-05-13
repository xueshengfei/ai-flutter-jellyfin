import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jellyfin_music/src/models/lyrics_models.dart';
import 'package:jellyfin_music/src/services/audio_playback_port.dart';
import 'package:jellyfin_music/src/services/lyrics_port.dart';

/// 歌词面板组件（可嵌入）
///
/// 只负责：歌词加载 → 同步滚动 → 远程搜索/下载 → 点击跳转。
/// 不包含背景模糊、顶部歌曲信息、底部播放控制。
/// 只依赖 [AudioPlaybackPort] 和回调注入。
class LyricsPanel extends StatefulWidget {
  final AudioPlaybackPort playbackPort;
  final LyricsFetcher fetchLyrics;
  final RemoteLyricsSearcher? searchRemoteLyrics;
  final RemoteLyricsDownloader? downloadRemoteLyrics;
  final String itemId;

  const LyricsPanel({
    super.key,
    required this.playbackPort,
    required this.fetchLyrics,
    required this.itemId,
    this.searchRemoteLyrics,
    this.downloadRemoteLyrics,
  });

  @override
  State<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<LyricsPanel> {
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
    _positionSub = widget.playbackPort.onPositionChanged.listen((p) {
      if (!mounted) return;
      _updateCurrentLine(p);
    });
  }

  Future<void> _loadLyrics() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.fetchLyrics(widget.itemId);
      if (mounted) {
        setState(() {
          _lyricsData = data;
          _isLoading = false;
        });
        if (data != null && data.hasLyrics) {
          _startPositionTracking();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
      if (!_isUserScrolling) {
        _scrollToLine(newIndex);
      }
    }
  }

  void _scrollToLine(int index) {
    if (!_scrollController.hasClients || index < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final targetOffset = (index * _itemHeight) + (_itemHeight / 2);
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
      await widget.playbackPort.seek(startTime);
    }
  }

  Future<void> _searchRemoteLyrics() async {
    final searcher = widget.searchRemoteLyrics;
    final downloader = widget.downloadRemoteLyrics;
    if (searcher == null || downloader == null) return;

    try {
      final results = await searcher(widget.itemId);
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
        final data = await downloader(
          itemId: widget.itemId,
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
          if (widget.searchRemoteLyrics != null &&
              widget.downloadRemoteLyrics != null) ...[
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
        ],
      ),
    );
  }
}
