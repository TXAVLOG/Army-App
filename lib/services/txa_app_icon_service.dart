import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_auth_service.dart';
import 'txa_achievement_service.dart';
import 'txa_language.dart';
import 'txa_festival_manager.dart';

import 'package:flutter/services.dart';
import 'txa_logger.dart';

class TXAIconChangeResult {
  final bool success;
  final String iconId;
  final String? errorMessage;
  final String? appliedAlias;

  const TXAIconChangeResult({
    required this.success,
    required this.iconId,
    this.errorMessage,
    this.appliedAlias,
  });
}

class TXAAppIconItem {
  final String id;
  final String nameVi;
  final String nameEn;
  final String emoji;
  final String assetPath;
  final List<Color> gradient;
  final bool isVip;
  final String badge;

  const TXAAppIconItem({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    required this.emoji,
    required this.assetPath,
    required this.gradient,
    this.isVip = false,
    this.badge = '',
  });

  String getName(bool isVi) => isVi ? nameVi : nameEn;
}

class TXAAppIconService extends ChangeNotifier {
  static final TXAAppIconService instance = TXAAppIconService._internal();

  TXAAppIconService._internal() {
    _loadSelectedIcon();
  }

  static const String _keySelectedIcon = 'txa_selected_app_icon_id';
  static const MethodChannel _channel = MethodChannel('vn.army.txa/app_icon');

  String _selectedIconId = 'default_gold';
  String get selectedIconId => _selectedIconId;

  final Map<String, DateTime> _adUnlockedUntil = {};

