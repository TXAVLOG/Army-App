import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TXACameraThemeData {
  final String id;
  final String name;
  final String icon;

  // ─── App-wide colors ─────────────────────────────
  final Color appBgColor;      // Nền toàn app (Scaffold background)
  final Color appCardBg;       // Nền card / bottom sheet / pill buttons
  final Color appCardBorder;   // Viền card nổi bật tương phản
  final Color textPrimary;     // Màu chữ chính
  final Color textSecondary;   // Màu chữ phụ
  final Color textMuted;       // Màu chữ mờ

  // ─── Camera-specific ─────────────────────────────
  final Color accentColor;      // Màu accent cho UI buttons, zoom, flash...
  final Color cameraBgColor;    // Màu nền khi camera chưa sẵn sàng
  final Color? overlayColor;    // Màu filter phủ lên camera preview (null = không có)
  final double overlayOpacity;
  final BoxDecoration frameDecoration; // Viền khung camera
  final Color? shutterBorderColor;
  final Color? shutterFillColor;
  final String? shutterInnerIcon;
  final String? samplePhotoUrl;

  const TXACameraThemeData({
    required this.id,
    required this.name,
    required this.icon,
    required this.appBgColor,
    required this.appCardBg,
    required this.appCardBorder,
    this.textPrimary = const Color(0xFFFFFFFF),
    this.textSecondary = const Color(0xFFA1A1AA),
    this.textMuted = const Color(0xFF71717A),
    required this.accentColor,
    required this.cameraBgColor,
    this.overlayColor,
    this.overlayOpacity = 0.12,
    required this.frameDecoration,
    this.shutterBorderColor,
    this.shutterFillColor,
    this.shutterInnerIcon,
    this.samplePhotoUrl,
  });

  // Backward compat
  Color get bgColor => cameraBgColor;
}

class TXACameraThemeService extends ChangeNotifier {
  static final TXACameraThemeService instance = TXACameraThemeService._internal();

