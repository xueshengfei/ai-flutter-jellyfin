import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 全局迷你播放卡片
///
/// 显示在页面底部，包含封面缩略图、歌曲信息、播放/暂停和下一首按钮。
/// 点击卡片（非按钮区域）跳转到 AudioPlayerPage。
class MiniPlayerCard extends StatelessWidget {
  final JellyfinClient client;

  const MiniPlayerCard({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioPlaybackManager.instance,
      builder: (context, _) {
        final manager = AudioPlaybackManager.instance;
        final song = manager.currentSong;
        if (song == null) return const SizedBox.shrink();

        final durationMs = manager.displayDuration.inMilliseconds;
        final positionMs = manager.position.inMilliseconds;
        final progress =
            durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AudioPlayerPage(
                client: client,
                song: song,
                playlist: manager.playlist,
                initialIndex: manager.currentIndex,
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度指示条
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                // 主内容
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // 封面缩略图
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: song.getAlbumCoverUrl(
                                  fillWidth: 88, fillHeight: 88) !=
                              null
                                  ? Image.network(
                                      song.getAlbumCoverUrl(
                                          fillWidth: 88, fillHeight: 88)!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _placeholder(context),
                                    )
                                  : _placeholder(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 歌曲信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              song.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              song.artistText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      // 播放/暂停
                      IconButton(
                        onPressed: () => manager.isPlaying
                            ? manager.pause()
                            : manager.resume(),
                        icon: Icon(
                          manager.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 36,
                        ),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      // 下一首
                      IconButton(
                        onPressed: () => manager.playNext(),
                        icon: const Icon(Icons.skip_next, size: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: const Center(
            child: Icon(Icons.music_note, size: 24, color: Colors.white54)),
      );
}
