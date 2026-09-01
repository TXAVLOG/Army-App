import 'package:flutter/material.dart';
import '../services/txa_admob_service.dart';
import '../services/txa_analytics.dart';
import '../services/txa_app_icon_service.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_language.dart';
import 'txa_gold_pass_paywall_screen.dart';

enum TXAAppIconFilter {
  all,
  free,
  vip,
}

class TXAAppIconGalleryScreen extends StatefulWidget {
  const TXAAppIconGalleryScreen({super.key});

  @override
  State<TXAAppIconGalleryScreen> createState() => _TXAAppIconGalleryScreenState();
}

class _TXAAppIconGalleryScreenState extends State<TXAAppIconGalleryScreen> {
  TXAAppIconFilter _filter = TXAAppIconFilter.all;
  bool _isLoadingAd = false;

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: 'app_icon_gallery');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TXAAppIconService.instance.checkAndAutoResetExpiredIcon(context);
    });
  }

  List<TXAAppIconItem> _getFilteredIcons() {
    final all = TXAAppIconService.icons;
    switch (_filter) {
      case TXAAppIconFilter.all:
        return all;
      case TXAAppIconFilter.free:
        return all.where((i) => !i.isVip).toList();
      case TXAAppIconFilter.vip:
        return all.where((i) => i.isVip).toList();
    }
  }

  void _watchAdToUnlock(TXAAppIconItem item) {
    if (_isLoadingAd) return;
    setState(() => _isLoadingAd = true);

    final lang = TXALanguage.instance;
    final isVi = lang.currentLanguage == 'vi';

    TXAAdMobService.instance.showRewardedAd(
      onUserEarnedReward: (reward) async {
        await TXAAppIconService.instance.unlockWithAd(item.id, days: 30);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang.getText('app_icon_ad_success').replaceAll('%name%', item.getName(isVi)),
              ),
              backgroundColor: const Color(0xFF00E676),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      onAdDismissed: () {
        if (mounted) {
          setState(() => _isLoadingAd = false);
        }
      },
      onAdFailedToShow: (error) {
        if (mounted) {
          setState(() => _isLoadingAd = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.getText('app_icon_ad_failed')),
              backgroundColor: const Color(0xFFE53935),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TXALanguage.instance,
        TXAAppIconService.instance,
        TXAAuthService.instance,
      ]),
      builder: (context, _) {
        final lang = TXALanguage.instance;
        final iconService = TXAAppIconService.instance;
        final authService = TXAAuthService.instance;
        final isVi = lang.currentLanguage == 'vi';
        final isVip = authService.currentUser?.isVipCurrentlyActive ?? false;

        final currentIcon = iconService.currentIcon;
        final unlockedCount = iconService.unlockedIconsCount;
        final totalCount = TXAAppIconService.icons.length;
        final filteredList = _getFilteredIcons();

        return Scaffold(
          backgroundColor: const Color(0xFF0C0C10),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0C0C10),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              lang.getText('app_icon_gallery_title'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Header Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isVip
                          ? [const Color(0xFF38270A), const Color(0xFF1F1706)]
                          : [const Color(0xFF1B1B26), const Color(0xFF12121A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isVip
                          ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.15),
                      width: isVip ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isVip ? const Color(0xFFFFD700) : Colors.black)
                            .withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Active Icon Preview with Glow
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFD700),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            currentIcon.assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: currentIcon.gradient),
                              ),
                              child: Center(
                                child: Text(currentIcon.emoji, style: const TextStyle(fontSize: 28)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  currentIcon.getName(isVi),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    lang.getText('app_icon_status_active'),
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isVip
                                  ? lang.getText('app_icon_all_unlocked')
                                  : lang.getText('app_icon_unlocked_banner')
                                      .replaceAll('%unlocked%', unlockedCount.toString())
                                      .replaceAll('%total%', totalCount.toString()),
                              style: TextStyle(
                                color: isVip ? const Color(0xFFFFD700) : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalCount > 0 ? (unlockedCount / totalCount).clamp(0.0, 1.0) : 0.0,
                                backgroundColor: Colors.black45,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isVip ? const Color(0xFFFFD700) : const Color(0xFF00E5FF),
                                ),
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: lang.getText('app_icon_filter_all').replaceAll('%count%', totalCount.toString()),
                      selected: _filter == TXAAppIconFilter.all,
                      onTap: () => setState(() => _filter = TXAAppIconFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: lang.getText('app_icon_filter_free').replaceAll('%count%', '5'),
                      selected: _filter == TXAAppIconFilter.free,
                      onTap: () => setState(() => _filter = TXAAppIconFilter.free),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: lang.getText('app_icon_filter_vip').replaceAll('%count%', '20'),
                      selected: _filter == TXAAppIconFilter.vip,
                      onTap: () => setState(() => _filter = TXAAppIconFilter.vip),
                      isGold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 3D Card Grid View
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisExtent: 250,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    final isSelected = iconService.selectedIconId == item.id;
                    final isUnlocked = iconService.isIconUnlocked(item);
                    final adDaysLeft = iconService.getAdRemainingDays(item.id);

                    return _buildIcon3DCard(
                      context: context,
                      item: item,
                      isSelected: isSelected,
                      isUnlocked: isUnlocked,
                      adDaysLeft: adDaysLeft,
                      isVi: isVi,
                      lang: lang,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool isGold = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (isGold ? const Color(0xFFFFD700) : const Color(0xFF00E5FF))
              : const Color(0xFF1B1B24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (isGold ? const Color(0xFFFFD700) : const Color(0xFF00E5FF))
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildIcon3DCard({
    required BuildContext context,
    required TXAAppIconItem item,
    required bool isSelected,
    required bool isUnlocked,
    required int? adDaysLeft,
    required bool isVi,
    required TXALanguage lang,
  }) {
    final iconService = TXAAppIconService.instance;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected
              ? [const Color(0xFF2E240D), const Color(0xFF1C1505)]
              : (item.isVip
                  ? [const Color(0xFF1D1B28), const Color(0xFF13121C)]
                  : [const Color(0xFF191922), const Color(0xFF101017)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFFD700)
              : (item.isVip
                  ? const Color(0xFFFFD700).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.12)),
          width: isSelected ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                : (item.isVip ? const Color(0xFF7C4DFF).withValues(alpha: 0.12) : Colors.black38),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // VIP / FREE Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.isVip
                      ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                      : const Color(0xFF00E676).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.isVip
                        ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                        : const Color(0xFF00E676).withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.isVip ? '👑 VIP' : '🟢 FREE',
                      style: TextStyle(
                        color: item.isVip ? const Color(0xFFFFD700) : const Color(0xFF00E676),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Countdown or Lock/Active status
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.black, size: 12),
                )
              else if (adDaysLeft != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF29B6F6).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF29B6F6), width: 0.8),
                  ),
                  child: Text(
                    lang.getText('app_icon_days_left').replaceAll('%days%', adDaysLeft.toString()),
                    style: const TextStyle(
                      color: Color(0xFF29B6F6),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (!isUnlocked)
                const Icon(Icons.lock_rounded, color: Colors.white38, size: 14),
            ],
          ),

          // Center Real 3D Icon Image
          Hero(
            tag: 'app_icon_${item.id}',
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: isUnlocked
                        ? item.gradient.first.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  item.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: item.gradient),
                    ),
                    child: Center(
                      child: Text(item.emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Title
          Text(
            item.getName(isVi),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Action Buttons
          if (isSelected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700), width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                lang.getText('app_icon_status_active'),
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else if (isUnlocked)
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await iconService.selectIcon(item.id);
                  if (context.mounted) {
                    if (result.success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            lang.getText('app_icon_applied_toast').replaceAll('%name%', item.getName(isVi)),
                          ),
                          backgroundColor: const Color(0xFFFFD700),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            lang.getText('app_icon_applied_failed').replaceAll('%reason%', result.errorMessage ?? 'Không xác định'),
                          ),
                          backgroundColor: const Color(0xFFE53935),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  lang.getText('app_icon_apply_btn'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            Column(
              children: [
                // Watch Ad Button (30 Days)
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: () => _watchAdToUnlock(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      lang.getText('app_icon_ad_unlock_btn'),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Gold Pass link
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TXAGoldPassPaywallScreen()),
                    );
                  },
                  child: Text(
                    lang.getText('app_icon_vip_unlock_btn'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
