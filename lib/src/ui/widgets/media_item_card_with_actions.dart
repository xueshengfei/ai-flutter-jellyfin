import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 带操作按钮的媒体项卡片组件
///
/// 显示媒体项封面、标题、年份等信息，并支持收藏按钮
class MediaItemCardWithActions extends StatelessWidget {
  final JellyfinClient client;
  final MediaItem item;
  final VoidCallback onTap;
  final ValueChanged<bool>? onFavoriteToggle;

  const MediaItemCardWithActions({
    super.key,
    required this.client,
    required this.item,
    required this.onTap,
    this.onFavoriteToggle,
  });

  /// 切换收藏状态
  Future<void> _toggleFavorite(BuildContext context) async {
    try {
      final newState = !(item.isFavorite ?? false);
      await client.user.markFavorite(
        itemId: item.id,
        isFavorite: newState,
      );

      // 通知父组件更新
      onFavoriteToggle?.call(newState);

      // 显示提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newState ? '已添加到收藏' : '已取消收藏'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _toggleFavorite(context),
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
                          color: Colors.green.withOpacity(0.9),
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
    // 如果有封面，使用JellyfinImageWithClient加载认证图片
    if (item.hasCoverImage) {
      return JellyfinImageWithClient(
        client: client,
        itemId: item.id,
        imageTag: item.primaryImageTag,
        fillWidth: 200,
        fillHeight: 300,
        fit: BoxFit.cover,
        placeholder: _buildPlaceholder(context),
        errorWidget: _buildPlaceholder(context),
      );
    }

    // 没有封面，显示占位图
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
