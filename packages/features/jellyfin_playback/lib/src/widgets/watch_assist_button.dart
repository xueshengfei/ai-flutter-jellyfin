import 'package:flutter/material.dart';

class WatchAssistButton extends StatelessWidget {
  final VoidCallback onPressed;

  const WatchAssistButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('AI 解读'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
