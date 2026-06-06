import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_video_downloader_platform_interface.dart';

/// An implementation of [NativeVideoDownloaderPlatform] that uses method channels.
class MethodChannelNativeVideoDownloader extends NativeVideoDownloaderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('native_video_downloader');

  @visibleForTesting
  final eventChannel = const EventChannel('native_video_downloader/events');

  @override
  Stream<Map<Object?, Object?>> watchDownloadEvents() {
    return eventChannel.receiveBroadcastStream().map((event) {
      return event as Map<Object?, Object?>;
    });
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<String?> startDownload(String url) async {
    final result = await methodChannel.invokeMethod<String>('startDownload', {
      'url': url,
    });
    return result;
  }
}
