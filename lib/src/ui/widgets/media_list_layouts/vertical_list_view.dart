import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 垂直列表视图
///
/// 左图右文的列表布局
class VerticalListView extends StatelessWidget {
  final JellyfinClient client;
  final List<MediaItem> items;
  final ValueChanged<MediaItem>? onTap;

  const VerticalListView({
    super.key,
    required this.client,
    required this.items,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _VerticalListItem(
          client: client,
          item: item,
          onTap: () => onTap?.call(item),
        );
      },
    );
  }
}

class _VerticalListItem extends StatelessWidget {
  final JellyfinClient client;
  final MediaItem item;
  final VoidCallback onTap;

  const _VerticalListItem({
    required this.client,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧海报图片
              AspectRatio(
                aspectRatio: 0.67,
                child: JellyfinImageWithClient(
                  client: client,
                  itemId: item.id,
                  imageTag: item.primaryImageTag,
                  fillWidth: 120,
                  fillHeight: 180,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.movie_outlined),
                    ),
                  ),
                  errorWidget: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                    ),
                  ),
                ),
              ),

              // 右侧信息
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 标题
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // 元数据
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.productionYear != null)
                            Text(
                              '${item.productionYear}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (item.communityRating != null) ...[
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            Text(
                              item.communityRating!.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (item.officialRating != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.officialRating!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),

                      // 简介
                      if (item.overview != null && item.overview!.isNotEmpty)
                        Expanded(
                          child: Text(
                            item.overview!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
