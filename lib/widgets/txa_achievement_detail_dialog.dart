import 'package:flutter/material.dart';
import '../models/txa_achievement.dart';
import '../services/txa_achievement_service.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';

class TXAAchievementDetailDialog extends StatelessWidget {
  final TXAAchievement achievement;
  final int currentValue;

  const TXAAchievementDetailDialog({
    super.key,
    required this.achievement,
    required this.currentValue,
  });

  static void show(
    BuildContext context, {
    required TXAAchievement achievement,
    required int currentValue,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TXAAchievementDetailDialog(
        achievement: achievement,
        currentValue: currentValue,
      ),
    );
  }

  String _getDifficultyText(TXAAchievementDifficulty difficulty) {
    switch (difficulty) {
      case TXAAchievementDifficulty.easy:
        return TXALanguage.instance.getText('diff_easy');
      case TXAAchievementDifficulty.medium:
        return TXALanguage.instance.getText('diff_medium');
      case TXAAchievementDifficulty.hard:
        return TXALanguage.instance.getText('diff_hard');
      case TXAAchievementDifficulty.ultimate:
        return TXALanguage.instance.getText('diff_ultimate');
    }
  }

  Color _getDifficultyColor(TXAAchievementDifficulty difficulty) {
    switch (difficulty) {
      case TXAAchievementDifficulty.easy:
        return const Color(0xFF00E676);
      case TXAAchievementDifficulty.medium:
        return const Color(0xFFFFD700);
      case TXAAchievementDifficulty.hard:
        return const Color(0xFFFF1744);
      case TXAAchievementDifficulty.ultimate:
        return const Color(0xFF00E5FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedTierIndex = achievement.getUnlockedTierIndex(currentValue);
    final isUnlocked = unlockedTierIndex > 0;
    final currentTier = achievement.getCurrentTier(currentValue);
    final isMaxTier = unlockedTierIndex >= achievement.tiers.length;
    final completionPercentage = achievement.getCompletionPercentage(currentValue);

    final nextTarget = achievement.getNextTarget(currentValue);

    final activeTierForRate = currentTier?.tierIndex ?? (unlockedTierIndex + 1);
    final globalUnlockRate = TXAAchievementService.instance.getGlobalUnlockRate(
      achievement.id,
      activeTierForRate,
    );

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Enlarged Badge Header Container
          Center(
            child: Container(
              width: 90,
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isUnlocked && currentTier != null
                    ? LinearGradient(
                        colors: currentTier.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF2A2A32), Color(0xFF1A1A20)],
                      ),
                border: Border.all(
                  color: isUnlocked
                      ? (currentTier?.colors.first ?? TXATheme.primaryYellow)
                      : Colors.white24,
                  width: 3,
                ),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: (currentTier?.colors.first ??
                                  TXATheme.primaryYellow)
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                isUnlocked && currentTier != null
                    ? currentTier.medalEmoji
                    : achievement.icon,
                style: const TextStyle(fontSize: 42),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Title & Description
          Text(
            TXALanguage.instance.getText(achievement.titleKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            TXALanguage.instance.getText(achievement.descKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 16),

          // Row: Difficulty Badge Pill & Active Tier Badge Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Difficulty Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getDifficultyColor(achievement.difficulty),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getDifficultyText(achievement.difficulty),
                  style: TextStyle(
                    color: _getDifficultyColor(achievement.difficulty),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Active Tier Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? (currentTier?.colors.first.withValues(alpha: 0.25) ??
                          TXATheme.primaryYellow.withValues(alpha: 0.2))
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUnlocked
                        ? (currentTier?.colors.first ?? TXATheme.primaryYellow)
                        : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Text(
                  isUnlocked && currentTier != null
                      ? TXALanguage.instance.getText('tier_label').replaceAll(
                          '%tier%',
                          currentTier.tierIndex.toString(),
                        ).replaceAll(
                          '%max%',
                          achievement.tiers.length.toString(),
                        ).replaceAll(
                          '%name%',
                          TXALanguage.instance
                              .getText(currentTier.badgeNameKey),
                        )
                      : TXALanguage.instance.getText('achievement_locked'),
                  style: TextStyle(
                    color: isUnlocked ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Global Unlock Rate Pill Banner
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1C2A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: globalUnlockRate < 5.0
                      ? const Color(0xFFFFD700)
                      : Colors.white24,
                  width: globalUnlockRate < 5.0 ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    globalUnlockRate < 5.0
                        ? Icons.local_fire_department_rounded
                        : Icons.public_rounded,
                    color: globalUnlockRate < 5.0
                        ? const Color(0xFFFF9100)
                        : const Color(0xFF29B6F6),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    TXALanguage.instance
                        .getText('global_unlock_rate')
                        .replaceAll('%rate%', globalUnlockRate.toStringAsFixed(1)),
                    style: TextStyle(
                      color: globalUnlockRate < 5.0
                          ? const Color(0xFFFFD700)
                          : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Dynamic Progress & Bar Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF22222C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      TXALanguage.instance.getText('current_progress'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isMaxTier
                          ? '${TXALanguage.instance.getText('max_tier_reached')} (100%)'
                          : '$currentValue / $nextTarget ($completionPercentage%)',
                      style: TextStyle(
                        color: isMaxTier
                            ? TXATheme.primaryYellow
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: isMaxTier
                        ? 1.0
                        : (currentValue / nextTarget).clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUnlocked ? TXATheme.primaryYellow : Colors.white38,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tiers Roadmap Timeline Title
          Text(
            TXALanguage.instance.getText('roadmap_title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Tiers Roadmap List
          ...achievement.tiers.map((tier) {
            final isTierUnlocked = currentValue >= tier.targetValue;
            final isCurrentActiveTier =
                currentTier != null && currentTier.tierIndex == tier.tierIndex;
            final tierUnlockRate = TXAAchievementService.instance.getGlobalUnlockRate(
              achievement.id,
              tier.tierIndex,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentActiveTier
                    ? tier.colors.first.withValues(alpha: 0.2)
                    : const Color(0xFF1E1E26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrentActiveTier
                      ? tier.colors.first
                      : (isTierUnlocked ? Colors.white24 : Colors.white10),
                  width: isCurrentActiveTier ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    tier.medalEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TXALanguage.instance.getText(tier.badgeNameKey),
                          style: TextStyle(
                            color: isTierUnlocked ? Colors.white : Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              TXALanguage.instance
                                  .getText('target_label')
                                  .replaceAll('%target%', tier.targetValue.toString()),
                              style: TextStyle(
                                color: isTierUnlocked ? Colors.white70 : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${tierUnlockRate.toStringAsFixed(1)}% player rate',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isTierUnlocked)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF00E676),
                      size: 18,
                    )
                  else
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white30,
                      size: 18,
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Close Button
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A36),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              TXALanguage.instance.getText('close_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
