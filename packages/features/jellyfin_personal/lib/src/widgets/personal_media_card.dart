import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart' as models;
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../contracts/personal_actions.dart';

enum PersonalMediaCardLayout { landscape, poster, square }

/// Compact personal-center media card.
final class PersonalMediaCard extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final models.MediaItem item;
  final PersonalActions actions;
  final PersonalMediaCardLayout layout;
  final ValueChanged<bool>? onFavoriteToggle;

  const PersonalMediaCard({
    super.key,
    required this.imageProvider,
    required this.item,
    required this.actions,
    this.layout = PersonalMediaCardLayout.poster,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLayout = _isMusic ? PersonalMediaCardLayout.square : layout;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => actions.onOpenMedia(context, item),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageHeight = _imageHeight(
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
              layout: effectiveLayout,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: imageHeight,
                  child: _Cover(
                    imageProvider: imageProvider,
                    item: item,
                    layout: effectiveLayout,
                    actions: actions,
                    onFavoriteToggle: onFavoriteToggle,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool get _isMusic {
    final type = item.type.toLowerCase();
    return type == 'audio' || type == 'musicalbum' || type == 'musicartist';
  }

  String get _subtitle {
    final year = item.productionYear;
    if (year == null) return item.typeDisplayName;
    return '${item.typeDisplayName} · $year';
  }

  double _imageHeight({
    required double maxWidth,
    required double maxHeight,
    required PersonalMediaCardLayout layout,
  }) {
    final effectiveMaxHeight = maxHeight.isFinite
        ? maxHeight
        : switch (layout) {
            PersonalMediaCardLayout.landscape => 184.0,
            PersonalMediaCardLayout.square => 212.0,
            PersonalMediaCardLayout.poster => 224.0,
          };
    final maxImageHeight = (effectiveMaxHeight - 58).clamp(
      96.0,
      effectiveMaxHeight,
    );
    final desiredHeight = switch (layout) {
      PersonalMediaCardLayout.landscape => maxWidth / (16 / 9),
      PersonalMediaCardLayout.square => maxWidth,
      PersonalMediaCardLayout.poster => maxWidth / 0.72,
    };
    return desiredHeight.clamp(96.0, maxImageHeight);
  }
}

class _Cover extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final models.MediaItem item;
  final PersonalMediaCardLayout layout;
  final PersonalActions actions;
  final ValueChanged<bool>? onFavoriteToggle;

  const _Cover({
    required this.imageProvider,
    required this.item,
    required this.layout,
    required this.actions,
    required this.onFavoriteToggle,
  });

  JellyfinImageType get _imageType {
    if (layout == PersonalMediaCardLayout.landscape) {
      if (item.hasThumbImage) return JellyfinImageType.thumb;
      if (item.hasBackdropImage) return JellyfinImageType.backdrop;
    }
    return JellyfinImageType.primary;
  }

  String? get _imageTag {
    if (layout == PersonalMediaCardLayout.landscape) {
      if (item.hasThumbImage) return item.thumbImageTag;
      if (item.hasBackdropImage) return item.backdropImageTag;
    }
    return item.primaryImageTag;
  }

  @override
  Widget build(BuildContext context) {
    final progress = ((item.playedPercentage ?? 0) / 100).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        item.hasCoverImage
            ? JellyfinImage(
                imageProvider: imageProvider,
                itemId: item.id,
                imageType: _imageType,
                imageTag: _imageTag,
                fillWidth: 360,
                fillHeight: 360,
                fit: BoxFit.cover,
                placeholder: _placeholder(context),
                errorWidget: _placeholder(context),
              )
            : _placeholder(context),
        if (item.played ?? false)
          Positioned(
            top: 8,
            left: 8,
            child: _Badge(
              label: '已观看',
              color: Colors.green.withValues(alpha: 0.92),
            ),
          ),
        if (onFavoriteToggle != null)
          Positioned(
            top: 8,
            right: 8,
            child: _RoundIconButton(
              icon: item.isFavorite ?? false
                  ? Icons.favorite
                  : Icons.favorite_border,
              iconColor: item.isFavorite ?? false
                  ? Colors.redAccent
                  : Colors.white,
              tooltip: '收藏',
              onPressed: () =>
                  onFavoriteToggle?.call(!(item.isFavorite ?? false)),
            ),
          ),
        if (actions.onPlayMedia != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: _RoundIconButton(
              icon: Icons.play_arrow,
              iconColor: Colors.white,
              tooltip: '播放',
              onPressed: () => actions.onPlayMedia!(context, item),
            ),
          ),
        if (progress > 0 && !(item.played ?? false))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.black.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(item.typeIcon, style: const TextStyle(fontSize: 34)),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.iconColor,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.56),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
