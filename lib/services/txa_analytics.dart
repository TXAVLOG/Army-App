import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class TXAAnalytics {
  static bool get _isSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  static Future<void> logEvent(String eventName, {Map<String, Object>? parameters}) async {
    // 1. Log to Firestore statistics
    try {
      final docRef = FirebaseFirestore.instance.collection('statistics').doc('global');
      await docRef.set({
        eventName: FieldValue.increment(1),
        'lastUpdated': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      debugPrint('📊 [Analytics] Logged event: $eventName');
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
