import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/txa_supabase_service.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_network_monitor.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_google_play_services.dart';
import '../services/txa_battery_service.dart';
import '../services/txa_logger.dart';
import 'txa_language_screen.dart';
import 'txa_login_screen.dart';
import 'locket_main_screen.dart';
import 'txa_crash_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _exitController;
  late Animation<double> _exitScaleAnimation;
  late Animation<double> _exitFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _exitScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOutBack),
    );

    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );

    _controller.forward();

    TXABatteryService.instance.init();
    _initAndCheckGMS();
  }

  Future<void> _initAndCheckGMS() async {
    final hasNet = await TXANetworkMonitor.instance.checkConnection();
    if (!hasNet) {
      if (mounted) {
        _showNoInternetDialog();
      }
      return;
    }

    await TXAGooglePlayServices.instance.checkAvailability();
    // Chạy sửa ảnh lỗi bất đồng bộ ở nền để không gây đơ/lag màn hình khởi động
    _fixBrokenImages().catchError((e) => debugPrint('Fix images background error: $e'));
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    if (!TXAGooglePlayServices.instance.isAvailable) {
      _showGMSWarningDialog();
    } else {
      _navigateToNextScreen();
    }
  }

  void _showNoInternetDialog() {
    final txaLang = TXALanguage.instance;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TXATheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            txaLang.getText('no_internet_title'),
            style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            txaLang.getText('no_internet_desc'),
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                io.exit(0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TXATheme.statusRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(txaLang.getText('exit_app_btn')),
            ),
          ],
        );
      },
    );
  }

  void _showGMSWarningDialog() {
    final txaLang = TXALanguage.instance;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TXATheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            txaLang.getText('gms_warning_title'),
            style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            txaLang.getText('gms_warning_desc'),
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _navigateToNextScreen();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TXATheme.primaryYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(txaLang.getText('gms_warning_btn')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    if (TXABatteryService.instance.isBatteryCritical) {
      VoidCallback? listener;
      listener = () {
        if (!TXABatteryService.instance.isBatteryCritical) {
          TXABatteryService.instance.removeListener(listener!);
          _navigateToNextScreen();
        }
      };
      TXABatteryService.instance.addListener(listener);
      return;
    }

    // Chạy hiệu ứng đóng màn hình trước khi chuyển màn
    await _exitController.forward();

    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final isSetupCompleted = prefs.getBool('txa_initial_setup_completed') ?? false;
    final isLoggedIn = TXAAuthService.instance.isLoggedIn;

    // Check if there was a pending Native Android Crash detected during launch
    final nativeCrashLogs = TXALogger.localErrorLogs.where((log) => log['isNativeCrash'] == true).toList();

    Widget targetScreen;
    if (nativeCrashLogs.isNotEmpty) {
      final nativeCrash = nativeCrashLogs.first;
      targetScreen = TXACrashScreen(
        error: nativeCrash['errorMessage'],
        stackTrace: StackTrace.fromString(nativeCrash['stackTrace'] ?? ''),
      );
    } else if (isLoggedIn) {
      targetScreen = const LocketMainScreen();
    } else if (isSetupCompleted) {
      targetScreen = const TXALoginScreen();
    } else {
      targetScreen = const TXALanguageScreen();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Widget _buildBatteryCriticalOverlay(TXALanguage txaLang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.battery_alert_rounded,
                color: TXATheme.statusRed,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              txaLang.getText('battery_critical_title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              txaLang.getText('battery_critical_desc'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    return Scaffold(
      backgroundColor: TXATheme.background,
      body: AnimatedBuilder(
        animation: TXABatteryService.instance,
        builder: (context, _) {
          final isCritical = TXABatteryService.instance.isBatteryCritical;

          if (isCritical) {
            return _buildBatteryCriticalOverlay(txaLang);
          }

          return Center(
            child: FadeTransition(
              opacity: _exitFadeAnimation,
              child: ScaleTransition(
                scale: _exitScaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: TXATheme.cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: TXATheme.primaryYellow, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: TXATheme.primaryYellow.withAlpha(90),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/armi_mascot.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'ARMY',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: TXATheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          txaLang.getText('splash_subtitle'),
                          style: TextStyle(
                            fontSize: 14,
                            color: TXATheme.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Loading indicator
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(TXATheme.primaryYellow.withAlpha(204)),
                            backgroundColor: Colors.white10,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          txaLang.currentLanguage == 'vi' ? 'Đang kết nối hệ thống...' : 'Connecting to system...',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white30,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fixBrokenImages() async {
    try {
      final querySnapshot = await TXASupabaseService.instance.client
          .from('txa_posts')
          .select('id, photoPath, photopath');

      int count = 0;
      for (var row in querySnapshot) {
        final String photoPath = row['photoPath'] ?? row['photopath'] ?? '';
        if (photoPath.contains('photo-1472214222541-d510753a4707') || photoPath.contains('404')) {
          await TXASupabaseService.instance.client
              .from('txa_posts')
              .update({
                'photoPath': 'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=600',
                'photopath': 'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=600',
              })
              .eq('id', row['id']);
          count++;
        }
      }
      if (count > 0) {
        debugPrint('🚀 [Fix] Đã tự động thay thế $count link ảnh cũ lỗi 404 bằng ảnh Unsplash mới hoạt động tốt!');
      }
    } catch (e) {
      debugPrint('❌ [Fix] Lỗi khi quét sửa ảnh hỏng: $e');
    }
  }
}