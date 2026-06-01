import 'package:flutter/material.dart';

/// 亮度指示器
///
/// 显示太阳图标 + 进度条，指示当前亮度值
class BrightnessIndicator extends StatelessWidget {
  final double brightness; // 0.0 ~ 1.0

  const BrightnessIndicator({
    super.key,
    required this.brightness,
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
              brightness < 0.3
                  ? Icons.brightness_low
                  : brightness < 0.7
                      ? Icons.brightness_medium
                      : Icons.brightness_high,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: brightness,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(brightness * 100).round()}%',
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
