import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'native_video_downloader_method_channel.dart';

abstract class NativeVideoDownloaderPlatform extends PlatformInterface {
  /// Constructs a NativeVideoDownloaderPlatform.
  NativeVideoDownloaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeVideoDownloaderPlatform _instance =
      MethodChannelNativeVideoDownloader();

  /// The default instance of [NativeVideoDownloaderPlatform] to use.
  ///
  /// Defaults to [MethodChannelNativeVideoDownloader].
  static NativeVideoDownloaderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NativeVideoDownloaderPlatform] when
  /// they register themselves.
  static set instance(NativeVideoDownloaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> startDownload(String url) {
    throw UnimplementedError('startDownload() has not been implemented.');
  }

  /// 删除一个下载任务。
  ///
  /// 平台实现现在只需要先接住这个接口；真正删除文件和数据库记录后面补。
  Future<bool> deleteDownload(String taskId) {
    throw UnimplementedError('deleteDownload() has not been implemented.');
  }

  Stream<Map<Object?, Object?>> watchDownloadEvents() {
    throw UnimplementedError('watchDownloadEvents() has not been implemented.');
  }
}
