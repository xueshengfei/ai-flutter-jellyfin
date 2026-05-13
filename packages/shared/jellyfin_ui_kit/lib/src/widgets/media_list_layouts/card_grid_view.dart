import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import '../../image/jellyfin_image.dart';
import '../../image/jellyfin_image_provider.dart';

/// 卡片网格视图
///
/// 卡片式布局，包含更多元数据和操作按钮
class CardGridView extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final List<MediaItem> items;
  final int crossAxisCount;
  final ValueChanged<MediaItem>? onTap;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const CardGridView({
    super.key,
    required this.imageProvider,
    required this.items,
    this.crossAxisCount = 3,
    this.onTap,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _MediaItemCard(
          imageProvider: imageProvider,
          item: item,
          onTap: () => onTap?.call(item),
        );
      },
    );
  }
}

class _MediaItemCard extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final MediaItem item;
  final VoidCallback onTap;

  const _MediaItemCard({
    required this.imageProvider,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 海报图片
            Expanded(
              child: JellyfinImage(
                imageProvider: imageProvider,
                itemId: item.id,
                imageTag: item.primaryImageTag,
                fillWidth: 200,
                fillHeight: 300,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.movie_outlined, size: 48),
                  ),
                ),
                errorWidget: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(item.typeIcon != '' ? null : Icons.broken_image_outlined,
                        size: 48, color: Colors.white54),
                  ),
                ),
              ),
            ),

            // 卡片内容
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // 元数据行
                  Row(
                    children: [
                      if (item.productionYear != null)
                        Text(
                          '${item.productionYear}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      if (item.productionYear != null && item.communityRating != null)
                        const SizedBox(width: 4),
                      if (item.communityRating != null) ...[
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          item.communityRating!.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // 操作按钮占位
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      Icon(
                        Icons.favorite_border,
                        size: 16,
                        color: Colors.grey,
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.circle_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
