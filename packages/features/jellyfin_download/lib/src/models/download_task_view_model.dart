/// 下载任务在 UI 上的状态。
enum DownloadTaskState {
  /// 正在下载，页面应展示进度、实时速度和暂停按钮。
  downloading,

  /// 已暂停，当前阶段只表示原生下载已经停止。
  paused,

  /// 已完成，页面会把它归到“已缓存”区域。
  completed,

  /// 下载失败，后面可以展示重试或错误原因。
  failed,
}

/// 下载任务的页面展示模型。
///
/// 这个类不是 Android 原生下载任务本体。
/// 它只负责把“页面要显示的数据”收拢到一起，方便 Widget 使用。
class DownloadTaskViewModel {
  const DownloadTaskViewModel({
    required this.id,
    required this.title,
    required this.progress,
    required this.sizeText,
    required this.speedText,
    required this.state,
    this.mediaItemId,
    this.imageItemId,
    this.imageTag,
  });

  /// 任务唯一 ID，用来区分不同下载任务。
  final String id;

  /// Jellyfin 媒体 ID。
  ///
  /// 下载完成后，页面可以用它跳转到播放器页。
  final String? mediaItemId;

  /// 页面上显示的视频标题。
  final String title;

  /// 用来加载封面图的 Jellyfin item id。
  final String? imageItemId;

  /// 封面图 tag。
  final String? imageTag;

  /// 当前任务状态。
  final DownloadTaskState state;

  /// 下载进度，取值范围约定为 0.0 到 1.0。
  final double progress;

  /// 页面直接展示的速度文本，例如 3.2 MB/s。
  final String speedText;

  /// 页面直接展示的大小文本，例如 420 MB / 1.0 GB。
  final String sizeText;

  bool get isCompleted => state == DownloadTaskState.completed;

  bool get isDownloading => state == DownloadTaskState.downloading;

  bool get isPaused => state == DownloadTaskState.paused;

  DownloadTaskViewModel copyWith({
    DownloadTaskState? state,
    double? progress,
    String? speedText,
    String? sizeText,
  }) {
    return DownloadTaskViewModel(
      id: id,
      mediaItemId: mediaItemId,
      title: title,
      imageItemId: imageItemId,
      imageTag: imageTag,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      speedText: speedText ?? this.speedText,
      sizeText: sizeText ?? this.sizeText,
    );
  }
}
