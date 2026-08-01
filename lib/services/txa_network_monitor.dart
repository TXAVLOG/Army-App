import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'txa_auth_service.dart';
import 'txa_feed_service.dart';
import 'txa_logger.dart';

class TXANetworkMonitor extends ChangeNotifier {
  static final TXANetworkMonitor instance = TXANetworkMonitor._internal();
  TXANetworkMonitor._internal();

  bool _hasConnection = true;
  bool get hasConnection => _hasConnection;

  Timer? _timer;
  bool _isChecking = false;
  int _consecutiveFailures = 0;

  void startMonitoring() {
    _timer?.cancel();
    // Check immediately, then check every 3 seconds
    checkConnection();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      checkConnection();
    });
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> checkConnection() async {
    if (_isChecking) return _hasConnection;
    _isChecking = true;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _consecutiveFailures = 0;
      if (connected != _hasConnection) {
        _hasConnection = connected;
        notifyListeners();
        if (_hasConnection) {
          _triggerSync();
        }
      }
    } catch (_) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 2) {
        if (_hasConnection) {
          _hasConnection = false;
          notifyListeners();
        }
      }
    } finally {
      _isChecking = false;
    }
    return _hasConnection;
  }

  void _triggerSync() {
    debugPrint('🌐 [NetworkMonitor] Reconnected! Triggering sync...');
    // 1. Sync pending crash/action logs to Firestore
    TXALogger.syncPendingLogs();
    // 2. Sync friends lists from Firestore
    TXAAuthService.instance.syncFriendsFromFirestore();
    // 3. Refresh feed posts from Firestore
    TXAFeedService.instance.init();
  }
}
