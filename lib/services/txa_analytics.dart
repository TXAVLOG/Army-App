import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'txa_supabase_service.dart';

class TXAAnalytics {
  // ─── Screen name constants ───────────────────────────────────────────────
  static const String screenSplash         = 'splash';
  static const String screenLogin          = 'login';
  static const String screenRegister       = 'register';
  static const String screenFeed           = 'feed';
  static const String screenMain           = 'main';
  static const String screenPhotoPreview   = 'photo_preview';
  static const String screenProfile        = 'profile';
  static const String screenChatList       = 'chat_list';
  static const String screenChatDetail     = 'chat_detail';
  static const String screenLoveDashboard  = 'love_dashboard';
  static const String screenLoveFeed       = 'love_feed';
  static const String screenLoveInvitation = 'love_invitation';
  static const String screenLoveSetup      = 'love_setup';
  static const String screenAchievement    = 'achievement';
  static const String screenGoldPass       = 'gold_pass_paywall';
  static const String screenAdminPanel     = 'admin_panel';
  static const String screenRecap          = 'recap';
  static const String screenRollcall       = 'rollcall_responses';
  static const String screenLanguage       = 'language';
  static const String screenCrash          = 'crash_report';

  // ─── Platform guard ──────────────────────────────────────────────────────
  static bool get _isSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  // ─── Screen view ─────────────────────────────────────────────────────────
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    debugPrint('📱 [Analytics] Screen: $screenName');
    if (_isSupported) {
      try {
        await FirebaseAnalytics.instance.logScreenView(
          screenName: screenName,
          screenClass: screenClass ?? screenName,
        );
      } catch (_) {}
    }
  }

  // ─── Custom event (also increments Supabase counter) ────────────────────
  static Future<void> logEvent(String eventName,
      {Map<String, Object>? parameters}) async {
    // 1. Increment counter in Supabase txa_statistics
    try {
      final supabase = TXASupabaseService.instance.client;
      final existing = await supabase
          .from('txa_statistics')
          .select()
          .eq('key', eventName)
          .maybeSingle();
      final int current = (existing?['value'] as int?) ?? 0;
      await supabase.from('txa_statistics').upsert(
        {'key': eventName, 'value': current + 1},
        onConflict: 'key',
      );
      debugPrint('📊 [Analytics] Logged event to Supabase: $eventName');
    } catch (e) {
      debugPrint('Error logging analytics event: $e');
    }

    // 2. Log to Firebase Analytics
    if (_isSupported) {
      try {
        await FirebaseAnalytics.instance
            .logEvent(name: eventName, parameters: parameters);
      } catch (_) {}
    }
  }

  // ─── Convenience helpers ─────────────────────────────────────────────────
  static Future<void> logLogin({required String loginMethod}) async {
    if (_isSupported) {
      try {
        await FirebaseAnalytics.instance.logLogin(loginMethod: loginMethod);
      } catch (_) {}
    }
  }

  static Future<void> logAppOpen() async {
    if (_isSupported) {
      try {
        await FirebaseAnalytics.instance.logAppOpen();
      } catch (_) {}
    }
  }
}
