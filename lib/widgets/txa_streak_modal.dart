import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_streak_service.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_format.dart';
import '../services/txa_admob_service.dart';
import '../services/txa_iap_service.dart';
import 'txa_toast.dart';
import 'txa_avatar_frame.dart';


class TXAStreakMilestoneInfo {
  final int days;
  final String langKey;
  final Color primaryColor;
  final List<Color> gradient;

  const TXAStreakMilestoneInfo({
    required this.days,
    required this.langKey,
    required this.primaryColor,
    required this.gradient,
  });
}

class TXAStreakModal {
  static const List<TXAStreakMilestoneInfo> milestones = [
    TXAStreakMilestoneInfo(
      days: 3,
      langKey: 'streak_m_3',
      primaryColor: Color(0xFFFF9800),
      gradient: [Color(0xFFFF9800), Color(0xFFFF5722)],
    ),
    TXAStreakMilestoneInfo(
      days: 7,
      langKey: 'streak_m_7',
      primaryColor: Color(0xFFFF3D00),
      gradient: [Color(0xFFFF9100), Color(0xFFFF1744)],
    ),
    TXAStreakMilestoneInfo(
      days: 14,
      langKey: 'streak_m_14',
      primaryColor: Color(0xFFE91E63),
      gradient: [Color(0xFFEC407A), Color(0xFFC2185B)],
    ),
    TXAStreakMilestoneInfo(
      days: 30,
      langKey: 'streak_m_30',
      primaryColor: Color(0xFFFFD700),
      gradient: [Color(0xFFFFD700), Color(0xFFFFAB00)],
    ),
    TXAStreakMilestoneInfo(
      days: 45,
      langKey: 'streak_m_45',
      primaryColor: Color(0xFF00E676),
      gradient: [Color(0xFF69F0AE), Color(0xFF00C853)],
    ),
    TXAStreakMilestoneInfo(
      days: 60,
      langKey: 'streak_m_60',
      primaryColor: Color(0xFF9C27B0),
      gradient: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
    ),
    TXAStreakMilestoneInfo(
      days: 75,
      langKey: 'streak_m_75',
      primaryColor: Color(0xFFFF5252),
      gradient: [Color(0xFFFF8A80), Color(0xFFD50000)],
    ),
    TXAStreakMilestoneInfo(
      days: 90,
      langKey: 'streak_m_90',
      primaryColor: Color(0xFF00E5FF),
      gradient: [Color(0xFF18FFFF), Color(0xFF00B0FF)],
    ),
  ];

