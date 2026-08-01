import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'txa_auth_service.dart';
import 'txa_language.dart';
import '../widgets/txa_toast.dart';
import '../theme/txa_theme.dart';
import '../widgets/txa_avatar_frame.dart';
import '../main.dart'; // import navigatorKey

class TXADeepLinkService {
  static final TXADeepLinkService instance = TXADeepLinkService._internal();
  TXADeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  ServerSocket? _lockSocket;
  static const int _lockPort = 49190;

  static const String _keyPendingInvite = 'txa_pending_invite_username';

  Future<void> init({List<String> args = const []}) async {
    if (_linkSubscription != null) return; // Prevent duplicate subscriptions

    // 1. Single Instance check (Windows only)
    if (!kIsWeb && Platform.isWindows) {
      final isFirstInstance = await _checkSingleInstance(args);
      if (!isFirstInstance) return;
    }

    // 2. Register protocol on Windows HKCU registry (requires no Admin UAC prompts)
    if (!kIsWeb && Platform.isWindows) {
      await _registerWindowsProtocol();
    }

    // 3. Handle initial link (cold start for Android/iOS)
    if (kIsWeb || !Platform.isWindows) {
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          debugPrint('Cold start Deep Link received: $initialUri');
          _processUri(initialUri);
        }
      } catch (e) {
        debugPrint('Error getting initial deep link: $e');
      }
    }

    // 4. Listen to incoming links (warm start for other platforms)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('Warm start Deep Link received: $uri');
        _processUri(uri);
      },
      onError: (err) {
        debugPrint('Deep Link stream error: $err');
      },
    );
  }

  Future<bool> _checkSingleInstance(List<String> args) async {
    // Check command line arguments for deep links
    String? deepLink;
    for (final arg in args) {
      if (arg.startsWith('txa://') || arg.startsWith('https://')) {
        deepLink = arg;
        break;
      }
    }

    try {
      // Try to bind to localhost lock port
      _lockSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, _lockPort);
      
      // Successfully bound -> This is the first instance!
      _lockSocket!.listen((socket) {
        socket.listen((data) {
          final message = String.fromCharCodes(data).trim();
          if (message.isNotEmpty) {
            debugPrint('Received deep link from another instance: $message');
            final uri = Uri.tryParse(message);
            if (uri != null) {
              _processUri(uri);
            }
          }
        });
      });

      // Process our own deep link if launched with one (cold start)
      if (deepLink != null) {
        final uri = Uri.tryParse(deepLink);
        if (uri != null) {
          // Wait a moment for app to fully load before processing
          Future.delayed(const Duration(milliseconds: 1500), () {
            _processUri(uri);
          });
        }
      }

      return true; // Keep running
    } catch (e) {
      // Failed to bind -> Another instance is already running!
      debugPrint('Another instance is running, forwarding link: $deepLink');
      
      if (deepLink != null) {
        try {
          final socket = await Socket.connect(InternetAddress.loopbackIPv4, _lockPort);
          socket.write(deepLink);
          await socket.flush();
          socket.close();
        } catch (err) {
          debugPrint('Failed to forward link: $err');
        }
      }
      
      // Exit second instance immediately
      exit(0);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _lockSocket?.close();
    _lockSocket = null;
  }

  /// Registers txa:// protocol in HKCU on Windows without UAC prompts
  Future<void> _registerWindowsProtocol() async {
    try {
      final appPath = Platform.resolvedExecutable;
      // We run reg.exe commands. /f forces overwrite.
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Classes\\txa',
        '/ve',
        '/d',
        'URL:txa Protocol',
        '/f'
      ]);
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Classes\\txa',
        '/v',
        'URL Protocol',
        '/d',
        '',
        '/f'
      ]);
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Classes\\txa\\shell\\open\\command',
        '/ve',
        '/d',
        '"$appPath" "%1"',
        '/f'
      ]);
      debugPrint('Windows Registry Deep Link Protocol txa:// registered.');
    } catch (e) {
      debugPrint('Failed to register Windows protocol: $e');
    }
  }

  /// Process Uri, parse invite command
  void _processUri(Uri uri) async {
    final path = uri.toString();
    debugPrint('Processing Deep Link URI: $path');
    
    // Support formats:
    // txa://invite/username
    // txa:///invite/username
    // txa://army/invite/username
    // https://army.web.app/invite/username
    
    String? inviteUsername;
    
    if (uri.scheme == 'txa') {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'invite') {
        inviteUsername = segments[1];
      } else if (segments.isNotEmpty && uri.host == 'invite') {
        inviteUsername = segments[0];
      }
    } else if (uri.scheme == 'https' && (uri.host == 'army.web.app' || uri.host == 'army-txa-app.web.app')) {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'invite') {
        inviteUsername = segments[1];
      }
    }

    if (inviteUsername == null || inviteUsername.isEmpty) return;

    // Clean username to starts with '@'
    if (!inviteUsername.startsWith('@')) {
      inviteUsername = '@$inviteUsername';
    }

    final auth = TXAAuthService.instance;
    final context = navigatorKey.currentContext;

    if (auth.currentUser == null || context == null) {
      // Not logged in or view is not mounted yet: save pending invite to shared_preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPendingInvite, inviteUsername);
      debugPrint('Saved pending invite username: $inviteUsername');
    } else {
      // Logged in & app running: show invite UI immediately
      _showInviteDialog(inviteUsername);
    }
  }

  /// Check and trigger pending invite if any (called after successful login/registration)
  Future<void> checkPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_keyPendingInvite);
    if (pending != null && pending.isNotEmpty) {
      await prefs.remove(_keyPendingInvite);
      // Wait a moment for UI transition
      Future.delayed(const Duration(milliseconds: 1000), () {
        _showInviteDialog(pending);
      });
    }
  }

  /// Show the premium full-screen dialog to request adding friend matching the reference UI
  void _showInviteDialog(String targetUsername) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('Cannot show invite dialog: context is null');
      return;
    }

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      barrierDismissible: true,
      barrierLabel: 'Close',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return _InviteDialog(targetUsername: targetUsername);
      },
    );
  }
}

