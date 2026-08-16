import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'txa_auth_service.dart';
import 'txa_achievement_service.dart';

class TXAAppIconItem {
  final String id;
  final String nameVi;
  final String nameEn;
  final String emoji;
  final List<Color> gradient;
  final bool isVip;
  final String badge;

  const TXAAppIconItem({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    required this.emoji,
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
  String _selectedIconId = 'default_gold';
  String get selectedIconId => _selectedIconId;

  static const List<TXAAppIconItem> icons = [
    // ─── Free Starter Icons ──────────────────────────────────
    TXAAppIconItem(
      id: 'default_gold',
      nameVi: 'Army Cổ Điển',
      nameEn: 'Army Classic Gold',
      emoji: '🌟',
      gradient: [Color(0xFFFFD700), Color(0xFFFF8C00)],
      badge: 'GỐC',
    ),
    TXAAppIconItem(
      id: 'midnight_dark',
      nameVi: 'Bóng Đêm Thần Bí',
      nameEn: 'Midnight Shadow',
      emoji: '🌙',
      gradient: [Color(0xFF2C3E50), Color(0xFF000000)],
      badge: 'DARK',
    ),
    TXAAppIconItem(
      id: 'cyberpunk_neon',
      nameVi: 'Cyberpunk Neon',
      nameEn: 'Cyberpunk Neon',
      emoji: '⚡',
      gradient: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
      badge: 'NEON',
    ),
    TXAAppIconItem(
      id: 'sakura_pink',
      nameVi: 'Hoa Anh Đào',
      nameEn: 'Sakura Blossom',
      emoji: '🌸',
      gradient: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
      badge: 'CUTE',
    ),
    TXAAppIconItem(
      id: 'ocean_breeze',
      nameVi: 'Đại Dương Xanh',
      nameEn: 'Ocean Breeze',
      emoji: '🌊',
      gradient: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
      badge: 'COOL',
    ),

    // ─── VIP Premium 3D Icons (20 Icons) ─────────────────────
    TXAAppIconItem(
      id: 'sunset_glow',
      nameVi: 'Hoàng Hôn Rực Rỡ',
      nameEn: 'Sunset Glow',
      emoji: '🌅',
      gradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'matrix_matrix',
      nameVi: 'Ma Trận Số',
      nameEn: 'Matrix Code',
      emoji: '💻',
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'fire_dragon',
      nameVi: 'Rồng Lửa Bất Diệt',
      nameEn: 'Inferno Dragon',
      emoji: '🔥',
      gradient: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'galaxy_cosmic',
      nameVi: 'Vũ Trụ Galaxy',
      nameEn: 'Galaxy Nebula',
      emoji: '🌌',
      gradient: [Color(0xFF8A2387), Color(0xFFE94057)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'frost_ice',
      nameVi: 'Băng Giá Cực Bắc',
      nameEn: 'Frost Blizzard',
      emoji: '❄️',
      gradient: [Color(0xFF83A4D4), Color(0xFFB6FBFF)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'emerald_gem',
      nameVi: 'Ngọc Lục Bảo',
      nameEn: 'Emerald Jewel',
      emoji: '💎',
      gradient: [Color(0xFF0BA360), Color(0xFF3CBA92)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'ruby_luxury',
      nameVi: 'Hồng Ngọc Quý Tộc',
      nameEn: 'Ruby Royal',
      emoji: '👑',
      gradient: [Color(0xFF93291E), Color(0xFFED213A)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'amethyst_purple',
      nameVi: 'Thạch Anh Tím',
      nameEn: 'Amethyst Crystal',
      emoji: '🔮',
      gradient: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'retro_synthwave',
      nameVi: 'Synthwave 80s',
      nameEn: 'Retro Synthwave',
      emoji: '🕹️',
      gradient: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'matcha_zen',
      nameVi: 'Trà Xanh Matcha',
      nameEn: 'Matcha Zen',
      emoji: '🍵',
      gradient: [Color(0xFF56AB2F), Color(0xFFA8E063)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'phantom_ghost',
      nameVi: 'Bóng Ma Phantom',
      nameEn: 'Phantom Shadow',
      emoji: '👻',
      gradient: [Color(0xFF434343), Color(0xFF000000)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'golden_king',
      nameVi: 'Vương Giả Hoàng Kim',
      nameEn: 'Imperial Gold',
      emoji: '🏆',
      gradient: [Color(0xFFBF953F), Color(0xFFFCF6BA)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'diamond_ultra',
      nameVi: 'Kim Cương Tối Thượng',
      nameEn: 'Ultra Diamond',
      emoji: '💠',
      gradient: [Color(0xFF00C6FF), Color(0xFF0072FF)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'blood_moon',
      nameVi: 'Mặt Trăng Máu',
      nameEn: 'Blood Moon',
      emoji: '🌕',
      gradient: [Color(0xFFCB2D3E), Color(0xFFEF473A)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'aurora_lights',
      nameVi: 'Cực Quang Huyền Ảo',
      nameEn: 'Aurora Borealis',
      emoji: '🌠',
      gradient: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'space_blackhole',
      nameVi: 'Hố Đen Không Gian',
      nameEn: 'Cosmic Singularity',
      emoji: '🪐',
      gradient: [Color(0xFF0F2027), Color(0xFF2C5364)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'coffee_caramel',
      nameVi: 'Caramel Macchiato',
      nameEn: 'Caramel Macchiato',
      emoji: '☕',
      gradient: [Color(0xFFBA8B02), Color(0xFF181818)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'neon_toxic',
      nameVi: 'Độc Dược Phát Sáng',
      nameEn: 'Toxic Biohazard',
      emoji: '🧪',
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'quantum_portal',
      nameVi: 'Cổng Lượng Tử',
      nameEn: 'Quantum Warp',
      emoji: '🌀',
      gradient: [Color(0xFF4776E6), Color(0xFF8E54E9)],
      isVip: true,
      badge: 'VIP',
    ),
    TXAAppIconItem(
      id: 'infinity_titan',
      nameVi: 'Vô Cực Titan',
      nameEn: 'Titan Infinity',
      emoji: '🛡️',
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
    return isVip;
  }

  int get unlockedIconsCount {
    final isVip = TXAAuthService.instance.currentUser?.isVipCurrentlyActive ?? false;
    if (isVip) return icons.length;
    return icons.where((i) => !i.isVip).length;
  }

  Future<void> _loadSelectedIcon() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedIconId = prefs.getString(_keySelectedIcon) ?? 'default_gold';
    notifyListeners();
  }

  Future<bool> selectIcon(String iconId) async {
    final target = icons.firstWhere((i) => i.id == iconId, orElse: () => icons.first);
    if (!isIconUnlocked(target)) {
      return false;
    }

    _selectedIconId = iconId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedIcon, iconId);
    notifyListeners();

    // Trigger achievement check
    TXAAchievementService.instance.checkAndEvaluate();
    return true;
  }
}
