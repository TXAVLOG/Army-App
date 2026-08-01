import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import '../widgets/txa_toast.dart';
import '../main.dart';
import 'txa_language.dart';
import 'package:flutter/material.dart';
import 'txa_logger.dart';

class TXAInAppUpdateService {
  static final TXAInAppUpdateService instance = TXAInAppUpdateService._internal();
  TXAInAppUpdateService._internal();

  Future<void> checkForUpdates() async {
    if (kIsWeb || !Platform.isAndroid) {
      TXALogger.logInfo('In-App Update only supported on Android.', extraInfo: {'service': 'TXAInAppUpdateService'});
      return;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          // Perform immediate update (force fullscreen Play Store UI)
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          // Perform flexible update (download in background)
          await InAppUpdate.startFlexibleUpdate();
          
          final context = navigatorKey.currentContext;
          if (context != null) {
            TXAToast.show(
              context,
              TXALanguage.instance.getText('update_downloading') ?? '📥 Đang tải bản cập nhật mới trong nền...',
              icon: Icons.cloud_download_rounded,
            );
          }

          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e, stack) {
      TXALogger.logError(e, stackTrace: stack, extraInfo: {'service': 'TXAInAppUpdateService'});
    }
  }
}
