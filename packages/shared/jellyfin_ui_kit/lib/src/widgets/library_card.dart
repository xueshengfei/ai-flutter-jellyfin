import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

import '../image/jellyfin_image.dart';
import '../image/jellyfin_image_provider.dart';

/// Compact media-library card with responsive width.
class LibraryCard extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final MediaLibrary library;
  final VoidCallback onTap;

  const LibraryCard({
    super.key,
    required this.imageProvider,
    required this.library,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = switch (screenWidth) {
      >= 1200 => 4,
      >= 760 => 3,
      >= 520 => 2,
      _ => 1,
    };
    final horizontalPadding = screenWidth >= 520 ? 48.0 : 32.0;
    final spacing = (columns - 1) * 12.0;
    final width = ((screenWidth - horizontalPadding - spacing) / columns)
        .clamp(220.0, 360.0);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: 84,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _LibraryCover(imageProvider: imageProvider, library: library),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        library.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (library.itemCount != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${library.itemCount} 项',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryCover extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final MediaLibrary library;

  const _LibraryCover({
    required this.imageProvider,
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: library.hasCoverImage
          ? JellyfinImage(
              imageProvider: imageProvider,
              itemId: library.id,
              imageTag: library.primaryImageTag,
              fillWidth: 96,
              fillHeight: 96,
              fit: BoxFit.cover,
            )
          : Center(
              child: Text(
                library.type.icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
    );
  }
}
