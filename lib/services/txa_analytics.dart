import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TXAAnalytics {
  static Future<void> logEvent(String eventName) async {
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
  }
}
