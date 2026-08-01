import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_network_image.dart';

class TXALoveInvitationScreen extends StatefulWidget {
  final String invitationId;
  final String senderUsername;
  final String startDate;

  const TXALoveInvitationScreen({
    super.key,
    required this.invitationId,
    required this.senderUsername,
    required this.startDate,
  });

  @override
  State<TXALoveInvitationScreen> createState() => _TXALoveInvitationScreenState();
}

class _TXALoveInvitationScreenState extends State<TXALoveInvitationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isProcessing = false;
  Map<String, dynamic>? _senderInfo;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchSenderDetails();
  }

  Future<void> _fetchSenderDetails() async {
    // Listen to user snapshot from auth service to find their avatar details
    TXAAuthService.instance.listenToUser(widget.senderUsername).first.then((user) {
      if (mounted && user != null) {
        setState(() {
          _senderInfo = {
            'avatar': user.avatar,
            'bgColor': int.tryParse(user.avatarBgColor) ?? 0xFFF57C00,
          };
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _acceptInvitation() async {
    setState(() => _isProcessing = true);
    final result = await TXAAuthService.instance.acceptLoveInvitation(
      widget.invitationId,
      widget.senderUsername,
      widget.startDate,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (result['success'] == true) {
        final txaLang = TXALanguage.instance;
        TXAToast.show(
          context,
          txaLang.getText('love_couple_success_toast'),
          icon: Icons.favorite_rounded,
          backgroundColor: const Color(0xFFF43F5E),
        );
        Navigator.pop(context, true);
      } else {
        final txaLang = TXALanguage.instance;
        TXAToast.show(
          context,
          result['message'] ?? txaLang.getText('feature_coming_soon'), // or custom key if needed
          icon: Icons.error_outline_rounded,
          backgroundColor: TXATheme.statusRed,
        );
      }
    }
  }

  Future<void> _declineInvitation() async {
    setState(() => _isProcessing = true);
    await TXAAuthService.instance.declineLoveInvitation(widget.invitationId);
    if (mounted) {
      setState(() => _isProcessing = false);
      final txaLang = TXALanguage.instance;
      TXAToast.show(
        context,
        txaLang.getText('love_couple_declined_toast'),
        icon: Icons.close_rounded,
        backgroundColor: TXATheme.textMuted,
      );
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final currentUser = TXAAuthService.instance.currentUser;

    // Format proposed date
    String formattedDate = '';
    try {
      final dt = DateTime.parse(widget.startDate);
      formattedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      formattedDate = widget.startDate;
    }

    return Scaffold(
      backgroundColor: TXATheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1E0B11),
              TXATheme.background,
              TXATheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Heart Animation
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E).withAlpha(40),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withAlpha(50),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFF43F5E),
                      size: 72,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Couple avatars display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Sender avatar
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Color(_senderInfo?['bgColor'] as int? ?? 0xFF607D8B),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF43F5E), width: 3),
                          ),
                          child: ClipOval(
                            child: (_senderInfo?['avatar'] as String? ?? '👤').startsWith('http')
                                ? TXANetworkImage(url: _senderInfo?['avatar'] as String, fit: BoxFit.cover)
                                : Center(
                                    child: Text(
                                      _senderInfo?['avatar'] as String? ?? '👤',
                                      style: const TextStyle(fontSize: 40),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.senderUsername,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Connective heartbeat indicator
                    const Icon(Icons.swap_horiz_rounded, color: Color(0xFFF43F5E), size: 36),
                    const SizedBox(width: 16),
                    // Current user avatar
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Color(int.tryParse(currentUser?.avatarBgColor ?? '0xFF607D8B') ?? 0xFF607D8B),
                            shape: BoxShape.circle,
                            border: Border.all(color: TXATheme.primaryYellow, width: 3),
                          ),
                          child: ClipOval(
                            child: (currentUser?.avatar ?? '👤').startsWith('http')
                                ? TXANetworkImage(url: currentUser!.avatar, fit: BoxFit.cover)
                                : Center(
                                    child: Text(
                                      currentUser?.avatar ?? '👤',
                                      style: const TextStyle(fontSize: 40),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentUser?.username ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Title & Description
                Text(
                  txaLang.getText('love_invitation_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    txaLang.getText('love_invitation_desc')
                        .replaceFirst('%user%', widget.senderUsername)
                        .replaceFirst('%date%', formattedDate),
                    style: const TextStyle(
                      color: TXATheme.textMuted,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(),

                // Action buttons
                if (_isProcessing)
                  const CircularProgressIndicator(color: Color(0xFFF43F5E))
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _acceptInvitation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF43F5E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        txaLang.getText('accept'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _declineInvitation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TXATheme.textMuted,
                        side: BorderSide(color: TXATheme.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        txaLang.getText('decline'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
