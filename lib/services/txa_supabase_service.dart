import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'txa_config.dart';

class TXASupabaseService {
  static final TXASupabaseService instance = TXASupabaseService._internal();
  TXASupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  Future<void> init() async {
    try {
      await Supabase.initialize(
        url: TXAConfig.supabaseUrl,
        publishableKey: TXAConfig.supabaseAnonKey,
      );
      debugPrint('⚡ Supabase initialized successfully!');
    } catch (e) {
      debugPrint('❌ Supabase initialization error: $e');
    }
  }
}
