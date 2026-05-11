import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

/// 集卡片组件
class EpisodeCard extends StatelessWidget {
  final Episode episode;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  const EpisodeCard({
    super.key,
    required this.episode,
    required this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 缩略图
            SizedBox(
              width: 120,
              height: 68,
              child: episode.hasThumbnailImage
                  ? Image.network(
                      episode.getThumbnailImageUrl()!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Center(
                            child:
                                Icon(Icons.error_outline, color: Colors.grey),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 32,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),

            // 信息区域
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 集号和名称
                    Text(
                      episode.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 集号
                    Text(
                      episode.episodeNumberText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),

                    // 时长和评分
                    Row(
                      children: [
                        // 时长
                        if (episode.runTimeMinutes != null) ...[
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            episode.durationText,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // 评分
                        if (episode.communityRating != null) ...[
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            episode.communityRating!.toStringAsFixed(1),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                        ],
                      ],
                    ),

                    // 剧情简介
                    if (episode.overview != null &&
                        episode.overview!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        episode.overview!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 播放按钮
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: IconButton(
                icon: const Icon(Icons.play_circle_filled),
                color: Theme.of(context).colorScheme.primary,
                iconSize: 32,
                onPressed: onPlay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
