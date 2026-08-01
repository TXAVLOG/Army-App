import 'package:flutter/material.dart';
import '../services/txa_camera_theme_service.dart';

class TXATheme {
  // ─── Static const fallbacks (dùng khi chưa có theme) ───────────
  static const Color _defaultBackground = Color(0xFF151419);
  static const Color _defaultCardBg     = Color(0xFF212026);
  static const Color _defaultCardBorder = Color(0xFF2F2D3A);

  static const Color primaryYellow = Color(0xFFFFC72C);
  static const Color actionBlue    = Color(0xFF2F80ED);
  static const Color statusGreen   = Color(0xFF27AE60);
  static const Color statusRed     = Color(0xFFEB5757);
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted     = Color(0xFF71717A);

  // ─── Dynamic getters — thay đổi theo camera theme ─────────────
  /// Màu nền chính của toàn app
  static Color get background {
    try {
      return TXACameraThemeService.instance.currentThemeData.appBgColor;
    } catch (_) {
      return _defaultBackground;
    }
  }

  /// Màu nền card / bottom sheet
  static Color get cardBg {
    try {
      return TXACameraThemeService.instance.currentThemeData.appCardBg;
    } catch (_) {
      return _defaultCardBg;
    }
  }

  /// Màu viền card
  static Color get cardBorder {
    try {
      return TXACameraThemeService.instance.currentThemeData.appCardBorder;
    } catch (_) {
      return _defaultCardBorder;
    }
  }

  /// Màu accent chủ đạo theo theme
  static Color get accentColor {
    try {
      return TXACameraThemeService.instance.currentThemeData.accentColor;
    } catch (_) {
      return primaryYellow;
    }
  }

  // ─── ThemeData ─────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final bg = background;
    final card = cardBg;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: primaryYellow,
      fontFamily: 'Outfit',
      colorScheme: ColorScheme.dark(
        primary: primaryYellow,
        secondary: actionBlue,
        surface: card,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'Outfit',
            bodyColor: textPrimary,
            displayColor: textPrimary,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF18181F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(45), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 12,
              spreadRadius: 1,
              offset: Offset(0, 4),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
