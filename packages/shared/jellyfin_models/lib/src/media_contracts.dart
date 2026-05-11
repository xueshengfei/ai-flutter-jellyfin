/// 跨模块共享的数据获取回调类型定义
///
/// 这些 typedef 定义了 feature 模块与外部服务之间的契约。
/// feature 页面通过注入这些回调获取数据，不直接依赖具体的 service/client。
library;

import 'media_item_models.dart';

/// 获取媒体项详情回调
typedef MediaItemDetailFetcher = Future<MediaItem> Function(String itemId);

/// 获取媒体项列表回调
typedef MediaItemsFetcher = Future<MediaItemListResult> Function({
  required String parentId,
  bool recursive,
  int? limit,
});

/// 获取季列表回调
typedef SeasonsFetcher = Future<SeasonListResult> Function(String seriesId);
