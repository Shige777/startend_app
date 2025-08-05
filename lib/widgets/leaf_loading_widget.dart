import 'package:flutter/material.dart';

class LeafLoadingWidget extends StatelessWidget {
  final double size;
  final Color color;
  final bool showText;

  const LeafLoadingWidget({
    super.key,
    this.size = 20.0,
    this.color = Colors.black,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.eco,
          size: size,
          color: color,
        ),
        if (showText) ...[
          const SizedBox(height: 8),
          Text(
            '読み込み中...',
            style: TextStyle(
              color: color,
              fontSize: size * 0.3,
            ),
          ),
        ],
      ],
    );
  }
}
