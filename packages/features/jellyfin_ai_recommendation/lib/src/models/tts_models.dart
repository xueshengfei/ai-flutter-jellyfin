import 'package:equatable/equatable.dart';

/// TTS 设置
class TtsSettings extends Equatable {
  final String voiceName;

  const TtsSettings({
    this.voiceName = 'demo_boy.wav',
  });

  TtsSettings copyWith({
    String? voiceName,
  }) =>
      TtsSettings(
        voiceName: voiceName ?? this.voiceName,
      );

  @override
  List<Object?> get props => [voiceName];
}

/// 单个分段的状态
enum TtsSegmentState {
  pending,
  synthesizing,
  ready,
  playing,
  played,
  error,
}

/// TTS 分段
class TtsSegment extends Equatable {
  final int index;
  final String text;
  final TtsSegmentState state;
  final String audioUrl;
  final String errorMessage;

  const TtsSegment({
    required this.index,
    required this.text,
    this.state = TtsSegmentState.pending,
    this.audioUrl = '',
    this.errorMessage = '',
  });

  TtsSegment copyWith({
    int? index,
    String? text,
    TtsSegmentState? state,
    String? audioUrl,
    String? errorMessage,
  }) =>
      TtsSegment(
        index: index ?? this.index,
        text: text ?? this.text,
        state: state ?? this.state,
        audioUrl: audioUrl ?? this.audioUrl,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [index, text, state, audioUrl, errorMessage];
}

/// 全局播放状态
enum TtsPlaybackState {
  idle,
  preparing,
  playing,
  paused,
  completed,
  error,
}
