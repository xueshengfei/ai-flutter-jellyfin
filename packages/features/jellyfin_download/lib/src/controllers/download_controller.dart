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
///
/// 注意：这里不直接写 OkHttp、不写文件 IO、不写 Android 逻辑。
/// 这些底层能力都留在 native_video_downloader 插件里。
class DownloadController extends ChangeNotifier {
  DownloadController({NativeVideoDownloader? downloader})
    : _downloader = downloader ?? NativeVideoDownloader();

  /// Android 原生下载插件的 Dart 门面。
  final NativeVideoDownloader _downloader;

  /// EventChannel 订阅句柄。
  ///
  /// controller 销毁时必须取消订阅，否则页面销毁后还可能收到事件。
  StreamSubscription<Map<Object?, Object?>>? _subscription;

  /// 内部可变任务列表。
  ///
  /// 页面不要直接修改这个列表，而是通过 [tasks] 读取只读快照。
  final List<DownloadTaskViewModel> _tasks = [];

  /// 对外暴露只读任务列表。
  List<DownloadTaskViewModel> get tasks => List.unmodifiable(_tasks);

  /// 开始监听 Android 原生插件推回来的下载事件。
  ///
  /// 这个方法通常在页面 initState 里调用一次。
  void startListening() {
    _subscription?.cancel();

    _subscription = _downloader.watchDownloadEvents().listen((event) {
      final task = _taskFromNativeEvent(event);
      if (task == null) return;

      _upsertTask(task);
    });
  }

  /// 兼容旧页面调用。
  ///
  /// 之前页面调用的是 startMockProgress()；现在真实进度来自原生插件。
  /// 后面改完页面后，可以把这个方法删掉。
  void startMockProgress() {
    startListening();
  }

  /// 发起一个原生下载任务。
  ///
  /// [url] 是要下载的 MP4 直链。当前阶段由 example 传测试 URL；
  /// 后面接入 Jellyfin 时，会从媒体详情页传入真实下载地址。
  Future<void> startDownload(String url) async {
    final result = await _downloader.startDownload(url);
    if (result == null || result.isEmpty) return;

    final taskId = _taskIdFromStartResult(result);

    _upsertTask(
      DownloadTaskViewModel(
        id: taskId,
        title: 'Big Buck Bunny',
        state: DownloadTaskState.downloading,
        progress: 0,
        speedText: 'Starting',
        sizeText: '0 B',
      ),
    );
  }

  /// 删除页面中的任务。
  ///
  /// 这一版会先通过 MethodChannel 把删除信号发给 Android 原生插件。
  /// 原生插件当前只接收信号；后面接 Room 和文件删除时，会在原生侧补真正删除逻辑。
  Future<void> deleteTasks(Set<String> taskIds) async {
    if (taskIds.isEmpty) return;

    final acceptedTaskIds = <String>{};
    for (final taskId in taskIds) {
      final accepted = await _downloader.deleteDownload(taskId);
      if (accepted) {
        acceptedTaskIds.add(taskId);
      }
    }

    _tasks.removeWhere((task) => acceptedTaskIds.contains(task.id));
    notifyListeners();
  }

  /// 把原生 EventChannel 事件转换成页面模型。
  DownloadTaskViewModel? _taskFromNativeEvent(Map<Object?, Object?> event) {
    final taskId = event['taskId']?.toString();
    if (taskId == null || taskId.isEmpty) return null;

    final nativeState = event['state']?.toString() ?? 'downloading';
    final progressPercent = _asDouble(event['progress']);
    final downloadedBytes = _asInt(event['downloadedBytes']);
    final totalBytes = _asInt(event['totalBytes']);
    final speedBytesPerSecond = _asInt(event['speedBytesPerSecond']);

    return DownloadTaskViewModel(
      id: taskId,
      title: 'Big Buck Bunny',
      state: _stateFromNative(nativeState),
      progress: (progressPercent / 100).clamp(0.0, 1.0),
      speedText: _formatSpeed(speedBytesPerSecond),
      sizeText:
          '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}',
    );
  }

  /// 插入或更新任务。
  ///
  /// EventChannel 会不断推同一个 taskId 的新状态：
  /// - 第一次收到：添加到列表。
  /// - 后续收到：替换旧任务。
  void _upsertTask(DownloadTaskViewModel task) {
    final index = _tasks.indexWhere((item) => item.id == task.id);

    if (index == -1) {
      _tasks.add(task);
    } else {
      _tasks[index] = task;
    }

    notifyListeners();
  }

  /// 插件当前为了调试会返回 "taskId|url"。
  ///
  /// UI 只需要 taskId，所以这里把左边切出来。
  String _taskIdFromStartResult(String result) {
    return result.split('|').first;
  }

  /// 把原生字符串状态映射成 UI 枚举。
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
