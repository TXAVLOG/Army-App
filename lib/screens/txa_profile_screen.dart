import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/txa_theme.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_analytics.dart';
import '../services/txa_feed_service.dart';
import '../services/txa_language.dart';
import '../services/txa_format.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_network_image.dart';
import '../services/txa_camera_theme_service.dart';
import '../services/txa_festival_manager.dart';
import '../services/txa_streak_service.dart';
import '../services/txa_achievement_service.dart';
import '../widgets/txa_streak_modal.dart';
import 'txa_admin_panel_screen.dart';
import 'txa_recap_screen.dart';
import 'txa_achievement_screen.dart';
import 'locket_feed_screen.dart';
import 'txa_login_screen.dart';
import '../services/txa_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/txa_avatar_frame.dart';
import '../services/txa_iap_service.dart';
import 'txa_gold_pass_paywall_screen.dart';

class TXAProfileScreen extends StatefulWidget {
  const TXAProfileScreen({super.key});

  @override
  State<TXAProfileScreen> createState() => _TXAProfileScreenState();
}

class _TXAProfileScreenState extends State<TXAProfileScreen>
    with SingleTickerProviderStateMixin {

  static bool _hasLoadedOnce = false;
  static int _lastPostCount = 0;
  static String _lastLatestPostId = '';
  static String _lastLatestPostTime = '';
  static int _lastFriendsCount = 0;

  late final AnimationController _menuAnimCtrl;
  bool _isPopping = false;
  bool _copiedUsername = false;
  bool _isLoading = false;
  bool _isBuildingTimeline = false;

  static void resetLoadState() {
    _hasLoadedOnce = false;
    _lastPostCount = 0;
    _lastLatestPostId = '';
    _lastLatestPostTime = '';
    _lastFriendsCount = 0;
  }

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenProfile);
    _menuAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkAndLoadData();
  }

  void _checkAndLoadData() async {
    final txaAuth = TXAAuthService.instance;
    final txaFeed = TXAFeedService.instance;
    final currentUsername = txaAuth.currentUser?.username ?? '';

    final visiblePosts = txaFeed.getVisiblePostsForUser(currentUsername);
    final count = visiblePosts.length;
    final latestId = visiblePosts.isNotEmpty ? visiblePosts.first.id : '';
    final latestTime = visiblePosts.isNotEmpty ? visiblePosts.first.createdTime : '';
    final friendsCount = txaAuth.friendsList.length;

    final dataChanged = count != _lastPostCount ||
        latestId != _lastLatestPostId ||
        latestTime != _lastLatestPostTime ||
        friendsCount != _lastFriendsCount;

    if (!_hasLoadedOnce || dataChanged) {
      setState(() {
        _isLoading = true;
      });

      // Phase 1: Sync user data
      await txaAuth.syncUserFromFirestore();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBuildingTimeline = true;
        });
      }

      // Phase 2: Precache images in background
      final freshPosts = txaFeed.getVisiblePostsForUser(currentUsername);
      if (mounted) {
        final recentPosts = freshPosts.take(10).toList();
        final futures = <Future<void>>[];
        for (var post in recentPosts) {
          if (post.photoPath.isNotEmpty && post.photoPath.startsWith('http')) {
            futures.add(precacheImage(NetworkImage(post.photoPath), context).catchError((_) {}));
          }
        }
        await Future.wait([
          Future.wait(futures),
          Future.delayed(const Duration(milliseconds: 950)),
        ]);
      }

      _lastPostCount = count;
      _lastLatestPostId = latestId;
      _lastLatestPostTime = latestTime;
      _lastFriendsCount = friendsCount;
      _hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          _isBuildingTimeline = false;
        });
      }
    } else {
      txaAuth.syncUserFromFirestore();
    }
  }

  @override
  void dispose() {
    _menuAnimCtrl.dispose();
    super.dispose();
  }

  void _showCameraThemeBottomSheet(BuildContext context) {
    final service = TXACameraThemeService.instance;
    final themes = TXACameraThemeService.themes;
    final initialIndex = themes.indexWhere((t) => t.id == service.currentTheme).clamp(0, themes.length - 1);
    final PageController pageController = PageController(viewportFraction: 0.72, initialPage: initialIndex);

    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return AnimatedBuilder(
              animation: service,
              builder: (ctx2, _) {
                final isVi = TXALanguage.instance.currentLanguage == 'vi';

                return Container(
                  height: MediaQuery.of(context).size.height * 0.78,
                  padding: const EdgeInsets.only(top: 16, bottom: 20),
                  child: Column(
                    children: [
                      // Handle Bar & Close Button (X)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: TXATheme.textMuted.withAlpha(80),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  TXALanguage.instance.getText('camera_theme_title').toUpperCase(),
                                  style: TextStyle(
                                    color: TXATheme.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isVi
                                      ? 'Vuốt ngang để xem trước khung ảnh & màu sắc của từng theme'
                                      : 'Swipe horizontally to preview camera frame & theme colors',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: TXATheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 16,
                            top: 0,
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ─── CAROUSEL THEME PREVIEW SLIDER ─────────────────────
                      Expanded(
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: themes.length,
                          onPageChanged: (index) {
                            setSheetState(() {});
                          },
                          itemBuilder: (ctx3, i) {
                            final theme = themes[i];
                            final isSelected = service.currentTheme == theme.id;
                            final accent = theme.accentColor;

                            final now = DateTime.now();
                            final isSelectable = (theme.id != 'tet' && theme.id != 'national') ||
                                (theme.id == 'tet' && TXAFestivalManager.isTetPeriod(now)) ||
                                (theme.id == 'national' && (TXAFestivalManager.isNationalDayPeriod(now) || TXAFestivalManager.isNationalDay29Period(now)));

                            return GestureDetector(
                              onTap: () {
                                pageController.animateToPage(
                                  i,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.appBgColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected ? accent : theme.appCardBorder,
                                    width: isSelected ? 3.5 : 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? accent.withAlpha(120)
                                          : theme.appCardBorder.withAlpha(50),
                                      blurRadius: isSelected ? 18 : 8,
                                      spreadRadius: isSelected ? 2 : 0,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Theme Header: Icon & Name
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(theme.icon, style: const TextStyle(fontSize: 22)),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              theme.name,
                                              style: TextStyle(
                                                color: accent,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 6),
                                            Icon(Icons.check_circle_rounded, color: accent, size: 18),
                                          ],
                                        ],
                                      ),

                                      // ── Mini Viewfinder Photo Preview ───────
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: AspectRatio(
                                            aspectRatio: 1.0,
                                            child: Container(
                                              decoration: theme.frameDecoration,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(26),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    // Sample Photo
                                                    if (theme.samplePhotoUrl != null)
                                                      Image.network(
                                                        theme.samplePhotoUrl!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) => Container(
                                                          color: theme.cameraBgColor,
                                                          child: Icon(Icons.camera_alt_rounded, size: 48, color: accent.withAlpha(100)),
                                                        ),
                                                      )
                                                    else
                                                      Container(
                                                        color: theme.cameraBgColor,
                                                        child: Icon(Icons.camera_alt_rounded, size: 48, color: accent.withAlpha(100)),
                                                      ),

                                                    // Filter Overlay
                                                    if (theme.overlayColor != null)
                                                      Container(
                                                        color: theme.overlayColor!.withValues(alpha: theme.overlayOpacity),
                                                      ),

                                                    // Lock overlay if unavailable
                                                    if (!isSelectable)
                                                      Container(
                                                        color: Colors.black54,
                                                        child: const Center(
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.lock_rounded, color: Colors.white70, size: 36),
                                                              SizedBox(height: 6),
                                                              Text(
                                                                'Khóa chủ đề',
                                                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ── 1. Controls Row Preview (Gallery, Shutter, Flip) ─────
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          // Gallery Icon Preview
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: theme.appCardBg,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: theme.appCardBorder, width: 1.5),
                                              boxShadow: [
                                                BoxShadow(color: theme.appCardBorder.withAlpha(50), blurRadius: 6),
                                              ],
                                            ),
                                            child: Icon(Icons.photo_library_outlined, color: accent, size: 18),
                                          ),

                                          // Center: Signature Shutter Preview
                                          Container(
                                            width: 52,
                                            height: 52,
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: theme.shutterBorderColor ?? accent,
                                                width: 3.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (theme.shutterBorderColor ?? accent).withAlpha(100),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: theme.shutterFillColor ?? accent,
                                                shape: BoxShape.circle,
                                              ),
                                              child: theme.shutterInnerIcon != null
                                                  ? Center(
                                                      child: Text(
                                                        theme.shutterInnerIcon!,
                                                        style: const TextStyle(fontSize: 20),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          ),

                                          // Flip Camera Icon Preview
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: theme.appCardBg,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: theme.appCardBorder, width: 1.5),
                                              boxShadow: [
                                                BoxShadow(color: theme.appCardBorder.withAlpha(50), blurRadius: 6),
                                              ],
                                            ),
                                            child: Icon(Icons.flip_camera_ios_rounded, color: accent, size: 18),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // ── 2. Apply Button directly BELOW shutter ─────────────────
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            if (!isSelectable) {
                                              TXAToast.show(
                                                context,
                                                isVi
                                                    ? 'Chủ đề này chỉ tự động kích hoạt khi đến ngày lễ!'
                                                    : 'This theme is automatically unlocked during festival!',
                                                icon: Icons.lock_outline_rounded,
                                              );
                                              return;
                                            }
                                            await service.setTheme(theme.id);
                                            if (context.mounted) {
                                              TXAToast.show(
                                                context,
                                                isVi ? 'Đã áp dụng chủ đề ${theme.name}!' : 'Applied ${theme.name} theme!',
                                                icon: Icons.check_circle_rounded,
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isSelected ? accent : theme.appCardBg,
                                            foregroundColor: isSelected ? Colors.black : accent,
                                            side: BorderSide(color: accent, width: 1.5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            padding: const EdgeInsets.symmetric(vertical: 9),
                                          ),
                                          child: Text(
                                            isSelected
                                                ? (isVi ? '✓ Đang sử dụng' : '✓ Active')
                                                : (isVi ? 'Áp dụng chủ đề' : 'Apply Theme'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Carousel Page Indicator Dots
                      Builder(
                        builder: (ctx4) {
                          final currentPage = pageController.hasClients ? (pageController.page?.round() ?? initialIndex) : initialIndex;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(themes.length, (idx) {
                              final isCurrent = idx == currentPage;
                              final theme = themes[idx];
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: isCurrent ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isCurrent ? theme.accentColor : TXATheme.textMuted.withAlpha(60),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            }),
                          );
                        }
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  void _showEditAvatarBottomSheet(BuildContext context) {
    final txaAuth = TXAAuthService.instance;
    final txaLang = TXALanguage.instance;

    String selectedEmoji = txaAuth.currentUser?.avatar ?? '🦊';
    String selectedColor = txaAuth.currentUser?.avatarBgColor ?? '0xFFF57C00';

    final currentUser = txaAuth.currentUser;
    final googlePhoto = currentUser?.googlePhotoUrl;
    final isGoogleAcc = currentUser?.isGoogleAccount == true && googlePhoto != null && googlePhoto.isNotEmpty;

    final List<Map<String, dynamic>> options = [];
    if (isGoogleAcc) {
      options.add({
        'emoji': googlePhoto,
        'color': '0xFF1F1F1F',
        'isGoogle': true,
      });
    }
    options.addAll(TXAAuthService.presetAvatars.map((e) => {...e, 'isGoogle': false}));

    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateSheet) {
            return SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    txaLang.getText('edit_avatar_title').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(int.tryParse(selectedColor) ?? 0xFFF57C00).withAlpha(200),
                        border: Border.all(color: const Color(0xFF42A5F5), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF42A5F5).withAlpha(120),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: selectedEmoji.startsWith('http')
                            ? TXANetworkImage(url: selectedEmoji, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  selectedEmoji,
                                  style: const TextStyle(fontSize: 40),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: options.length,
                      itemBuilder: (ctx3, index) {
                        final option = options[index];
                        final isSelected = selectedEmoji == option['emoji'];
                        final isOptGoogle = option['isGoogle'] == true;
                        return GestureDetector(
                          onTap: () {
                            setStateSheet(() {
                              selectedEmoji = option['emoji']!;
                              selectedColor = option['color']!;
                            });
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(int.tryParse(option['color']!) ?? 0xFFF57C00).withAlpha(isSelected ? 230 : 100),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF42A5F5) : Colors.white10,
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: isOptGoogle
                                      ? TXANetworkImage(url: option['emoji']!, fit: BoxFit.cover)
                                      : Center(
                                          child: Text(
                                            option['emoji']!,
                                            style: const TextStyle(fontSize: 26),
                                          ),
                                        ),
                                ),
                              ),
                              if (isOptGoogle)
                                Positioned(
                                  right: 12,
                                  bottom: 0,
                                  child: Image.asset(
                                    'assets/google_logo.png',
                                    width: 18,
                                    height: 18,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final ctx = context;
                        await txaAuth.updateAvatar(selectedEmoji, selectedColor);
                        if (ctx.mounted) {
                          nav.pop();
                          TXAToast.show(ctx, txaLang.getText('avatar_emoji_changed'));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        txaLang.getText('save'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        }
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final txaAuth = TXAAuthService.instance;
    final txaLang = TXALanguage.instance;
    final txaFeed = TXAFeedService.instance;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (!_isPopping && details.primaryVelocity != null && details.primaryVelocity! < -300) {
          _isPopping = true;
          Navigator.pop(context);
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([txaAuth, txaLang, txaFeed, TXAStreakService.instance]),
        builder: (context, _) {
          final currentUser = txaAuth.currentUser;
          final currentUsername = currentUser?.username ?? '@user';
          final avatarEmoji = currentUser?.avatar ?? '🦊';
          final avatarColorVal = int.tryParse(currentUser?.avatarBgColor ?? '0xFFF57C00') ?? 0xFFF57C00;

          final visiblePosts = txaFeed.getVisiblePostsForUser(currentUsername);

          return Scaffold(
            backgroundColor: TXATheme.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _menuAnimCtrl,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => _showSettingsBottomSheet(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 24),
                  onPressed: () {
                    if (!_isPopping) {
                      _isPopping = true;
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const MicrosoftSpinner(size: 60),
                        const SizedBox(height: 20),
                        Text(
                          txaLang.getText('loading_profile_data'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification notification) {
                          // Disabling drag down to pop completely
                          return false;
                        },
                        child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                // 1. Avatar (Viền Neon xanh có hiệu ứng phát sáng & nút Edit)
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      TXAAvatarFrame(
                        username: currentUsername,
                        radius: 50,
                        tier: TXAFriendTier.normal,
                        child: Container(
                          color: Color(avatarColorVal).withAlpha(200),
                          child: avatarEmoji.startsWith('http')
                              ? TXANetworkImage(url: avatarEmoji, fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    avatarEmoji,
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: GestureDetector(
                          onTap: () => _showEditAvatarBottomSheet(context),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: Color(0xFF42A5F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Display Name (Bold, Uppercase)
                Text(
                  (currentUser?.displayName ?? currentUser?.username ?? '').replaceAll('@', '').toUpperCase(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),

                // 3. Username Text + Copy Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentUsername,
                      style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: currentUsername));
                        HapticFeedback.mediumImpact();
                        TXAToast.show(
                          context,
                          txaLang.getText('username_copied').replaceAll('%user%', currentUsername),
                          icon: _copiedUsername ? Icons.check_circle_rounded : Icons.copy_rounded,
                        );
                        setState(() {
                          _copiedUsername = true;
                        });
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            setState(() {
                              _copiedUsername = false;
                            });
                          }
                        });
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          _copiedUsername ? Icons.check_circle_rounded : Icons.copy_rounded,
                          key: ValueKey<bool>(_copiedUsername),
                          color: _copiedUsername ? TXATheme.statusGreen : Colors.white38,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                // 3.5. Account Creation Date
                Builder(
                  builder: (context) {
                    final createdStr = currentUser?.createdTime;
                    if (createdStr == null || createdStr.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final createdDate = DateTime.tryParse(createdStr)?.toLocal();
                    if (createdDate == null) {
                      return const SizedBox.shrink();
                    }
                    final formattedDate = '${TXAFormat.formatNumber(createdDate.day)}/${TXAFormat.formatNumber(createdDate.month)}/${createdDate.year}';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        txaLang.getText('account_created_at').replaceAll('%date%', formattedDate),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 4. Two Pills Row: [Count] Bạn bè & Chia sẻ
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context, 'show_friends_modal');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: TXATheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: TXATheme.cardBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: TXATheme.cardBorder.withAlpha(40),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_rounded, color: TXATheme.accentColor, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '${txaAuth.friendsList.length} ${txaLang.getText('friends_badge')}',
                              style: TextStyle(color: TXATheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final inviteLink = TXAWeb.getInviteLink(currentUsername);
                        final shareMsg = 'Add me on Army: $inviteLink';
                        Clipboard.setData(ClipboardData(text: shareMsg));
                        TXAToast.show(
                          context,
                          txaLang.getText('copy_invite_link_success').replaceAll('%link%', inviteLink),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: TXATheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: TXATheme.cardBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: TXATheme.cardBorder.withAlpha(40),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.reply_rounded, color: TXATheme.accentColor, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              txaLang.getText('share_profile'),
                              style: TextStyle(color: TXATheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 5. Combined Pill: [myPostsCount] Army | [currentStreak] Nhịp
                Builder(
                  builder: (ctx) {
                    final myPostsCount = visiblePosts.where((p) => p.senderUsername == currentUsername).length;
                    final currentStreak = TXAStreakService.instance.getStreak(currentUsername);
                    final isStreakContinuedToday = TXAStreakService.instance.hasPostedToday(currentUsername);
                    final isStreakActiveAndLit = isStreakContinuedToday && currentStreak >= 3;

                    // Dù ở bất kỳ theme nào, nếu chưa nối chuỗi hôm nay thì màu sẽ là màu xám riêng biệt
                    final streakItemColor = isStreakActiveAndLit ? TXATheme.accentColor : const Color(0xFF8E8E93);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: TXATheme.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: TXATheme.cardBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: TXATheme.cardBorder.withAlpha(40),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_rounded, color: TXATheme.accentColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$myPostsCount ${txaLang.getText('posts_badge')}',
                            style: TextStyle(color: TXATheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '|',
                            style: TextStyle(color: TXATheme.textMuted, fontSize: 14),
                          ),
                          const SizedBox(width: 12),
                          TXARealtimeStreakTooltip(
                            username: currentUsername,
                            streakCount: currentStreak,
                            child: GestureDetector(
                              onTap: () => TXAStreakModal.show(context, username: currentUsername),
                              onLongPress: () => TXAStreakModal.show(context, username: currentUsername),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.whatshot_rounded,
                                    color: streakItemColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$currentStreak ${txaLang.getText('streak_label')}',
                                    style: TextStyle(
                                      color: streakItemColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
                const SizedBox(height: 16),

                // --- Recap & Achievements Row ---
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    // Recap Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TXARecapScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF42A5F5), Color(0xFFAB47BC)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF42A5F5).withAlpha(100),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              txaLang.getText('recap_button_title'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Achievements Button
                    GestureDetector(
                      onTap: () {
                        TXAAchievementService.instance.syncStats(
                          postsCount: visiblePosts.where((p) => p.senderUsername == currentUsername).length,
                          friendsCount: txaAuth.friendsList.length,
                          streakDays: TXAStreakService.instance.getStreak(currentUsername),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TXAAchievementScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withAlpha(100),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              txaLang.getText('achievements_title'),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. Lịch Vạn Niên (Calendar Photo Grid)
                _buildCalendarSection(visiblePosts, currentUsername),

                 const SizedBox(height: 32),
               ],
             ),
           ),
         ),
       if (_isBuildingTimeline)
         Positioned(
           bottom: 24,
           left: 24,
           right: 24,
           child: IgnorePointer(
             child: AnimatedOpacity(
               opacity: _isBuildingTimeline ? 1.0 : 0.0,
               duration: const Duration(milliseconds: 300),
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                 decoration: BoxDecoration(
                   color: const Color(0xFF1E1E24),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: const Color(0xFF42A5F5).withAlpha(100), width: 1.5),
                   boxShadow: [
                     BoxShadow(
                       color: const Color(0xFF42A5F5).withAlpha(50),
                       blurRadius: 12,
                       spreadRadius: 1,
                     ),
                   ],
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const SizedBox(
                       width: 14,
                       height: 14,
                       child: CircularProgressIndicator(
                         strokeWidth: 2,
                         valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF42A5F5)),
                       ),
                     ),
                     const SizedBox(width: 12),
                     Expanded(
                       child: Text(
                         txaLang.getText('army_building_timeline'),
                         style: const TextStyle(
                           color: Colors.white,
                           fontSize: 13,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
           ),
         ),
     ],
   ),
 );
       },
     ),
   );
 }



  int _calculateMaxStreakInMonth(List<LocketPostModel> posts, String username, int year, int month) {
    final userPostDays = posts
        .where((p) => p.senderUsername == username)
        .map((p) {
          final parsed = DateTime.tryParse(p.createdTime);
          if (parsed == null) return null;
          final local = parsed.toLocal();
          return local;
        })
        .where((d) => d != null && d.year == year && d.month == month)
        .map((d) => d!.day)
        .toSet()
        .toList();

    userPostDays.sort();

    if (userPostDays.isEmpty) return 0;

    int maxStreak = 0;
    int currentStreak = 0;
    int? prevDay;

    for (final day in userPostDays) {
      if (prevDay == null) {
        currentStreak = 1;
      } else if (day == prevDay + 1) {
        currentStreak++;
      } else {
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
        currentStreak = 1;
      }
      prevDay = day;
    }

    if (currentStreak > maxStreak) {
      maxStreak = currentStreak;
    }

    return maxStreak;
  }

  Widget _buildCalendarSection(List<LocketPostModel> visiblePosts, String currentUsername) {
    final txaAuth = TXAAuthService.instance;
    final currentUser = txaAuth.currentUser;
    final txaLang = TXALanguage.instance;

    // Get registration date. Fallback to 3 months ago if null.
    final createdStr = currentUser?.createdTime ?? DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
    final createdDate = DateTime.tryParse(createdStr)?.toLocal() ?? DateTime.now().subtract(const Duration(days: 90));

    final now = DateTime.now();
    final List<DateTime> months = [];
    var tempDate = DateTime(now.year, now.month, 1);
    final limitDate = DateTime(createdDate.year, createdDate.month, 1);

    while (!tempDate.isBefore(limitDate)) {
      months.add(DateTime(tempDate.year, tempDate.month));
      tempDate = DateTime(tempDate.year, tempDate.month - 1);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: List.generate(months.length, (idx) {
              final m = months[idx];
              final isLast = idx == months.length - 1;
              final showYearBadge = idx == 0 || months[idx].year != months[idx - 1].year;
              return Column(
                children: [
                  _buildSingleCompactMonth(
                    m,
                    visiblePosts,
                    txaLang,
                    currentUsername,
                    showYearBadge: showYearBadge,
                    isCurrentMonth: idx == 0,
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 0),
                            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withAlpha(120), shape: BoxShape.circle)),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withAlpha(120), shape: BoxShape.circle)),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withAlpha(120), shape: BoxShape.circle)),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withAlpha(120), shape: BoxShape.circle)),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 0),
                            child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withAlpha(120), size: 26),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  void _showEditMemoryBottomSheet(
    BuildContext context,
    String yearMonthKey,
    int month,
    int year,
    String currentTitle,
  ) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final textCtrl = TextEditingController(text: currentTitle.startsWith('tháng') || currentTitle == 'Cá tháng 4' || currentTitle == 'ngày lọ' ? '' : currentTitle);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final textLen = textCtrl.text.length;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Center drag indicator line
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title: Tên kỷ niệm
                  Text(
                    txaLang.getText('memory_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Gray Chip: tháng X năm Y
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'tháng $month năm $year',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Custom minimal Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textCtrl,
                            maxLength: 100,
                            autofocus: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: txaLang.getText('memory_hint'),
                              hintStyle: const TextStyle(color: Colors.white30),
                              border: InputBorder.none,
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              setModalState(() {});
                            },
                          ),
                        ),
                        Text(
                          '$textLen/100',
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottom Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Button: Dùng mặc định
                      TextButton(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          final ctx = context;
                          await txaAuth.updateMonthlyMemory(yearMonthKey, '');
                          if (ctx.mounted) {
                            nav.pop();
                            TXAToast.show(ctx, txaLang.getText('memory_saved'));
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          txaLang.getText('use_default'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Right Button: Lưu
                      ElevatedButton(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          final ctx = context;
                          await txaAuth.updateMonthlyMemory(yearMonthKey, textCtrl.text.trim());
                          if (ctx.mounted) {
                            nav.pop();
                            TXAToast.show(ctx, txaLang.getText('memory_saved'));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          txaLang.getText('save'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSingleCompactMonth(
    DateTime monthDate,
    List<LocketPostModel> visiblePosts,
    TXALanguage txaLang,
    String currentUsername, {
    required bool showYearBadge,
    required bool isCurrentMonth,
  }) {
    final txaAuth = TXAAuthService.instance;
    final currentUser = txaAuth.currentUser;
    final year = monthDate.year;
    final month = monthDate.month;

    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDayOffset = DateTime(year, month, 1).weekday - 1; // 0 = Mon, 6 = Sun
    final weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    // Determine streak / badge display strictly per month
    int displayStreakCount = 0;
    bool showStreakBadge = false;
    bool isStreakDimmed = false;

    // Thống kê chuỗi liên tiếp chuẩn theo từng tháng riêng biệt (Hiển thị cho tất cả tháng có bài đăng)
    final maxStreakInMonth = _calculateMaxStreakInMonth(visiblePosts, currentUsername, year, month);
    if (maxStreakInMonth > 0) {
      displayStreakCount = maxStreakInMonth;
      showStreakBadge = true;

      if (isCurrentMonth) {
        // Tháng hiện tại: Làm mờ (xám) nếu hôm nay chưa nối chuỗi
        final hasPostedToday = TXAStreakService.instance.hasPostedToday(currentUsername);
        isStreakDimmed = !hasPostedToday;
      } else {
        // Tháng quá khứ: Nếu bỏ lỡ/không rep tròn đủ tất cả các ngày trong tháng (maxStreakInMonth < daysInMonth) -> Vĩnh viễn xám xịt, không thể sáng xanh nổi lại được nữa!
        isStreakDimmed = maxStreakInMonth < daysInMonth;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Year Badge (Nằm ngoài góc trên trái của Container lịch, chỉ hiện khi đổi năm hoặc ở phần tử đầu tiên)
        if (showYearBadge) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              '$year',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 2. Main Calendar Container
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withAlpha(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Slanted Title (e.g. Cá tháng 4 / ngày lọ) with Edit icon & Right indicator pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final yearMonthKey = '${year}_$month';
                        final customTitle = currentUser?.monthlyMemories[yearMonthKey];
                        final defaultTitle = month == 4 ? 'Cá tháng 4' : month == 10 ? 'ngày lọ' : 'tháng $month năm $year';
                        final displayTitle = (customTitle != null && customTitle.isNotEmpty) ? customTitle : defaultTitle;

                        return GestureDetector(
                          onTap: () => _showEditMemoryBottomSheet(context, yearMonthKey, month, year, displayTitle),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    displayTitle,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.edit_rounded, color: Colors.white38, size: 14),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Streak Badge (Con đếm chuỗi liên tiếp màu xanh dương chuẩn theo profile.png)
                  if (showStreakBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isStreakDimmed ? Colors.white.withAlpha(4) : const Color(0xFF42A5F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isStreakDimmed ? Colors.white.withAlpha(10) : const Color(0xFF42A5F5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCurrentMonth ? Icons.bolt_rounded : Icons.auto_awesome_rounded,
                            color: isStreakDimmed ? Colors.white38 : Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$displayStreakCount',
                            style: TextStyle(
                              color: isStreakDimmed ? Colors.white30 : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Tiny Week Days Headers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: weekDays.map((day) {
                  return SizedBox(
                    width: 32,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withAlpha(40), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Compact Days Grid Builder
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: firstDayOffset + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (ctx, index) {
                  if (index < firstDayOffset) {
                    return const SizedBox.shrink();
                  }

                  final dayNum = index - firstDayOffset + 1;
                  final dayDateStr = '$year-${month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';

                  final now = DateTime.now();
                  final isToday = now.year == year && now.month == month && now.day == dayNum;

                  // Find posts on this day (only current user's posts for calendar)
                  final postsOnDay = visiblePosts.where((p) =>
                    p.senderUsername == currentUsername && p.createdTime.startsWith(dayDateStr)
                  ).toList()
                    ..sort((a, b) => b.createdTime.compareTo(a.createdTime)); // newest first

                  if (postsOnDay.isNotEmpty) {
                    final images = postsOnDay.map((p) => p.photoPath).toList();
                    return GestureDetector(
                      onTap: () => _showDayPreview(context, dayDateStr, postsOnDay, visiblePosts),
                      child: _buildFanThumb(images, isToday),
                    );
                  }

                  // Today with no posts: gold circle
                  if (isToday) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5).withAlpha(25),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF42A5F5).withAlpha(128), width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                    );
                  }

                  // Empty day: tiny dot
                  return Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Cánh quạt xòe ra khi có nhiều ảnh trong ngày (tối đa 3 ảnh)
  Widget _buildFanThumb(List<String> images, bool isToday) {
    final count = images.length;
    final displayCount = count > 3 ? 3 : count;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        for (int i = displayCount - 1; i >= 0; i--)
          Transform.translate(
            offset: Offset((i - (displayCount - 1) / 2) * 5, 0),
            child: Transform.rotate(
              angle: (i - (displayCount - 1) / 2) * 0.35,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: isToday ? const Color(0xFF42A5F5) : Colors.white.withAlpha(80),
                    width: isToday ? 2.0 : 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: _buildCalImageWidget(images[i]),
                ),
              ),
            ),
          ),
        if (count > 1)
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(60), width: 0.5),
              ),
              child: Text(
                '+$count',
                style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalImageWidget(String path) {
    // Placeholder chung khi đang tải hoặc path rỗng
    Widget placeholder() => Container(
      color: const Color(0xFF2A2A32),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white12, size: 14),
      ),
    );

    if (path.isEmpty) return placeholder();

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => placeholder(),
      );
    }
    if (path.startsWith('http')) {
      return TXANetworkImage(
        url: path,
        fit: BoxFit.cover,
        loadingBuilder: (context) => placeholder(),
        errorBuilder: (context, error, stackTrace) => placeholder(),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => placeholder(),
    );
  }

  void _showDayPreview(BuildContext context, String dateStr, List<LocketPostModel> dayPosts, List<LocketPostModel> allPosts) {
    if (dayPosts.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withAlpha(230),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim1, anim2) {
        return _DayPostsPreview(
          posts: dayPosts,
          dateStr: dateStr,
          onPostTap: (post) {
            Navigator.pop(context);
            final idx = allPosts.indexOf(post);
            if (idx >= 0) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LocketFeedScreen(initialIndex: idx)),
              );
            }
          },
        );
      },
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final txaFormat = TXAFormat.instance;

    // Animate ≡ → ✕
    _menuAnimCtrl.forward();

    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.background,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final currentUser = txaAuth.currentUser;
        final isAdmin = currentUser?.role == 'admin';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with Handle bar & Close Button (X) at far right corner
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 44), // Spacer for symmetry
                          Expanded(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 44,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: TXATheme.cardBorder,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  txaLang.getText('settings_title'),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ─── Army Subscription Card ───
                      _buildSubscriptionCard(context, currentUser, setModalState),
                      const SizedBox(height: 16),
                      Divider(color: TXATheme.cardBorder),
                      const SizedBox(height: 12),

                      // ─── 1. Ngôn ngữ ───────────────────────────────────────
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.language_rounded, color: Colors.white70),
                        title: Text(txaLang.getText('language_settings'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: DropdownButton<String>(
                          value: txaLang.currentLanguage,
                          dropdownColor: TXATheme.cardBg,
                          underline: const SizedBox(),
                          onChanged: (val) {
                            if (val != null) {
                              txaLang.setLanguage(val);
                              setModalState(() {});
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'en', child: Text('English',   style: TextStyle(color: Colors.white))),
                          ],
                        ),
                      ),
                      Divider(color: TXATheme.cardBorder),



                      // ─── 3. Chủ đề Camera ────────────────────────────────
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.palette_rounded, color: Colors.white70),
                        title: Text(txaLang.getText('camera_theme_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(txaLang.getText('camera_theme_subtitle'), style: TextStyle(color: TXATheme.textMuted, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
                        onTap: () => _showCameraThemeBottomSheet(context),
                      ),

                      // ─── 3.1. Đổi icon app ────────────────────────────────
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.crop_original_rounded, color: Colors.white70),
                        title: Text(txaLang.getText('change_app_icon'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
                        onTap: () {
                          TXAToast.show(context, txaLang.getText('feature_coming_soon'));
                        },
                      ),

                      // ─── 4. Chế độ hiển thị Feed ─────────────────────────
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.grid_view_rounded, color: Colors.white70),
                        title: Text(txaLang.getText('feed_display_mode'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          txaAuth.feedGridMode == 'thought_bubble'
                              ? txaLang.getText('thought_bubbles')
                              : txaLang.getText('photos_only'),
                          style: TextStyle(color: TXATheme.textMuted, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
                        onTap: () {
                          _showFeedGridModeSelectionSheet(context, () => setModalState(() {}));
                        },
                      ),
                      Divider(color: TXATheme.cardBorder),



                      // ─── 5. Hiển thị timestamp ────────────────────────────
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time_rounded, color: Colors.white70),
                        title: Text(txaLang.getText('show_timestamp'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: Switch(
                          value: txaFormat.showTimestamp,
                          activeThumbColor: TXATheme.primaryYellow,
                          activeTrackColor: TXATheme.primaryYellow.withAlpha(80),
                          onChanged: (val) {
                            txaFormat.setShowTimestamp(val);
                            setModalState(() {});
                          },
                        ),
                      ),
                      Divider(color: TXATheme.cardBorder),

                      // ─── 6. Xem lại hướng dẫn Armi 🐜 ────────────────────
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: TXATheme.primaryYellow, width: 1.5),
                          ),
                          child: ClipOval(
                            child: Image.asset('assets/armi_mascot.png', fit: BoxFit.contain),
                          ),
                        ),
                        title: Text(
                          txaLang.getText('replay_coachmark'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        trailing: const Icon(Icons.play_circle_fill_rounded, color: TXATheme.primaryYellow, size: 22),
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('txa_armi_coachmark_seen', false);

                          if (context.mounted) {
                            Navigator.pop(context); // Đóng Sheet Cài đặt
                            Navigator.pop(context); // Về lại LocketMainScreen
                          }
                        },
                      ),
                      Divider(color: TXATheme.cardBorder),

                      // ─── 6. Admin Panel ───────────────────────────────────
                      if (isAdmin) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.shield_rounded, color: TXATheme.primaryYellow),
                          title: Text(txaLang.getText('admin_panel_title'), style: const TextStyle(color: TXATheme.primaryYellow, fontWeight: FontWeight.bold)),
                          subtitle: Text(txaLang.getText('admin_panel_subtitle'), style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: TXATheme.primaryYellow, size: 16),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const TXAAdminPanelScreen()));
                          },
                        ),
                        Divider(color: TXATheme.cardBorder),
                      ],

                      const SizedBox(height: 32),

                      // ─── 7. Đăng xuất ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Capture navigator TRƯỚC khi pop sheet
                            // để tránh lỗi context bị unmounted sau khi đóng modal
                            final rootNavigator = Navigator.of(context, rootNavigator: true);

                            // Hiện dialog xác nhận đăng xuất
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: TXATheme.cardBg,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(
                                  txaLang.getText('logout_confirm_title'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                content: Text(
                                  txaLang.getText('logout_confirm_msg'),
                                  style: TextStyle(color: TXATheme.textSecondary),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      txaLang.getText('cancel'),
                                      style: TextStyle(color: TXATheme.textMuted),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(
                                      txaLang.getText('logout_confirm_btn'),
                                      style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) return;

                            // Reset static state của Profile
                            _TXAProfileScreenState.resetLoadState();

                            // Đóng settings sheet rồi logout
                            if (context.mounted) Navigator.pop(context);
                            await txaAuth.logout();

                            // Dùng rootNavigator đã capture để về màn login,
                            // xóa toàn bộ stack — KHÔNG cần check mounted nữa
                            rootNavigator.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const TXALoginScreen()),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TXATheme.statusRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: Text(txaLang.getText('logout'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ─── 8. Nút Đóng Cài Đặt ───────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: TXATheme.cardBorder, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          label: Text(
                            txaLang.currentLanguage == 'vi' ? 'Đóng Cài Đặt' : 'Close Settings',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Khi đóng modal → quay icon về ≡
      if (mounted) {
        _menuAnimCtrl.reverse();
      }
    });
  }

  void _showFeedGridModeSelectionSheet(BuildContext context, VoidCallback onChanged) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;

    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentMode = txaAuth.feedGridMode;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 16),
                    Text(
                      txaLang.getText('choose_feed_mode_title'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    // Option 1: Bong bóng suy nghĩ
                    GestureDetector(
                      onTap: () async {
                        await txaAuth.setFeedGridMode('thought_bubble');
                        onChanged();
                        if (context.mounted) {
                          setModalState(() {});
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: currentMode == 'thought_bubble' ? const Color(0xFF42A5F5) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_rounded, color: Color(0xFF42A5F5), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                txaLang.getText('thought_bubbles'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            if (currentMode == 'thought_bubble')
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF42A5F5), size: 24),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Option 2: Hình ảnh
                    GestureDetector(
                      onTap: () async {
                        await txaAuth.setFeedGridMode('image');
                        onChanged();
                        if (context.mounted) {
                          setModalState(() {});
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: currentMode == 'image' ? const Color(0xFF42A5F5) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.image_rounded, color: Colors.white70, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                txaLang.getText('photos_only'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            if (currentMode == 'image')
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF42A5F5), size: 24),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, UserModel? user, StateSetter setModalState) {
    final txaLang = TXALanguage.instance;
    final isVip = TXAIAPService.instance.isVipActive;

    if (isVip && user != null) {
      String expiryText = '';
      if (user.vipExpiryDate != null) {
        try {
          final dt = DateTime.parse(user.vipExpiryDate!).toLocal();
          expiryText = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        } catch (_) {}
      }

      final planType = user.vipProductId == TXAIAPService.yearlyProductId
          ? txaLang.getText('vip_plan_yearly')
          : txaLang.getText('vip_plan_monthly');

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFF3E5AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Color(0xFF5C4033), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Army Gold Pass 🌟',
                    style: const TextStyle(
                      color: Color(0xFF5C4033),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C4033),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    planType,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${txaLang.getText('vip_status_active')} • ${txaLang.getText('vip_expiry_date').replaceAll('%date%', expiryText)}',
              style: const TextStyle(
                color: Color(0xFF5C4033),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await TXAIAPService.instance.openCancelSubscription();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5C4033),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    txaLang.getText('vip_cancel_renewal'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TXAGoldPassPaywallScreen()),
                    ).then((_) {
                      setModalState(() {});
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C4033),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0,
                  ),
                  child: Text(
                    txaLang.getText('vip_upgrade_btn'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD700).withAlpha(100),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Army Gold Pass 🌟',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    txaLang.getText('gold_pass_paywall_subtitle'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TXAGoldPassPaywallScreen()),
                ).then((_) {
                  setModalState(() {});
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
              ),
              child: Text(
                txaLang.getText('vip_upgrade_btn'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
  }
}

// ─── DayPostsPreview ────────────────────────────────────────────────────────
// Modal xem tất cả bài đăng trong một ngày từ lịch profile

class _DayPostsPreview extends StatefulWidget {
  final List<LocketPostModel> posts;
  final String dateStr;
  final void Function(LocketPostModel post)? onPostTap;

  const _DayPostsPreview({required this.posts, required this.dateStr, this.onPostTap});

  @override
  State<_DayPostsPreview> createState() => _DayPostsPreviewState();
}

class _DayPostsPreviewState extends State<_DayPostsPreview> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildImg(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    if (path.startsWith('http')) {
      return TXANetworkImage(
        url: path,
        fit: BoxFit.cover,
        loadingBuilder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5), strokeWidth: 2)),
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40)),
      );
    }
    return Image.file(File(path), fit: BoxFit.cover, width: double.infinity, height: double.infinity,
      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40)));
  }

  void _saveCurrentPhoto() {
    TXAToast.show(context, TXALanguage.instance.getText('photo_saved'), icon: Icons.download_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final currentPost = widget.posts[_currentIndex];
    DateTime? postDt;
    try { postDt = DateTime.parse(currentPost.createdTime).toLocal(); } catch (_) {}
    final dateStrText = postDt != null
        ? '${postDt.day.toString().padLeft(2, '0')}/${postDt.month.toString().padLeft(2, '0')}/${postDt.year}'
        : widget.dateStr;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(onTap: () => Navigator.pop(context), behavior: HitTestBehavior.opaque, child: Container(color: Colors.black)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    // 1. Top Bar (Khớp 100% lịch 3.png: [✕] Trái, [3/11] Giữa, [↓] Phải)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Circle Close (✕)
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            ),
                          ),

                          // Center: Slide Counter Pill [ 3 / 11 ]
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${widget.posts.length}',
                              style: const TextStyle(
                                fontFamily: 'ShareTechMono',
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Right: Circle Download (↓)
                          GestureDetector(
                            onTap: _saveCurrentPhoto,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // 2. Photo Viewport with Rounded Corners (Khớp 100% lịch 3.png)
                    SizedBox(
                      height: MediaQuery.of(context).size.width > 520 ? 500.0 : MediaQuery.of(context).size.width * 0.92,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: widget.posts.length,
                          onPageChanged: (idx) => setState(() => _currentIndex = idx),
                          itemBuilder: (context, index) {
                            final post = widget.posts[index];
                            final isSquare = post.aspectRatio == '1:1';
                            return Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: 330,
                                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                                ),
                                child: AspectRatio(
                                  aspectRatio: isSquare ? 1.0 : 3 / 4,
                                  child: GestureDetector(
                                    onTap: () => widget.onPostTap?.call(post),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(40),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(160),
                                            blurRadius: 28,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(40),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            _buildImg(post.photoPath),
                                            if (post.caption.isNotEmpty)
                                              Positioned(
                                                bottom: 0, left: 0, right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                                      colors: [Colors.black.withAlpha(180), Colors.transparent],
                                                    ),
                                                  ),
                                                  child: Text(
                                                    post.caption,
                                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 3,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const Spacer(),

                    // 3. Bottom Left Date Capsule Pill [ 📷 20/06/2026 ] (Khớp 100% lịch 3.png)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withAlpha(30), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                dateStrText,
                                style: const TextStyle(
                                  fontFamily: 'ShareTechMono',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 4. Bottom Horizontal Thumbnail Reel Bar (Phim cuộn ảnh nhỏ giống lịch 3.png)
                    if (widget.posts.length > 1)
                      Container(
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 16, top: 4),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: widget.posts.length,
                          itemBuilder: (ctx, idx) {
                            final p = widget.posts[idx];
                            final isSel = idx == _currentIndex;
                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  idx,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 44,
                                height: 44,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? Colors.white : Colors.transparent,
                                    width: isSel ? 2.2 : 0,
                                  ),
                                  boxShadow: [
                                    if (isSel)
                                      BoxShadow(
                                        color: Colors.white.withAlpha(80),
                                        blurRadius: 8,
                                      ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _buildImg(p.photoPath),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class MicrosoftSpinner extends StatefulWidget {
  final double size;
  final Color color;
  const MicrosoftSpinner({
    super.key,
    this.size = 50.0,
    this.color = const Color(0xFF42A5F5),
  });

  @override
  State<MicrosoftSpinner> createState() => _MicrosoftSpinnerState();
}

class _MicrosoftSpinnerState extends State<MicrosoftSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          children: List.generate(8, (index) {
            final angle = index * (3.141592653589793 * 2) / 8;
            final offset = widget.size / 2 - 3;
            final double radius = widget.size / 2 - 5;
            final double x = offset + radius * cos(angle);
            final double y = offset + radius * sin(angle);
            final opacity = (1.0 - (index / 8.0)).clamp(0.1, 1.0);
            return Positioned(
              left: x,
              top: y,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
