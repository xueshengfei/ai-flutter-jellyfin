import 'package:flutter/material.dart';

/// 字母索引条组件
///
/// 显示在列表右侧的 A-Z 字母条，支持点击和拖拽快速定位。
class AlphabetIndexBar extends StatefulWidget {
  final List<String> letters;
  final String activeLetter;
  final ValueChanged<String> onLetterTap;

  const AlphabetIndexBar({
    super.key,
    required this.letters,
    required this.activeLetter,
    required this.onLetterTap,
  });

  @override
  State<AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<AlphabetIndexBar> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (widget.letters.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onVerticalDragStart: (_) => setState(() => _isDragging = true),
      onVerticalDragEnd: (_) => setState(() => _isDragging = false),
      onVerticalDragUpdate: (details) => _handleDrag(details.localPosition.dy),
      onTapUp: (details) => _handleTap(details.localPosition.dy),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _isDragging ? 36 : 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: _isDragging ? 0.3 : 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: widget.letters.map((letter) {
            final isActive = letter == widget.activeLetter;
            return Expanded(
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: _isDragging ? 12 : 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _handleTap(double dy) {
    final index = (dy / (context.size!.height / widget.letters.length))
        .floor()
        .clamp(0, widget.letters.length - 1);
    widget.onLetterTap(widget.letters[index]);
  }

  void _handleDrag(double dy) {
    final index = (dy / (context.size!.height / widget.letters.length))
        .floor()
        .clamp(0, widget.letters.length - 1);
    widget.onLetterTap(widget.letters[index]);
  }
}
