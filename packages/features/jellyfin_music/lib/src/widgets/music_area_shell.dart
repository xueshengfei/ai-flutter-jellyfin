import 'package:flutter/material.dart';
import '../services/audio_playback_port.dart';
import 'mini_player_bar.dart';

/// 音乐模块范围壳
///
/// 在音乐业务页面底部挂载迷你播放器。
/// 只在音乐 route page 中使用，非音乐页面不会感知到此组件。
class MusicAreaShell extends StatelessWidget {
  final Widget child;
  final AudioPlaybackPort audioPlaybackPort;
  final VoidCallback onOpenMusicPlayer;

  /// 是否显示迷你播放器（播放详情页传 false）
  final bool showMiniPlayer;

  const MusicAreaShell({
    super.key,
    required this.child,
    required this.audioPlaybackPort,
    required this.onOpenMusicPlayer,
    this.showMiniPlayer = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        if (showMiniPlayer)
          MiniPlayerBar(
            playbackPort: audioPlaybackPort,
            onOpenPlayer: onOpenMusicPlayer,
          ),
      ],
    );
  }
}