class _InviteDialog extends StatefulWidget {
  final String targetUsername;

  const _InviteDialog({required this.targetUsername});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  StreamSubscription? _subOutgoing;
  StreamSubscription? _subIncoming;

  bool _isOutgoingPending = false;
  bool _isIncomingPending = false;
  String? _incomingRequestId;
  Map<String, dynamic>? _incomingRequestData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final auth = TXAAuthService.instance;
    final fromUser = auth.currentUser?.username ?? '';
    final toUser = widget.targetUsername;

    if (fromUser.isNotEmpty) {
      // 1. Listen to outgoing pending request
      _subOutgoing = FirebaseFirestore.instance
          .collection('friend_requests')
          .where('from', isEqualTo: fromUser)
          .where('to', isEqualTo: toUser)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snap) {
        if (mounted) {
          setState(() {
            _isOutgoingPending = snap.docs.isNotEmpty;
          });
        }
      });

      // 2. Listen to incoming pending request
      _subIncoming = FirebaseFirestore.instance
          .collection('friend_requests')
          .where('from', isEqualTo: toUser)
          .where('to', isEqualTo: fromUser)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snap) {
        if (mounted) {
          setState(() {
            _isIncomingPending = snap.docs.isNotEmpty;
            if (_isIncomingPending) {
              _incomingRequestId = snap.docs.first.id;
              _incomingRequestData = snap.docs.first.data();
            } else {
              _incomingRequestId = null;
              _incomingRequestData = null;
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _subOutgoing?.cancel();
    _subIncoming?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = TXAAuthService.instance;
    final isVi = TXALanguage.instance.currentLanguage == 'vi';
    final target = widget.targetUsername;
    final currentUser = auth.currentUser;

    // Check relationship status
    final isSelf = currentUser?.username == target;
    final isAlreadyFriend = auth.friendsList.any((f) => f['username'] == target);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Top-Left Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 2. Centered Card UI (Matching references)
          Center(
            child: StreamBuilder<UserModel?>(
              stream: auth.listenToUser(target),
              builder: (ctx, snapshot) {
                final user = snapshot.data;
                final displayName = user?.username ?? target;
                final cleanName = displayName.replaceAll('@', '');
                final capitalizedName = cleanName.isNotEmpty
                    ? '${cleanName[0].toUpperCase()}${cleanName.substring(1)}'
                    : target;
                final avatar = user?.avatar ?? '🦊';
                final avatarBgColor = int.tryParse(user?.avatarBgColor ?? '0xFFFFC72C') ?? 0xFFFFC72C;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main Card Container
                    Container(
                      width: 320,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24), // Locket dark card color
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          // circular avatar with thick border
                          Container(
                            padding: const EdgeInsets.all(3.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Color(avatarBgColor), width: 2.5),
                            ),
                            child: TXAAvatarFrame(
                              username: target,
                              radius: 46,
                              tier: TXAFriendTier.normal,
                              showStreakBadge: false,
                              overrideStreak: 0,
                              child: Container(
                                color: Color(avatarBgColor),
                                child: Center(
                                  child: Text(
                                    avatar,
                                    style: const TextStyle(fontSize: 40),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Display Name
                          Text(
                            capitalizedName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Username
                          Text(
                            target,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // Description Prompt
                          Text(
                            isSelf
                                ? (isVi ? 'Đây là tài khoản của bạn trên Army' : 'This is your account on Army')
                                : (isVi
                                    ? 'Muốn kết bạn với người này trên Army?'
                                    : 'Want to be friends with this person on Army?'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: _buildActionButton(
                              isVi,
                              isSelf,
                              isAlreadyFriend,
                              auth,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mascot Sticker Badge overlapping the top-right
                    Positioned(
                      top: -24,
                      right: 12,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFE082), Color(0xFFFFC72C)], // Premium Yellow gradient matching branding
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF1E1E24), width: 3.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFC72C).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                '🐜',
                                style: TextStyle(fontSize: 26),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.redAccent,
                                size: 10,
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
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    bool isVi,
    bool isSelf,
    bool isAlreadyFriend,
    TXAAuthService auth,
  ) {
    if (_isLoading) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.6),
          disabledBackgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    if (isSelf) {
      return ElevatedButton(
        onPressed: () {
          TXAToast.show(
            context,
            isVi ? 'Bạn không thể kết bạn với chính mình!' : 'You cannot add yourself!',
            icon: Icons.info_outline_rounded,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          foregroundColor: Colors.white38,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          isVi ? 'Tài khoản của bạn' : 'Your Account',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      );
    }

    if (isAlreadyFriend) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          disabledForegroundColor: Colors.white30,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          isVi ? 'Đã là bạn bè' : 'Already Friends',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      );
    }

    if (_isOutgoingPending) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
          disabledBackgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.25),
          disabledForegroundColor: const Color(0xFF60A5FA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          isVi ? 'Chờ chấp nhận' : 'Waiting to Accept',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      );
    }

    if (_isIncomingPending) {
      return ElevatedButton(
        onPressed: () async {
          setState(() => _isLoading = true);
          try {
            await auth.acceptFriendRequest(_incomingRequestId!, _incomingRequestData!);
            if (mounted) {
              TXAToast.show(
                context,
                isVi ? 'Đã đồng ý kết bạn!' : 'Friend request accepted!',
                icon: Icons.check_circle_rounded,
                backgroundColor: Colors.green,
              );
            }
          } catch (e) {
            if (mounted) {
              TXAToast.show(
                context,
                'Lỗi: $e',
                icon: Icons.error_rounded,
                backgroundColor: TXATheme.statusRed,
              );
            }
          } finally {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4ADE80), // Green for accept
          foregroundColor: Colors.black,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          isVi ? 'Chấp nhận' : 'Accept Invite',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      );
    }

    // Default: Not friends, allow adding (premium blue button matching Moodet)
    return ElevatedButton(
      onPressed: () async {
        setState(() => _isLoading = true);
        final res = await auth.sendFriendRequest(widget.targetUsername);
        if (mounted) {
          setState(() => _isLoading = false);
          if (res['success'] == true) {
            TXAToast.show(
              context,
              isVi
                  ? '✉️ Đã gửi lời mời tới ${widget.targetUsername}!'
                  : '✉️ Request sent to ${widget.targetUsername}!',
              icon: Icons.check_circle_rounded,
              backgroundColor: Colors.green,
            );
          } else {
            TXAToast.show(
              context,
              res['message'] ?? (isVi ? 'Có lỗi xảy ra' : 'Error occurred'),
              icon: Icons.error_rounded,
              backgroundColor: TXATheme.statusRed,
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6), // Premium Locket Blue
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        isVi ? 'Kết bạn' : 'Add Friend',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      ),
    );
  }
}

