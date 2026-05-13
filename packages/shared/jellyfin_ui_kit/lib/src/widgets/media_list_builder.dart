import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import '../image/jellyfin_image_provider.dart';
import '../models/view_mode_models.dart';
import 'media_list_layouts/banner_list_view.dart';
import 'media_list_layouts/vertical_list_view.dart';
import 'media_list_layouts/poster_grid_view.dart';
import 'media_list_layouts/card_grid_view.dart';

/// 媒体列表构建器
///
/// 根据视图模式配置动态构建不同的布局
class MediaListBuilder extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final List<MediaItem> items;
  final ViewModeConfig config;
  final ValueChanged<MediaItem>? onTap;

  const MediaListBuilder({
    super.key,
    required this.imageProvider,
    required this.items,
    required this.config,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (config.viewMode) {
      case ViewMode.banner:
        return BannerListView(
          imageProvider: imageProvider,
          items: items,
          onTap: onTap,
        );

      case ViewMode.list:
        return VerticalListView(
          imageProvider: imageProvider,
          items: items,
          onTap: onTap,
        );

      case ViewMode.poster:
        return PosterGridView(
          imageProvider: imageProvider,
          items: items,
          crossAxisCount: config.crossAxisCount,
          onTap: onTap,
        );

      case ViewMode.card:
        return CardGridView(
          imageProvider: imageProvider,
          items: items,
          crossAxisCount: config.crossAxisCount,
          onTap: onTap,
        );
    }
  }
}
