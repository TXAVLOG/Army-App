import 'dart:math';
import 'package:flutter/material.dart';

class TXASnowEffect extends StatefulWidget {
  final bool isPlaying;

  const TXASnowEffect({super.key, required this.isPlaying});

  @override
  State<TXASnowEffect> createState() => _TXASnowEffectState();
}

class _TXASnowEffectState extends State<TXASnowEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Snowflake> _snowflakes = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _controller.addListener(() {
      if (widget.isPlaying) {
        _updateSnowflakes();
      }
    });
  }

  @override
  void didUpdateWidget(TXASnowEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initSnowflakes(Size size) {
    if (_snowflakes.isNotEmpty) return;
    for (int i = 0; i < 80; i++) {
      _snowflakes.add(Snowflake(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        radius: _random.nextDouble() * 3 + 1.5,
        density: _random.nextDouble() * 1.5 + 0.8,
        drift: _random.nextDouble() * 2 - 1,
      ));
    }
  }

  void _updateSnowflakes() {
    for (var flake in _snowflakes) {
      flake.y += flake.density * 1.0; // Fall speed
      flake.x += sin(flake.y / 25) * 0.3 + flake.drift * 0.15; // Horizontal sway
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _initSnowflakes(size);

        return CustomPaint(
          size: size,
          painter: SnowPainter(_snowflakes, size),
        );
      },
    );
  }
}

class Snowflake {
  double x;
  double y;
  double radius;
  double density;
  double drift;

  Snowflake({
    required this.x,
    required this.y,
    required this.radius,
    required this.density,
    required this.drift,
  });
}

class SnowPainter extends CustomPainter {
  final List<Snowflake> snowflakes;
  final Size viewSize;

  SnowPainter(this.snowflakes, this.viewSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(180)
      ..style = PaintingStyle.fill;

    for (var flake in snowflakes) {
      double drawX = flake.x;
      if (drawX > size.width) {
        drawX = drawX % size.width;
      } else if (drawX < 0) {
        drawX = size.width + (drawX % size.width);
      }
      
      // Infinite vertical loop
      double drawY = flake.y % (size.height + 20) - 10;
      
      canvas.drawCircle(Offset(drawX, drawY), flake.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
