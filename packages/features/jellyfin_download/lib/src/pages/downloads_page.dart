import 'package:flutter/material.dart';

import '../controllers/download_controller.dart';
import '../widgets/download_task_tile.dart';

/// 下载管理页面。
///
/// 这一层只负责“页面怎么展示”和“用户点按钮后调用哪个业务方法”。
/// 真正的下载逻辑、速度计算、文件写入，都在 Android 原生插件里完成。
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, required this.controller});

  /// 下载页面的状态控制器。
  ///
  /// controller 连接 Flutter UI 和 native_video_downloader 插件：
  /// - 页面调用 controller.startListening() 订阅原生进度。
  /// - 页面调用 controller.startDownload(url) 发起原生下载。
  /// - controller 收到原生 EventChannel 事件后通知页面刷新。
  final DownloadController controller;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  /// 临时测试用 MP4 直链。
  ///
  /// 这个地址有稳定的 Content-Length，适合先验证“Flutter 按钮 -> MethodChannel
  /// -> Android OkHttp 下载 -> EventChannel 进度回传 -> Flutter UI 刷新”这条链路。
  static const _testVideoUrl =
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_5MB.mp4';

  /// 是否处于多选管理模式。
  bool _selectionMode = false;

  /// 当前选中的任务 id 集合。
  final Set<String> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();

    // 页面创建后先订阅原生下载事件。
    // 注意：这里只是“开始听进度”，不会自动开始下载。
    widget.controller.startListening();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;

      // 退出管理模式时清空已选项，避免下次进入时还残留旧选择。
      if (!_selectionMode) {
        _selectedTaskIds.clear();
      }
    });
  }

  void _toggleTaskSelected(String taskId, bool selected) {
    setState(() {
      if (selected) {
        _selectedTaskIds.add(taskId);
      } else {
        _selectedTaskIds.remove(taskId);
      }
    });
  }

  Future<void> _deleteSelectedTasks() async {
    final taskIds = Set<String>.from(_selectedTaskIds);
    await widget.controller.deleteTasks(taskIds);
    if (!mounted) return;

    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
    });
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
          appBar: AppBar(
            title: Text(_selectionMode ? '选择视频' : '下载管理'),
            actions: [
              IconButton(
                tooltip: _selectionMode ? '退出管理' : '管理',
                icon: Icon(
                  _selectionMode ? Icons.close : Icons.settings_outlined,
                ),
                onPressed: _toggleSelectionMode,
              ),
            ],
          ),
          bottomNavigationBar: _selectionMode
              ? SafeArea(
                  child: BottomAppBar(
                    child: Row(
                      children: [
                        Text('已选 ${_selectedTaskIds.length} 个'),
                        const Spacer(),
                        TextButton.icon(
                          // 这一版先删除页面里的任务；后面会接到原生插件删除文件和 Room 记录。
                          onPressed: _selectedTaskIds.isEmpty
                              ? null
                              : _deleteSelectedTasks,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('删除'),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  // 用户点击按钮后，Flutter 通过 MethodChannel 通知 Android 开始下载。
                  // Android 下载过程中会通过 EventChannel 不断把进度、速度、状态推回来。
                  onPressed: () =>
                      widget.controller.startDownload(_testVideoUrl),
                  label: const Text('测试下载'),
                ),
              ),
              const SizedBox(height: 24),
              const Text('下载中'),
              const SizedBox(height: 8),

              // collection-for：把每一个下载任务转换成一行 Widget。
              for (final task in downloading)
                DownloadTaskTile(
                  task: task,
                  selectionMode: _selectionMode,
                  selected: _selectedTaskIds.contains(task.id),
                  onSelectedChanged: (selected) {
                    _toggleTaskSelected(task.id, selected);
                  },
                ),

              // 横线分隔“下载中”和“已缓存”两个区域。
              const Divider(height: 32),

              const Text('已缓存'),
              const SizedBox(height: 8),
              for (final task in completed)
                DownloadTaskTile(
                  task: task,
                  selectionMode: _selectionMode,
                  selected: _selectedTaskIds.contains(task.id),
                  onSelectedChanged: (selected) {
                    _toggleTaskSelected(task.id, selected);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
