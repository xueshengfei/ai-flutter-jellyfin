// 视频手势控制集成测试
//
// 验证核心组件可以正常导入和使用

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:video_gesture_controls/video_gesture_controls.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('核心组件导入测试', (WidgetTester tester) async {
    // 验证核心类型可正常实例化
    final config = VideoGestureConfig();
    expect(config.gestureThreshold, 12.0);

    final callbacks = VideoGestureCallbacks();
    expect(callbacks.onSeek, isNull);

    final controller = GestureOverlayController(config: config);
    expect(controller.mode, GestureMode.idle);
    controller.dispose();
  });
}
