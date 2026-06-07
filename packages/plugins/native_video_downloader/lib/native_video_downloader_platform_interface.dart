import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'native_video_downloader_method_channel.dart';

abstract class NativeVideoDownloaderPlatform extends PlatformInterface {
  NativeVideoDownloaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeVideoDownloaderPlatform _instance =
      MethodChannelNativeVideoDownloader();

  static NativeVideoDownloaderPlatform get instance => _instance;

  static set instance(NativeVideoDownloaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<String?> startDownload(String url) {
    throw UnimplementedError('startDownload() has not been implemented.');
  }

  Future<bool> pauseDownload(String taskId) {
    throw UnimplementedError('pauseDownload() has not been implemented.');
  }

  Future<bool> deleteDownload(String taskId) {
    throw UnimplementedError('deleteDownload() has not been implemented.');
  }

  Stream<Map<Object?, Object?>> watchDownloadEvents() {
    throw UnimplementedError('watchDownloadEvents() has not been implemented.');
  }
}
