import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_streak_service.dart';
import '../services/txa_language.dart';

enum TXAFriendTier {
  normal,     // Bạn bè bình thường (Viền xám phân 3 đốt)
  bestFriend, // Bạn thân (Viền vàng lục giác - Tổ kiến)
  lover,      // Người yêu (Viền đỏ + chấm đôi ant trail + râu anten)
}

/// Widget bọc Tooltip tự động cập nhật đếm ngược thời gian thực từng giây 1
class TXARealtimeStreakTooltip extends StatefulWidget {
  final String username;
  final int streakCount;
  final Widget child;

  const TXARealtimeStreakTooltip({
    super.key,
    required this.username,
    required this.streakCount,
    required this.child,
  });

  @override
  State<TXARealtimeStreakTooltip> createState() => _TXARealtimeStreakTooltipState();
}

class _TXARealtimeStreakTooltipState extends State<TXARealtimeStreakTooltip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Tự động nhảy từng giây 1 để đếm ngược real-time
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _buildTooltipMessage() {
    final txaLang = TXALanguage.instance;
    final streakService = TXAStreakService.instance;
    final hasPostedToday = streakService.hasPostedToday(widget.username);

    if (!hasPostedToday) {
      return streakService.getStreakCountdownText(widget.username);
    } else {
      if (widget.streakCount >= 3) {
        return txaLang.getText('streak_active_msg').replaceAll('%count%', '${widget.streakCount}');
      } else {
        return txaLang.getText('streak_below_3_msg').replaceAll('%count%', '${widget.streakCount}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _buildTooltipMessage(),
      waitDuration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF18181F), // Dark background matching app theme
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(45), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 12,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
      ),
      child: widget.child,
    );
  }
}

class TXAAvatarFrame extends StatelessWidget {
  final Widget child;
  final double radius;
  final TXAFriendTier tier;
  final String username;
  final bool showStreakBadge;
  final int? overrideStreak;
  final bool forceActive;