  TXACameraThemeService._internal() {
    // Tự động lắng nghe khi hệ thống chuyển đổi Sáng/Tối (Light/Dark mode)
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      if (_currentTheme == 'default' || _currentTheme == 'system') {
        notifyListeners();
      }
    };
  }

  static const String _keyTheme = 'txa_camera_theme_name';

  String _currentTheme = 'default';
  String get currentTheme => _currentTheme;

  // ─── Theme Hệ Thống (Light & Dark Fallback) ────────────────────────────────

  static const TXACameraThemeData systemDarkTheme = TXACameraThemeData(
    id: 'system_dark',
    name: 'Mặc định (Tối)',
    icon: '🌙',
    appBgColor:      Color(0xFF141318),
    appCardBg:       Color(0xFF222129),
    appCardBorder:   Color(0xFFFFC72C),
    accentColor:     Color(0xFFFFC72C),
    cameraBgColor:   Color(0xFF222129),
    overlayColor:    null,
    frameDecoration: BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(28)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFFFFC72C), width: 3.5)),
      boxShadow: [
        BoxShadow(color: Color(0x66FFC72C), blurRadius: 18, spreadRadius: 1),
      ],
    ),
    shutterBorderColor: Color(0xFFFFC72C),
    shutterFillColor: Color(0xFFFFFFFF),
    samplePhotoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=600&auto=format&fit=crop',
  );

  static const TXACameraThemeData systemLightTheme = TXACameraThemeData(
    id: 'system_light',
    name: 'Mặc định (Sáng)',
    icon: '☀️',
    appBgColor:      Color(0xFFF3F4F8),
    appCardBg:       Color(0xFFFFFFFF),
    appCardBorder:   Color(0xFF2563EB),
    textPrimary:     Color(0xFF0F172A),
    textSecondary:   Color(0xFF475569),
    textMuted:       Color(0xFF94A3B8),
    accentColor:     Color(0xFF2563EB),
    cameraBgColor:   Color(0xFFE2E8F0),
    overlayColor:    null,
    frameDecoration: BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(28)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFF2563EB), width: 3.5)),
      boxShadow: [
        BoxShadow(color: Color(0x442563EB), blurRadius: 16, spreadRadius: 1),
      ],
    ),
    shutterBorderColor: Color(0xFF2563EB),
    shutterFillColor: Color(0xFF2563EB),
    shutterInnerIcon: '📸',
    samplePhotoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=600&auto=format&fit=crop',
  );

  // ─── Danh sách chủ đề ───────────────────────────────────────────────────────
  static const List<TXACameraThemeData> themes = [

    // 0. Default — Sáng / Tối tự động theo hệ thống
    TXACameraThemeData(
      id: 'default',
      name: 'Mặc định (Hệ thống)',
      icon: '🌓',
      appBgColor:      Color(0xFF141318),
      appCardBg:       Color(0xFF222129),
      appCardBorder:   Color(0xFFFFC72C),
      accentColor:     Color(0xFFFFC72C),
      cameraBgColor:   Color(0xFF222129),
      overlayColor:    null,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFFFC72C), width: 3.5)),
        boxShadow: [
          BoxShadow(color: Color(0x66FFC72C), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      shutterBorderColor: Color(0xFFFFC72C),
      shutterFillColor: Color(0xFFFFFFFF),
      samplePhotoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=600&auto=format&fit=crop',
    ),

    // 1. Classic — Xám Titanium sang trọng, viền bạc nổi bật
    TXACameraThemeData(
      id: 'classic',
      name: 'Classic Slate',
      icon: '📷',
      appBgColor:      Color(0xFF16161D),
      appCardBg:       Color(0xFF23232C),
      appCardBorder:   Color(0xFF6B7280),
      accentColor:     Color(0xFFFFFFFF),
      cameraBgColor:   Color(0xFF23232C),
      overlayColor:    null,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFFFFFFF), width: 3.5)),
        boxShadow: [
          BoxShadow(color: Color(0x55FFFFFF), blurRadius: 16, spreadRadius: 1),
        ],
      ),
      shutterBorderColor: Color(0xFFFFFFFF),
      shutterFillColor: Color(0xFF383848),
      samplePhotoUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=600&auto=format&fit=crop',
    ),

    // 2. Gold — Nền nâu ấm hoàng kim, card nâu đậm, viền vàng glow rực rỡ
    TXACameraThemeData(
      id: 'gold',
      name: 'Locket Gold',
      icon: '👑',
      appBgColor:      Color(0xFF1A1300),
      appCardBg:       Color(0xFF2B2000),
      appCardBorder:   Color(0xFFFFD700),
      accentColor:     Color(0xFFFFC72C),
      cameraBgColor:   Color(0xFF2B2000),
      overlayColor:    Color(0xFFFFC72C),
      overlayOpacity:  0.10,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFFFD700), width: 3.5)),
        boxShadow: [
          BoxShadow(color: Color(0x88FFD700), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      shutterBorderColor: Color(0xFFFFD700),
      shutterFillColor: Color(0xFFFFD666),
      shutterInnerIcon: '👑',
      samplePhotoUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?q=80&w=600&auto=format&fit=crop',
    ),

    // 3. Neon Pink — Nền tím hồng Cyber, viền hồng neon phát sáng
    TXACameraThemeData(
      id: 'pink',
      name: 'Neon Pink',
      icon: '🌸',
      appBgColor:      Color(0xFF1C0022),
      appCardBg:       Color(0xFF2D0037),
      appCardBorder:   Color(0xFFFF69B4),
      accentColor:     Color(0xFFFF69B4),
      cameraBgColor:   Color(0xFF2D0037),
      overlayColor:    Color(0xFFFF69B4),
      overlayOpacity:  0.10,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFFF69B4), width: 3.5)),
        boxShadow: [
          BoxShadow(color: Color(0x88FF69B4), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      shutterBorderColor: Color(0xFFFF69B4),
      shutterFillColor: Color(0xFFFFB3D9),
      shutterInnerIcon: '💖',
      samplePhotoUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?q=80&w=600&auto=format&fit=crop',
    ),

    // 4. Cyber Blue — Nền xanh đêm Cyber, viền neon Cyan điện quang
    TXACameraThemeData(
      id: 'cyber',
      name: 'Cyber Blue',
      icon: '🔵',
      appBgColor:      Color(0xFF001124),
      appCardBg:       Color(0xFF001D3D),
      appCardBorder:   Color(0xFF00E5FF),
      accentColor:     Color(0xFF00E5FF),
      cameraBgColor:   Color(0xFF001D3D),
      overlayColor:    Color(0xFF00BFFF),
      overlayOpacity:  0.10,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFF00E5FF), width: 3.5)),
        boxShadow: [
          BoxShadow(color: Color(0x8800E5FF), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      shutterBorderColor: Color(0xFF00E5FF),
      shutterFillColor: Color(0xFF80F3FF),
      shutterInnerIcon: '⚡️',
      samplePhotoUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=600&auto=format&fit=crop',
    ),

    // 5. Sunset — Nền cam hoàng hôn đất rực rỡ, viền cam lửa tương phản cao
    TXACameraThemeData(
      id: 'sunset',
      name: 'Sunset Orange',
      icon: '🌅',
      appBgColor:      Color(0xFF220800),
      appCardBg:       Color(0xFF380E00),
      appCardBorder:   Color(0xFFFF6B35),
      accentColor:     Color(0xFFFF6B35),
      cameraBgColor:   Color(0xFF380E00),
      overlayColor:    Color(0xFFFF6B35),
      overlayOpacity:  0.10,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFFF6B35), width: 3.5)),
        boxShadow: [
          BoxShadow(color: Color(0x88FF6B35), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      shutterBorderColor: Color(0xFFFF6B35),
      shutterFillColor: Color(0xFFFFB399),
      shutterInnerIcon: '🔥',
      samplePhotoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=600&auto=format&fit=crop',
    ),

    // 6. Emerald Mint — Nền xanh lục bảo đậm, viền bạc hà phát sáng
    TXACameraThemeData(
      id: 'emerald',
      name: 'Emerald Mint',
      icon: '🌿',
      appBgColor:      Color(0xFF021B10),
      appCardBg:       Color(0xFF052E1B),
      appCardBorder:   Color(0xFF00E676),
      accentColor:     Color(0xFF00E676),
      cameraBgColor:   Color(0xFF052E1B),
      overlayColor:    Color(0xFF00E676),
      overlayOpacity:  0.10,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFF00E676), width: 3.5)),
        boxShadow: [
          BoxShadow(color: Color(0x8800E676), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      shutterBorderColor: Color(0xFF00E676),
      shutterFillColor: Color(0xFFB3FFD6),
      shutterInnerIcon: '🌱',
      samplePhotoUrl: 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?q=80&w=600&auto=format&fit=crop',
    ),

    // 7. Stealth Dark — Đen tuyền tuyệt đối OLED, viền bạc metallic tương phản
    TXACameraThemeData(
      id: 'dark',
      name: 'Stealth Dark',
      icon: '🖤',
      appBgColor:      Color(0xFF000000),
      appCardBg:       Color(0xFF101014),
      appCardBorder:   Color(0xFF8A99AD),
      accentColor:     Color(0xFF8A99AD),
      cameraBgColor:   Color(0xFF101014),
      overlayColor:    null,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFF8A99AD), width: 3.0)),
        boxShadow: [
          BoxShadow(color: Color(0x668A99AD), blurRadius: 16, spreadRadius: 1),
        ],
      ),
      shutterBorderColor: Color(0xFF8A99AD),
      shutterFillColor: Color(0xFF262E3B),
      shutterInnerIcon: '🖤',
      samplePhotoUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=600&auto=format&fit=crop',
    ),

    // 8. Tết Theme — Nền đỏ sậm Tết, viền vàng kim, nút chụp màu đỏ viền vàng với emoji tết 🧧
    TXACameraThemeData(
      id: 'tet',
      name: 'Tết Nguyên Đán',
      icon: '🧧',
      appBgColor:      Color(0xFF2A0303),
      appCardBg:       Color(0xFF450606),
      appCardBorder:   Color(0xFFFFD700),
      accentColor:     Color(0xFFFFD700),
      cameraBgColor:   Color(0xFF450606),
      overlayColor:    Color(0xFFD32F2F),
      overlayOpacity:  0.10,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFFFD700), width: 3.5)),
        boxShadow: [
          BoxShadow(color: Color(0x88FFD700), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      shutterBorderColor: Color(0xFFFFD700),
      shutterFillColor: Color(0xFFD32F2F),
      shutterInnerIcon: '🧧',
      samplePhotoUrl: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?q=80&w=600&auto=format&fit=crop',
    ),

    // 9. 30/4 Theme — Nền đỏ quốc kỳ, viền vàng ngôi sao ⭐️
    TXACameraThemeData(
      id: 'national',
      name: 'Giải Phóng 30/4',
      icon: '⭐️',
      appBgColor:      Color(0xFF2E0000),
      appCardBg:       Color(0xFF4A0000),
      appCardBorder:   Color(0xFFFFEE58),
      accentColor:     Color(0xFFFFEE58),
      cameraBgColor:   Color(0xFF4A0000),
      overlayColor:    Color(0xFFE53935),
      overlayOpacity:  0.10,
      frameDecoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFFFEE58), width: 3.5)),
        boxShadow: [
          BoxShadow(color: Color(0x88FFEE58), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      shutterBorderColor: Color(0xFFFFEE58),
      shutterFillColor: Color(0xFFD32F2F),
      shutterInnerIcon: '⭐️',
      samplePhotoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=600&auto=format&fit=crop',
    ),
  ];

  // ─── Getters ─────────────────────────────────────────────────────────────────

  /// Danh sách map để UI dùng (tương thích ngược)
  List<Map<String, dynamic>> get availableThemes => themes.map((t) => {
    'id': t.id,
    'name': t.name,
    'icon': t.icon,
    'color': t.accentColor.toARGB32(),
  }).toList();

  TXACameraThemeData get currentThemeData {
    if (_currentTheme == 'default' || _currentTheme == 'system') {
      final isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      return isDark ? systemDarkTheme : systemLightTheme;
    }
    return themes.firstWhere((t) => t.id == _currentTheme, orElse: () => systemDarkTheme);
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_keyTheme);
    if (savedTheme == null) {
      _currentTheme = 'default';
    } else {
      _currentTheme = savedTheme;
    }
    notifyListeners();
  }

  Future<void> setTheme(String themeId) async {
    if (themeId == 'default' || themes.any((t) => t.id == themeId)) {
      _currentTheme = themeId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTheme, themeId);
      notifyListeners();
    }
  }

  // ─── Backward compat helpers ─────────────────────────────────────────────────
  BoxDecoration getFrameDecoration() => currentThemeData.frameDecoration;
  Color getAccentColor()             => currentThemeData.accentColor;
  Color getBgColor()                 => currentThemeData.cameraBgColor;

  /// Widget overlay phủ lên CameraPreview
  Widget? buildOverlay() {
    final data = currentThemeData;
    if (data.overlayColor == null) return null;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: data.overlayColor!.withValues(alpha: data.overlayOpacity),
        ),
      ),
    );
  }
}

