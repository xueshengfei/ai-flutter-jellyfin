import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'video_gesture_controls_platform_interface.dart';

/// An implementation of [VideoGestureControlsPlatform] that uses method channels.
class MethodChannelVideoGestureControls extends VideoGestureControlsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('video_gesture_controls');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
