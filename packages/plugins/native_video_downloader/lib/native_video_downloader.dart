import 'native_video_downloader_platform_interface.dart';

class NativeVideoDownloader {
  Future<String?> getPlatformVersion() {
    return NativeVideoDownloaderPlatform.instance.getPlatformVersion();
  }

  Future<String?> startDownload(String url) {
    return NativeVideoDownloaderPlatform.instance.startDownload(url);
  }

  Stream<Map<Object?, Object?>> watchDownloadEvents() {
    return NativeVideoDownloaderPlatform.instance.watchDownloadEvents();
  }
}
