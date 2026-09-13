import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_supabase_service.dart';
import 'txa_version.dart';
import 'txa_auth_service.dart';
import 'txa_language.dart';
import 'txa_format.dart';
import '../utils/txa_device_info.dart';

class TXALogger {
  static final TXALogger instance = TXALogger._internal();
  TXALogger._internal();

  static const String _keyCrashLogs = 'txa_crash_logs_queue';

  // Throttle map & repeat counters to prevent spam
  static final Map<String, DateTime> _errorThrottleMap = {};
  static final Map<String, int> _errorRepeatCounts = {};
  static const Duration _throttleWindow = Duration(seconds: 30);

  static final List<Map<String, dynamic>> _localErrorLogs = [];
  static List<Map<String, dynamic>> get localErrorLogs =>
      List.unmodifiable(_localErrorLogs);

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<Directory> _getLogsDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${baseDir.path}/txa_logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  static Future<File> _getLogFile(String type, [String? dateStr]) async {
    final logsDir = await _getLogsDirectory();
    final date = dateStr ?? _todayString();
    final cleanType = type.toLowerCase().trim();
    return File('${logsDir.path}/${cleanType}_$date.log');
  }

  /// Base log method to append structured log line to daily file
  static Future<void> log(String message, {String type = 'app'}) async {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final upperType = type.toUpperCase();
    final logLine = '[$timeStr] [$upperType] $message\n';

    debugPrint('📝 [TXALogger] $logLine'.trim());

    if (!kIsWeb) {
      try {
        final file = await _getLogFile(type);
        await file.writeAsString(logLine, mode: FileMode.append, flush: true);
      } catch (e) {
        debugPrint('❌ [TXALogger] Error writing log file: $e');
      }
    }
  }

  /// Specialized log methods
  static void logApp(String message) => log(message, type: 'app');
  static void logApi(String message) => log(message, type: 'api');
  static void logInfo(String message, {Map<String, dynamic>? extraInfo}) {
    final extraStr = extraInfo != null ? ' | Extra: $extraInfo' : '';
    log('$message$extraStr', type: 'app');
  }

  /// Initialize system handlers
  static Future<void> init() async {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      final exStr = details.exception.toString();
      if (exStr.contains('RenderFlex') || exStr.contains('overflowed')) {
        return;
      }
      logCrash(
        details.exception,
        stackTrace: details.stack,
        contextDescription: details.context?.toString(),
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final errStr = error.toString();
      // Classify transient network / realtime websocket reconnect exceptions as non-fatal API logs
      final isRealtimeNetworkTimeout = errStr.contains('RealtimeSubscribeException') ||
          errStr.contains('timedOut') ||
          errStr.contains('SocketException') ||
          errStr.contains('HttpException') ||
          errStr.contains('ClientException') ||
          errStr.contains('HandshakeException');

      if (isRealtimeNetworkTimeout) {
        logApi('Transient Realtime / Network Reconnect: $errStr');
        return true;
      }

      logCrash(
        error,
        stackTrace: stack,
        contextDescription: 'PlatformDispatcher Async Error',
      );
      return true;
    };

    await syncPendingLogs();
    await checkAndSubmitNativeCrash();
  }

  /// Read logs by type (all, app, api, crash) for a given date
  static Future<String> readLogs(String type, [String? dateStr]) async {
    final cleanType = type.toLowerCase().trim();
    final date = dateStr ?? _todayString();

    if (cleanType == 'all') {
      final List<String> allLines = [];
      for (final t in ['app', 'api', 'crash']) {
        try {
          final file = await _getLogFile(t, date);
          if (await file.exists()) {
            final lines = await file.readAsLines();
            allLines.addAll(lines);
          }
        } catch (_) {}
      }

      if (allLines.isEmpty) {
        return TXALanguage.instance.getText('log_empty');
      }

      // Sort lines by timestamp [HH:mm:ss.SSS]
      allLines.sort((a, b) {
        final matchA = RegExp(r'^\[(\d{2}:\d{2}:\d{2}\.\d{3})\]').firstMatch(a);
        final matchB = RegExp(r'^\[(\d{2}:\d{2}:\d{2}\.\d{3})\]').firstMatch(b);
        if (matchA != null && matchB != null) {
          return matchA.group(1)!.compareTo(matchB.group(1)!);
        }
        return 0;
      });

      return allLines.join('\n');
    } else {
      try {
        final file = await _getLogFile(cleanType, date);
        if (await file.exists()) {
          final content = await file.readAsString();
          return content.trim().isEmpty
              ? TXALanguage.instance.getText('log_empty')
              : content;
        }
      } catch (e) {
        debugPrint('TXALogger readLogs error: $e');
      }
      return TXALanguage.instance.getText('log_empty');
    }
  }

