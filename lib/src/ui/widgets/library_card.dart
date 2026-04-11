import 'package:flutter/material.dart';
import 'package:jellyfin_service/src/jellyfin_client.dart';
import 'package:jellyfin_service/src/models/media_library_models.dart';
import 'package:jellyfin_service/src/ui/widgets/jellyfin_image.dart';

/// 媒体库卡片（紧凑横条）
class LibraryCard extends StatelessWidget {
  final JellyfinClient client;
  final MediaLibrary library;
  final VoidCallback onTap;

  const LibraryCard({
    super.key,
    required this.client,
    required this.library,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 42) / 2,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 小图标/封面
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: library.hasCoverImage
                  ? JellyfinImageWithClient(client: client, itemId: library.id, imageTag: library.primaryImageTag, fillWidth: 80, fillHeight: 80, fit: BoxFit.cover)
                  : Center(child: Text(library.type.icon, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(library.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (library.itemCount != null)
                    Text('${library.itemCount} 项', style: TextStyle(color: Colors.grey[600], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
