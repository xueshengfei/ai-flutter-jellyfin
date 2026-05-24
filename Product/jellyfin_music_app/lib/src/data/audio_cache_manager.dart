import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 音频 LRU 缓存管理器
///
/// 自动缓存播放过的音频文件到本地磁盘，最多保留 [maxCacheCount] 首。
/// 使用文件最后修改时间作为 LRU 淘汰依据。
class AudioCacheManager {
  /// 最大缓存数量
  static const int maxCacheCount = 200;

  Directory? _cacheDir;

  /// 获取缓存目录（懒初始化）
  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final tempDir = await getTemporaryDirectory();
    _cacheDir = Directory('${tempDir.path}/audio_cache');
    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }
    return _cacheDir!;
  }

  /// 查询缓存文件
  ///
  /// 如果命中缓存，更新文件最后修改时间（标记为最近使用）并返回文件。
  /// 未命中返回 null。
  Future<File?> getCacheFile(String itemId) async {
    final dir = await _ensureCacheDir();
    final file = File('${dir.path}/$itemId');
    if (file.existsSync()) {
      // LRU：更新访问时间
      await file.setLastModified(DateTime.now());
      return file;
    }
    return null;
  }

  /// 从网络下载并写入缓存
  ///
  /// 使用 [streamUrl] 下载音频数据并保存到磁盘。
  /// 下载完成后自动执行 LRU 淘汰。
  Future<void> putCache(String itemId, String streamUrl) async {
    try {
      final response = await http.get(Uri.parse(streamUrl));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final dir = await _ensureCacheDir();
        final file = File('${dir.path}/$itemId');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        await _evictIfNeeded();
      }
    } catch (_) {
      // 缓存失败不影响播放
    }
  }

  /// 后台缓存（不阻塞播放）
  ///
  /// 启动一个异步任务下载音频数据到本地缓存。
  void cacheInBackground(String itemId, String streamUrl) {
    // 不 await，后台执行
    putCache(itemId, streamUrl);
  }

  /// LRU 淘汰：当缓存文件数超过 [maxCacheCount] 时删除最旧的
  Future<void> _evictIfNeeded() async {
    final dir = await _ensureCacheDir();
    final files = dir.listSync().whereType<File>().toList();

    if (files.length <= maxCacheCount) return;

    // 按最后修改时间排序（最旧的在前）
    files.sort((a, b) =>
        a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    final toDelete = files.length - maxCacheCount;
    for (int i = 0; i < toDelete; i++) {
      try {
        await files[i].delete();
      } catch (_) {
        // 文件可能正在使用，跳过
      }
    }
  }

  /// 清除全部缓存
  Future<void> clearCache() async {
    final dir = _cacheDir;
    if (dir != null && dir.existsSync()) {
      await dir.delete(recursive: true);
      dir.createSync(recursive: true);
    }
  }

  /// 获取当前缓存数量
  Future<int> get cacheCount async {
    final dir = _cacheDir;
    if (dir == null || !dir.existsSync()) return 0;
    return dir.listSync().whereType<File>().length;
  }

  /// 获取缓存总大小（字节）
  Future<int> get cacheSize async {
    final dir = _cacheDir;
    if (dir == null || !dir.existsSync()) return 0;
    int totalSize = 0;
    for (final file in dir.listSync().whereType<File>()) {
      totalSize += await file.length();
    }
    return totalSize;
  }
}