  static const List<TXAAppIconItem> icons = [
    // ─── Special Festival Icons (Lễ Hội Đặc Biệt) ─────────────
    TXAAppIconItem(
      id: 'national_day_29',
      nameVi: 'Quốc Khánh 2/9 🇻🇳',
      nameEn: 'Vietnam National Day 🇻🇳',
      emoji: '🇻🇳',
      assetPath: 'assets/icons/army_vietnam_flag_vip.png',
      gradient: [Color(0xFFD32F2F), Color(0xFFFFC72C)],
      isVip: false, // Miễn phí cho toàn thể người dùng
      badge: 'LỄ HỘI',
    ),

    // ─── Free Starter Icons (5 Mẫu) ───────────────────────────
    TXAAppIconItem(
      id: 'default_gold',
      nameVi: 'Army Cổ Điển',
      nameEn: 'Army Classic Gold',
      emoji: '🌟',
      assetPath: 'assets/icons/armi_classic_gold.png',
      gradient: [Color(0xFFFFD700), Color(0xFFFF8C00)],
      badge: 'GỐC',
    ),
    TXAAppIconItem(
      id: 'midnight_dark',
      nameVi: 'Bóng Đêm Stealth',
      nameEn: 'Stealth Black',
      emoji: '🖤',
      assetPath: 'assets/icons/armi_stealth_black.png',
      gradient: [Color(0xFF2C3E50), Color(0xFF000000)],
      badge: 'DARK',
    ),
    TXAAppIconItem(
      id: 'cyberpunk_neon',
      nameVi: 'Cyberpunk Neon',
      nameEn: 'Cyberpunk Neon',
      emoji: '⚡',
      assetPath: 'assets/icons/army_cyber_neon_vip.png',
      gradient: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
      badge: 'NEON',
    ),
    TXAAppIconItem(
      id: 'sakura_pink',
      nameVi: 'Hoa Anh Đào',
      nameEn: 'Sakura Blossom',
      emoji: '🌸',
      assetPath: 'assets/icons/army_sakura_blossom_vip.png',
      gradient: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
      badge: 'CUTE',
    ),
    TXAAppIconItem(
      id: 'ocean_breeze',
      nameVi: 'Đại Dương Xanh',
      nameEn: 'Ocean Breeze',
      emoji: '🌊',
      assetPath: 'assets/icons/armi_ocean_blue.png',
      gradient: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
      badge: 'COOL',
    ),

    // ─── VIP Premium 3D Icons (20 Mẫu) ──────────────────────
    TXAAppIconItem(
      id: 'sunset_glow',
      nameVi: 'Hoàng Hôn Rực Rỡ',
      nameEn: 'Sunset Glow',
      emoji: '🌅',
      assetPath: 'assets/icons/army_sunset_gradient_vip.png',
      gradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'matrix_matrix',
      nameVi: 'Xanh Bạc Hà Mint',
      nameEn: 'Mint Green',
      emoji: '💚',
      assetPath: 'assets/icons/armi_mint_green.png',
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'fire_dragon',
      nameVi: 'Rồng Đỏ Thiêng',
      nameEn: 'Sacred Red Dragon',
      emoji: '🐉',
      assetPath: 'assets/icons/army_red_dragon_vip.png',
      gradient: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'galaxy_cosmic',
      nameVi: 'Vũ Trụ Galaxy',
      nameEn: 'Galaxy Cosmic',
      emoji: '🌌',
      assetPath: 'assets/icons/army_space_galaxy_vip.png',
      gradient: [Color(0xFF8A2387), Color(0xFFE94057)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'frost_ice',
      nameVi: 'Băng Giá Cực Bắc',
      nameEn: 'Frost Winter Ice',
      emoji: '❄️',
      assetPath: 'assets/icons/army_winter_ice_vip.png',
      gradient: [Color(0xFF83A4D4), Color(0xFFB6FBFF)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'emerald_gem',
      nameVi: 'Thông Giáng Sinh',
      nameEn: 'Christmas Pine',
      emoji: '🎄',
      assetPath: 'assets/icons/army_christmas_pine_vip.png',
      gradient: [Color(0xFF0BA360), Color(0xFF3CBA92)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'ruby_luxury',
      nameVi: 'Trái Tim Tình Yêu',
      nameEn: 'Love Neon Pink',
      emoji: '💖',
      assetPath: 'assets/icons/army_love_pink_vip.png',
      gradient: [Color(0xFF93291E), Color(0xFFED213A)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'amethyst_purple',
      nameVi: 'Tím Đêm Huyền Ảo',
      nameEn: 'Midnight Purple',
      emoji: '🍇',
      assetPath: 'assets/icons/army_midnight_purple_vip.png',
      gradient: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'retro_synthwave',
      nameVi: 'GameBoy Cổ Điển',
      nameEn: 'Retro GameBoy',
      emoji: '🎮',
      assetPath: 'assets/icons/army_retro_gameboy_vip.png',
      gradient: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'matcha_zen',
      nameVi: 'Rằn Ri Quân Đội 🇻🇳',
      nameEn: 'Military Camo 🇻🇳',
      emoji: '🛡️',
      assetPath: 'assets/icons/army_military_camo_vip.png',
      gradient: [Color(0xFF56AB2F), Color(0xFFA8E063)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'phantom_ghost',
      nameVi: 'Trắng Tinh Khôi',
      nameEn: 'Clean White',
      emoji: '🤍',
      assetPath: 'assets/icons/armi_clean_white.png',
      gradient: [Color(0xFF434343), Color(0xFF000000)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'golden_king',
      nameVi: 'Vương Giả Hoàng Gia 👑',
      nameEn: 'Imperial Gold 👑',
      emoji: '👑',
      assetPath: 'assets/icons/army_imperial_gold_vip.png',
      gradient: [Color(0xFFBF953F), Color(0xFFFCF6BA)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'diamond_ultra',
      nameVi: 'Bạch Kim Lấp Lánh 💎',
      nameEn: 'Diamond Platinum 💎',
      emoji: '💎',
      assetPath: 'assets/icons/army_diamond_platinum_vip.png',
      gradient: [Color(0xFF00C6FF), Color(0xFF0072FF)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'blood_moon',
      nameVi: 'Bí Ngô Halloween 🎃',
      nameEn: 'Spooky Halloween 🎃',
      emoji: '🎃',
      assetPath: 'assets/icons/army_spooky_halloween_vip.png',
      gradient: [Color(0xFFCB2D3E), Color(0xFFEF473A)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'aurora_lights',
      nameVi: 'Ngân Hà Starlight 💫',
      nameEn: 'Starlight Neon 💫',
      emoji: '💫',
      assetPath: 'assets/icons/army_starlight_neon_vip.png',
      gradient: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'space_blackhole',
      nameVi: '3D Hologram Siêu Thực',
      nameEn: '3D Holographic',
      emoji: '🌌',
      assetPath: 'assets/icons/army_holographic_3d_vip.png',
      gradient: [Color(0xFF0F2027), Color(0xFF2C5364)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'coffee_caramel',
      nameVi: 'Cà Phê Đậm Đà ☕',
      nameEn: 'Roasted Coffee ☕',
      emoji: '☕',
      assetPath: 'assets/icons/army_coffee_roast_vip.png',
      gradient: [Color(0xFFBA8B02), Color(0xFF181818)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'neon_toxic',
      nameVi: 'Sân Cỏ Vô Địch ⚽',
      nameEn: 'Champion Football ⚽',
      emoji: '⚽',
      assetPath: 'assets/icons/army_champion_football_vip.png',
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'quantum_portal',
      nameVi: 'Giai Điệu Âm Nhạc 🎵',
      nameEn: 'Music Beats 🎵',
      emoji: '🎵',
      assetPath: 'assets/icons/army_music_beats_vip.png',
      gradient: [Color(0xFF4776E6), Color(0xFF8E54E9)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'infinity_titan',
      nameVi: 'Linh Vật Armi Vàng 🦊',
      nameEn: 'Golden Armi Mascot 🦊',
      emoji: '🦊',
      assetPath: 'assets/icons/army_golden_ant_vip.png',
      gradient: [Color(0xFFFF007A), Color(0xFF7928CA)],
      isVip: true,
      badge: 'VIP',
    ),
  ];

  TXAAppIconItem get currentIcon =>
      icons.firstWhere((icon) => icon.id == _selectedIconId, orElse: () => icons.first);

  bool isIconUnlocked(TXAAppIconItem item) {
    if (!item.isVip) return true;
    final isVip = TXAAuthService.instance.currentUser?.isVipCurrentlyActive ?? false;
    if (isVip) return true;
    final expiry = _adUnlockedUntil[item.id];
    if (expiry != null && DateTime.now().isBefore(expiry)) {
      return true;
    }
    return false;
  }

  /// Trả về số ngày còn lại nếu icon mở khóa qua Ads, null nếu mở vĩnh viễn hoặc chưa mở
  int? getAdRemainingDays(String iconId) {
    final isVip = TXAAuthService.instance.currentUser?.isVipCurrentlyActive ?? false;
    if (isVip) return null;
    final expiry = _adUnlockedUntil[iconId];
    if (expiry != null && DateTime.now().isBefore(expiry)) {
      final diff = expiry.difference(DateTime.now()).inDays;
      return diff >= 0 ? diff + 1 : 0;
    }
    return null;
  }

  int get unlockedIconsCount {
    return icons.where((i) => isIconUnlocked(i)).length;
  }

  Future<void> _loadSelectedIcon() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedIconId = prefs.getString(_keySelectedIcon) ?? 'default_gold';

    // Load ad expiration dates
    for (final icon in icons) {
      if (icon.isVip) {
        final expStr = prefs.getString('txa_app_icon_ad_expiry_${icon.id}');
        if (expStr != null && expStr.isNotEmpty) {
          final dt = DateTime.tryParse(expStr);
          if (dt != null) {
            _adUnlockedUntil[icon.id] = dt;
          }
        }
      }
    }

    // Auto-check expired icon
    final current = currentIcon;
    if (!isIconUnlocked(current)) {
      _selectedIconId = 'default_gold';
      await prefs.setString(_keySelectedIcon, 'default_gold');
    }

    // Auto-apply festival icon if in active holiday period
    await checkAndAutoApplyFestivalIcon();

    notifyListeners();
  }

  /// Tự động kích hoạt icon lễ hội (Quốc Khánh 2/9) nếu đang trong dịp lễ
  Future<void> checkAndAutoApplyFestivalIcon() async {
    final now = DateTime.now();
    if (TXAFestivalManager.isNationalDay29Period(now)) {
      final prefs = await SharedPreferences.getInstance();
      final lastAutoYear = prefs.getInt('txa_auto_applied_national_29_year');
      if (lastAutoYear != now.year) {
        TXALogger.logApp('🇻🇳 [AppIcon] Phát hiện mùa lễ Quốc Khánh 2/9 (${now.day}/${now.month}). Tự động kích hoạt Icon Quốc Khánh 2/9!');
        await selectIcon('national_day_29');
        await prefs.setInt('txa_auto_applied_national_29_year', now.year);
      }
    }
  }

  /// Mở khóa icon qua Ads trong 30 ngày (cộng dồn nếu còn hạn)
  Future<bool> unlockWithAd(String iconId, {int days = 30}) async {
    final now = DateTime.now();
    final currentExpiry = _adUnlockedUntil[iconId];
    final baseTime = (currentExpiry != null && currentExpiry.isAfter(now)) ? currentExpiry : now;
    final newExpiry = baseTime.add(Duration(days: days));

    _adUnlockedUntil[iconId] = newExpiry;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('txa_app_icon_ad_expiry_$iconId', newExpiry.toIso8601String());

    notifyListeners();
    TXAAchievementService.instance.checkAndEvaluate();
    TXALogger.logApp('Mở khóa icon $iconId qua Ads trong $days ngày (Hết hạn: $newExpiry)');
    return true;
  }

  /// Kiểm tra và tự động reset icon về mặc định nếu icon đang dùng đã hết hạn
  Future<bool> checkAndAutoResetExpiredIcon([BuildContext? context]) async {
    final current = currentIcon;
    if (!isIconUnlocked(current)) {
      TXALogger.logApp('Icon hiện tại (${current.id}) đã hết hạn. Tự động reset về default_gold');
      await selectIcon('default_gold');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TXALanguage.instance.getText('app_icon_expired_reset')),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    }
    return false;
  }

  Future<TXAIconChangeResult> selectIcon(String iconId) async {
    final target = icons.firstWhere((i) => i.id == iconId, orElse: () => icons.first);
    if (!isIconUnlocked(target)) {
      final msg = 'Icon $iconId chưa mở khóa (VIP: ${target.isVip})';
      TXALogger.logApp('⚠️ [AppIcon] Từ chối đổi icon: $msg');
      return TXAIconChangeResult(success: false, iconId: iconId, errorMessage: msg);
    }

    _selectedIconId = iconId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedIcon, iconId);
    notifyListeners();

    // Trigger achievement check
    TXAAchievementService.instance.checkAndEvaluate();

    // Invoke Native launcher icon change on Android / iOS
    try {
      TXALogger.logApp('🔄 [AppIcon] Đang yêu cầu hệ thống đổi Launcher Icon sang: $iconId (${target.nameVi})...');
      final result = await _channel.invokeMethod('changeAppIcon', {'iconName': iconId});
      final appliedAlias = result is Map ? result['appliedAlias']?.toString() : null;
      TXALogger.logApp('✅ [AppIcon] Đổi icon launcher thành công sang: $iconId (${target.nameVi}) [Alias: $appliedAlias]');
      return TXAIconChangeResult(
        success: true,
        iconId: iconId,
        appliedAlias: appliedAlias,
      );
    } on PlatformException catch (e) {
      final errorMsg = 'Lỗi nền tảng (${e.code}): ${e.message}';
      TXALogger.logError('❌ [AppIcon] $errorMsg', extraInfo: {
        'code': e.code,
        'details': e.details?.toString(),
        'targetIcon': iconId,
      });
      return TXAIconChangeResult(success: false, iconId: iconId, errorMessage: errorMsg);
    } catch (e, stack) {
      final errorMsg = 'Lỗi không xác định khi đổi icon: $e';
      TXALogger.logError('❌ [AppIcon] $errorMsg', stackTrace: stack, extraInfo: {
        'targetIcon': iconId,
      });
      return TXAIconChangeResult(success: false, iconId: iconId, errorMessage: errorMsg);
    }
  }
}

