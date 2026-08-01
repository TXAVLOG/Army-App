import 'package:flutter/material.dart';
import '../models/txa_achievement.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';

class TXAAchievementBadgeWidget extends StatelessWidget {
  final TXAAchievement achievement;
  final int currentValue;
  final VoidCallback onTap;

  const TXAAchievementBadgeWidget({
    super.key,
    required this.achievement,
    required this.currentValue,
    required this.onTap,
  });

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

    final targetVal = isMaxTier
        ? achievement.tiers.last.targetValue
        : achievement.tiers[unlockedTierIndex].targetValue;

    // Grayscale matrix for locked state
    const List<double> grayscaleMatrix = <double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 0.6, 0,
    ];

    final cardChild = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isUnlocked && currentTier != null
                ? LinearGradient(
                    colors: currentTier.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF1E1E24), Color(0xFF141419)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: isUnlocked
                  ? (currentTier?.colors.first.withValues(alpha: 0.8) ??
                      TXATheme.primaryYellow)
                  : Colors.white.withValues(alpha: 0.1),
              width: isUnlocked ? 2 : 1,
            ),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: (currentTier?.colors.first ?? TXATheme.primaryYellow)
                          .withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Row: Difficulty Pill & Tier Medal / Lock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Difficulty Badge Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getDifficultyColor(achievement.difficulty)
                            .withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getDifficultyText(achievement.difficulty),
                      style: TextStyle(
                        color: _getDifficultyColor(achievement.difficulty),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Tier Badge Index
                  if (isUnlocked && currentTier != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${currentTier.medalEmoji} ${currentTier.tierIndex}/${achievement.tiers.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white54,
                        size: 12,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 6),

              // Center Icon / Medal Emoji
              Text(
                isUnlocked && currentTier != null
                    ? currentTier.medalEmoji
                    : achievement.icon,
                style: TextStyle(
                  fontSize: isUnlocked ? 36 : 32,
                ),
              ),

              const SizedBox(height: 4),

              // Title
              Text(
                TXALanguage.instance.getText(achievement.titleKey),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnlocked ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  shadows: isUnlocked
                      ? [
                          const Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),

              const SizedBox(height: 4),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: isMaxTier
                      ? 1.0
                      : (currentValue / targetVal).clamp(0.0, 1.0),
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUnlocked ? Colors.white : TXATheme.primaryYellow,
                  ),
                  minHeight: 5,
                ),
              ),

              const SizedBox(height: 4),

              // Bottom Row: Numerical Progress & Percentage %
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMaxTier
                        ? TXALanguage.instance.getText('max_tier_reached')
                        : '$currentValue/$targetVal',
                    style: TextStyle(
                      color: isUnlocked ? Colors.white70 : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$completionPercentage%',
                    style: TextStyle(
                      color: isUnlocked
                          ? TXATheme.primaryYellow
                          : Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!isUnlocked) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(grayscaleMatrix),
        child: cardChild,
      );
    }

    return cardChild;
  }
}
