import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

// MediaItemsFetcher 已收敛到 jellyfin_models/media_contracts.dart

/// 媒体项列表页面
///
/// 显示指定媒体库中的所有媒体项
/// 通过回调解耦，不直接依赖 JellyfinClient 和 ViewModeManager
class MediaItemsPage extends StatefulWidget {
  /// 媒体库信息
  final MediaLibrary library;

  /// 获取媒体项回调
  final MediaItemsFetcher fetchMediaItems;

  /// 跳转到媒体详情页
  final void Function(BuildContext context, MediaItem item)?
      onNavigateToMediaItem;

  /// 列表项构建器（用于自定义列表布局）
  /// 传入 items 和 onTap 回调，返回完整的列表 Widget
  final Widget Function(List<MediaItem> items, ValueChanged<MediaItem> onTap)?
      listBuilder;

  /// AppBar 右侧额外操作按钮（如 ViewModeSelector）
  final List<Widget>? appBarActions;

  const MediaItemsPage({
    super.key,
    required this.library,
    required this.fetchMediaItems,
    this.onNavigateToMediaItem,
    this.listBuilder,
    this.appBarActions,
  });

  @override
  State<MediaItemsPage> createState() => _MediaItemsPageState();
}

class _MediaItemsPageState extends State<MediaItemsPage> {
  /// GlobalKey 用于外部调用 PaginatedListState.refresh()
  final _paginatedListKey = GlobalKey<PaginatedListState<MediaItem>>();

  /// 对于电视剧类型，只获取 Series 类型的媒体项
  bool get _isTvShows => widget.library.type == MediaLibraryType.tvshows;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.library.name),
        actions: [
          ...?widget.appBarActions,
          IconButton(
            onPressed: () => _paginatedListKey.currentState?.refresh(),
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PaginatedList<MediaItem>(
        key: _paginatedListKey,
        refreshKey: widget.library.id,
        pageSize: 100,
        padding: const EdgeInsets.all(16),
        fetcher: ({required startIndex, required limit}) async {
          final result = await widget.fetchMediaItems(
            parentId: widget.library.id,
            recursive: !_isTvShows,
            startIndex: startIndex,
            limit: limit,
          );
          return PagedResult(
            items: result.items,
            totalCount: result.totalCount ?? result.items.length,
          );
        },
        loadingBuilder: (context) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载媒体项...'),
            ],
          ),
        ),
        errorBuilder: (context, error, retry) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '获取媒体项失败: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: retry, child: const Text('重试')),
            ],
          ),
        ),
        emptyBuilder: (context) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.library.type.icon,
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.library.name} 中没有找到媒体项',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        contentBuilder: (context, page) {
          if (widget.listBuilder != null) {
            return widget.listBuilder!(
              page.items,
              (item) => widget.onNavigateToMediaItem?.call(context, item),
            );
          }

          return GridView.builder(
            padding: page.padding,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.67,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: page.items.length,
            itemBuilder: (context, index) =>
                page.itemBuilder(context, page.items[index], index),
          );
        },
        itemBuilder: (context, item, index) {
          // 如果提供了自定义列表构建器，这里只处理默认情况
          return _buildDefaultItem(context, item);
        },
      ),
    );
  }

  Widget _buildDefaultItem(BuildContext context, MediaItem item) {
    return InkWell(
      onTap: () => widget.onNavigateToMediaItem?.call(context, item),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: item.hasCoverImage
                  ? Image.network(
                      item.getCoverImageUrl()!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(item.typeIcon,
                            style: const TextStyle(fontSize: 40)),
                      ),
                    )
                  : Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Text(item.typeIcon,
                            style: const TextStyle(fontSize: 40)),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                item.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
