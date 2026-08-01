import 'dart:async';
import 'package:flutter/material.dart';

class TXAMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;

  const TXAMarquee({super.key, required this.text, required this.style});

  @override
  State<TXAMarquee> createState() => _TXAMarqueeState();
}

class _TXAMarqueeState extends State<TXAMarquee> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !_scrollController.hasClients) return;

      final maxExtent = _scrollController.position.maxScrollExtent;
      final currentPosition = _scrollController.offset;

      if (maxExtent <= 0) return; // Nếu text vừa khít màn hình thì không cần chạy

      if (currentPosition >= maxExtent) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(currentPosition + 1.0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          // Thêm khoảng trống đuôi để chữ quay vòng nhìn tự nhiên
          const SizedBox(width: 50),
          Text(widget.text, style: widget.style),
        ],
      ),
    );
  }
}