  /// Clear all local log files
  static Future<void> clearLogs() async {
    try {
      final logsDir = await _getLogsDirectory();
      if (await logsDir.exists()) {
        final entities = logsDir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.log')) {
            await entity.delete();
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCrashLogs);
      _localErrorLogs.clear();
      debugPrint('🧹 [TXALogger] Cleared all local log files and queues.');
    } catch (e) {
      debugPrint('TXALogger clearLogs error: $e');
    }
  }

  /// Share log file via system share dialog
  static Future<void> shareLogs(String type) async {
    try {
      final cleanType = type.toLowerCase().trim();
      final logsDir = await _getLogsDirectory();
      final date = _todayString();

      File shareTargetFile;
      if (cleanType == 'all') {
        final content = await readLogs('all', date);
        shareTargetFile = File('${logsDir.path}/all_$date.log');
        await shareTargetFile.writeAsString(content);
      } else {
        shareTargetFile = await _getLogFile(cleanType, date);
        if (!await shareTargetFile.exists()) {
          await shareTargetFile.writeAsString(
            TXALanguage.instance.getText('log_empty'),
          );
        }
      }

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(shareTargetFile.path, mimeType: 'text/plain', name: 'army_${cleanType}_$date.log')],
        subject: 'Army App System Logs ($cleanType)',
        text: 'Army App System Logs ($cleanType - $date)',
      );
    } catch (e) {
      debugPrint('TXALogger shareLogs error: $e');
    }
  }

  /// Get effective user session with fallback to stored local preferences
  static Future<Map<String, dynamic>> _getEffectiveUserSession() async {
    final installId = await TXADeviceInfo.getInstallationId();
    final currentUser = TXAAuthService.instance.currentUser;
    if (currentUser != null && currentUser.username.isNotEmpty && currentUser.username != 'anonymous') {
      return {
        'id': currentUser.id,
        'username': currentUser.username,
        'email': currentUser.email,
        'avatar': currentUser.avatar,
        'dob': currentUser.dob,
        'createdTime': currentUser.createdTime,
        'status': 'Logged In',
        'installId': installId,
      };
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('txa_active_user_session');
      if (userJsonStr != null && userJsonStr.isNotEmpty) {
        final decoded = jsonDecode(userJsonStr);
        if (decoded is Map && decoded['username'] != null && decoded['username'].toString().isNotEmpty) {
          final uName = decoded['username'].toString();
          if (uName != 'anonymous') {
            return {
              'id': decoded['id']?.toString() ?? 'cached_user',
              'username': uName,
              'email': decoded['email']?.toString() ?? '',
              'avatar': decoded['avatar']?.toString() ?? '🦊',
              'dob': decoded['dob']?.toString() ?? '',
              'createdTime': decoded['createdTime']?.toString() ?? '',
              'status': 'Restored from Cached Session',
              'installId': installId,
            };
          }
        }
      }
    } catch (_) {}

    return {
      'status': 'Anonymous / Not Logged In',
      'username': 'anonymous',
      'installId': installId,
    };
  }

  /// Helper to generate rich formatted diagnostic caption for admin reports
  static String _buildStructuredReportCaption(Map<String, dynamic> payload) {
    final errorType = payload['errorType'] ?? 'Error';
    final errorMsg = payload['errorMessage'] ?? 'Unknown Error';
    final contextDesc = payload['contextDescription'] ?? 'General Application Execution';
    final time = payload['timestamp'] ?? DateTime.now().toIso8601String();

    // User session details
    final userSession = payload['userSession'] is Map ? payload['userSession'] : {};
    final username = userSession['username']?.toString() ?? 'anonymous';
    final installId = userSession['installId']?.toString() ?? 'N/A';
    final userStatus = userSession['status']?.toString() ?? 'Chưa đăng nhập';
    final userDisplay = username == 'anonymous'
        ? 'anonymous (Mã cài đặt: $installId)'
        : '$username (ID: ${userSession['id'] ?? 'N/A'}) [$userStatus]';

    // App details
    final appInfo = payload['app'] is Map ? payload['app'] : {};
    final appVer = appInfo['fullVersionString'] ?? TXAVersion.fullVersionString;
    final activeLang = appInfo['activeLanguage'] ?? 'vi';

    // Device & Hardware details
    final deviceInfo = payload['deviceInfo'] is Map ? payload['deviceInfo'] : {};
    final deviceModel = deviceInfo['device'] ?? deviceInfo['model'] ?? 'Unknown Device';
    final brand = deviceInfo['brand']?.toString() ?? '';
    final fullDevice = (brand.isNotEmpty && !deviceModel.toString().toUpperCase().contains(brand.toUpperCase()))
        ? '$brand $deviceModel'
        : deviceModel.toString();
    final os = deviceInfo['osVersion'] ?? deviceInfo['platform'] ?? Platform.operatingSystem;
    final screen = deviceInfo['screen']?.toString() ?? 'N/A';
    final ram = deviceInfo['ram']?.toString() ?? 'N/A';
    final cpu = deviceInfo['cpuCores']?.toString() ?? 'N/A';
    final battery = deviceInfo['batteryLevel']?.toString() ?? 'N/A';
    final isPhysical = deviceInfo['isPhysicalDevice'];
    final deviceTypeStr = isPhysical == null
        ? 'N/A'
        : (isPhysical == true ? 'Thiết bị thật (Physical Device) 📱' : 'Máy ảo / Giả lập (Emulator) ⚠️');
    final isRooted = deviceInfo['isRootedOrJailbroken'];
    final rootStatus = isRooted == true ? 'Rooted / Jailbroken ⚠️' : 'An toàn / Chưa Root 🛡️';
    final timezone = deviceInfo['timezone']?.toString() ?? 'N/A';
    final locale = deviceInfo['locale']?.toString() ?? 'N/A';
    final stack = payload['stackTrace']?.toString() ?? 'No StackTrace Available';

    return '''💥 [HỆ THỐNG / BÁO LỖI TỰ ĐỘNG - TXALogger]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Người dùng: $userDisplay
📱 Thiết bị: $fullDevice
⚙️ Hệ điều hành: $os
💻 Phần cứng: CPU: $cpu | RAM: $ram | Màn hình: $screen
🔋 Mức Pin: $battery
🛡️ Bảo mật: $rootStatus | $deviceTypeStr
🌍 Khu vực: $timezone (Locale: $locale)
🚀 Phiên bản App: $appVer (Ngôn ngữ: $activeLang)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ Loại lỗi: [$errorType]
📝 Nội dung: $errorMsg
📍 Ngữ cảnh: $contextDesc
⏰ Thời gian: $time
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Chi tiết StackTrace:
$stack''';
  }

  /// Check and submit pending Native Android crashes saved by MainApplication.kt
  static Future<Map<String, dynamic>?> checkAndSubmitNativeCrash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasNativeCrash = prefs.getBool('has_pending_native_crash') ?? false;
      if (!hasNativeCrash) return null;

      final msg =
          prefs.getString('pending_native_crash_msg') ??
          'Android Native Uncaught Exception';
      final trace =
          prefs.getString('pending_native_crash_trace') ??
          'No Native StackTrace';
      final timestampMs =
          prefs.getInt('pending_native_crash_time') ??
          DateTime.now().millisecondsSinceEpoch;
      final timeStr = DateTime.fromMillisecondsSinceEpoch(
        timestampMs,
      ).toIso8601String();

      await prefs.remove('has_pending_native_crash');
      await prefs.remove('pending_native_crash_msg');
      await prefs.remove('pending_native_crash_trace');
      await prefs.remove('pending_native_crash_time');

      final userSession = await _getEffectiveUserSession();

      final logPayload = {
        'id': 'native_crash_$timestampMs',
        'level': 'CRASH',
        'errorType': 'AndroidNativeException',
        'errorMessage': msg,
        'stackTrace': trace,
        'contextDescription':
            'Android Native MainApplication Uncaught Exception',
        'repeatCountInWindow': 1,
        'isNativeCrash': true,
        'app': {
          'appName': TXAVersion.appName,
          'version': TXAVersion.currentVersion,
          'buildNumber': TXAVersion.buildNumber,
          'fullVersionString': TXAVersion.fullVersionString,
          'releaseDate': TXAVersion.releaseDate,
        },
        'userSession': userSession,
        'deviceInfo': await TXADeviceInfo.getRawDiagnosticData(),
        'timestamp': timeStr,
      };

      _localErrorLogs.insert(0, logPayload);
      await log('NATIVE CRASH: $msg\nStackTrace: $trace', type: 'crash');
      await _submitToSupabase(logPayload);
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
    final errorMessage = error.toString();
    final errorType = error.runtimeType.toString();
    final fingerprint = '$level:$errorType:$errorMessage';
    final now = DateTime.now();

    // Append to crash file
    final extraStr = extraInfo != null ? '\nExtraInfo: $extraInfo' : '';
    final stackStr = stackTrace != null ? '\nStackTrace:\n$stackTrace' : '';
    await log(
      '$level: [$errorType] $errorMessage$extraStr$stackStr',
      type: 'crash',
    );

    // Deduplication Throttle Window
    if (_errorThrottleMap.containsKey(fingerprint)) {
      final lastTime = _errorThrottleMap[fingerprint]!;
      if (now.difference(lastTime) < _throttleWindow) {
        _errorRepeatCounts[fingerprint] =
            (_errorRepeatCounts[fingerprint] ?? 1) + 1;
        debugPrint(
          '🛡️ [TXALogger] Throttled duplicate $level: "$errorMessage"',
        );
        return;
      }
    }

    _errorThrottleMap[fingerprint] = now;
    final count = _errorRepeatCounts[fingerprint] ?? 1;
    _errorRepeatCounts[fingerprint] = 1;

    // Collect metadata
    final deviceInfo = await TXADeviceInfo.getRawDiagnosticData();
    final userSession = await _getEffectiveUserSession();
    final activeLang = TXALanguage.instance.currentLanguage;
    final activeFormat = TXAFormat.instance.aspectRatio;

    final logPayload = {
      'id': 'crash_${now.millisecondsSinceEpoch}',
      'level': level,
      'errorType': errorType,
      'errorMessage': errorMessage,
      'stackTrace': stackTrace?.toString() ?? 'No StackTrace Available',
      'contextDescription':
          contextDescription ?? 'General Application Execution',
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
      'userSession': userSession,
      'deviceInfo': deviceInfo,
      'timestamp': now.toIso8601String(),
    };

    _localErrorLogs.insert(0, logPayload);

    // Submit Log Payload to Supabase (skip UI layout overflows and transient realtime network timeouts)
    final isOverflowError =
        errorMessage.contains('overflowed') ||
        errorMessage.contains('RenderFlex');
    final isRealtimeTimeout =
        errorMessage.contains('RealtimeSubscribeException') ||
        errorMessage.contains('timedOut');
    if (!isOverflowError && !isRealtimeTimeout) {
      await _submitToSupabase(logPayload);
    }
  }

  /// Submit Crash/Error Log directly to Supabase txa_reports
  static Future<void> _submitToSupabase(Map<String, dynamic> logPayload) async {
    try {
      if (!TXASupabaseService.instance.isInitialized) {
        throw Exception('Supabase is not initialized');
      }
      final docId =
          logPayload['id'] as String? ??
          'crash_${DateTime.now().millisecondsSinceEpoch}';
      final userSession = logPayload['userSession'] is Map
          ? (logPayload['userSession'] as Map<String, dynamic>)
          : <String, dynamic>{};
      var username = userSession['username']?.toString() ?? 'anonymous';
      if (username == 'anonymous' || username.isEmpty) {
        final fallback = await _getEffectiveUserSession();
        username = fallback['username']?.toString() ?? 'anonymous';
      }
      final installId = userSession['installId']?.toString() ?? await TXADeviceInfo.getInstallationId();
      final postSender = username == 'anonymous' ? 'anonymous ($installId)' : username;

      final formattedCaption = _buildStructuredReportCaption(logPayload);

      await TXASupabaseService.instance.client.from('txa_reports').insert({
        'id': docId,
        'postId': null,
        'postid': null,
        'postSender': postSender,
        'postsender': postSender,
        'reporter': 'TXALogger',
        'status': 'pending',
        'photoPath': '',
        'photopath': '',
        'caption': formattedCaption,
        'createdTime':
            logPayload['timestamp'] ?? DateTime.now().toIso8601String(),
        'createdtime':
            logPayload['timestamp'] ?? DateTime.now().toIso8601String(),
      });
      debugPrint(
        '🔥 [TXALogger] Successfully submitted Crash log to Supabase! User: $postSender',
      );
    } catch (e) {
      debugPrint('❌ [TXALogger] Error submitting crash log to Supabase: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentQueue = prefs.getStringList(_keyCrashLogs) ?? [];
        currentQueue.add(jsonEncode(logPayload));
        await prefs.setStringList(_keyCrashLogs, currentQueue);
      } catch (_) {}
    }
  }

  /// Synchronize all pending offline logs to Supabase
  static Future<void> syncPendingLogs() async {
    try {
      if (!TXASupabaseService.instance.isInitialized) return;
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyCrashLogs) ?? [];
      if (list.isEmpty) return;

      final List<String> succeeded = [];
      for (var item in list) {
        try {
          final payload = Map<String, dynamic>.from(jsonDecode(item));
          final docId =
              payload['id'] as String? ??
              'crash_${DateTime.now().millisecondsSinceEpoch}';
          final userSession = payload['userSession'] is Map
              ? (payload['userSession'] as Map<String, dynamic>)
              : <String, dynamic>{};
          var username = userSession['username']?.toString() ?? 'anonymous';
          if (username == 'anonymous' || username.isEmpty) {
            final fallback = await _getEffectiveUserSession();
            username = fallback['username']?.toString() ?? 'anonymous';
          }
          final installId = userSession['installId']?.toString() ?? await TXADeviceInfo.getInstallationId();
          final postSender = username == 'anonymous' ? 'anonymous ($installId)' : username;

          final formattedCaption = _buildStructuredReportCaption(payload);

          await TXASupabaseService.instance.client.from('txa_reports').insert({
            'id': docId,
            'postId': null,
            'postid': null,
            'postSender': postSender,
            'postsender': postSender,
            'reporter': 'TXALogger',
            'status': 'pending',
            'photoPath': '',
            'photopath': '',
            'caption': formattedCaption,
            'createdTime':
                payload['timestamp'] ?? DateTime.now().toIso8601String(),
            'createdtime':
                payload['timestamp'] ?? DateTime.now().toIso8601String(),
          });
          succeeded.add(item);
        } catch (_) {
          break;
        }
      }

      if (succeeded.isNotEmpty) {
        final newQueue = list
            .where((item) => !succeeded.contains(item))
            .toList();
        await prefs.setStringList(_keyCrashLogs, newQueue);
        debugPrint(
          '🧹 [TXALogger] Synced and cleared ${succeeded.length} pending crash logs to Supabase.',
        );
      }
    } catch (_) {}
  }
}
