import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import '../image/jellyfin_image.dart';
import '../image/jellyfin_image_provider.dart';

/// 带操作按钮的媒体项卡片组件
///
/// 显示媒体项封面、标题、年份等信息，并支持收藏按钮、播放进度、已看标记
class MediaItemCardWithActions extends StatelessWidget {
  final JellyfinImageProvider imageProvider;
  final MediaItem item;
  final VoidCallback onTap;

  /// 收藏切换回调，参数为新的收藏状态
  final ValueChanged<bool>? onFavoriteToggle;

  const MediaItemCardWithActions({
    super.key,
    required this.imageProvider,
    required this.item,
    required this.onTap,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面图片区域
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  _buildCoverImage(context),
                  // 收藏按钮
                  if (onFavoriteToggle != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => onFavoriteToggle?.call(!(item.isFavorite ?? false)),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              item.isFavorite ?? false
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: item.isFavorite ?? false
                                  ? Colors.red
                                  : Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 播放进度指示器
                  if (item.playedPercentage != null &&
                      item.playedPercentage! > 0 &&
                      !(item.played ?? false))
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: item.playedPercentage! / 100,
                        backgroundColor: Colors.black26,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  // 已播放标记
                  if (item.played ?? false)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '已观看',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 信息区域
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 媒体项标题
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // 年份和评分
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 年份
                        if (item.productionYear != null)
                          Text(
                            '${item.productionYear}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                        // 评分
                        if (item.communityRating != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  item.communityRating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    if (item.hasCoverImage) {
      return JellyfinImage(
        imageProvider: imageProvider,
        itemId: item.id,
        imageTag: item.primaryImageTag,
        fillWidth: 200,
        fillHeight: 300,
        fit: BoxFit.cover,
        placeholder: _buildPlaceholder(context),
        errorWidget: _buildPlaceholder(context),
      );
    }

    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.typeIcon,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 8),
            Text(
              item.typeDisplayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
