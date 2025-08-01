import 'package:flutter/material.dart';

class LeafLoadingWidget extends StatelessWidget {
  final double size;
  final Color color;

  const LeafLoadingWidget({
    super.key,
    this.size = 20.0,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.eco,
      size: size,
      color: color,
    );
  }
}
