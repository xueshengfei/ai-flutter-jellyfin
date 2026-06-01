import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_gesture_controls/video_gesture_controls.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '手势控制 Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const VideoDemoPage(),
    );
  }
}

class VideoDemoPage extends StatefulWidget {
  const VideoDemoPage({super.key});

  @override
  State<VideoDemoPage> createState() => _VideoDemoPageState();
}

class _VideoDemoPageState extends State<VideoDemoPage> {
  late VideoPlayerController _videoController;
  late GestureOverlayController _gestureController;
  bool _isInitialized = false;
  bool _isFullScreen = false;

  // 示例视频 URL（Big Buck Bunny）
  static const _videoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  void initState() {
    super.initState();
    _gestureController = GestureOverlayController();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(_videoUrl));

    _videoController.initialize().then((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
        _videoController.play();
      }
    });

    _videoController.addListener(_onVideoUpdate);
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController.removeListener(_onVideoUpdate);
    _videoController.dispose();
    _gestureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? Center(
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoGestureOverlay(
                  controller: _gestureController,
                  isPlaying: _videoController.value.isPlaying,
                  position: _videoController.value.position,
                  duration: _videoController.value.duration,
                  isFullScreen: _isFullScreen,
                  callbacks: VideoGestureCallbacks(
                    onSeek: (delta) {
                      final newPos = _videoController.value.position + delta;
                      final clamped = Duration(
                        milliseconds: newPos.inMilliseconds.clamp(
                          0,
                          _videoController.value.duration.inMilliseconds,
                        ),
                      );
                      _videoController.seekTo(clamped);
                    },
                    onTogglePlayPause: () {
                      if (_videoController.value.isPlaying) {
                        _videoController.pause();
                      } else {
                        _videoController.play();
                      }
                    },
                    onSetSpeed: (speed) {
                      _videoController.setPlaybackSpeed(speed);
                    },
                    onBrightnessChanged: (value) {
                      // 模拟亮度，实际项目中可调用系统 API
                      debugPrint('亮度: ${(value * 100).round()}%');
                    },
                    onVolumeChanged: (value) {
                      _videoController.setVolume(value);
                    },
                    onSeekTo: (position) {
                      _videoController.seekTo(position);
                    },
                    onEnterFullScreen: () {
                      setState(() => _isFullScreen = true);
                    },
                    onExitFullScreen: () {
                      setState(() => _isFullScreen = false);
                    },
                  ),
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
    );
  }
}
