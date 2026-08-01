import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'txa_version.dart';
import 'txa_auth_service.dart';
import 'txa_language.dart';
import 'txa_format.dart';

class TXALogger {
  static final TXALogger instance = TXALogger._internal();
  TXALogger._internal();

  static const String _keyCrashLogs = 'txa_crash_logs_queue';

  // Throttle map & repeat counters to prevent spam
  static final Map<String, DateTime> _errorThrottleMap = {};
  static final Map<String, int> _errorRepeatCounts = {};

  static const Duration _throttleWindow = Duration(seconds: 30);

  static final List<Map<String, dynamic>> _localErrorLogs = [];
  static List<Map<String, dynamic>> get localErrorLogs => List.unmodifiable(_localErrorLogs);

  static Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCrashLogs);
      _localErrorLogs.clear();
      debugPrint('🧹 [TXALogger] Cleared all local pending crash logs.');
    } catch (_) {}
  }

  static Future<void> init() async {
    // Catch Unhandled Flutter Framework UI Exceptions
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logCrash(
        details.exception,
        stackTrace: details.stack,
        contextDescription: details.context?.toString(),
      );
    };

    // Catch Asynchronous Platform & Dart Runtime Errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logCrash(error, stackTrace: stack, contextDescription: 'PlatformDispatcher Async Error');
      return true;
    };

    await syncPendingLogs();
    await checkAndSubmitNativeCrash();
  }

  /// Check and submit pending Native Android crashes saved by MainApplication.kt
  static Future<Map<String, dynamic>?> checkAndSubmitNativeCrash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasNativeCrash = prefs.getBool('has_pending_native_crash') ?? false;
      if (!hasNativeCrash) return null;

      final msg = prefs.getString('pending_native_crash_msg') ?? 'Android Native Uncaught Exception';
      final trace = prefs.getString('pending_native_crash_trace') ?? 'No Native StackTrace';
      final timestampMs = prefs.getInt('pending_native_crash_time') ?? DateTime.now().millisecondsSinceEpoch;
      final timeStr = DateTime.fromMillisecondsSinceEpoch(timestampMs).toIso8601String();

      // Clear the pending native crash flag
      await prefs.remove('has_pending_native_crash');
      await prefs.remove('pending_native_crash_msg');
      await prefs.remove('pending_native_crash_trace');
      await prefs.remove('pending_native_crash_time');

      final logPayload = {
        'id': 'native_crash_$timestampMs',
        'level': 'CRASH',
        'errorType': 'AndroidNativeException',
        'errorMessage': msg,
        'stackTrace': trace,
        'contextDescription': 'Android Native MainApplication Uncaught Exception',
        'repeatCountInWindow': 1,
        'isNativeCrash': true,
        'app': {
          'appName': TXAVersion.appName,
          'version': TXAVersion.currentVersion,
          'buildNumber': TXAVersion.buildNumber,
          'fullVersionString': TXAVersion.fullVersionString,
          'releaseDate': TXAVersion.releaseDate,
        },
        'deviceInfo': _getExhaustiveDeviceInfo(),
        'timestamp': timeStr,
      };

      _localErrorLogs.insert(0, logPayload);
      await _submitToFirebase(logPayload);
      return logPayload;
    } catch (e) {
      debugPrint('TXALogger checkAndSubmitNativeCrash error: $e');
      return null;
    }
  }

  /// Log a Critical Crash
  static Future<void> logCrash(
    dynamic crashError, {
    StackTrace? stackTrace,
    String? contextDescription,
  }) async {
    await _processLog(
      level: 'CRASH',
      error: crashError,
      stackTrace: stackTrace,
      contextDescription: contextDescription,
    );
  }

  /// Log an Error / Bug
  static Future<void> logError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extraInfo,
  }) async {
    await _processLog(
      level: 'ERROR',
      error: error,
      stackTrace: stackTrace,
      extraInfo: extraInfo,
    );
  }

  /// Core Logger Processor with Deduplication & Exhaustive Metadata
  static Future<void> _processLog({
    required String level,
    required dynamic error,
    StackTrace? stackTrace,
    String? contextDescription,
    Map<String, dynamic>? extraInfo,
  }) async {
    // STRICT RULE: ONLY log CRASH & ERROR. Ignore Info/Warning.
    if (level != 'CRASH' && level != 'ERROR') {
      return;
    }

    final errorMessage = error.toString();
    final errorType = error.runtimeType.toString();
    final fingerprint = '$level:$errorType:$errorMessage';
    final now = DateTime.now();

    // Deduplication Throttle Window
    if (_errorThrottleMap.containsKey(fingerprint)) {
      final lastTime = _errorThrottleMap[fingerprint]!;
      if (now.difference(lastTime) < _throttleWindow) {
        _errorRepeatCounts[fingerprint] = (_errorRepeatCounts[fingerprint] ?? 1) + 1;
        debugPrint('🛡️ [TXALogger] Throttled duplicate $level: "$errorMessage" (Count: ${_errorRepeatCounts[fingerprint]})');
        return;
      }
    }

    _errorThrottleMap[fingerprint] = now;
    final count = _errorRepeatCounts[fingerprint] ?? 1;
    _errorRepeatCounts[fingerprint] = 1;

    // Collect EXHAUSTIVE Device, User Session & App Metadata
    final deviceInfo = _getExhaustiveDeviceInfo();
    final currentUser = TXAAuthService.instance.currentUser;
    final activeLang = TXALanguage.instance.currentLanguage;
    final activeFormat = TXAFormat.instance.aspectRatio;

    final logPayload = {
      'id': 'crash_${now.millisecondsSinceEpoch}',
      'level': level,
      'errorType': errorType,
      'errorMessage': errorMessage,
      'stackTrace': stackTrace?.toString() ?? 'No StackTrace Available',
      'contextDescription': contextDescription ?? 'General Application Execution',
      'repeatCountInWindow': count,
      'app': {
        'appName': TXAVersion.appName,
        'version': TXAVersion.currentVersion,
        'buildNumber': TXAVersion.buildNumber,
        'fullVersionString': TXAVersion.fullVersionString,
        'releaseDate': TXAVersion.releaseDate,
        'activeLanguage': activeLang,
        'activeAspectRatio': activeFormat,
      },
      'userSession': currentUser != null
          ? {
              'id': currentUser.id,
              'username': currentUser.username,
              'email': currentUser.email,
              'avatar': currentUser.avatar,
              'dob': currentUser.dob,
              'createdTime': currentUser.createdTime,
            }
          : {'status': 'Anonymous / Not Logged In'},
      'deviceInfo': deviceInfo,
      'timestamp': now.toIso8601String(),
    };

    _localErrorLogs.insert(0, logPayload);
    debugPrint('🚨 [TXALogger] EXHAUSTIVE $level LOG RECORDED:');
    debugPrint(const JsonEncoder.withIndent('  ').convert(logPayload));

    // Submit Log Payload to Firebase Firestore (skip RenderFlex overflow errors)
    final isOverflowError = errorMessage.contains('overflowed') || errorMessage.contains('RenderFlex');
    if (!isOverflowError) {
      await _submitToFirebase(logPayload);
    } else {
      debugPrint('ℹ️ [TXALogger] RenderFlex overflow log skipped from Firebase queue submission.');
    }
  }

  /// Collect EXHAUSTIVE OS, System Environment, CPU, Locale & Platform Specs
  static Map<String, dynamic> _getExhaustiveDeviceInfo() {
    String osVersion = Platform.operatingSystemVersion;
    if (Platform.isWindows) {
      final regExp = RegExp(r'Build\s+(\d+)');
      final match = regExp.firstMatch(osVersion);
      if (match != null) {
        final buildNum = int.tryParse(match.group(1) ?? '');
        if (buildNum != null && buildNum >= 22000) {
          osVersion = osVersion.replaceAll('Windows 10', 'Windows 11');
        }
      }
    }

    return {
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': osVersion,
      'locale': Platform.localeName,
      'processorCount': Platform.numberOfProcessors,
      'hostname': Platform.localHostname,
      'dartVersion': Platform.version,
      'isDesktop': Platform.isWindows || Platform.isMacOS || Platform.isLinux,
      'isMobile': Platform.isAndroid || Platform.isIOS,
      'pathSeparator': Platform.pathSeparator,
      'environment': {
        'userProfile': Platform.environment['USERPROFILE'] ?? 'N/A',
        'tempDir': Platform.environment['TEMP'] ?? 'N/A',
        'osPlatform': Platform.environment['OS'] ?? 'N/A',
      },
    };
  }

  /// Submit Crash/Error Log directly to Firebase Firestore
  static Future<void> _submitToFirebase(Map<String, dynamic> logPayload) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final docId = logPayload['id'] as String? ?? 'crash_${DateTime.now().millisecondsSinceEpoch}';
      await firestore.collection('crash_logs').doc(docId).set(logPayload);
      debugPrint('🔥 [TXALogger] Successfully submitted Crash log to Firebase Firestore (crash_logs)!');
    } catch (e) {
      debugPrint('❌ [TXALogger] Error submitting crash log to Firebase: $e');
      // Offline fallback: save to local queue
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentQueue = prefs.getStringList(_keyCrashLogs) ?? [];
        currentQueue.add(jsonEncode(logPayload));
        await prefs.setStringList(_keyCrashLogs, currentQueue);
      } catch (_) {}
    }
  }

  /// Synchronize all pending offline logs to Firebase Firestore
  static Future<void> syncPendingLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyCrashLogs) ?? [];
      if (list.isEmpty) return;

      final firestore = FirebaseFirestore.instance;
      final List<String> succeeded = [];
      for (var item in list) {
        try {
          final payload = Map<String, dynamic>.from(jsonDecode(item));
          final docId = payload['id'] as String? ?? 'crash_${DateTime.now().millisecondsSinceEpoch}';
          await firestore.collection('crash_logs').doc(docId).set(payload);
          succeeded.add(item);
        } catch (_) {
          break;
        }
      }

      if (succeeded.isNotEmpty) {
        final newQueue = list.where((item) => !succeeded.contains(item)).toList();
        await prefs.setStringList(_keyCrashLogs, newQueue);
        debugPrint('🧹 [TXALogger] Synced and cleared ${succeeded.length} pending crash logs to Firestore.');
      }
    } catch (_) {}
  }

}
