import 'package:flutter/material.dart';

/// 播放/暂停闪烁图标
///
/// 双击时居中显示播放或暂停图标，带渐入渐出动画
class PlayPauseFlash extends StatefulWidget {
  /// 是否正在播放（显示暂停图标表示即将暂停，反之亦然）
  final bool isPlaying;

  const PlayPauseFlash({
    super.key,
    required this.isPlaying,
  });

  @override
  State<PlayPauseFlash> createState() => _PlayPauseFlashState();
}

class _PlayPauseFlashState extends State<PlayPauseFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }
}