  const TXAAvatarFrame({
    super.key,
    required this.child,
    this.radius = 24.0,
    this.tier = TXAFriendTier.normal,
    required this.username,
    this.showStreakBadge = true,
    this.overrideStreak,
    this.forceActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TXAStreakService.instance,
      builder: (context, _) {
        final streakService = TXAStreakService.instance;
        final actualStreak = streakService.getStreak(username);
        final streakCount = overrideStreak ?? actualStreak;
        
        final isStreakActive = forceActive || streakService.shouldShowStreak(username) || (overrideStreak != null && overrideStreak! >= 3);
        
        // Lấy theme tương ứng với streakCount
        final streakTheme = streakService.getStreakThemeForCount(streakCount);

        final frameSize = radius * 2 + 10;

        return SizedBox(
          width: frameSize,
          height: frameSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Custom Painter viền họa tiết kiến
              CustomPaint(
                size: Size(frameSize, frameSize),
                painter: _AntFramePainter(
                  tier: tier,
                  isStreakActive: isStreakActive,
                  streakTheme: streakTheme,
                  streakCount: streakCount,
                ),
              ),

              // Avatar nội dung
              CircleAvatar(
                radius: radius,
                backgroundColor: Colors.transparent,
                child: ClipOval(child: child),
              ),

              // Râu anten nhỏ trang trí ở đỉnh dành cho Tier Lover (chỉ hiện khi chưa đạt mốc Nữ hoàng để tránh chồng chéo vương miện)
              if (tier == TXAFriendTier.lover && streakCount < 90)
                Positioned(
                  top: -4,
                  child: CustomPaint(
                    size: const Size(20, 10),
                    painter: _AntennaePainter(),
                  ),
                ),

              // Badge Streak 🔥 (Chỉ hiển thị khi Streak >= 3)
              if (showStreakBadge && isStreakActive)
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: TXARealtimeStreakTooltip(
                    username: username,
                    streakCount: streakCount,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: streakTheme.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TXATheme.background, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: streakTheme.badgeColor.withAlpha(120),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🔥',
                            style: TextStyle(fontSize: 10),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$streakCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// CustomPainter vẽ các kiểu khung mang hơi hướng kiến
class _AntFramePainter extends CustomPainter {
  final TXAFriendTier tier;
  final bool isStreakActive;
  final TXAStreakTheme streakTheme;
  final int streakCount;

  _AntFramePainter({
    required this.tier,
    required this.isStreakActive,
    required this.streakTheme,
    required this.streakCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final baseColor = isStreakActive
        ? streakTheme.borderColor
        : (tier == TXAFriendTier.bestFriend
            ? TXATheme.primaryYellow
            : (tier == TXAFriendTier.lover ? TXATheme.statusRed : TXATheme.textMuted));

    final paint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isStreakActive ? 2.8 : 2.0
      ..strokeCap = StrokeCap.round;

    if (isStreakActive) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      paint.shader = SweepGradient(
        colors: [...streakTheme.gradientColors, streakTheme.gradientColors.first],
      ).createShader(rect);
    }

    // 1. Khung đặc biệt cho các mốc Streak siêu cao
    if (isStreakActive && streakCount >= 90) {
      // Mốc 90+ Streak: Nữ hoàng (Vương miện + Viền đôi + các tia ngọc)
      // Viền tròn chính
      canvas.drawCircle(center, radius, paint);

      // Viền phụ đồng tâm nhỏ hơn chút tạo hiệu ứng viền đôi hoàng gia
      final innerPaint = Paint()
        ..color = baseColor.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      if (isStreakActive) {
        innerPaint.shader = paint.shader;
      }
      canvas.drawCircle(center, radius - 4, innerPaint);

      // Vẽ các tia ngọc / hạt hào quang tỏa sáng xung quanh (12 hạt nhỏ)
      final dotPaint = Paint()
        ..color = baseColor
        ..style = PaintingStyle.fill;
      for (int i = 0; i < 12; i++) {
        final angle = i * (2 * math.pi / 12);
        final dotX = center.dx + (radius + 4) * math.cos(angle);
        final dotY = center.dy + (radius + 4) * math.sin(angle);
        canvas.drawCircle(Offset(dotX, dotY), 1.5, dotPaint);
      }

      // Vẽ vương miện 👑 nhỏ ở đỉnh
      _drawQueenCrown(canvas, center, radius, baseColor);
      return;
    }

    if (isStreakActive && streakCount >= 60) {
      // Mốc 60+ Streak: Chiến sĩ (Viền bánh răng / hoa tuyết nhọn giáp sắt - 12 khía)
      final path = Path();
      const numPoints = 12;
      for (int i = 0; i <= numPoints; i++) {
        final angle = i * (2 * math.pi / numPoints) - math.pi / 2;
        // Xen kẽ bán kính lớn và nhỏ tạo đỉnh răng cưa sắc bén
        final r = (i % 2 == 0) ? radius + 2.5 : radius - 2.5;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
      return;
    }

    if (isStreakActive && streakCount >= 30) {
      // Mốc 30+ Streak: Tổ Kiến (Viền Bát giác kép - 8 cạnh phong cách hoàng gia)
      final path1 = Path();
      final path2 = Path();
      const numSides = 8;
      
      // Bát giác ngoài
      for (int i = 0; i < numSides; i++) {
        final angle = i * (2 * math.pi / numSides) - math.pi / 8;
        final x = center.dx + (radius + 1) * math.cos(angle);
        final y = center.dy + (radius + 1) * math.sin(angle);
        if (i == 0) {
          path1.moveTo(x, y);
        } else {
          path1.lineTo(x, y);
        }
      }
      path1.close();
      canvas.drawPath(path1, paint);

      // Bát giác trong mảnh hơn
      final innerPaint = Paint()
        ..color = baseColor.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      if (isStreakActive) {
        innerPaint.shader = paint.shader;
      }
      for (int i = 0; i < numSides; i++) {
        final angle = i * (2 * math.pi / numSides) - math.pi / 8;
        final x = center.dx + (radius - 3) * math.cos(angle);
        final y = center.dy + (radius - 3) * math.sin(angle);
        if (i == 0) {
          path2.moveTo(x, y);
        } else {
          path2.lineTo(x, y);
        }
      }
      path2.close();
      canvas.drawPath(path2, innerPaint);
      return;
    }

    // 2. Các khung cơ bản theo Tier nếu chưa đạt mốc cao
    switch (tier) {
      case TXAFriendTier.normal:
        // Viền phân 3 đốt (Segmented triple arc)
        const segmentAngle = (2 * math.pi - (3 * 0.3)) / 3;
        for (int i = 0; i < 3; i++) {
          final startAngle = i * (segmentAngle + 0.3) - math.pi / 2;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            startAngle,
            segmentAngle,
            false,
            paint,
          );
        }
        break;

      case TXAFriendTier.bestFriend:
        // Viền lục giác (Hexagon - Tổ kiến)
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * 60 - 30) * math.pi / 180;
          final x = center.dx + radius * math.cos(angle);
          final y = center.dy + radius * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;

      case TXAFriendTier.lover:
        // Viền liền tròn đỏ + họa tiết chấm đôi ant trail xung quanh
        canvas.drawCircle(center, radius, paint);

        // Vẽ các cặp chấm đôi xung quanh đường viền (Ant Trail)
        final dotPaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;

        for (int i = 0; i < 4; i++) {
          final angle = (i * 90 + 45) * math.pi / 180;
          final dotDist = radius + 3.5;
          final dx1 = center.dx + dotDist * math.cos(angle - 0.05);
          final dy1 = center.dy + dotDist * math.sin(angle - 0.05);
          final dx2 = center.dx + dotDist * math.cos(angle + 0.05);
          final dy2 = center.dy + dotDist * math.sin(angle + 0.05);

          canvas.drawCircle(Offset(dx1, dy1), 1.2, dotPaint);
          canvas.drawCircle(Offset(dx2, dy2), 1.2, dotPaint);
        }
        break;
    }
  }

  /// Vẽ vương miện mini hoàng gia ở đỉnh Avatar cho mốc Nữ hoàng 👑
  void _drawQueenCrown(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final startY = center.dy - radius - 1;
    final startX = center.dx;

    // Vẽ phác họa 3 đỉnh vương miện
    path.moveTo(startX - 10, startY + 5);
    path.lineTo(startX - 12, startY - 4); // Chóp trái
    path.lineTo(startX - 4, startY + 1);
    path.lineTo(startX, startY - 9); // Chóp giữa
    path.lineTo(startX + 4, startY + 1);
    path.lineTo(startX + 12, startY - 4); // Chóp phải
    path.lineTo(startX + 10, startY + 5);
    path.close();

    canvas.drawPath(path, paint);

    // Vẽ 3 viên ngọc sáng lấp lánh màu trắng sữa trên đỉnh chóp vương miện
    final gemPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(startX - 12, startY - 4.5), 1.6, gemPaint);
    canvas.drawCircle(Offset(startX, startY - 9.5), 1.9, gemPaint);
    canvas.drawCircle(Offset(startX + 12, startY - 4.5), 1.6, gemPaint);
  }

  @override
  bool shouldRepaint(covariant _AntFramePainter oldDelegate) {
    return oldDelegate.tier != tier ||
        oldDelegate.isStreakActive != isStreakActive ||
        oldDelegate.streakTheme != streakTheme ||
        oldDelegate.streakCount != streakCount;
  }
}

/// Painter vẽ 2 anten nhỏ ở đỉnh avatar
class _AntennaePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TXATheme.statusRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = TXATheme.statusRed
      ..style = PaintingStyle.fill;

    // Anten trái
    final leftPath = Path()
      ..moveTo(5, size.height)
      ..quadraticBezierTo(2, size.height / 2, 0, 0);
    canvas.drawPath(leftPath, paint);
    canvas.drawCircle(const Offset(0, 0), 1.8, dotPaint);

    // Anten phải
    final rightPath = Path()
      ..moveTo(size.width - 5, size.height)
      ..quadraticBezierTo(size.width - 2, size.height / 2, size.width, 0);
    canvas.drawPath(rightPath, paint);
    canvas.drawCircle(Offset(size.width, 0), 1.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
