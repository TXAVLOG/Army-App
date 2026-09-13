import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'txa_config.dart';
import 'txa_logger.dart';
import 'txa_language.dart';

class TXASupabaseService {
  static final TXASupabaseService instance = TXASupabaseService._internal();
  TXASupabaseService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _lastError;
  String? get lastError => _lastError;

  SupabaseClient get client => Supabase.instance.client;

  SupabaseClient? get safeClient {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Trả về trạng thái kết nối Supabase bản địa hoá theo ngôn ngữ người dùng
  String getStatusMessage() {
    final txaLang = TXALanguage.instance;
    return _isInitialized
        ? txaLang.getText('supabase_connected')
        : txaLang.getText('supabase_connect_failed');
  }

  Future<void> init() async {
    try {
      await Supabase.initialize(
        url: TXAConfig.supabaseUrl,
        publishableKey: TXAConfig.supabaseAnonKey,
      );
      _isInitialized = true;
      _lastError = null;
      debugPrint('⚡ Supabase initialized successfully!');
      TXALogger.logApp('⚡ [TXASupabaseService] Khởi tạo Supabase thành công! URL: ${TXAConfig.supabaseUrl}');
    } catch (e, stack) {
      _isInitialized = false;
      _lastError = e.toString();
      debugPrint('❌ Supabase initialization error: $e');
      TXALogger.logError('❌ [TXASupabaseService] Lỗi khởi tạo Supabase: $e', stackTrace: stack);
    }
  }
}
