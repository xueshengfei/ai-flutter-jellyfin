import 'package:flutter/material.dart';

import '../controllers/download_controller.dart';
import '../widgets/download_task_tile.dart';

/// 下载管理页。
///
/// 页面只负责监听 controller，然后把任务分成“下载中”和“已缓存”两块展示。
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, required this.controller});

  /// 下载页面的状态控制器。
  ///
  /// 现在它只产生模拟进度；后面会改成监听原生插件返回的任务流。
  final DownloadController controller;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  void initState() {
    super.initState();

    // 页面第一次创建时启动模拟进度。
    // 这一步只是练习 UI 刷新，暂时不接 Android 原生下载。
    widget.controller.startMockProgress();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // AnimatedBuilder 会监听 ChangeNotifier。
      // controller 调用 notifyListeners() 后，这里的 builder 会重新执行。
      animation: widget.controller,
      builder: (context, _) {
        final tasks = widget.controller.tasks;

        // 未完成任务展示在“下载中”区域。
        final downloading = tasks.where((task) => !task.isCompleted).toList();

        // 已完成任务展示在“已缓存”区域。
        final completed = tasks.where((task) => task.isCompleted).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('下载管理')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('下载中'),
              const SizedBox(height: 8),

              // collection-for: 把每一个下载任务转换成一行 Widget。
              for (final task in downloading) DownloadTaskTile(task: task),

              // 横线分隔“下载中”和“已缓存”两个区域。
              const Divider(height: 32),

              const Text('已缓存'),
              const SizedBox(height: 8),
              for (final task in completed) DownloadTaskTile(task: task),
            ],
          ),
        );
      },
    );
  }
}
