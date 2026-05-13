import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import '../media_item_card.dart';
import '../../image/jellyfin_image_provider.dart';

/// 海报网格视图
///
/// 竖版海报网格布局（复用 MediaItemCard）
class PosterGridView extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final List<MediaItem> items;
  final int crossAxisCount;
  final ValueChanged<MediaItem>? onTap;
  final Widget Function(MediaItem item, VoidCallback onTap)? cardBuilder;

  const PosterGridView({
    super.key,
    required this.imageProvider,
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
        void handleTap() => onTap?.call(item);

        // 如果提供了自定义卡片构建器，使用它
        if (cardBuilder != null) {
          return cardBuilder!(item, handleTap);
        }

        // 否则使用默认的 MediaItemCard
        return MediaItemCard(
          imageProvider: imageProvider,
          item: item,
          onTap: handleTap,
        );
      },
    );
  }
}
