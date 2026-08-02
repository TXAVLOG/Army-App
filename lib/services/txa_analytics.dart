import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'txa_supabase_service.dart';

class TXAAnalytics {
  static bool get _isSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  static Future<void> logEvent(String eventName, {Map<String, Object>? parameters}) async {
    // 1. Log to Firestore statistics
    try {
      final supabase = TXASupabaseService.instance.client;
      final doc = await supabase.from('txa_statistics').select().eq('id', 'global').maybeSingle();
      final Map<String, dynamic> data = doc != null ? Map<String, dynamic>.from(doc['data'] ?? {}) : {};
      final int currentCount = data[eventName] as int? ?? 0;
      data[eventName] = currentCount + 1;

      await supabase.from('txa_statistics').upsert({
        'id': 'global',
        'data': data,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      debugPrint('📊 [Analytics] Logged event to Supabase: $eventName');
    } catch (e) {
      debugPrint('Error logging analytics event: $e');
    }

    // 2. Log to Firebase Analytics
    if (_isSupported) {
      try {
        await FirebaseAnalytics.instance.logEvent(name: eventName, parameters: parameters);
      } catch (_) {}
    }
  }

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
