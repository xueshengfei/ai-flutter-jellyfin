import 'package:flutter/material.dart';
import 'package:jellyfin_models/jellyfin_models.dart';

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
  final void Function(BuildContext context, MediaItem item)? onNavigateToMediaItem;

  /// 列表项构建器（用于自定义列表布局）
  /// 传入 items 和 onTap 回调，返回完整的列表 Widget
  final Widget Function(List<MediaItem> items, ValueChanged<MediaItem> onTap)? listBuilder;

  const MediaItemsPage({
    super.key,
    required this.library,
    required this.fetchMediaItems,
    this.onNavigateToMediaItem,
    this.listBuilder,
  });

  @override
  State<MediaItemsPage> createState() => _MediaItemsPageState();
}

class _MediaItemsPageState extends State<MediaItemsPage> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMediaItems();
  }

  Future<void> _loadMediaItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 对于电视剧类型，只获取 Series 类型的媒体项
      final isTvShows = widget.library.type == MediaLibraryType.tvshows;

      final result = await widget.fetchMediaItems(
        parentId: widget.library.id,
        recursive: !isTvShows,
        limit: isTvShows ? null : 50,
      );

      if (mounted) {
        setState(() {
          _mediaItems = result.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '获取媒体项失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.library.name),
        actions: [
          if (!_isLoading && _errorMessage == null && _mediaItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Text(
                  '${_mediaItems.length} 项',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadMediaItems,
        tooltip: '刷新',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载媒体项...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadMediaItems,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_mediaItems.isEmpty) {
      return Center(
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
      );
    }

    // 如果提供了自定义列表构建器，使用它
    if (widget.listBuilder != null) {
      return RefreshIndicator(
        onRefresh: _loadMediaItems,
        child: widget.listBuilder!(
          _mediaItems,
          (item) => _navigateToDetail(item),
        ),
      );
    }

    // 默认：简单的网格布局
    return RefreshIndicator(
      onRefresh: _loadMediaItems,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.67,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _mediaItems.length,
        itemBuilder: (context, index) {
          final item = _mediaItems[index];
          return InkWell(
            onTap: () => _navigateToDetail(item),
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
                              child: Text(item.typeIcon, style: const TextStyle(fontSize: 40)),
                            ),
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Text(item.typeIcon, style: const TextStyle(fontSize: 40)),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToDetail(MediaItem item) {
    widget.onNavigateToMediaItem?.call(context, item);
  }
}
