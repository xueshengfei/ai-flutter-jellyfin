import 'package:flutter_test/flutter_test.dart';
import 'package:video_gesture_controls/video_gesture_controls.dart';
import 'package:video_gesture_controls/video_gesture_controls_platform_interface.dart';
import 'package:video_gesture_controls/video_gesture_controls_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVideoGestureControlsPlatform
    with MockPlatformInterfaceMixin
    implements VideoGestureControlsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VideoGestureControlsPlatform initialPlatform = VideoGestureControlsPlatform.instance;

  test('$MethodChannelVideoGestureControls is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVideoGestureControls>());
  });

  test('getPlatformVersion', () async {
    VideoGestureControls videoGestureControlsPlugin = VideoGestureControls();
    MockVideoGestureControlsPlatform fakePlatform = MockVideoGestureControlsPlatform();
    VideoGestureControlsPlatform.instance = fakePlatform;

    expect(await videoGestureControlsPlugin.getPlatformVersion(), '42');
  });
}
