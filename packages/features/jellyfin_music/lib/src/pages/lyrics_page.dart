import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jellyfin_music/src/services/audio_playback_port.dart';
import 'package:jellyfin_music/src/services/lyrics_port.dart';
import 'package:jellyfin_music/src/widgets/lyrics_panel.dart';

/// 歌词页面（完整版：背景模糊 + 顶部歌曲信息 + 底部播放控制）
///
/// 内部组合 [LyricsPanel]。
/// 不依赖 JellyfinClient、AudioPlaybackManager 单例。
/// 通过 [AudioPlaybackPort] 和回调注入。
class LyricsPage extends StatelessWidget {
  final AudioPlaybackPort playbackPort;
  final LyricsFetcher fetchLyrics;
  final RemoteLyricsSearcher? searchRemoteLyrics;
  final RemoteLyricsDownloader? downloadRemoteLyrics;
  final String? albumCoverUrl;

  const LyricsPage({
    super.key,
    required this.playbackPort,
    required this.fetchLyrics,
    this.searchRemoteLyrics,
    this.downloadRemoteLyrics,
    this.albumCoverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBlurredBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(child: _buildLyricsPanel()),
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredBackground() {
    final coverUrl = albumCoverUrl;
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

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 32),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: playbackPort,
              builder: (context, _) {
                final track = playbackPort.currentTrack;
                return Column(
                  children: [
                    Text(
                      track?.name ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (track?.artistText != null)
                      Text(
                        track!.artistText!,
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

  Widget _buildLyricsPanel() {
    final track = playbackPort.currentTrack;
    if (track == null) {
      return const Center(
        child: Text('没有正在播放的歌曲',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return LyricsPanel(
      playbackPort: playbackPort,
      fetchLyrics: fetchLyrics,
      itemId: track.id,
      searchRemoteLyrics: searchRemoteLyrics,
      downloadRemoteLyrics: downloadRemoteLyrics,
    );
  }

  Widget _buildBottomControls() {
    return ListenableBuilder(
      listenable: playbackPort,
      builder: (context, _) {
        final position = playbackPort.position;
        final duration = playbackPort.duration;
        final isPlaying = playbackPort.isPlaying;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(_fmtDuration(position),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: duration.inMilliseconds > 0
                            ? (position.inMilliseconds /
                                    duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: (v) => playbackPort.seek(Duration(
                            milliseconds:
                                (duration.inMilliseconds * v).round())),
                      ),
                    ),
                  ),
                  Text(_fmtDuration(duration),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11)),
                ],
              ),
              IconButton(
                onPressed: () =>
                    isPlaying ? playbackPort.pause() : playbackPort.resume(),
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
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
