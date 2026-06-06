import 'package:flutter/material.dart';

import '../models/download_task_view_model.dart';

/// 单个下载任务的列表项。
///
/// 这个 Widget 只负责展示一条任务，不负责下载逻辑，也不直接修改状态。
class DownloadTaskTile extends StatelessWidget {
  const DownloadTaskTile({
    super.key,
    required this.task,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
  });

  /// 页面传进来的任务展示数据。
  final DownloadTaskViewModel task;

  /// 是否进入“多选管理”模式。
  final bool selectionMode;

  /// 当前任务是否被选中。
  final bool selected;

  /// 用户勾选或取消勾选时回调给页面。
  final ValueChanged<bool>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // 管理模式下显示 checkbox；普通模式下不显示，列表会更干净。
      leading: selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (value) => onSelectedChanged?.call(value ?? false),
            )
          : null,

      // 管理模式下点击整行也可以切换选择，比只点 checkbox 更顺手。
      onTap: selectionMode ? () => onSelectedChanged?.call(!selected) : null,

      // 主标题显示视频名。
      title: Text(task.title),
      subtitle: Column(
        // 让进度条和文字都从左侧开始排列。
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LinearProgressIndicator 的 value 使用 0.0 到 1.0 的进度值。
          LinearProgressIndicator(value: task.progress),
          const SizedBox(height: 6),

          // 下载完成后只留标题和进度条；下载中才显示大小和实时速度。
          if (!task.isCompleted) Text('${task.sizeText}  ${task.speedText}'),
        ],
      ),
    );
  }
}
