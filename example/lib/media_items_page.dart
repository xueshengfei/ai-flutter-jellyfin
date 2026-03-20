import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';
import 'media_item_card.dart';

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('📡 调用 client.mediaLibrary.getMediaItems()...');
      print('   媒体库ID: ${widget.library.id}');

      final result = await widget.client.mediaLibrary.getMediaItems(
        parentId: widget.library.id,
        recursive: true,
        limit: 50,
      );

      print('✅ 媒体项获取成功!');
      print('   媒体项数量: ${result.items.length}');

      if (result.totalCount != null) {
        print('   总数: ${result.totalCount}');
      }

      for (var i = 0; i < result.items.length && i < 5; i++) {
        final item = result.items[i];
        print('   [$i] ${item.name} (${item.typeDisplayName})');
      }

      setState(() {
        _mediaItems = result.items;
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
          return MediaItemCard(
            client: widget.client,
            item: _mediaItems[index],
            onTap: () {
              print('🖱️ 点击了媒体项: ${_mediaItems[index].name}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('点击了: ${_mediaItems[index].name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
