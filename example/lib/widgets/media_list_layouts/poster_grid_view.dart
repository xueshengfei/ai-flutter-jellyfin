import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import '../../media_item_card.dart';

/// 海报网格视图
///
/// 竖版海报网格布局（复用现有的MediaItemCard）
class PosterGridView extends StatelessWidget {
  final JellyfinClient client;
  final List<MediaItem> items;
  final int crossAxisCount;
  final ValueChanged<MediaItem>? onTap;
  final Widget Function(MediaItem item, VoidCallback onTap)? cardBuilder;

  const PosterGridView({
    super.key,
    required this.client,
    required this.items,
    this.crossAxisCount = 3,
    this.onTap,
    this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.67,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final handleTap = () => onTap?.call(item);

        // 如果提供了自定义卡片构建器，使用它
        if (cardBuilder != null) {
          return cardBuilder!(item, handleTap);
        }

        // 否则使用默认的 MediaItemCard
        return MediaItemCard(
          client: client,
          item: item,
          onTap: handleTap,
        );
      },
    );
  }
}
