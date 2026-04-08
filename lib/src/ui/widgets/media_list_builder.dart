import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'package:jellyfin_service/src/ui/widgets/media_list_layouts/banner_list_view.dart';
import 'package:jellyfin_service/src/ui/widgets/media_list_layouts/vertical_list_view.dart';
import 'package:jellyfin_service/src/ui/widgets/media_list_layouts/poster_grid_view.dart';
import 'package:jellyfin_service/src/ui/widgets/media_list_layouts/card_grid_view.dart';

/// 媒体列表构建器
///
/// 根据视图模式配置动态构建不同的布局
class MediaListBuilder extends StatelessWidget {
  final JellyfinClient client;
  final List<MediaItem> items;
  final ViewModeConfig config;
  final ValueChanged<MediaItem>? onTap;

  const MediaListBuilder({
    super.key,
    required this.client,
    required this.items,
    required this.config,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (config.viewMode) {
      case ViewMode.banner:
        return BannerListView(
          client: client,
          items: items,
          onTap: onTap,
        );

      case ViewMode.list:
        return VerticalListView(
          client: client,
          items: items,
          onTap: onTap,
        );

      case ViewMode.poster:
        return PosterGridView(
          client: client,
          items: items,
          crossAxisCount: config.crossAxisCount,
          onTap: onTap,
        );

      case ViewMode.card:
        return CardGridView(
          client: client,
          items: items,
          crossAxisCount: config.crossAxisCount,
          onTap: onTap,
        );
    }
  }
}
