import 'package:flutter/material.dart';

import '../controllers/download_controller.dart';
import '../models/download_task_view_model.dart';
import '../widgets/download_task_tile.dart';

/// 下载管理页面。
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({
    super.key,
    required this.controller,
    this.onOpenCompletedTask,
  });

  final DownloadController controller;

  /// 已缓存卡片点击回调。
  ///
  /// 下载模块不知道主 App 的播放器路由，所以把跳转交给外部注入。
  final void Function(BuildContext context, DownloadTaskViewModel task)?
  onOpenCompletedTask;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  static const _testVideoUrl =
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_5MB.mp4';

  bool _selectionMode = false;
  final Set<String> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();
    widget.controller.startListening();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
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
      animation: widget.controller,
      builder: (context, _) {
        final tasks = widget.controller.tasks;
        final downloading = tasks.where((task) => !task.isCompleted).toList();
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
                  onPressed: () =>
                      widget.controller.startDownload(_testVideoUrl),
                  label: const Text('测试下载'),
                ),
              ),
              const SizedBox(height: 24),
              const Text('下载中'),
              const SizedBox(height: 8),
              for (final task in downloading)
                DownloadTaskTile(
                  task: task,
                  selectionMode: _selectionMode,
                  selected: _selectedTaskIds.contains(task.id),
                  onSelectedChanged: (selected) {
                    _toggleTaskSelected(task.id, selected);
                  },
                  onPauseTask: () {
                    widget.controller.pauseTask(task.id);
                  },
                ),
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
                  onOpenCompletedTask: () {
                    widget.onOpenCompletedTask?.call(context, task);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
