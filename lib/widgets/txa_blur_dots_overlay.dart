import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class TXABlurDotsOverlay extends StatefulWidget {
  final double blur;
  final Widget? child;

  const TXABlurDotsOverlay({
    super.key,
    this.blur = 15.0,
    this.child,
  });

  @override
  State<TXABlurDotsOverlay> createState() => _TXABlurDotsOverlayState();
}

class _TXABlurDotsOverlayState extends State<TXABlurDotsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Khởi tạo 35 dot chuyển động ngẫu nhiên
    for (int i = 0; i < 35; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speedX: (_random.nextDouble() - 0.5) * 0.005,
        speedY: (_random.nextDouble() - 0.5) * 0.005,
        radius: _random.nextDouble() * 3 + 1.5,
        opacity: _random.nextDouble() * 0.5 + 0.3,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.child != null) widget.child!,
          // Phủ lớp mờ BackdropFilter blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
            child: Container(
              color: Colors.black.withAlpha(100),
            ),
          ),
          // Vẽ các dot animation trắng chuyển động liên tục
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              for (final p in _particles) {
                p.x += p.speedX;
                p.y += p.speedY;
                if (p.x < 0) p.x = 1.0;
                if (p.x > 1) p.x = 0.0;
                if (p.y < 0) p.y = 1.0;
                if (p.y > 1) p.y = 0.0;
              }
              return CustomPaint(
                painter: _ParticlePainter(_particles),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  double speedX;
  double speedY;
  double radius;
  double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.radius,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = Colors.white.withAlpha((p.opacity * 255).round());
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
