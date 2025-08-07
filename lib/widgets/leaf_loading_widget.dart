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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3), // 2秒から3秒に変更してより滑らかに
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _controller.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 中央のアプリ画像（パルスアニメーション付き）
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Image.asset(
                      'assets/icons/startend_icon.png',
                      width: widget.size * 0.5,
                      height: widget.size * 0.5,
                    ),
                  );
                },
              ),
              // 外側の回転する円
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value * 2 * 3.14159,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      child: CustomPaint(
                        painter: CircleLoadingPainter(
                          color: widget.color,
                          progress: _rotationAnimation.value,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
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

class CircleLoadingPainter extends CustomPainter {
  final Color color;
  final double progress;

  CircleLoadingPainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;

    // 完全な円を描画（継ぎ目なし）
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(CircleLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
