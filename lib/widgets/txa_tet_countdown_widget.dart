import 'dart:async';
import 'package:flutter/material.dart';
import '../services/txa_festival_manager.dart';
import '../services/txa_language.dart';
import '../services/txa_format.dart';
import 'txa_marquee.dart';

class TXATetCountdownWidget extends StatefulWidget {
  final TextStyle style;

  const TXATetCountdownWidget({super.key, required this.style});

  @override
  State<TXATetCountdownWidget> createState() => _TXATetCountdownWidgetState();
}

class _TXATetCountdownWidgetState extends State<TXATetCountdownWidget> {
  Timer? _timer;
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final target = TXAFestivalManager.getActiveTetDate(now);
    final diff = target.difference(now);

    final langCode = TXALanguage.instance.currentLanguage;
    final txaLang = TXALanguage.instance;
    final tetName = TXAFestivalManager.getTetNameForDate(target, langCode);

    String text;
    if (diff.inSeconds <= 0) {
      text = txaLang.getText('tet_new_year').replaceAll('%name%', tetName);
    } else {
      final days = diff.inDays;
      final hours = TXAFormat.formatNumber(diff.inHours % 24);
      final minutes = TXAFormat.formatNumber(diff.inMinutes % 60);
      final seconds = TXAFormat.formatNumber(diff.inSeconds % 60);
      final timeStr = '$hours:$minutes:$seconds';

      if (days > 0) {
        text = langCode == 'vi'
            ? 'Còn $days ngày $timeStr đến Tết $tetName 🧧'
            : 'Only $days days $timeStr left until Lunar New Year $tetName 🧧';
      } else {
        text = langCode == 'vi'
            ? 'Còn $timeStr đến Tết $tetName 🧧'
            : 'Only $timeStr left until Lunar New Year $tetName 🧧';
      }
    }

    if (mounted && text != _displayText) {
      setState(() {
        _displayText = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TXAMarquee(
      text: _displayText,
      style: widget.style,
    );
  }
}
