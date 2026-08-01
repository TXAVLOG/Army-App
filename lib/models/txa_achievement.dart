import 'package:flutter/material.dart';

enum TXAAchievementCategory {
  all,
  posts,
  friends,
  streak,
  love,
  stamps,
  spotify,
  ultimate,
}

enum TXAAchievementDifficulty {
  easy,
  medium,
  hard,
  ultimate,
}

class TXAAchievementTier {
  final int tierIndex; // 1..N
  final int targetValue;
  final String badgeNameKey; // Key in TXALanguage
  final List<Color> colors;
  final String medalEmoji;

  const TXAAchievementTier({
    required this.tierIndex,
    required this.targetValue,
    required this.badgeNameKey,
    required this.colors,
    required this.medalEmoji,
  });
}

class TXAAchievement {
  final String id;
  final String titleKey;
  final String descKey;
  final String icon;
  final TXAAchievementCategory category;
  final TXAAchievementDifficulty difficulty;
  final List<TXAAchievementTier> tiers;

  const TXAAchievement({
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.icon,
    required this.category,
    required this.difficulty,
    required this.tiers,
  });

  /// Returns 0 if locked (below Tier 1), or 1..N for the highest tier unlocked.
  int getUnlockedTierIndex(int currentValue) {
    int unlocked = 0;
    for (int i = 0; i < tiers.length; i++) {
      if (currentValue >= tiers[i].targetValue) {
        unlocked = i + 1;
      } else {
        break;
      }
    }
    return unlocked;
  }

  /// Returns integer completion percentage (0..100%).
  int getCompletionPercentage(int currentValue) {
    final maxTarget = tiers.last.targetValue;
    if (maxTarget <= 0) return 0;
    if (currentValue >= maxTarget) return 100;
    return ((currentValue / maxTarget) * 100).clamp(0, 100).round();
  }

  /// Get the target value for the next tier to unlock.
  int getNextTarget(int currentValue) {
    for (final tier in tiers) {
      if (currentValue < tier.targetValue) {
        return tier.targetValue;
      }
    }
    return tiers.last.targetValue;
  }

  /// Get current tier object if any tier is unlocked (tierIndex: 1..N), otherwise null.
  TXAAchievementTier? getCurrentTier(int currentValue) {
    final index = getUnlockedTierIndex(currentValue);
    if (index == 0) return null;
    return tiers[index - 1];
  }

