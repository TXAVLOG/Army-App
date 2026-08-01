import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'txa_auth_service.dart';

class TXAScreenSecurity {
  static final TXAScreenSecurity instance = TXAScreenSecurity._internal();
  TXAScreenSecurity._internal();

  static const _channel = MethodChannel('vn.army.txa/security');

  Future<void> init() async {
    // Lắng nghe sự kiện đăng nhập/đổi thông tin gói VIP để cập nhật bảo mật màn hình
    TXAAuthService.instance.addListener(_updateSecurity);
    _updateSecurity();
  }

  void dispose() {
    TXAAuthService.instance.removeListener(_updateSecurity);
  }

  void _updateSecurity() {
    final txaAuth = TXAAuthService.instance;
    final currentUser = txaAuth.currentUser;
    
    // Nếu là VIP (Gold Pass) hoặc Admin -> Cho phép chụp màn hình (clear FLAG_SECURE)
    // Nếu là Free -> Chặn chụp màn hình (add FLAG_SECURE)
    final isVip = currentUser?.isVipActive == true || currentUser?.role == 'admin';
    
    setScreenSecurity(!isVip);
  }

  Future<void> setScreenSecurity(bool enable) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('setScreenSecurity', {'enable': enable});
        debugPrint('TXAScreenSecurity: setScreenSecurity($enable) success');
      } catch (e) {
        debugPrint('TXAScreenSecurity error: $e');
      }
    }
  }
}
