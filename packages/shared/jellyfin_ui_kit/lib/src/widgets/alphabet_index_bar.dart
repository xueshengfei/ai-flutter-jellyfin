import 'package:flutter/material.dart';

/// 字母索引条组件
///
/// 显示在列表右侧的 A-Z + # 字母条，支持点击和拖拽快速定位。
/// 有数据的字母正常显示，无数据的字母灰显且不可点击。
class AlphabetIndexBar extends StatefulWidget {
  /// 所有要显示的字母（通常是 A-Z + #）
  final List<String> letters;

  /// 有数据的字母集合
  final Set<String> availableLetters;

  final String activeLetter;
  final ValueChanged<String> onLetterTap;

  const AlphabetIndexBar({
    super.key,
    required this.letters,
    required this.availableLetters,
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
            final isAvailable = widget.availableLetters.contains(letter);
            return Expanded(
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: _isDragging ? 12 : 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : isAvailable
                            ? Colors.grey.shade600
                            : Colors.grey.shade300,
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
    final letter = widget.letters[index];
    if (widget.availableLetters.contains(letter)) {
      widget.onLetterTap(letter);
    }
  }

  void _handleDrag(double dy) {
    final index = (dy / (context.size!.height / widget.letters.length))
        .floor()
        .clamp(0, widget.letters.length - 1);
    final letter = widget.letters[index];
    if (widget.availableLetters.contains(letter)) {
      widget.onLetterTap(letter);
    }
  }
}
