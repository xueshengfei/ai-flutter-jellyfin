import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// 媒体项卡片组件
///
/// 显示单个媒体项的封面、标题、年份等信息
class MediaItemCard extends StatelessWidget {
  final JellyfinClient client;
  final MediaItem item;
  final VoidCallback onTap;

  const MediaItemCard({
    super.key,
    required this.client,
    required this.item,
    required this.onTap,
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
              child: _buildCoverImage(context),
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
