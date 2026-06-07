import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:native_video_downloader/native_video_downloader.dart';

import '../models/download_task_view_model.dart';

/// 下载页面的状态控制器。
///
/// 这一层负责连接“Flutter 业务 UI”和“Android 原生下载插件”：
///
/// - 调用 [NativeVideoDownloader.startDownload] 发起下载命令。
/// - 监听 [NativeVideoDownloader.watchDownloadEvents] 接收原生进度。
/// - 把原生事件转换成页面可以直接显示的 [DownloadTaskViewModel]。
/// - 调用 [notifyListeners] 通知页面刷新。
class DownloadController extends ChangeNotifier {
  DownloadController({NativeVideoDownloader? downloader})
    : _downloader = downloader ?? NativeVideoDownloader();

  final NativeVideoDownloader _downloader;

  StreamSubscription<Map<Object?, Object?>>? _subscription;

  final List<DownloadTaskViewModel> _tasks = [];

  /// 原生事件只会回传 taskId、进度、速度等下载状态。
  ///
  /// 标题、媒体 id、封面图这些是 Flutter 主 App 在点击下载时知道的业务信息。
  /// 所以这里用一个 Map 暂存：taskId -> 媒体展示信息。
  final Map<String, _DownloadTaskMetadata> _metadataByTaskId = {};

  List<DownloadTaskViewModel> get tasks => List.unmodifiable(_tasks);

  /// 开始监听 Android 原生插件推回来的下载事件。
  ///
  /// 这个方法可以被重复调用；重复调用时会先取消旧订阅，再建立新订阅。
  void startListening() {
    _subscription?.cancel();

    _subscription = _downloader.watchDownloadEvents().listen((event) {
      final task = _taskFromNativeEvent(event);
      if (task == null) return;

      _upsertTask(task);
    });
  }

  void startMockProgress() {
    startListening();
  }

  /// 发起一个原生下载任务。
  ///
  /// [url] 是真实下载地址；主 App 会从 Jellyfin 媒体详情页拼出这个地址。
  /// [title]、[mediaItemId]、[imageItemId]、[imageTag] 是页面展示需要的业务信息。
  Future<void> startDownload(
    String url, {
    String title = 'Big Buck Bunny',
    String? mediaItemId,
    String? imageItemId,
    String? imageTag,
  }) async {
    final result = await _downloader.startDownload(url);
    if (result == null || result.isEmpty) return;

    final taskId = _taskIdFromStartResult(result);
    final metadata = _DownloadTaskMetadata(
      title: title,
      mediaItemId: mediaItemId,
      imageItemId: imageItemId ?? mediaItemId,
      imageTag: imageTag,
    );
    _metadataByTaskId[taskId] = metadata;

    _upsertTask(
      DownloadTaskViewModel(
        id: taskId,
        mediaItemId: mediaItemId,
        title: title,
        imageItemId: imageItemId ?? mediaItemId,
        imageTag: imageTag,
        state: DownloadTaskState.downloading,
        progress: 0,
        speedText: 'Starting',
        sizeText: '0 B',
      ),
    );
  }

  /// 删除页面中的任务。
  ///
  /// 当前会先通过 MethodChannel 把删除信号发给 Android 原生插件。
  Future<void> deleteTasks(Set<String> taskIds) async {
    if (taskIds.isEmpty) return;

    final acceptedTaskIds = <String>{};
    for (final taskId in taskIds) {
      final accepted = await _downloader.deleteDownload(taskId);
      if (accepted) {
        acceptedTaskIds.add(taskId);
      }
    }

    _metadataByTaskId.removeWhere(
      (taskId, _) => acceptedTaskIds.contains(taskId),
    );
    _tasks.removeWhere((task) => acceptedTaskIds.contains(task.id));
    notifyListeners();
  }

  Future<void> pauseTask(String taskId) async {
    final accepted = await _downloader.pauseDownload(taskId);
    if (!accepted) return;

    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) return;

    _tasks[index] = _tasks[index].copyWith(
      state: DownloadTaskState.paused,
      speedText: '已暂停',
    );
    notifyListeners();
  }

  DownloadTaskViewModel? _taskFromNativeEvent(Map<Object?, Object?> event) {
    final taskId = event['taskId']?.toString();
    if (taskId == null || taskId.isEmpty) return null;

    final metadata = _metadataByTaskId[taskId];
    final nativeState = event['state']?.toString() ?? 'downloading';
    final progressPercent = _asDouble(event['progress']);
    final downloadedBytes = _asInt(event['downloadedBytes']);
    final totalBytes = _asInt(event['totalBytes']);
    final speedBytesPerSecond = _asInt(event['speedBytesPerSecond']);

    return DownloadTaskViewModel(
      id: taskId,
      mediaItemId: metadata?.mediaItemId,
      title: metadata?.title ?? '下载视频',
      imageItemId: metadata?.imageItemId,
      imageTag: metadata?.imageTag,
      state: _stateFromNative(nativeState),
      progress: (progressPercent / 100).clamp(0.0, 1.0),
      speedText: _formatSpeed(speedBytesPerSecond),
      sizeText:
          '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}',
    );
  }

  void _upsertTask(DownloadTaskViewModel task) {
    final index = _tasks.indexWhere((item) => item.id == task.id);

    if (index == -1) {
      _tasks.add(task);
    } else {
      _tasks[index] = task;
    }

    notifyListeners();
  }

  String _taskIdFromStartResult(String result) {
    return result.split('|').first;
  }

  DownloadTaskState _stateFromNative(String state) {
    return switch (state) {
      'completed' => DownloadTaskState.completed,
      'failed' => DownloadTaskState.failed,
      'paused' => DownloadTaskState.paused,
      _ => DownloadTaskState.downloading,
    };
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    return '${_formatBytes(bytesPerSecond)}/s';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class _DownloadTaskMetadata {
  const _DownloadTaskMetadata({
    required this.title,
    this.mediaItemId,
    this.imageItemId,
    this.imageTag,
  });

  final String title;
  final String? mediaItemId;
  final String? imageItemId;
  final String? imageTag;
}
