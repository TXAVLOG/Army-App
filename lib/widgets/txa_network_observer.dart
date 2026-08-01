import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import '../services/txa_network_monitor.dart';
import '../services/txa_language.dart';
import '../widgets/txa_toast.dart';
import '../theme/txa_theme.dart';

class TXANetworkObserver extends StatefulWidget {
  final Widget child;

  const TXANetworkObserver({super.key, required this.child});

  @override
  State<TXANetworkObserver> createState() => _TXANetworkObserverState();
}

class _TXANetworkObserverState extends State<TXANetworkObserver> {
  bool _showOverlay = false;
  int _countdown = 10;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    TXANetworkMonitor.instance.startMonitoring();
    TXANetworkMonitor.instance.addListener(_onNetworkChanged);
  }

  @override
  void dispose() {
    TXANetworkMonitor.instance.removeListener(_onNetworkChanged);
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onNetworkChanged() {
    final hasNet = TXANetworkMonitor.instance.hasConnection;
    final txaLang = TXALanguage.instance;

    if (!hasNet) {
      // Network lost!
      if (!_showOverlay) {
        setState(() {
          _showOverlay = true;
          _countdown = 10;
        });

        TXAToast.show(
          context,
          txaLang.getText('connection_lost_toast').replaceAll('%sec%', '10'),
          icon: Icons.wifi_off_rounded,
          backgroundColor: TXATheme.statusRed,
        );

        _startCountdown();
      }
    } else {
      // Network restored!
      if (_showOverlay) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        setState(() {
          _showOverlay = false;
        });

        TXAToast.show(
          context,
          txaLang.getText('connection_restored_toast'),
          icon: Icons.wifi_rounded,
          backgroundColor: Colors.green[700],
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          timer.cancel();
          io.exit(0);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_showOverlay)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: Colors.black.withAlpha(225),
                child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        shape: BoxShape.circle,
                        border: Border.all(color: TXATheme.statusRed, width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.wifi_off_rounded,
                          color: TXATheme.statusRed,
                          size: 54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      txaLang.getText('countdown_exit_msg'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$_countdown',
                      style: const TextStyle(
                        color: TXATheme.primaryYellow,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: TXATheme.primaryYellow,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
