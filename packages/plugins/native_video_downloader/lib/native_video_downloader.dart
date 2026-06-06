import 'native_video_downloader_platform_interface.dart';

class NativeVideoDownloader {
  Future<String?> getPlatformVersion() {
    return NativeVideoDownloaderPlatform.instance.getPlatformVersion();
  }

  Future<String?> startDownload() {
    return NativeVideoDownloaderPlatform.instance.startDownload();
  }

  Stream<Map<Object?, Object?>> watchDownloadEvents() {
    return NativeVideoDownloaderPlatform.instance.watchDownloadEvents();
  }
}
