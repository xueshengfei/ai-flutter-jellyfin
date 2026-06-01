import 'package:flutter/material.dart';

/// 快进/快退指示器
///
/// 居中显示 "<< 15s" / ">> 10s" 风格的指示文本 + 图标
class SeekIndicator extends StatelessWidget {
  /// 快进/快退秒数（正数=快进，负数=快退）
  final double deltaSeconds;

  const SeekIndicator({
    super.key,
    required this.deltaSeconds,
  });

  @override
  Widget build(BuildContext context) {
    if (deltaSeconds == 0) return const SizedBox.shrink();

    final isForward = deltaSeconds > 0;
    final seconds = deltaSeconds.abs().round();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isForward) ...[
              const Icon(Icons.fast_rewind, color: Colors.white, size: 28),
              const SizedBox(width: 8),
            ],
            Text(
              '${isForward ? ">>" : "<<"} ${seconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isForward) ...[
              const SizedBox(width: 8),
              const Icon(Icons.fast_forward, color: Colors.white, size: 28),
            ],
          ],
        ),
      ),
    );
  }
}
