import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import '../image/jellyfin_image.dart';
import '../image/jellyfin_image_provider.dart';

/// 继续观看卡片
///
/// 紧凑卡片样式，显示封面 + 底部进度条 + 标题 + 副标题
class ContinueWatchingCard extends StatelessWidget {
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
    final progress = (item.playedPercentage ?? 0) / 100;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面 + 进度条
            Expanded(
              child: Stack(
                children: [
                  // 封面
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.hasCoverImage
                        ? JellyfinImage(
                            imageProvider: imageProvider,
                            itemId: item.id,
                            imageTag: item.primaryImageTag,
                            fillWidth: 260,
                            fillHeight: 390,
                            fit: BoxFit.cover,
                            placeholder: _placeholder(context),
                            errorWidget: _placeholder(context),
                          )
                        : _placeholder(context),
                  ),
                  // 底部蓝色进度条
                  if (progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 标题
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            // 副标题（类型 + 年份）
            Text(
              '${item.typeDisplayName}${item.productionYear != null ? ' · ${item.productionYear}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => SizedBox(
    width: 130,
    child: Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(
        item.typeIcon.isNotEmpty ? null : Icons.play_circle_outline,
        size: 32,
        color: Colors.white54,
      )),
    ),
  );
}
