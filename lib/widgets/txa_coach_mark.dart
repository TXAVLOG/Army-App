import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';

enum ArmiExpression {
  happy,     // Armi vui 😄
  surprised, // Armi ngạc nhiên 😲
  pointing,  // Armi chỉ trỏ 👉
  waving,    // Armi vẫy tay 👋
}

class TXACoachMarkStep {
  final GlobalKey targetKey;
  final String dialogueText;
  final ArmiExpression expression;

  const TXACoachMarkStep({
    required this.targetKey,
    required this.dialogueText,
    this.expression = ArmiExpression.happy,
  });
}

class TXACoachMark extends StatefulWidget {
  final List<TXACoachMarkStep> steps;
  final VoidCallback onFinished;

  const TXACoachMark({
    super.key,
    required this.steps,
    required this.onFinished,
  });

  static OverlayEntry? _currentEntry;

  /// Phương thức tĩnh khởi chạy CoachMark Overlay tiện lợi toàn app
  static void show({
    required BuildContext context,
    required List<TXACoachMarkStep> steps,
    required VoidCallback onFinished,
  }) {
    _currentEntry?.remove();
    _currentEntry = OverlayEntry(
      builder: (ctx) => TXACoachMark(
        steps: steps,
        onFinished: () {
          _currentEntry?.remove();
          _currentEntry = null;
          onFinished();
        },
      ),
    );
    Overlay.of(context).insert(_currentEntry!);
  }

  @override
  State<TXACoachMark> createState() => _TXACoachMarkState();
}

class _TXACoachMarkState extends State<TXACoachMark> with SingleTickerProviderStateMixin {
  int _currentStepIdx = 0;
  String _displayedText = "";
  Timer? _typewriterTimer;
  bool _isTypingComplete = false;

