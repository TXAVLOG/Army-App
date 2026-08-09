import 'package:flutter/material.dart';
import '../services/txa_camera_theme_service.dart';

class TXATheme {
  // ─── Static const fallbacks (dùng khi chưa có theme) ───────────
  static const Color _defaultBackground = Color(0xFF0A0A0E);
  static const Color _defaultCardBg     = Color(0xFF16161C);
  static const Color _defaultCardBorder = Color(0xFF272732);

  static const Color primaryYellow = Color(0xFFFFC72C);
  static const Color actionBlue    = Color(0xFF2F80ED);
  static const Color statusGreen   = Color(0xFF27AE60);
  static const Color statusRed     = Color(0xFFEB5757);

  // ─── Dynamic getters — thay đổi theo camera theme & hệ thống sáng/tối ─────────────
  /// Màu chữ chính (chữ sậm ở Light mode, chữ trắng ở Dark mode)
  static Color get textPrimary {
    try {
      return TXACameraThemeService.instance.currentThemeData.textPrimary;
    } catch (_) {
      return const Color(0xFFFFFFFF);
    }
  }

  /// Màu chữ phụ
  static Color get textSecondary {
    try {
      return TXACameraThemeService.instance.currentThemeData.textSecondary;
    } catch (_) {
      return const Color(0xFFA1A1AA);
    }
  }

  /// Màu chữ mờ
  static Color get textMuted {
    try {
      return TXACameraThemeService.instance.currentThemeData.textMuted;
    } catch (_) {
      return const Color(0xFF71717A);
    }
  }

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
  static ThemeData get appTheme {
    final bg = background;
    final card = cardBg;
    final activeTheme = TXACameraThemeService.instance.currentThemeData;
    final isLight = activeTheme.id == 'system_light';
    final brightness = isLight ? Brightness.light : Brightness.dark;

    final primaryTextColor = textPrimary;
    final secondaryTextColor = textSecondary;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: accentColor,
      fontFamily: 'Outfit',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accentColor,
        onPrimary: isLight ? Colors.white : Colors.black,
        secondary: actionBlue,
        onSecondary: Colors.white,
        error: statusRed,
        onError: Colors.white,
        surface: card,
        onSurface: primaryTextColor,
      ),
      textTheme: (isLight ? ThemeData.light() : ThemeData.dark()).textTheme.apply(
            fontFamily: 'Outfit',
            bodyColor: primaryTextColor,
            displayColor: primaryTextColor,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryTextColor),
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: primaryTextColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: primaryTextColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: secondaryTextColor,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: isLight ? Colors.white : Colors.black,
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
          color: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF18181F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLight ? Colors.black.withAlpha(20) : Colors.white.withAlpha(45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isLight ? Colors.black12 : Colors.black87,
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: primaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Backward compat getter for darkTheme
  static ThemeData get darkTheme => appTheme;
}
