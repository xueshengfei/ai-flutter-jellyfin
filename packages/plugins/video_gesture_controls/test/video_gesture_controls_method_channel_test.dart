import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_gesture_controls/video_gesture_controls_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelVideoGestureControls platform = MethodChannelVideoGestureControls();
  const MethodChannel channel = MethodChannel('video_gesture_controls');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