  late AnimationController _glowAnimCtrl;
  Offset _mascotPosition = const Offset(-100, 300); // Vị trí xuất phát ngoài màn hình
  Rect _targetRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _glowAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStep(_currentStepIdx);
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _glowAnimCtrl.dispose();
    super.dispose();
  }

  void _startStep(int index) {
    if (index >= widget.steps.length) {
      _finishTour();
      return;
    }

    final step = widget.steps[index];
    final RenderBox? renderBox = step.targetKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox != null && renderBox.attached) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final targetRect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

      setState(() {
        _targetRect = targetRect;
        // Đặt vị trí Armi đứng sát dưới/cạnh đốm sáng
        _mascotPosition = Offset(
          (position.dx + size.width / 2 - 30).clamp(16.0, MediaQuery.of(context).size.width - 270.0),
          (position.dy + size.height + 14).clamp(100.0, MediaQuery.of(context).size.height - 220.0),
        );
      });
    }

    _startTypewriter(step.dialogueText);
  }

  /// Sửa lỗi UTF-16 crash bằng cách sử dụng Grapheme Characters thay vì codeUnit index
  void _startTypewriter(String text) {
    _typewriterTimer?.cancel();
    setState(() {
      _displayedText = "";
      _isTypingComplete = false;
    });

    final characters = text.characters;
    int count = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (count < characters.length) {
        count++;
        if (mounted) {
          setState(() {
            _displayedText = characters.take(count).toString();
          });
        }
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isTypingComplete = true;
          });
        }
      }
    });
  }

  void _nextStep() {
    if (!_isTypingComplete) {
      // Nhấp click sẽ hiển thị ngay toàn bộ câu thoại
      _typewriterTimer?.cancel();
      setState(() {
        _displayedText = widget.steps[_currentStepIdx].dialogueText;
        _isTypingComplete = true;
      });
      return;
    }

    setState(() {
      _currentStepIdx++;
    });

    if (_currentStepIdx < widget.steps.length) {
      _startStep(_currentStepIdx);
    } else {
      _finishTour();
    }
  }

  void _finishTour() {
    // Armi vẫy tay chào và đi khỏi màn hình
    setState(() {
      _mascotPosition = Offset(MediaQuery.of(context).size.width + 100, _mascotPosition.dy);
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onFinished();
      }
    });
  }

  String _getMascotAssetPath(ArmiExpression expr) {
    switch (expr) {
      case ArmiExpression.happy:
        return 'assets/armi_happy.png';
      case ArmiExpression.surprised:
        return 'assets/armi_surprised.png';
      case ArmiExpression.pointing:
        return 'assets/armi_pointing.png';
      case ArmiExpression.waving:
        return 'assets/armi_waving.png';
    }
  }

  String _getExpressionEmoji(ArmiExpression expr) {
    switch (expr) {
      case ArmiExpression.happy:
        return '😄';
      case ArmiExpression.surprised:
        return '😲';
      case ArmiExpression.pointing:
        return '👉';
      case ArmiExpression.waving:
        return '👋';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStepIdx >= widget.steps.length) return const SizedBox.shrink();

    final step = widget.steps[_currentStepIdx];
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Overlay đục lỗ Spotlight làm nổi bật Target Element & Khoanh vùng đốm sáng
          GestureDetector(
            onTap: _nextStep,
            child: AnimatedBuilder(
              animation: _glowAnimCtrl,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _SpotlightHolePainter(
                    targetRect: _targetRect,
                    glowProgress: _glowAnimCtrl.value,
                  ),
                );
              },
            ),
          ),

          // 2. Linh vật Armi di chuyển mượt mà (AnimatedPositioned)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutBack,
            left: _mascotPosition.dx,
            top: _mascotPosition.dy,
            child: GestureDetector(
              onTap: _nextStep,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bong bóng thoại kiểu Comic Dark Premium (Comic Speech Bubble)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B26),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: TXATheme.primaryYellow, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: TXATheme.primaryYellow.withAlpha(90),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withAlpha(150),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Armi 🐜',
                              style: TextStyle(
                                color: TXATheme.primaryYellow,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(_getExpressionEmoji(step.expression), style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _displayedText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_isTypingComplete)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Chạm để tiếp tục ▸',
                                style: TextStyle(color: TXATheme.primaryYellow, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Mũi tên đuôi bong bóng thoại chỉ xuống linh vật Armi (Speech Bubble Tail)
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: CustomPaint(
                      size: const Size(16, 10),
                      painter: _ComicBubbleTailPainter(),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Armi mascot character với biểu cảm tương ứng
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TXATheme.cardBg,
                      border: Border.all(color: TXATheme.primaryYellow, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: TXATheme.primaryYellow.withAlpha(140),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _getMascotAssetPath(step.expression),
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => Image.asset(
                          'assets/armi_mascot.png',
                          width: 58,
                          height: 58,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter vẽ đuôi mũi tên chỉ xuống của bong bóng thoại Comic
class _ComicBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0xFF1B1B26)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = TXATheme.primaryYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter đục lỗ làm tối xung quanh và khoanh vùng đốm sáng Neon cho phần tử được chọn
class _SpotlightHolePainter extends CustomPainter {
  final Rect targetRect;
  final double glowProgress;

  _SpotlightHolePainter({
    required this.targetRect,
    required this.glowProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (targetRect.isEmpty) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black.withAlpha(170),
      );
      return;
    }

    final padding = 8.0;
    final inflatedRect = targetRect.inflate(padding);

    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(inflatedRect, Radius.circular(inflatedRect.height / 2)));

    // Đục lỗ spotlight
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, holePath);
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withAlpha(170),
    );

    // Vẽ khung viền đốm sáng phát sáng xung quanh Target Element
    final glowRadius = 4.0 + (glowProgress * 6.0);
    final borderPaint = Paint()
      ..color = TXATheme.primaryYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, glowRadius);

    canvas.drawRRect(
      RRect.fromRectAndRadius(inflatedRect, Radius.circular(inflatedRect.height / 2)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightHolePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.glowProgress != glowProgress;
  }
}
