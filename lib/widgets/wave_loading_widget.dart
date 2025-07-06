import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveLoadingWidget extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const WaveLoadingWidget({
    super.key,
    this.size = 50.0,
    this.color = Colors.blue,
    this.strokeWidth = 3.0,
  });

  @override
  State<WaveLoadingWidget> createState() => _WaveLoadingWidgetState();
}

class _WaveLoadingWidgetState extends State<WaveLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _rotationController;
  late Animation<double> _waveAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // 波のアニメーション
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // 回転のアニメーション
    _rotationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    // アニメーションを開始
    _waveController.repeat();
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_waveAnimation, _rotationAnimation]),
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            child: CustomPaint(
              painter: WavePainter(
                waveAnimation: _waveAnimation.value,
                color: widget.color,
                strokeWidth: widget.strokeWidth,
              ),
              size: Size(widget.size, widget.size),
            ),
          );
        },
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double waveAnimation;
  final Color color;
  final double strokeWidth;

  WavePainter({
    required this.waveAnimation,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // 複数の波を描画
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final waveOffset = (waveAnimation + i * math.pi / 3) % (2 * math.pi);

      // 波の形状を計算
      for (double angle = 0; angle < 2 * math.pi; angle += 0.1) {
        final waveAmplitude = math.sin(angle * 3 + waveOffset) * 5;
        final currentRadius = radius + waveAmplitude;

        final x = center.dx + currentRadius * math.cos(angle);
        final y = center.dy + currentRadius * math.sin(angle);

        if (angle == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      path.close();

      // 透明度を調整
      paint.color = color.withValues(alpha: 0.7 - i * 0.2);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
