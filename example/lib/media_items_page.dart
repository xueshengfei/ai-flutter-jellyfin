import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'media_item_card.dart';
import 'media_item_detail_page.dart';

/// 媒体项列表页面
///
/// 显示指定媒体库中的所有媒体项（如电影、电视剧、音乐等）
class MediaItemsPage extends StatefulWidget {
  final JellyfinClient client;
  final MediaLibrary library;

  const MediaItemsPage({
    super.key,
    required this.client,
    required this.library,
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
    print('📺 MediaItemsPage 初始化: ${widget.library.name}');
    _loadMediaItems();
  }

  Future<void> _loadMediaItems() async {
    print('🔄 _loadMediaItems 开始执行');
    print('   媒体库类型: ${widget.library.type}');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('📡 调用 client.mediaLibrary.getMediaItems()...');
      print('   媒体库ID: ${widget.library.id}');

      // 对于电视剧类型，只获取 Series 类型的媒体项
      final isTvShows = widget.library.type == MediaLibraryType.tvshows;

      final result = await widget.client.mediaLibrary.getMediaItems(
        parentId: widget.library.id,
        recursive: !isTvShows, // 电视剧不递归，只获取直接子项
        limit: isTvShows ? null : 50, // 电视剧不限制数量
      );

      print('✅ 媒体项获取成功!');
      print('   媒体项数量: ${result.items.length}');
      print('   媒体库类型: ${widget.library.type}');

      if (result.totalCount != null) {
        print('   总数: ${result.totalCount}');
      }

      // 对于电视剧类型，先打印所有项的类型，不过滤
      List<MediaItem> filteredItems = result.items;
      if (isTvShows) {
        print('   🔍 电视剧类型，打印所有项的类型（前10个）:');
        for (var i = 0; i < result.items.length && i < 10; i++) {
          final item = result.items[i];
          print('      [$i] "${item.name}"');
          print('          type: "${item.type}"');
          print('          typeDisplayName: ${item.typeDisplayName}');
          print('          id: ${item.id}');
        }

        // 暂时不过滤，显示所有项
        print('   ⚠️ 暂不过滤，显示所有项');
        filteredItems = result.items;

        // TODO: 确认数据类型后再决定是否过滤
        // filteredItems = result.items
        //     .where((item) => item.type.toLowerCase() == 'series')
        //     .toList();
        // print('   过滤后的剧集数量: ${filteredItems.length}');
      }

      for (var i = 0; i < filteredItems.length && i < 5; i++) {
        final item = filteredItems[i];
        print('   [$i] ${item.name} (${item.typeDisplayName})');
      }

      setState(() {
        _mediaItems = filteredItems;
        _isLoading = false;
      });

      print('✅ UI状态更新完成');
    } catch (e, stackTrace) {
      print('❌ 获取媒体项失败: $e');
      print('   堆栈跟踪: $stackTrace');
      setState(() {
        _errorMessage = '获取媒体项失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.library.name),
        actions: [
          // 显示数量
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
    print('🎨 _buildBody 被调用');
    print('   _isLoading: $_isLoading');
    print('   _errorMessage: $_errorMessage');
    print('   _mediaItems.length: ${_mediaItems.length}');

    if (_isLoading) {
      print('   显示加载指示器');
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
      print('   显示错误信息: $_errorMessage');
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
      print('   显示空状态');
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

    print('   显示媒体项列表 (${_mediaItems.length} 个)');

    // 显示媒体项网格
    return RefreshIndicator(
      onRefresh: () async {
        print('🔄 刷新媒体项...');
        await _loadMediaItems();
      },
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
          return MediaItemCard(
            client: widget.client,
            item: item,
            onTap: () {
              print('🖱️ 点击了媒体项: ${item.name}');
              print('   类型: ${item.type}');
              print('   ID: ${item.id}');

              // 统一跳转到通用详情页面
              // 详情页面会根据类型显示不同的内容
              print('   → 跳转到详情页面');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MediaItemDetailPage(
                    client: widget.client,
                    item: item,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
