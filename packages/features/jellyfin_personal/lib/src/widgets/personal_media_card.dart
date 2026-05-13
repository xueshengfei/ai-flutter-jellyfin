import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_actions.dart';

/// 个人页媒体卡片
///
/// 点击卡片主体调用 `onOpenMedia`（跳详情），
/// 播放按钮调用 `onPlayMedia`（跳播放）。
final class PersonalMediaCard extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final models.MediaItem item;
  final PersonalActions actions;
  final ValueChanged<bool>? onFavoriteToggle;

  const PersonalMediaCard({
    super.key,
    required this.imageProvider,
    required this.item,
    required this.actions,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: MediaItemCardWithActions(
            imageProvider: imageProvider,
            item: item,
            onTap: () => actions.onOpenMedia(context, item),
            onFavoriteToggle: onFavoriteToggle,
          ),
        ),
        if (actions.onPlayMedia != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.play_arrow),
                color: Theme.of(context).colorScheme.onPrimary,
                tooltip: '播放',
                onPressed: () => actions.onPlayMedia!(context, item),
              ),
            ),
          ),
      ],
    );
  }
}
