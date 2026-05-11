import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'video_gesture_controls_method_channel.dart';

abstract class VideoGestureControlsPlatform extends PlatformInterface {
  /// Constructs a VideoGestureControlsPlatform.
  VideoGestureControlsPlatform() : super(token: _token);

  static final Object _token = Object();

  static VideoGestureControlsPlatform _instance = MethodChannelVideoGestureControls();

  /// The default instance of [VideoGestureControlsPlatform] to use.
  ///
  /// Defaults to [MethodChannelVideoGestureControls].
  static VideoGestureControlsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VideoGestureControlsPlatform] when
  /// they register themselves.
  static set instance(VideoGestureControlsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