  /// Default predefined list of progressive & single-tier achievements in Army
  static List<TXAAchievement> get defaultList => const [
        // ─── 1. EASY (5 Tiers) — Khoảnh Khắc Bất Tận 📸 ────────────────────
        TXAAchievement(
          id: 'series_posts',
          titleKey: 'ach_posts_title',
          descKey: 'ach_posts_desc',
          icon: '📸',
          category: TXAAchievementCategory.posts,
          difficulty: TXAAchievementDifficulty.easy,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 1,
              badgeNameKey: 'ach_posts_t1',
              colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
              medalEmoji: '🥉',
            ),
            TXAAchievementTier(
              tierIndex: 2,
              targetValue: 10,
              badgeNameKey: 'ach_posts_t2',
              colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
              medalEmoji: '🥈',
            ),
            TXAAchievementTier(
              tierIndex: 3,
              targetValue: 50,
              badgeNameKey: 'ach_posts_t3',
              colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
              medalEmoji: '🥇',
            ),
            TXAAchievementTier(
              tierIndex: 4,
              targetValue: 200,
              badgeNameKey: 'ach_posts_t4',
              colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
              medalEmoji: '💎',
            ),
            TXAAchievementTier(
              tierIndex: 5,
              targetValue: 1000,
              badgeNameKey: 'ach_posts_t5',
              colors: [Color(0xFFFFD700), Color(0xFFFF1744)],
              medalEmoji: '👑',
            ),
          ],
        ),

        // ─── 2. EASY (5 Tiers) — Kết Bạn Tứ Phương 🤝 ────────────────────
        TXAAchievement(
          id: 'series_friends',
          titleKey: 'ach_friends_title',
          descKey: 'ach_friends_desc',
          icon: '🤝',
          category: TXAAchievementCategory.friends,
          difficulty: TXAAchievementDifficulty.easy,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 1,
              badgeNameKey: 'ach_friends_t1',
              colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
              medalEmoji: '🥉',
            ),
            TXAAchievementTier(
              tierIndex: 2,
              targetValue: 5,
              badgeNameKey: 'ach_friends_t2',
              colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
              medalEmoji: '🥈',
            ),
            TXAAchievementTier(
              tierIndex: 3,
              targetValue: 15,
              badgeNameKey: 'ach_friends_t3',
              colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
              medalEmoji: '🥇',
            ),
            TXAAchievementTier(
              tierIndex: 4,
              targetValue: 30,
              badgeNameKey: 'ach_friends_t4',
              colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
              medalEmoji: '💎',
            ),
            TXAAchievementTier(
              tierIndex: 5,
              targetValue: 100,
              badgeNameKey: 'ach_friends_t5',
              colors: [Color(0xFFFF4081), Color(0xFFFF9100)],
              medalEmoji: '👑',
            ),
          ],
        ),

        // ─── 3. EASY (4 Tiers) — Bậc Thầy Trò Chuyện 💬 ───────────────────
        TXAAchievement(
          id: 'series_chat',
          titleKey: 'ach_chat_title',
          descKey: 'ach_chat_desc',
          icon: '💬',
          category: TXAAchievementCategory.posts,
          difficulty: TXAAchievementDifficulty.easy,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 5,
              badgeNameKey: 'ach_chat_t1',
              colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
              medalEmoji: '🥉',
            ),
            TXAAchievementTier(
              tierIndex: 2,
              targetValue: 25,
              badgeNameKey: 'ach_chat_t2',
              colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
              medalEmoji: '🥈',
            ),
            TXAAchievementTier(
              tierIndex: 3,
              targetValue: 100,
              badgeNameKey: 'ach_chat_t3',
              colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
              medalEmoji: '🥇',
            ),
            TXAAchievementTier(
              tierIndex: 4,
              targetValue: 500,
              badgeNameKey: 'ach_chat_t4',
              colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
              medalEmoji: '💎',
            ),
          ],
        ),

        // ─── 4. MEDIUM (3 Tiers) — Giữ Nhịp Thắp Lửa 🔥 ───────────────────
        TXAAchievement(
          id: 'series_streak',
          titleKey: 'ach_streak_title',
          descKey: 'ach_streak_desc',
          icon: '🔥',
          category: TXAAchievementCategory.streak,
          difficulty: TXAAchievementDifficulty.medium,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 7,
              badgeNameKey: 'ach_streak_t1',
              colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
              medalEmoji: '🥉',
            ),
            TXAAchievementTier(
              tierIndex: 2,
              targetValue: 30,
              badgeNameKey: 'ach_streak_t2',
              colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
              medalEmoji: '🥇',
            ),
            TXAAchievementTier(
              tierIndex: 3,
              targetValue: 100,
              badgeNameKey: 'ach_streak_t3',
              colors: [Color(0xFFFF1744), Color(0xFFFF9100)],
              medalEmoji: '👑',
            ),
          ],
        ),

        // ─── 5. MEDIUM (3 Tiers) — Tình Yêu Vĩnh Cửu 💖 ────────────────────
        TXAAchievement(
          id: 'series_love',
          titleKey: 'ach_love_title',
          descKey: 'ach_love_desc',
          icon: '💖',
          category: TXAAchievementCategory.love,
          difficulty: TXAAchievementDifficulty.medium,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 30,
              badgeNameKey: 'ach_love_t1',
              colors: [Color(0xFFFF80AB), Color(0xFFC2185B)],
              medalEmoji: '💖',
            ),
            TXAAchievementTier(
              tierIndex: 2,
              targetValue: 100,
              badgeNameKey: 'ach_love_t2',
              colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
              medalEmoji: '🥇',
            ),
            TXAAchievementTier(
              tierIndex: 3,
              targetValue: 365,
              badgeNameKey: 'ach_love_t3',
              colors: [Color(0xFFF50057), Color(0xFFD500F9)],
              medalEmoji: '💎',
            ),
          ],
        ),

        // ─── 6. MEDIUM (2 Tiers) — Biến Hình Camera 🎨 ────────────────────
        TXAAchievement(
          id: 'series_camera_theme',
          titleKey: 'ach_cam_theme_title',
          descKey: 'ach_cam_theme_desc',
          icon: '🎨',
          category: TXAAchievementCategory.posts,
          difficulty: TXAAchievementDifficulty.medium,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 2,
              badgeNameKey: 'ach_cam_theme_t1',
              colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
              medalEmoji: '🎨',
            ),
            TXAAchievementTier(
              tierIndex: 2,
              targetValue: 5,
              badgeNameKey: 'ach_cam_theme_t2',
              colors: [Color(0xFF00E5FF), Color(0xFFD500F9)],
              medalEmoji: '💎',
            ),
          ],
        ),

        // ─── 7. HARD (2 Tiers) — Dấu Ấn Vintage 📮 ────────────────────────
        TXAAchievement(
          id: 'series_stamps',
          titleKey: 'ach_stamps_title',
          descKey: 'ach_stamps_desc',
          icon: '📮',
          category: TXAAchievementCategory.stamps,
          difficulty: TXAAchievementDifficulty.hard,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 5,
              badgeNameKey: 'ach_stamps_t1',
              colors: [Color(0xFF8D6E63), Color(0xFF4E342E)],
              medalEmoji: '📮',
            ),
            TXAAchievementTier(
              tierIndex: 2,
              targetValue: 30,
              badgeNameKey: 'ach_stamps_t2',
              colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
              medalEmoji: '💎',
            ),
          ],
        ),

        // ─── 8. HARD (2 Tiers) — Giai Điệu Cảm Xúc 🎵 ──────────────────────
        TXAAchievement(
          id: 'series_spotify',
          titleKey: 'ach_spotify_title',
          descKey: 'ach_spotify_desc',
          icon: '🎵',
          category: TXAAchievementCategory.spotify,
          difficulty: TXAAchievementDifficulty.hard,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 5,
              badgeNameKey: 'ach_spotify_t1',
              colors: [Color(0xFF1DB954), Color(0xFF121212)],
              medalEmoji: '🎵',
            ),
            TXAAchievementTier(
              tierIndex: 2,
              targetValue: 25,
              badgeNameKey: 'ach_spotify_t2',
              colors: [Color(0xFF1DB954), Color(0xFF00E5FF)],
              medalEmoji: '👑',
            ),
          ],
        ),

        // ─── 9. HARD (3 Tiers) — Sưu Tầm Icon 📱 ──────────────────────────
        TXAAchievement(
          id: 'series_app_icons',
          titleKey: 'ach_app_icons_title',
          descKey: 'ach_app_icons_desc',
          icon: '📱',
          category: TXAAchievementCategory.posts,
          difficulty: TXAAchievementDifficulty.hard,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 3,
              badgeNameKey: 'ach_app_icons_t1',
              colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
              medalEmoji: '📱',
            ),
            TXAAchievementTier(
              tierIndex: 2,
              targetValue: 10,
              badgeNameKey: 'ach_app_icons_t2',
              colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
              medalEmoji: '🥇',
            ),
            TXAAchievementTier(
              tierIndex: 3,
              targetValue: 25,
              badgeNameKey: 'ach_app_icons_t3',
              colors: [Color(0xFF00E5FF), Color(0xFFD500F9)],
              medalEmoji: '💎',
            ),
          ],
        ),

        // ─── 10. ULTRA HARD (CHỈ 1 MỐC) — Triệu Phú Streak ⚡ ──────────────
        TXAAchievement(
          id: 'series_streak_365',
          titleKey: 'ach_streak_365_title',
          descKey: 'ach_streak_365_desc',
          icon: '⚡',
          category: TXAAchievementCategory.ultimate,
          difficulty: TXAAchievementDifficulty.ultimate,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 365,
              badgeNameKey: 'ach_streak_365_t1',
              colors: [Color(0xFFFFD700), Color(0xFF00E5FF)],
              medalEmoji: '⚡',
            ),
          ],
        ),

        // ─── 11. ULTRA HARD (CHỈ 1 MỐC) — Thủ Lĩnh Armi 🐜👑 ─────────────
        TXAAchievement(
          id: 'series_ultimate_ant',
          titleKey: 'ach_ultimate_ant_title',
          descKey: 'ach_ultimate_ant_desc',
          icon: '🐜',
          category: TXAAchievementCategory.ultimate,
          difficulty: TXAAchievementDifficulty.ultimate,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 1000,
              badgeNameKey: 'ach_ultimate_ant_t1',
              colors: [Color(0xFFFFD700), Color(0xFFFF1744)],
              medalEmoji: '👑',
            ),
          ],
        ),

        // ─── 12. ULTRA HARD (CHỈ 1 MỐC) — Thượng Khách Gold Pass 👑 ───────
        TXAAchievement(
          id: 'series_vip',
          titleKey: 'ach_vip_title',
          descKey: 'ach_vip_desc',
          icon: '👑',
          category: TXAAchievementCategory.ultimate,
          difficulty: TXAAchievementDifficulty.ultimate,
          tiers: [
            TXAAchievementTier(
              tierIndex: 1,
              targetValue: 1,
              badgeNameKey: 'ach_vip_t1',
              colors: [Color(0xFFFFD700), Color(0xFFFF9100)],
              medalEmoji: '🌟',
            ),
          ],
        ),
      ];
}
