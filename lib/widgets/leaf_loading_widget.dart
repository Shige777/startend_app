import 'package:flutter/material.dart';

class LeafLoadingWidget extends StatefulWidget {
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
  State<LeafLoadingWidget> createState() => _LeafLoadingWidgetState();
}

class _LeafLoadingWidgetState extends State<LeafLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159, // 一回転
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _scale = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotation.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Icon(
                  Icons.eco,
                  size: widget.size,
                  color: widget.color,
                ),
              ),
            );
          },
        ),
        if (widget.showText) ...[
          const SizedBox(height: 8),
          Text(
            '読み込み中...',
            style: TextStyle(
              color: widget.color,
              fontSize: widget.size * 0.3,
            ),
          ),
        ],
      ],
    );
  }
}