  static void show(BuildContext context, {required String username}) {
    // Kích hoạt đồng bộ streak thực từ Firestore database
    TXAStreakService.instance.syncStreakFromFirestore(username);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TXATheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: Listenable.merge([TXAStreakService.instance, TXALanguage.instance]),
          builder: (ctx2, _) {
            final txaLang = TXALanguage.instance;
            final streakCount = TXAStreakService.instance.getStreak(username);

            // Tìm mốc tiếp theo
            TXAStreakMilestoneInfo? nextMilestone;
            for (var m in milestones) {
              if (m.days > streakCount) {
                nextMilestone = m;
                break;
              }
            }

            final neededDays = nextMilestone != null ? (nextMilestone.days - streakCount) : 0;
            final progressRatio = nextMilestone != null
                ? (streakCount / nextMilestone.days).clamp(0.0, 1.0)
                : 1.0;

            final currentUser = TXAAuthService.instance.currentUser;
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: TXATheme.cardBorder,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title Header with Flame Icon
                    Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            txaLang.getText('streak_sheet_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Subtitle: Current Streak & Keep Hint
                    Text(
                      txaLang.getText('streak_current_days').replaceAll('%count%', '$streakCount'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      txaLang.getText('streak_keep_subtitle'),
                      style: TextStyle(
                        color: TXATheme.textMuted,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    TXAStreakCountdownWidget(username: username),
                    const SizedBox(height: 22),

                    // Section Title: Army Milestones
                    Text(
                      txaLang.getText('streak_milestones_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Horizontal List of 8 Milestones
                    SizedBox(
                      height: 125,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: milestones.length,
                        itemBuilder: (context, idx) {
                          final item = milestones[idx];
                          final isUnlocked = streakCount >= item.days;
                          final isCurrent = streakCount >= item.days &&
                              (idx == milestones.length - 1 || streakCount < milestones[idx + 1].days);

                          return Container(
                            margin: const EdgeInsets.only(right: 14),
                            child: Column(
                              children: [
                                // Avatar circle preview with frame
                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    TXAAvatarFrame(
                                      radius: 25,
                                      username: username,
                                      showStreakBadge: false,
                                      overrideStreak: item.days,
                                      forceActive: isUnlocked,
                                      child: Opacity(
                                        opacity: isUnlocked ? 1.0 : 0.45,
                                        child: Container(
                                          color: const Color(0xFF2C2C35),
                                          child: const Center(
                                            child: Text(
                                              '👤',
                                              style: TextStyle(fontSize: 22),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Lock icon if locked
                                    if (!isUnlocked)
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2C2C34),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white24, width: 1.0),
                                          ),
                                          child: const Icon(
                                            Icons.lock_rounded,
                                            size: 11,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Milestone Name
                                Text(
                                  txaLang.getText(item.langKey),
                                  style: TextStyle(
                                    color: isUnlocked ? Colors.white : Colors.white54,
                                    fontSize: 12,
                                    fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                // Days label
                                Text(
                                  '${item.days}+',
                                  style: TextStyle(
                                    color: TXATheme.textMuted,
                                    fontSize: 10,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // Badge Pill ("Hiện tại" or "Đã mở")
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF42A5F5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      txaLang.getText('streak_current_badge'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Next Milestone Progress Card
                    if (nextMilestone != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txaLang
                                  .getText('streak_add_days_hint')
                                  .replaceAll('%count%', '$neededDays')
                                  .replaceAll('%name%', txaLang.getText(nextMilestone.langKey)),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progressRatio,
                                minHeight: 6,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(nextMilestone.primaryColor),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              '$streakCount / ${nextMilestone.days}',
                              style: TextStyle(
                                color: TXATheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // --- SHIELD STATUS CARD & RESTORATION CREDIT BADGE ---
                    Builder(
                      builder: (context) {
                        final isShieldUsed = TXAStreakService.instance.isShieldUsedThisWeek(username);
                        final isVip = TXAIAPService.instance.isVipActive;
                        final isAdmin = currentUser?.role == 'admin';
                        final hasUnlimited = isVip || isAdmin;
                        final freeMonthlyUsed = TXAStreakService.instance.isFreeMonthlyRestoreUsed(username);
                        final adCredits = TXAStreakService.instance.getRestorationCredits(username);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Shield Status Card
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isShieldUsed ? Colors.white12 : const Color(0xFF00E676).withAlpha(20),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isShieldUsed ? Colors.white24 : const Color(0xFF00E676).withAlpha(60),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shield_rounded,
                                    color: isShieldUsed ? Colors.grey : const Color(0xFF00E676),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isShieldUsed
                                          ? txaLang.getText('shield_used')
                                          : txaLang.getText('shield_ready'),
                                      style: TextStyle(
                                        color: isShieldUsed ? Colors.white54 : const Color(0xFF00E676),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Restoration Credit Badge
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: hasUnlimited ? const Color(0xFFFFD700).withAlpha(20) : const Color(0xFF42A5F5).withAlpha(20),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: hasUnlimited ? const Color(0xFFFFD700).withAlpha(60) : const Color(0xFF42A5F5).withAlpha(60),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    hasUnlimited ? Icons.workspace_premium_rounded : Icons.bolt_rounded,
                                    color: hasUnlimited ? const Color(0xFFFFD700) : const Color(0xFF42A5F5),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      hasUnlimited
                                          ? txaLang.getText('restore_vip_unlimited')
                                          : (!freeMonthlyUsed
                                              ? '${txaLang.getText('restore_credits_label').replaceAll('%count%', '1')} (${txaLang.getText('free')})'
                                              : txaLang.getText('restore_credits_label').replaceAll('%count%', '$adCredits')),
                                      style: TextStyle(
                                        color: hasUnlimited ? const Color(0xFFFFD700) : const Color(0xFF42A5F5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // Restore Streak Button
                    if (TXAStreakService.instance.canRestoreStreak(username))
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            final isVip = TXAIAPService.instance.isVipActive;
                            final isAdmin = currentUser?.role == 'admin';
                            final hasUnlimited = isVip || isAdmin;
                            final freeMonthlyUsed = TXAStreakService.instance.isFreeMonthlyRestoreUsed(username);
                            final adCredits = TXAStreakService.instance.getRestorationCredits(username);

                            if (hasUnlimited || !freeMonthlyUsed || adCredits > 0) {
                              // Perform direct restore
                              final success = await TXAStreakService.instance.restoreStreak(username);
                              if (success) {
                                final saved = TXAStreakService.instance.getLastSavedStreak(username);
                                if (context.mounted) {
                                  TXAToast.show(
                                    context,
                                    txaLang.getText('restore_success_toast').replaceAll('%count%', '$saved'),
                                    icon: Icons.local_fire_department_rounded,
                                  );
                                }
                              }
                            } else {
                              // Show dialog to watch rewarded ad
                              showDialog(
                                context: context,
                                builder: (dlgCtx) => AlertDialog(
                                  backgroundColor: TXATheme.cardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(color: Colors.white12),
                                  ),
                                  title: Row(
                                    children: [
                                      Text('🎬', style: TextStyle(fontSize: 22)),
                                      const SizedBox(width: 10),
                                      Text(
                                        txaLang.getText('watch_ad_to_restore_title'),
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    txaLang.getText('watch_ad_to_restore_desc'),
                                    style: TextStyle(color: TXATheme.textMuted),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dlgCtx),
                                      child: Text(
                                        txaLang.getText('cancel'),
                                        style: const TextStyle(color: Colors.white54),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF42A5F5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(dlgCtx);
                                        // Check ad limits
                                        final adCount = TXAStreakService.instance.getDailyStreakAdCount(username);
                                        if (adCount >= 5) {
                                          TXAToast.show(
                                            context,
                                            txaLang.getText('ad_limit_reached'),
                                            icon: Icons.warning_amber_rounded,
                                          );
                                          return;
                                        }

                                        // Play Ad
                                        TXAAdMobService.instance.showRewardedAd(
                                          onUserEarnedReward: (reward) {
                                            TXAStreakService.instance.incrementRestorationCredits(username);
                                            TXAStreakService.instance.incrementDailyStreakAdCount(username);
                                            TXAToast.show(
                                              context,
                                              txaLang.getText('ad_reward_success').replaceAll(
                                                    '%count%',
                                                    '${TXAStreakService.instance.getRestorationCredits(username)}',
                                                  ),
                                              icon: Icons.stars_rounded,
                                            );
                                          },
                                          onAdDismissed: () {},
                                          onAdFailedToShow: (err) {
                                            TXAToast.show(
                                              context,
                                              txaLang.getText('ad_load_failed'),
                                              icon: Icons.wifi_off_rounded,
                                            );
                                          },
                                        );
                                      },
                                      child: Text(
                                        txaLang.getText('watch_ad_btn'),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF42A5F5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            txaLang.getText('streak_restore_btn'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class TXAStreakCountdownWidget extends StatefulWidget {
  final String username;
  const TXAStreakCountdownWidget({super.key, required this.username});

  @override
  State<TXAStreakCountdownWidget> createState() => _TXAStreakCountdownWidgetState();
}

class _TXAStreakCountdownWidgetState extends State<TXAStreakCountdownWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final streakService = TXAStreakService.instance;
    
    final streakCount = streakService.getStreak(widget.username);
    final postedToday = streakService.hasPostedToday(widget.username);

    // Only show if streakCount >= 3 and NOT posted today
    if (streakCount < 3 || postedToday) {
      return const SizedBox.shrink();
    }

    final diff = streakService.getRemainingTimeToReset();
    final h = TXAFormat.formatNumber(diff.inHours);
    final m = TXAFormat.formatNumber(diff.inMinutes % 60);
    final s = TXAFormat.formatNumber(diff.inSeconds % 60);
    final timeStr = diff.inHours >= 1 ? '$h:$m:$s' : '$m:$s';

    final text = txaLang.getText('streak_countdown_tooltip').replaceAll('%time%', timeStr);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withAlpha(30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF9800).withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFFF9800), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFFF9800),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}