import 'package:flutter/material.dart';

/// 音量指示器
///
/// 显示扬声器图标 + 进度条，指示当前音量值
class VolumeIndicator extends StatelessWidget {
  final double volume; // 0.0 ~ 1.0

  const VolumeIndicator({
    super.key,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              volume <= 0
                  ? Icons.volume_off
                  : volume < 0.5
                      ? Icons.volume_down
                      : Icons.volume_up,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: volume,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(volume * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
