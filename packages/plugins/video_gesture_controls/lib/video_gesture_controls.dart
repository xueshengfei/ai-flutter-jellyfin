
import 'video_gesture_controls_platform_interface.dart';

class VideoGestureControls {
  Future<String?> getPlatformVersion() {
    return VideoGestureControlsPlatform.instance.getPlatformVersion();
  }
}
