import 'package:flutter/material.dart';

/// 底部控制栏
///
/// 包含：播放/暂停按钮 + 进度 Slider + 时间标签 + 全屏按钮
/// 顶部半透明渐变背景，3 秒无操作自动隐藏
class ControlBar extends StatelessWidget {
  /// 是否正在播放
  final bool isPlaying;

  /// 当前播放位置
  final Duration position;

  /// 视频总时长
  final Duration duration;

  /// 播放/暂停回调
  final VoidCallback? onPlayPause;

  /// 进度跳转回调
  final void Function(Duration position)? onSeekTo;

  /// 进度变化回调（拖动中）
  final void Function(Duration position)? onPositionChanged;

  /// 全屏回调
  final VoidCallback? onFullScreen;

  /// 是否全屏
  final bool isFullScreen;

  const ControlBar({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    this.onPlayPause,
    this.onSeekTo,
    this.onPositionChanged,
    this.onFullScreen,
    this.isFullScreen = false,
  });

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16,
          top: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            _ProgressBar(
              position: position,
              duration: duration,
              onSeekTo: onSeekTo,
              onChanged: onPositionChanged,
            ),
            const SizedBox(height: 8),
            // 按钮行
            Row(
              children: [
                // 播放/暂停
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: onPlayPause,
                ),
                // 时间标签
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // 全屏
                IconButton(
                  icon: Icon(
                    isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: onFullScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final void Function(Duration)? onSeekTo;
  final void Function(Duration)? onChanged;

  const _ProgressBar({
    required this.position,
    required this.duration,
    this.onSeekTo,
    this.onChanged,
  });

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0;

  double get _progress {
    if (_isDragging) return _dragValue;
    if (widget.duration.inMilliseconds <= 0) return 0;
    return widget.position.inMilliseconds / widget.duration.inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: Theme.of(context).primaryColor,
          inactiveTrackColor: Colors.white24,
          thumbColor: Theme.of(context).primaryColor,
        ),
        child: Slider(
          value: _progress.clamp(0.0, 1.0),
          onChanged: (value) {
            setState(() {
              _isDragging = true;
              _dragValue = value;
            });
            final pos = Duration(
              milliseconds: (value * widget.duration.inMilliseconds).round(),
            );
            widget.onChanged?.call(pos);
          },
          onChangeEnd: (value) {
            final pos = Duration(
              milliseconds: (value * widget.duration.inMilliseconds).round(),
            );
            widget.onSeekTo?.call(pos);
            setState(() {
              _isDragging = false;
            });
          },
        ),
      ),
    );
  }
}
