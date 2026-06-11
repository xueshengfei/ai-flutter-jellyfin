import 'package:flutter/material.dart';
import 'package:jellyfin_ui_kit/jellyfin_ui_kit.dart';

import '../models/download_task_view_model.dart';

/// 单个下载任务的列表项。
class DownloadTaskTile extends StatelessWidget {
  const DownloadTaskTile({
    super.key,
    required this.task,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
    this.onOpenCompletedTask,
    this.onPauseTask,
  });

  final DownloadTaskViewModel task;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onOpenCompletedTask;
  final VoidCallback? onPauseTask;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: selectionMode
            ? Checkbox(
                value: selected,
                onChanged: (value) => onSelectedChanged?.call(value ?? false),
              )
            : _TaskPoster(task: task),
        onTap: selectionMode
            ? () => onSelectedChanged?.call(!selected)
            : task.isCompleted
            ? onOpenCompletedTask
            : null,
        title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(value: task.progress),
            const SizedBox(height: 6),
            if (task.isCompleted)
              const Text('已缓存，点击播放')
            else if (task.isPaused)
              Text('${task.sizeText}  已暂停')
            else
              Text('${task.sizeText}  ${task.speedText}'),
          ],
        ),
        trailing: selectionMode ? null : _buildTrailingAction(),
      ),
    );
  }

  Widget? _buildTrailingAction() {
    if (task.isDownloading) {
      return IconButton(
        tooltip: '暂停下载',
        icon: const Icon(Icons.pause_circle_outline),
        onPressed: onPauseTask,
      );
    }

    if (task.isCompleted) {
      return const Icon(Icons.play_circle_outline);
    }

    if (task.isPaused) {
      return const Icon(Icons.pause_circle_filled);
    }

    return null;
  }
}

class _TaskPoster extends StatelessWidget {
  const _TaskPoster({required this.task});

  final DownloadTaskViewModel task;

  @override
  Widget build(BuildContext context) {
    final placeholder = _buildPlaceholder(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 48,
        height: 64,
        child:
            task.imageItemId == null || task.imageItemId!.isEmpty
            ? placeholder
            : JellyfinImage(
                itemId: task.imageItemId!,
                imageTag: task.imageTag,
                fillWidth: 96,
                fillHeight: 128,
                fit: BoxFit.cover,
                placeholder: placeholder,
                errorWidget: placeholder,
              ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_outlined, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
