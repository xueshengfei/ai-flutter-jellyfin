import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

import '../image/jellyfin_image.dart';
import '../image/jellyfin_image_provider.dart';

/// Landscape card for "continue watching" rails.
class ContinueWatchingCard extends StatelessWidget {
  static const double width = 240;
  static const double height = 184;

  final JellyfinImageProvider imageProvider;
  final MediaItem item;
  final VoidCallback? onTap;

  const ContinueWatchingCard({
    super.key,
    required this.imageProvider,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(imageProvider: imageProvider, item: item),
              const SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    final year = item.productionYear;
    if (year == null) return item.typeDisplayName;
    return '${item.typeDisplayName} · $year';
  }
}

class _Thumbnail extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final MediaItem item;

  const _Thumbnail({
    required this.imageProvider,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final progress = ((item.playedPercentage ?? 0) / 100).clamp(0.0, 1.0);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            item.hasCoverImage
                ? JellyfinImage(
                    imageProvider: imageProvider,
                    itemId: item.id,
                    imageTag: item.primaryImageTag,
                    fillWidth: 480,
                    fillHeight: 270,
                    fit: BoxFit.cover,
                    placeholder: _placeholder(context),
                    errorWidget: _placeholder(context),
                  )
                : _placeholder(context),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            if (progress > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.24),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          item.typeIcon,
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }
}
