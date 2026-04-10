import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 横幅列表视图
///
/// 大横幅图片布局，适合展示精选内容
class BannerListView extends StatelessWidget {
  final JellyfinClient client;
  final List<MediaItem> items;
  final ValueChanged<MediaItem>? onTap;

  const BannerListView({
    super.key,
    required this.client,
    required this.items,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _BannerListItem(
          client: client,
          item: item,
          onTap: () => onTap?.call(item),
        );
      },
    );
  }
}

class _BannerListItem extends StatelessWidget {
  final JellyfinClient client;
  final MediaItem item;
  final VoidCallback onTap;

  const _BannerListItem({
    required this.client,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 大横幅图片
            AspectRatio(
              aspectRatio: 2.5,
              child: JellyfinImageWithClient(
                client: client,
                itemId: item.id,
                imageTag: item.primaryImageTag,
                fillWidth: 800,
                fillHeight: 320,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.movie_outlined, size: 64),
                  ),
                ),
                errorWidget: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, size: 64, color: Colors.white54),
                  ),
                ),
              ),
            ),

            // 标题和信息
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (item.productionYear != null)
                        Chip(
                          label: Text('${item.productionYear}'),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (item.communityRating != null)
                        Chip(
                          avatar: const Icon(Icons.star, size: 16),
                          label: Text('${item.communityRating!.toStringAsFixed(1)}'),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (item.officialRating != null)
                        Chip(
                          label: Text(item.officialRating!),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (item.overview != null && item.overview!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      item.overview!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
