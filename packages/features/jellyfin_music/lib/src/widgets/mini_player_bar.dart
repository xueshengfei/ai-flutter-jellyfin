import 'package:flutter/material.dart';
import '../services/audio_playback_port.dart';

/// 全局迷你播放器条
///
/// 监听 [AudioPlaybackPort] 状态变化，无播放列表时隐藏。
/// 导航通过 [onOpenPlayer] 回调注入，不依赖 go_router。
class MiniPlayerBar extends StatelessWidget {
  final AudioPlaybackPort playbackPort;
  final VoidCallback onOpenPlayer;

  const MiniPlayerBar({
    super.key,
    required this.playbackPort,
    required this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playbackPort,
      builder: (context, _) {
        if (!playbackPort.hasPlaylist || playbackPort.currentTrack == null) {
          return const SizedBox.shrink();
        }

        final track = playbackPort.currentTrack!;
        final theme = Theme.of(context);
        final progress = playbackPort.duration.inMilliseconds > 0
            ? (playbackPort.position.inMilliseconds /
                    playbackPort.duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          onTap: onOpenPlayer,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Stack(
              children: [
                // 内容行
                Row(
                  children: [
                    // 封面
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: track.coverUrl != null
                            ? Image.network(
                                track.coverUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _coverPlaceholder(theme),
                              )
                            : _coverPlaceholder(theme),
                      ),
                    ),
                    // 歌名 + 歌手
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.name,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (track.artistText != null)
                            Text(
                              track.artistText!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // 播放/暂停
                    IconButton(
                      onPressed: () => playbackPort.isPlaying
                          ? playbackPort.pause()
                          : playbackPort.resume(),
                      icon: playbackPort.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              playbackPort.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 28,
                            ),
                    ),
                    // 下一首
                    IconButton(
                      onPressed: () => playbackPort.playNext(),
                      icon: const Icon(Icons.skip_next, size: 28),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                // 底部迷你进度条
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _coverPlaceholder(ThemeData theme) => Container(
        width: 44,
        height: 44,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.music_note, size: 24, color: Colors.white54),
      );
}
