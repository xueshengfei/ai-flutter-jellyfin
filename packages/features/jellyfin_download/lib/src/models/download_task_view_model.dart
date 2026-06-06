/// 下载任务在 UI 上的状态。
///
/// 这里先只描述页面展示需要的几个状态。
/// 后面接入 Android 原生下载插件时，可以再按真实任务状态扩展。
enum DownloadTaskState {
  /// 正在下载，页面应展示进度和实时速度。
  downloading,

  /// 已暂停，页面可以展示继续按钮。
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
  });

  /// 任务唯一 ID，用来区分不同下载任务。
  final String id;

  /// 页面上显示的视频标题。
  final String title;

  /// 当前任务状态，用来决定任务放在哪个分组、显示什么操作。
  final DownloadTaskState state;

  /// 下载进度，取值范围约定为 0.0 到 1.0。
  final double progress;

  /// 页面直接展示的速度文本，例如 3.2 MB/s。
  final String speedText;

  /// 页面直接展示的大小文本，例如 420 MB / 1.0 GB。
  final String sizeText;

  /// 是否已经完成。
  ///
  /// 页面用这个 getter 把任务分成“下载中”和“已缓存”。
  bool get isCompleted => state == DownloadTaskState.completed;
}
