import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import '../services/txa_version.dart';
import '../services/txa_language.dart';

class TXADeviceInfo {
  /// Check if the device is Rooted (Android) or Jailbroken (iOS)
  static Future<bool> checkIsRootedOrJailbroken() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        // 1. Check Android build tags for test-keys
        final deviceInfoPlugin = DeviceInfoPlugin();
        final androidInfo = await deviceInfoPlugin.androidInfo;
        if (androidInfo.tags.contains('test-keys')) return true;

        // 2. Check common Android Root SU binary locations
        final rootPaths = [
          '/system/app/Superuser.apk',
          '/sbin/su',
          '/system/bin/su',
          '/system/xbin/su',
          '/data/local/xbin/su',
          '/data/local/bin/su',
          '/system/sd/xbin/su',
          '/system/bin/failsafe/su',
          '/data/local/su',
          '/su/bin/su',
          '/magisk/.core/bin/su',
        ];
        for (final path in rootPaths) {
          if (File(path).existsSync()) return true;
        }
      } else if (Platform.isIOS) {
        // Check common iOS Jailbreak paths and apps
        final jbPaths = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
          '/private/var/lib/apt',
          '/private/var/lib/cydia',
          '/private/var/mobile/Library/SBSettings/Themes',
          '/Applications/Sileo.app',
          '/Applications/Zebra.app',
          '/var/binpack',
          '/Applications/FlyJB.app',
        ];
        for (final path in jbPaths) {
          if (File(path).existsSync()) return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Fetch comprehensive hardware, system, root status and diagnostic metadata
  static Future<Map<String, String>> getDiagnosticMetadata() async {
    final txaLang = TXALanguage.instance;
    final Map<String, String> specs = {};

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();

      // 1. Check Root / Jailbreak Status
      final isRooted = await checkIsRootedOrJailbroken();
      specs[txaLang.getText('diag_root_jb')] = isRooted
          ? txaLang.getText('diag_root_warning')
          : txaLang.getText('diag_root_safe');

      // 2. Screen resolution & pixel ratio
      try {
        final views = PlatformDispatcher.instance.views;
        if (views.isNotEmpty) {
          final view = views.first;
          final size = view.physicalSize;
          final ratio = view.devicePixelRatio;
          final dpWidth = (size.width / ratio).round();
          final dpHeight = (size.height / ratio).round();
          specs[txaLang.getText('diag_screen')] = '${size.width.toInt()}x${size.height.toInt()} px (${dpWidth}x$dpHeight dp @${ratio.toStringAsFixed(1)}x)';
        }
      } catch (_) {}

      // 3. Timezone, Locale & Processors
      final now = DateTime.now();
      final timeZone = now.timeZoneName;
      final timeOffset = now.timeZoneOffset;
      final offsetHours = timeOffset.inHours.toString().padLeft(2, '0');
      final offsetMins = (timeOffset.inMinutes % 60).abs().toString().padLeft(2, '0');
      final sign = timeOffset.isNegative ? '-' : '+';
      specs[txaLang.getText('diag_timezone')] = '$timeZone (UTC$sign$offsetHours:$offsetMins)';
      specs[txaLang.getText('diag_locale')] = Platform.localeName;
      specs[txaLang.getText('diag_cpu_cores')] = '${Platform.numberOfProcessors} Cores';

      // 4. Battery Level & Status
      try {
        final battery = Battery();
        final batteryLevel = await battery.batteryLevel;
        final batteryState = await battery.batteryState;
        final isCharging = batteryState == BatteryState.charging || batteryState == BatteryState.full;
        final chargingText = isCharging ? txaLang.getText('diag_battery_charging') : txaLang.getText('diag_battery_discharging');
        specs[txaLang.getText('diag_battery')] = '$batteryLevel% ($chargingText)';
      } catch (_) {
        specs[txaLang.getText('diag_battery')] = txaLang.getText('diag_battery_na');
      }

      // 5. OS & Hardware Specifications
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        specs[txaLang.getText('diag_platform_os')] = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        specs[txaLang.getText('diag_device')] = '${androidInfo.manufacturer.toUpperCase()} ${androidInfo.model} (${androidInfo.device})';
        specs[txaLang.getText('diag_brand')] = androidInfo.brand.toUpperCase();
        specs[txaLang.getText('diag_board_hw')] = '${androidInfo.board} / ${androidInfo.hardware}';
        specs['Fingerprint'] = androidInfo.fingerprint;
        specs[txaLang.getText('diag_build_id')] = androidInfo.display;
        specs[txaLang.getText('diag_device_type')] = androidInfo.isPhysicalDevice
            ? txaLang.getText('diag_physical_device')
            : txaLang.getText('diag_emulator');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        specs[txaLang.getText('diag_platform_os')] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        specs[txaLang.getText('diag_device')] = '${iosInfo.name} (${iosInfo.utsname.machine})';
        specs['Model'] = iosInfo.model;
        specs[txaLang.getText('diag_device_type')] = iosInfo.isPhysicalDevice
            ? txaLang.getText('diag_physical_device')
            : txaLang.getText('diag_emulator');
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfoPlugin.windowsInfo;
        specs[txaLang.getText('diag_platform_os')] = 'Windows ${windowsInfo.productName} (Build ${windowsInfo.buildNumber})';
        specs[txaLang.getText('diag_device')] = windowsInfo.computerName;
        specs[txaLang.getText('diag_ram')] = '${(windowsInfo.systemMemoryInMegabytes / 1024).toStringAsFixed(1)} GB RAM';
        specs[txaLang.getText('diag_cpu_cores')] = '${windowsInfo.numberOfCores} Cores';
      } else {
        specs[txaLang.getText('diag_platform_os')] = Platform.operatingSystem;
      }

      // 6. Application Version & Metadata
      specs[txaLang.getText('diag_app_name')] = TXAVersion.appName;
      specs[txaLang.getText('diag_app_version')] = TXAVersion.currentVersion;
      specs[txaLang.getText('diag_build_code')] = '${TXAVersion.buildNumber}';
      specs[txaLang.getText('diag_full_version')] = TXAVersion.fullVersionString;
      specs[txaLang.getText('diag_release_date')] = TXAVersion.releaseDate;
    } catch (e) {
      specs[txaLang.getText('diag_collect_error')] = e.toString();
    }

    return specs;
  }

  /// Generate a unified, rich diagnostic header for copying logs or exporting
  static Future<String> getFormattedHeader({
    required String logType,
    required String timestamp,
    String status = 'SUCCESS',
  }) async {
    final txaLang = TXALanguage.instance;
    final specs = await getDiagnosticMetadata();
    final buffer = StringBuffer();

    buffer.writeln('=========================================');
    buffer.writeln('📋 ${txaLang.getText('diag_title')}');
    buffer.writeln('=========================================');
    buffer.writeln('• ${txaLang.getText('diag_log_type')}: ${logType.toUpperCase()}');
    buffer.writeln('• ${txaLang.getText('diag_recorded_time')}: $timestamp');
    buffer.writeln('• ${txaLang.getText('diag_status')}: $status');
    buffer.writeln('-----------------------------------------');
    buffer.writeln('📱 ${txaLang.getText('diag_device_hardware')}');
    specs.forEach((key, value) {
      buffer.writeln('  - $key: $value');
    });
    buffer.writeln('-----------------------------------------');

    return buffer.toString();
  }
}
