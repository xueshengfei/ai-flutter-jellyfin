import 'package:flutter/material.dart';

import '../models/tts_models.dart';

/// TTS 播放/暂停按钮
class TtsControlButton extends StatelessWidget {
  final TtsPlaybackState state;
  final VoidCallback? onPressed;

  const TtsControlButton({super.key, required this.state, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IconButton(
      icon: _icon,
      iconSize: 20,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: _tooltip,
      color: color,
      onPressed: onPressed,
    );
  }

  Widget get _icon {
    switch (state) {
      case TtsPlaybackState.idle:
      case TtsPlaybackState.completed:
        return const Icon(Icons.play_circle_outline);
      case TtsPlaybackState.preparing:
        return const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
      case TtsPlaybackState.playing:
        return const Icon(Icons.pause_circle_outline);
      case TtsPlaybackState.paused:
        return const Icon(Icons.play_circle_filled);
      case TtsPlaybackState.error:
        return const Icon(Icons.warning_amber_outlined);
    }
  }

  String get _tooltip {
    switch (state) {
      case TtsPlaybackState.idle:
      case TtsPlaybackState.completed:
        return '朗读';
      case TtsPlaybackState.preparing:
        return '合成中...';
      case TtsPlaybackState.playing:
        return '暂停';
      case TtsPlaybackState.paused:
        return '继续朗读';
      case TtsPlaybackState.error:
        return '语音合成失败';
    }
  }
}
