import 'package:flutter/material.dart';
import 'package:jellyfin_service/jellyfin_service.dart';

/// API测试页面 - 用于调试
class TestApiPage extends StatefulWidget {
  final JellyfinClient client;

  const TestApiPage({
    super.key,
    required this.client,
  });

  @override
  State<TestApiPage> createState() => _TestApiPageState();
}

class _TestApiPageState extends State<TestApiPage> {
  String _log = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API测试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _runTests,
            tooltip: '运行测试',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                _log,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _runTests,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Future<void> _runTests() async {
    setState(() {
      _log = '🧪 开始API测试...\n\n';
      _isLoading = true;
    });

    try {
      // 测试1: 检查客户端状态
      _appendLog('✅ 客户端状态');
      _appendLog('   是否已认证: ${widget.client.isAuthenticated}');
      _appendLog('   用户ID: ${widget.client.userId}');
      _appendLog('   服务器URL: ${widget.client.configuration.serverUrl}\n');

      // 测试2: 获取媒体库列表
      _appendLog('📚 测试1: 获取媒体库列表');
      final libraries = await widget.client.mediaLibrary.getMediaLibraries();
      _appendLog('   ✅ 找到 ${libraries.libraries.length} 个媒体库\n');

      for (var i = 0; i < libraries.libraries.length && i < 5; i++) {
        final lib = libraries.libraries[i];
        _appendLog('   [$i] ${lib.name}');
        _appendLog('       ID: ${lib.id}');
        _appendLog('       类型: ${lib.type.name}');
        _appendLog('       数量: ${lib.itemCount}\n');
      }

      if (libraries.libraries.isEmpty) {
        _appendLog('⚠️ 没有找到任何媒体库！\n');
        setState(() => _isLoading = false);
        return;
      }

      // 测试3: 找到电影类型的媒体库
      final movieLibs = libraries.libraries
          .where((lib) => lib.type == MediaLibraryType.movies)
          .toList();

      _appendLog('🎬 测试2: 查找电影媒体库');
      _appendLog('   找到 ${movieLibs.length} 个电影媒体库\n');

      if (movieLibs.isEmpty) {
        _appendLog('⚠️ 没有找到电影类型的媒体库！\n');
        _appendLog('   可用的媒体库类型:');
        final types = libraries.libraries.map((lib) => lib.type.name).toSet();
        for (final type in types) {
          _appendLog('   - $type');
        }
        setState(() => _isLoading = false);
        return;
      }

      final movieLib = movieLibs.first;
      _appendLog('   使用媒体库: ${movieLib.name}');
      _appendLog('   ID: ${movieLib.id}\n');

      // 测试4: 创建MovieFilter
      _appendLog('🔧 测试3: 创建过滤器');
      final filter = MovieFilter.defaultFilter(
        parentId: movieLib.id,
        startIndex: 0,
        limit: 5,
      );
      _appendLog('   ✅ Filter created');
      _appendLog('   parentId: ${filter.parentId}');
      _appendLog('   startIndex: ${filter.startIndex}');
      _appendLog('   limit: ${filter.limit}\n');

      // 测试5: 调用getMovies
      _appendLog('📡 测试4: 调用 getMovies()');
      final movies = await widget.client.mediaLibrary.getMovies(filter);
      _appendLog('   ✅ API调用成功！');
      _appendLog('   返回数量: ${movies.items.length}');
      _appendLog('   总记录数: ${movies.totalCount}\n');

      if (movies.items.isNotEmpty) {
        _appendLog('🎉 成功！前5部电影:');
        for (var i = 0; i < movies.items.length && i < 5; i++) {
          final movie = movies.items[i];
          _appendLog('   [$i] ${movie.name} (${movie.productionYear ?? "N/A"})');
        }

        // 测试6: 导航到电影过滤页面
        _appendLog('\n🚀 测试5: 导航到电影过滤页面');
        if (mounted) {
          _appendLog('   ✅ 准备跳转...\n');
          setState(() => _isLoading = false);

          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MovieFilterPage(
                client: widget.client,
                libraryId: movieLib.id,
                libraryName: movieLib.name,
              ),
            ),
          );
        }
      } else {
        _appendLog('⚠️ 返回列表为空！\n');
        _appendLog('   可能原因:');
        _appendLog('   1. 媒体库中没有电影');
        _appendLog('   2. 权限不足');
        _appendLog('   3. 筛选条件过于严格');
      }

      _appendLog('\n✅ 所有测试完成!');
    } catch (e, stackTrace) {
      _appendLog('\n❌ 测试失败: $e');
      _appendLog('   堆栈跟踪: $stackTrace');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _appendLog(String message) {
    setState(() {
      _log += message + '\n';
    });
    print(message); // 同时打印到控制台
  }
}
