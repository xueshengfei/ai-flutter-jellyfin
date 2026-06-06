import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_download/jellyfin_download.dart';

void main() {
  test('completed tasks are marked as cached items', () {
    const task = DownloadTaskViewModel(
      id: 'task-1',
      title: 'Movie A',
      progress: 1,
      sizeText: '1.0 GB',
      speedText: 'Done',
      state: DownloadTaskState.completed,
    );

    expect(task.isCompleted, isTrue);
  });
}
