import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

/// 剧集详情底部弹窗
class EpisodeDetailSheet extends StatelessWidget {
  final Episode episode;
  final ScrollController scrollController;
  final JellyfinImageProvider? imageProvider;

  const EpisodeDetailSheet({
    super.key,
    required this.episode,
    required this.scrollController,
    this.imageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 内容
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // 标题和集号
                Text(
                  episode.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  episode.episodeNumberText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),

                // 缩略图
                if (episode.hasThumbnailImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildThumbnailImage(context),
                  ),
                if (episode.hasThumbnailImage) const SizedBox(height: 16),

                // 信息行
                Wrap(
                  spacing: 16,
                  children: [
                    // 时长
                    if (episode.runTimeMinutes != null)
                      _buildInfoChip(
                        context,
                        icon: Icons.schedule,
                        label: episode.durationText,
                      ),

                    // 评分
                    if (episode.communityRating != null)
                      _buildInfoChip(
                        context,
                        icon: Icons.star,
                        label:
                            '${episode.communityRating!.toStringAsFixed(1)} 分',
                      ),

                    // 播放状态
                    if (episode.played == true)
                      _buildInfoChip(
                        context,
                        icon: Icons.check_circle,
                        label: '已播放',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // 剧情简介
                if (episode.overview != null &&
                    episode.overview!.isNotEmpty) ...[
                  Text(
                    '剧情简介',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    episode.overview!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建缩略图：优先使用 JellyfinImage，否则回退到 Image.network
  Widget _buildThumbnailImage(BuildContext context) {
    if (imageProvider != null) {
      return SizedBox(
        height: 200,
        child: JellyfinImage(
          imageProvider: imageProvider!,
          itemId: episode.id,
          imageTag: episode.primaryImageTag,
          fit: BoxFit.cover,
          errorWidget: Container(
            height: 200,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.error_outline, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Image.network(
      episode.getThumbnailImageUrl()!,
      height: 200,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 200,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(Icons.error_outline, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
