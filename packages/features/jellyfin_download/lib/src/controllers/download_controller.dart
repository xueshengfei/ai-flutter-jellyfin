import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/download_task_view_model.dart';

/// 下载页面的状态控制器。
///
/// 现在这个类只负责生成模拟进度，目的是先练习 Flutter UI 状态刷新。
/// 后面接入原生插件时，这里会改成监听 EventChannel 返回的下载状态。
class DownloadController extends ChangeNotifier {
  DownloadController();

  /// 内部可变任务列表。
  ///
  /// 下划线开头表示这个字段只允许当前文件内部访问。
  final List<DownloadTaskViewModel> _tasks = [
    const DownloadTaskViewModel(
      id: '1',
      title: '电影 A',
      state: DownloadTaskState.downloading,
      progress: 0.1,
      speedText: '0 MB/s',
      sizeText: '100 MB / 1.0 GB',
    ),
  ];

  /// 用来每秒推进一次模拟下载进度。
  Timer? _timer;

  /// 对外暴露只读任务列表。
  ///
  /// 外部页面可以读取 tasks，但不能直接修改 _tasks。
  List<DownloadTaskViewModel> get tasks => List.unmodifiable(_tasks);

  /// 启动模拟下载进度。
  ///
  /// 每秒把第一个任务的进度加一点，然后调用 notifyListeners()
  /// 通知 DownloadsPage 重新 build。
  void startMockProgress() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final oldTask = _tasks.first;

      // clamp 把进度限制在 0.0 到 1.0 之间，避免超过 100%。
      final nextProgress = (oldTask.progress + 0.08).clamp(0.0, 1.0);

      // ViewModel 是不可变对象，所以更新任务时创建一个新对象替换旧对象。
      _tasks[0] = DownloadTaskViewModel(
        id: oldTask.id,
        title: oldTask.title,
        state: nextProgress >= 1
            ? DownloadTaskState.completed
            : DownloadTaskState.downloading,
        progress: nextProgress,
        speedText: nextProgress >= 1 ? '已完成' : '3.2 MB/s',
        sizeText: nextProgress >= 1 ? '1.0 GB' : '下载中',
      );

      // 通知所有监听者：数据变了，UI 可以刷新了。
      notifyListeners();

      if (nextProgress >= 1) {
        // 模拟下载完成后停止定时器。
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    // controller 销毁时取消定时器，避免后台继续跑。
    _timer?.cancel();
    super.dispose();
  }
}
