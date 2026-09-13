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
          if (context != null && context.mounted) {
            TXAToast.show(
              context,
              TXALanguage.instance.getText('update_downloading'),
              icon: Icons.cloud_download_rounded,
            );
          }

          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e, stack) {
      final errStr = e.toString();
      // Bỏ qua lỗi không cài từ Play Store (-10: ERROR_APP_NOT_OWNED)
      if (errStr.contains('ERROR_APP_NOT_OWNED') || errStr.contains('-10')) {
        TXALogger.logInfo('In-App Update skipped: App is not installed via Play Store.');
        return;
      }
      TXALogger.logError(e, stackTrace: stack, extraInfo: {'service': 'TXAInAppUpdateService'});
    }
  }
}
