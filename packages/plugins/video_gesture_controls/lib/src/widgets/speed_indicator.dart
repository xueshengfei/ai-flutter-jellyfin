import 'package:flutter/material.dart';

import '../models/gesture_config.dart';

/// 速度指示器
///
/// 长按时显示 "2.0x" 速度指示
class SpeedIndicator extends StatelessWidget {
  final double speed;

  const SpeedIndicator({
    super.key,
    this.speed = 2.0,
  });

  factory SpeedIndicator.fromConfig(VideoGestureConfig config) {
    return SpeedIndicator(speed: config.longPressSpeed);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fast_forward, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              '${speed.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
