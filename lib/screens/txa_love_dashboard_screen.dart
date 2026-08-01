import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../widgets/txa_toast.dart';
import 'txa_love_feed_screen.dart';

class TXALoveDashboardScreen extends StatefulWidget {
  final String loveId;

  const TXALoveDashboardScreen({super.key, required this.loveId});

  @override
  State<TXALoveDashboardScreen> createState() => _TXALoveDashboardScreenState();
}

class _TXALoveDashboardScreenState extends State<TXALoveDashboardScreen> {
  bool _isBreaking = false;
  Map<String, dynamic>? _partnerInfo;

  @override
  void initState() {
    super.initState();
    _fetchPartnerDetails();
  }

  void _fetchPartnerDetails() {
    final loverUsername = TXAAuthService.instance.currentUser?.loverUsername;
    if (loverUsername != null) {
      TXAAuthService.instance.listenToUser(loverUsername).first.then((user) {
        if (mounted && user != null) {
          setState(() {
            _partnerInfo = {
              'avatar': user.avatar,
              'bgColor': int.tryParse(user.avatarBgColor) ?? 0xFF607D8B,
            };
          });
        }
      });
    }
  }

  int _calculateDays(String startDateStr) {
    try {
      final startDate = DateTime.parse(startDateStr);
      final now = DateTime.now();
      // Calculate differences
      final diff = now.difference(startDate).inDays;
      return diff >= 0 ? diff + 1 : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _confirmBreakUp() async {
    final txaLang = TXALanguage.instance;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TXATheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          txaLang.getText('break_up_confirm_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          txaLang.getText('break_up_confirm_desc'),
          style: const TextStyle(color: TXATheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              txaLang.getText('cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TXATheme.statusRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(txaLang.getText('break_up_btn')),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isBreaking = true);
      final result = await TXAAuthService.instance.breakLoveRelation(widget.loveId);
      if (mounted) {
        setState(() => _isBreaking = false);
        if (result['success'] == true) {
          TXAToast.show(
            context,
            txaLang.getText('break_up_success_toast'),
            icon: Icons.broken_image_rounded,
            backgroundColor: TXATheme.textMuted,
          );
          Navigator.pop(context);
        } else {
          TXAToast.show(
            context,
            result['message'] ?? txaLang.getText('break_up_failed_toast'),
            icon: Icons.error_outline_rounded,
            backgroundColor: TXATheme.statusRed,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final currentUser = txaAuth.currentUser;

    return Scaffold(
      backgroundColor: TXATheme.background,
      appBar: AppBar(
        title: Text(
          txaLang.getText('love_menu_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isBreaking)
            IconButton(
              icon: const Icon(Icons.heart_broken_rounded, color: Colors.white70),
              onPressed: _confirmBreakUp,
              tooltip: txaLang.getText('break_up_btn'),
            ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: txaAuth.listenToLoveConnection(widget.loveId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFF43F5E)));
          }

          final loveData = snapshot.data;
          if (loveData == null) {
            return Center(
              child: Text(
                txaLang.getText('no_posts_yet'),
                style: const TextStyle(color: TXATheme.textMuted),
              ),
            );
          }

          final anniversaryStr = loveData['anniversaryDate'] as String? ?? '';
          final days = _calculateDays(anniversaryStr);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Couple Avatars in Dashboard
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // User Avatar
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Color(int.tryParse(currentUser?.avatarBgColor ?? '0xFF607D8B') ?? 0xFF607D8B),
                          shape: BoxShape.circle,
                          border: Border.all(color: TXATheme.primaryYellow, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            currentUser?.avatar ?? '👤',
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Connecting glowing pink gradient line with heart in center
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [TXATheme.primaryYellow, Color(0xFFF43F5E)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF43F5E).withAlpha(100),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: TXATheme.background,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFF43F5E),
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // Partner Avatar
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Color(_partnerInfo?['bgColor'] as int? ?? 0xFF607D8B),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF43F5E), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _partnerInfo?['avatar'] as String? ?? '👤',
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Large Anniversary counter
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF8A80), Color(0xFFFF1744)],
                    ).createShader(bounds),
                    child: Text(
                      '$days',
                      style: const TextStyle(
                        fontSize: 90,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                   Text(
                    txaLang.getText('love_days_together_label'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    txaLang.getText('anniversary_date_label').replaceFirst(
                      '%date%',
                      anniversaryStr.isNotEmpty
                          ? '${anniversaryStr.substring(8, 10)}/${anniversaryStr.substring(5, 7)}/${anniversaryStr.substring(0, 4)}'
                          : '',
                    ),
                    style: const TextStyle(
                      color: TXATheme.textMuted,
                      fontSize: 14,
                    ),
                  ),

                  const Spacer(),

                  // Open Love Feed Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TXALoveFeedScreen(loveId: widget.loveId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF43F5E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFFF43F5E).withAlpha(120),
                      ),
                      icon: const Icon(Icons.favorite_rounded, size: 24),
                      label: Text(
                        txaLang.getText('love_feed_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
