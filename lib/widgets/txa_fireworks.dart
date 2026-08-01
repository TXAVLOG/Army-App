import 'dart:math';
import 'package:flutter/material.dart';

class TXAFireworks extends StatefulWidget {
  final bool isPlaying;

  const TXAFireworks({super.key, this.isPlaying = true});

  @override
  State<TXAFireworks> createState() => _TXAFireworksState();
}

class _TXAFireworksState extends State<TXAFireworks> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<FireworkRocket> _rockets = [];
  final List<FireworkParticle> _particles = [];
  final Random _random = Random();
  DateTime _lastSpawn = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(_updateAnimation);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateAnimation);
    _controller.dispose();
    super.dispose();
  }

  void _updateAnimation() {
    if (!widget.isPlaying) return;

    final now = DateTime.now();
    // Spawn một tên lửa hoặc hạt nổ cứ mỗi 350ms
    if (now.difference(_lastSpawn).inMilliseconds > 350) {
      _lastSpawn = now;
      _spawnRocketOrExplosion();
    }

    setState(() {
      // Cập nhật tọa độ tên lửa
      for (int i = _rockets.length - 1; i >= 0; i--) {
        final r = _rockets[i];
        r.update();
        if (r.isDead) {
          _explode(r.x, r.y, r.color);
          _rockets.removeAt(i);
        }
      }

      // Cập nhật tọa độ hạt pháo hoa nổ
      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.update();
        if (p.isDead) {
          _particles.removeAt(i);
        }
      }
    });
  }

  void _spawnRocketOrExplosion() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final w = size.width.clamp(180.0, 420.0);
    final h = size.height.clamp(180.0, 420.0);

    final colors = [
      Colors.redAccent,
      Colors.amberAccent,
      Colors.yellowAccent,
      Colors.orangeAccent,
      Colors.lightGreenAccent,
      Colors.pinkAccent,
      Colors.cyanAccent,
      const Color(0xFFFFD700), // Vàng kim Tết
    ];
    final color = colors[_random.nextInt(colors.length)];

    if (_random.nextBool()) {
      // Bắn tên lửa từ dưới mép khung ảnh lên
      _rockets.add(FireworkRocket(
        startX: _random.nextDouble() * w,
        startY: h,
        targetY: h * 0.15 + _random.nextDouble() * h * 0.45,
        color: color,
        speed: 4.0 + _random.nextDouble() * 4.0,
      ));
    } else {
      // Nổ trực tiếp ngẫu nhiên bên trong khung ảnh
      final ex = _random.nextDouble() * w;
      final ey = _random.nextDouble() * h;
      _explode(ex, ey, color);
    }
  }

  void _explode(double x, double y, Color color) {
    final count = 12 + _random.nextInt(12);
    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 1.0 + _random.nextDouble() * 3.5;
      _particles.add(FireworkParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: color,
        maxLife: 15 + _random.nextInt(15),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: CustomPaint(
          painter: FireworkPainter(_rockets, _particles),
          child: Container(),
        ),
      ),
    );
  }
}

class FireworkRocket {
  double x;
  double y;
  final double targetY;
  final Color color;
  final double speed;
  bool isDead = false;

  FireworkRocket({
    required this.startX,
    required this.startY,
    required this.targetY,
    required this.color,
    required this.speed,
  })  : x = startX,
        y = startY;

  final double startX;
  final double startY;

  void update() {
    y -= speed;
    if (y <= targetY) {
      isDead = true;
    }
  }
}

class FireworkParticle {
  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  int life;
  final int maxLife;

  FireworkParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.maxLife,
  }) : life = maxLife;

  bool get isDead => life <= 0;

  void update() {
    x += vx;
    y += vy;
    vy += 0.07; // Trọng lực nhẹ kéo hạt rơi xuống
    life--;
  }
}

class FireworkPainter extends CustomPainter {
  final List<FireworkRocket> rockets;
  final List<FireworkParticle> particles;

  FireworkPainter(this.rockets, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2.0;

    // Vẽ tên lửa đang bay lên
    for (var r in rockets) {
      paint.color = r.color;
      canvas.drawCircle(Offset(r.x, r.y), 2.5, paint);
    }

    // Vẽ các tia lửa nổ bung ra
    for (var p in particles) {
      final double progress = p.life / p.maxLife;
      paint.color = p.color.withValues(alpha: progress);
      canvas.drawCircle(Offset(p.x, p.y), 1.0 + 2.5 * progress, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
