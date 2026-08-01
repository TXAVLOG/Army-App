import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'theme/txa_theme.dart';
import 'services/txa_language.dart';
import 'services/txa_format.dart';
import 'services/txa_notification_service.dart';
import 'services/txa_auth_service.dart';
import 'services/txa_feed_service.dart';
import 'services/txa_logger.dart';
import 'services/txa_camera_theme_service.dart';
import 'services/txa_achievement_service.dart';
import 'services/txa_config.dart';
import 'screens/splash_screen.dart';
import 'screens/txa_crash_screen.dart';
import 'services/txa_deep_link_service.dart';
import 'services/txa_screen_security.dart';
import 'widgets/txa_network_observer.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

/// Cho phép kéo bằng chuột (mouse drag) trên Windows / Desktop
/// → vuốt trái/phải, lên/xuống không cần màn hình cảm ứng
class TXAScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) {
  // Override Flutter Red/Gray Screen of Death with TXACrashScreen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return TXACrashScreen(
      details: details,
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  runZonedGuarded(() async {
    HttpOverrides.global = MyHttpOverrides();
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Catch uncaught Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      TXALogger.logError(
        'FlutterError: ${details.exceptionAsString()}',
        stackTrace: details.stack,
      );
    };

    // 2. Catch uncaught Platform Dispatcher async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('🚨 PlatformDispatcher Async Error: $error');
      TXALogger.logCrash(
        error,
        stackTrace: stack,
        contextDescription: 'PlatformDispatcher.instance.onError',
      );
      return true; // Prevents crash to OS desktop
    };

    // 3. Initialize Logger
    try {
      await TXALogger.init();
    } catch (e) {
      debugPrint('TXALogger init warning: $e');
    }

    // 4. Initialize Firebase safely per-platform with options fallback
    try {
      if (Firebase.apps.isEmpty) {
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          try {
            await Firebase.initializeApp();
          } catch (_) {
            // Fallback options if native google-services initialization encounters issues
            await Firebase.initializeApp(
              options: TXAConfig.currentFirebaseOptions,
            );
          }
        } else {
          // Web / Windows Desktop fallback options
          await Firebase.initializeApp(
            options: TXAConfig.currentFirebaseOptions,
          );
        }
      }
    } catch (e, stack) {
      debugPrint('Firebase init warning: $e');
      TXALogger.logError('Firebase init warning: $e', stackTrace: stack);
    }

    // 5. Initialize all core services with isolated error handling
    Future<void> safeInit(String name, Future<void> Function() initFunc) async {
      try {
        await initFunc();
      } catch (e, stack) {
        debugPrint('$name init warning: $e');
        TXALogger.logError('$name init warning: $e', stackTrace: stack);
      }
    }

    await safeInit('TXALanguage', () => TXALanguage.instance.init());
    await safeInit('TXAFormat', () => TXAFormat.instance.init());
    await safeInit('TXACameraThemeService', () => TXACameraThemeService.instance.init());
    await safeInit('TXANotificationService', () => TXANotificationService.instance.init());
    await safeInit('TXAAchievementService', () => TXAAchievementService.instance.init());
    await safeInit('TXAAuthService', () => TXAAuthService.instance.init());
    await safeInit('TXAFeedService', () => TXAFeedService.instance.init());
    await safeInit('TXADeepLinkService', () => TXADeepLinkService.instance.init(args: args));
    await safeInit('TXAScreenSecurity', () => TXAScreenSecurity.instance.init());

    // 5.5. Log app open event to Google Analytics
    try {
      FirebaseAnalytics.instance.logAppOpen();
      debugPrint('📊 Firebase Analytics app_open event logged successfully.');
    } catch (e) {
      debugPrint('Firebase Analytics event log error: $e');
    }

    // 6. Launch main app UI
    runApp(const ArmyApp());
  }, (error, stack) {
    debugPrint('🚨 Unhandled Top-level Zoned Exception: $error');
    TXALogger.logCrash(
      error,
      stackTrace: stack,
      contextDescription: 'Top-Level runZonedGuarded',
    );

    // If app state permits, show TXACrashScreen instead of terminating
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: TXATheme.darkTheme,
        home: TXACrashScreen(
          error: error,
          stackTrace: stack,
        ),
      ),
    );
  });
}

class ArmyApp extends StatelessWidget {
  const ArmyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Rebuild khi đổi ngôn ngữ HOẶC đổi chủ đề camera (để cập nhật màu nền app)
      animation: Listenable.merge([
        TXALanguage.instance,
        TXACameraThemeService.instance,
      ]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: TXALanguage.instance.getText('app_title'),
          debugShowCheckedModeBanner: false,
          theme: TXATheme.darkTheme,
          scrollBehavior: TXAScrollBehavior(), // vuốt bằng chuột toàn app
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            // Giới hạn hệ số phóng to chữ của hệ thống Android (Accessibility Font Scaling)
            // giúp giao diện responsive 100% không bị văng/vỡ layout trên mọi cỡ chữ hệ thống.
            final constrainedTextScaler = mediaQueryData.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.25,
            );
            return MediaQuery(
              data: mediaQueryData.copyWith(
                textScaler: constrainedTextScaler,
              ),
              child: TXANetworkObserver(child: child!),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
