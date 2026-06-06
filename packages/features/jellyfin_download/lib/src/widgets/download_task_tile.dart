import 'package:flutter/material.dart';

import '../models/download_task_view_model.dart';

/// 单个下载任务的列表项。
///
/// 这个 Widget 只负责展示一条任务，不负责下载逻辑，也不直接修改状态。
class DownloadTaskTile extends StatelessWidget {
  const DownloadTaskTile({super.key, required this.task});

  /// 页面传进来的任务展示数据。
  final DownloadTaskViewModel task;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // 主标题显示视频名。
      title: Text(task.title),
      subtitle: Column(
        // 让进度条和文字都从左侧开始排列。
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LinearProgressIndicator 的 value 使用 0.0 到 1.0 的进度值。
          LinearProgressIndicator(value: task.progress),
          const SizedBox(height: 6),
          // 这里先直接展示已经格式化好的大小和速度文本。
          Text('${task.sizeText}  ${task.speedText}'),
        ],
      ),
    );
  }
}
