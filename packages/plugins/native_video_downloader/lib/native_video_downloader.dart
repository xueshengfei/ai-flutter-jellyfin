import 'native_video_downloader_platform_interface.dart';

/// 原生视频下载插件的 Dart 入口。
///
/// Flutter 业务模块只依赖这个类，不直接关心底层是 MethodChannel、
/// Android OkHttp，还是后面要加入的 Room 数据库。
class NativeVideoDownloader {
  Future<String?> getPlatformVersion() {
    return NativeVideoDownloaderPlatform.instance.getPlatformVersion();
  }

  /// 发起一个原生下载任务。
  ///
  /// 当前返回值暂时是 "taskId|url"，方便 Flutter 侧先拿到任务 id 做 UI 展示。
  Future<String?> startDownload(String url) {
    return NativeVideoDownloaderPlatform.instance.startDownload(url);
  }

  /// 删除一个下载任务。
  ///
  /// 这一版先只打通 Flutter -> Android 的删除命令。
  /// 真正删除本地文件、删除 Room 记录、取消下载线程会在后续步骤实现。
  Future<bool> deleteDownload(String taskId) {
    return NativeVideoDownloaderPlatform.instance.deleteDownload(taskId);
  }

  /// 监听原生侧推回来的下载事件。
  Stream<Map<Object?, Object?>> watchDownloadEvents() {
    return NativeVideoDownloaderPlatform.instance.watchDownloadEvents();
  }
}
