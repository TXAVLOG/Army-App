import 'package:flutter/material.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';

class TXAToast {
  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline,
    Color? backgroundColor,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        onDismiss: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }

  static void showComingSoon(BuildContext context) {
    final msg = TXALanguage.instance.getText('feature_coming_soon');
    show(context, msg, icon: Icons.construction);
  }

  static void showSelfFriendBlocked(BuildContext context) {
    final msg = TXALanguage.instance.getText('self_friend_blocked');
    show(context, msg, icon: Icons.block);
  }

  static void showFriendRequestNotification(
    BuildContext context, {
    required String name,
    required String username,
    required String avatar,
    required String avatarColor,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
    required VoidCallback onTap,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _FriendRequestBannerWidget(
        name: name,
        username: username,
        avatar: avatar,
        avatarColor: avatarColor,
        onAccept: () {
          entry.remove();
          onAccept();
        },
        onDecline: () {
          entry.remove();
          onDecline();
        },
        onTap: () {
          entry.remove();
          onTap();
        },
        onDismiss: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }

  static void showFriendAcceptedNotification(
    BuildContext context, {
    required String name,
    required String avatar,
    required String avatarColor,
    required VoidCallback onTap,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _FriendAcceptedBannerWidget(
        name: name,
        avatar: avatar,
        avatarColor: avatarColor,
        onTap: () {
          entry.remove();
          onTap();
        },
        onDismiss: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _FriendRequestBannerWidget extends StatefulWidget {
  final String name;
  final String username;
  final String avatar;
  final String avatarColor;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _FriendRequestBannerWidget({
    required this.name,
    required this.username,
    required this.avatar,
    required this.avatarColor,
    required this.onAccept,
    required this.onDecline,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_FriendRequestBannerWidget> createState() => _FriendRequestBannerWidgetState();
}

class _FriendRequestBannerWidgetState extends State<_FriendRequestBannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Auto dismiss after 10 seconds if no interaction
    Future.delayed(const Duration(seconds: 10), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarColorVal = int.tryParse(widget.avatarColor) ?? 0xFF607D8B;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TXATheme.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: TXATheme.primaryYellow.withAlpha(204), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(153),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(avatarColorVal),
                          ),
                          child: Center(
                            child: Text(
                              widget.avatar,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TXALanguage.instance.getText('add_friend'),
                                style: const TextStyle(
                                  color: TXATheme.primaryYellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.name} gửi lời mời kết bạn',
                                style: const TextStyle(
                                  color: TXATheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.username,
                                style: const TextStyle(
                                  color: TXATheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: widget.onDecline,
                          style: TextButton.styleFrom(
                            foregroundColor: TXATheme.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text(TXALanguage.instance.getText('decline')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: widget.onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TXATheme.primaryYellow,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            TXALanguage.instance.getText('accept'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendAcceptedBannerWidget extends StatefulWidget {
  final String name;
  final String avatar;
  final String avatarColor;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _FriendAcceptedBannerWidget({
    required this.name,
    required this.avatar,
    required this.avatarColor,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_FriendAcceptedBannerWidget> createState() => _FriendAcceptedBannerWidgetState();
}

class _FriendAcceptedBannerWidgetState extends State<_FriendAcceptedBannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Auto dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarColorVal = int.tryParse(widget.avatarColor) ?? 0xFF607D8B;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: TXATheme.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: TXATheme.actionBlue.withAlpha(204), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(153),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(avatarColorVal),
                      ),
                      child: Center(
                        child: Text(
                          widget.avatar,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.name} đã chấp nhận lời mời!',
                            style: const TextStyle(
                              color: TXATheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Giờ các bạn đã có thể gửi ảnh cho nhau.',
                            style: TextStyle(
                              color: TXATheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: TXATheme.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color? backgroundColor;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.icon,
    this.backgroundColor,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? TXATheme.cardBg;
    final borderColor = widget.backgroundColor != null ? widget.backgroundColor! : TXATheme.primaryYellow.withAlpha(153);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(128),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: TXATheme.primaryYellow, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: TXATheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
