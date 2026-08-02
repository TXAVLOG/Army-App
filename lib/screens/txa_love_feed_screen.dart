import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_analytics.dart';
import '../services/txa_format.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_feed_service.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_network_image.dart';

class TXALoveFeedScreen extends StatefulWidget {
  final String loveId;

  const TXALoveFeedScreen({super.key, required this.loveId});

  @override
  State<TXALoveFeedScreen> createState() => _TXALoveFeedScreenState();
}

class _TXALoveFeedScreenState extends State<TXALoveFeedScreen> {
  final TextEditingController _statusController = TextEditingController();
  Map<String, dynamic>? _partnerInfo;
  
  // Local coordinates during drag to ensure super smooth movement
  double? _dragX;
  double? _dragY;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenLoveFeed);
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

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  void _showStatusInputDialog(String currentStatus, String loveId) {
    final txaLang = TXALanguage.instance;
    _statusController.text = currentStatus;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TXATheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          txaLang.getText('status_bubble_hint'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: _statusController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: txaLang.getText('love_status_hint'),
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: const Color(0xFFF43F5E).withAlpha(100)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF43F5E)),
            ),
          ),
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              txaLang.getText('cancel'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStatus = _statusController.text.trim();
              Navigator.pop(ctx);
              
              // Get current positions to preserve them
              final loveDoc = await FirebaseFirestore.instance.collection('loves').doc(loveId).get();
              final data = loveDoc.data();
              final double x = data?['bubblePositionX'] as double? ?? 0.5;
              final double y = data?['bubblePositionY'] as double? ?? 0.4;
              
              await TXAAuthService.instance.updateBubblePosition(loveId, x, y, newStatus);
              
              if (mounted) {
                final txaLang = TXALanguage.instance;
                TXAToast.show(
                  context,
                  txaLang.getText('love_status_updated_toast'),
                  icon: Icons.check_circle_rounded,
                  backgroundColor: const Color(0xFFF43F5E),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(txaLang.getText('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final currentUser = txaAuth.currentUser;
    final loverUsername = currentUser?.loverUsername ?? '';

    // Filter posts for couples
    final feedService = TXAFeedService.instance;
    final couplePosts = feedService.posts.where((post) {
      final isBetweenUs = (post.senderUsername == currentUser?.username && loverUsername.isNotEmpty) ||
                          (post.senderUsername == loverUsername);
      final isLoverRecipient = post.recipients.contains('lover');
      return isBetweenUs && isLoverRecipient;
    }).toList();

    return Scaffold(
      backgroundColor: TXATheme.background,
      appBar: AppBar(
        title: Text(
          txaLang.getText('love_feed_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: txaAuth.listenToLoveConnection(widget.loveId),
        builder: (context, snapshot) {
          final loveData = snapshot.data;
          final double firebaseX = loveData?['bubblePositionX'] as double? ?? 0.5;
          final double firebaseY = loveData?['bubblePositionY'] as double? ?? 0.4;
          final currentStatus = loveData?['statusText'] as String? ?? '';

          // Determine coordinate to use (local if dragging, firebase otherwise)
          final xPos = _isDragging ? (_dragX ?? firebaseX) : firebaseX;
          final yPos = _isDragging ? (_dragY ?? firebaseY) : firebaseY;

          return LayoutBuilder(
            builder: (context, constraints) {
              final double screenWidth = constraints.maxWidth;
              final double screenHeight = constraints.maxHeight;

              // Absolute pixel positions computed from ratios
              final double posX = xPos * (screenWidth - 90);
              final double posY = yPos * (screenHeight - 120);

              return Stack(
                children: [
                  // List of posts in background
                  couplePosts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              txaLang.getText('empty_love_feed'),
                              style: const TextStyle(color: TXATheme.textMuted, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 20, bottom: 120, left: 16, right: 16),
                          itemCount: couplePosts.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 24),
                          itemBuilder: (ctx, index) {
                            final post = couplePosts[index];
                            final isOwnPost = post.senderUsername == currentUser?.username;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: TXATheme.cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: TXATheme.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Post Sender Header
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Color(int.tryParse(post.senderAvatarColor) ?? 0xFF607D8B),
                                          shape: BoxShape.circle,
                                        ),
                                        child: ClipOval(
                                          child: post.senderAvatar.startsWith('http')
                                              ? TXANetworkImage(url: post.senderAvatar, fit: BoxFit.cover)
                                              : Center(
                                                  child: Text(
                                                    post.senderAvatar,
                                                    style: const TextStyle(fontSize: 18),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isOwnPost ? 'Bạn' : post.senderUsername,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            TXAFormat.formatPostTime(post.createdTime.isNotEmpty ? post.createdTime : post.timestampText),
                                            style: const TextStyle(
                                              color: TXATheme.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Heart-shaped clipped image frame
                                  Center(
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: ClipPath(
                                        clipper: HeartClipper(),
                                        child: Container(
                                          color: Colors.black12,
                                          child: TXANetworkImage(
                                            url: post.photoPath,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  if (post.caption.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      post.caption,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),

                  // Draggable Partner Avatar Bubble overlay
                  Positioned(
                    left: posX,
                    top: posY,
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _isDragging = true;
                          _dragX = xPos;
                          _dragY = yPos;
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          // Update ratios relative to screen bounds
                          _dragX = (_dragX ?? xPos) + (details.delta.dx / (screenWidth - 90));
                          _dragY = (_dragY ?? yPos) + (details.delta.dy / (screenHeight - 120));

                          // Clamp values
                          _dragX = _dragX!.clamp(0.0, 1.0);
                          _dragY = _dragY!.clamp(0.0, 1.0);
                        });
                      },
                      onPanEnd: (details) async {
                        setState(() {
                          _isDragging = false;
                        });
                        if (_dragX != null && _dragY != null) {
                          await txaAuth.updateBubblePosition(
                            widget.loveId,
                            _dragX!,
                            _dragY!,
                            currentStatus,
                          );
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Speech bubble status box
                          if (currentStatus.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 6),
                              constraints: const BoxConstraints(maxWidth: 160),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(80),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Text(
                                currentStatus,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          // Glowing Avatar Bubble
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Color(_partnerInfo?['bgColor'] as int? ?? 0xFFF43F5E),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF43F5E), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF43F5E).withAlpha(120),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: (_partnerInfo?['avatar'] as String? ?? '❤️').startsWith('http')
                                  ? TXANetworkImage(url: _partnerInfo?['avatar'] as String, fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        _partnerInfo?['avatar'] as String? ?? '❤️',
                                        style: const TextStyle(fontSize: 32),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating Edit Status trigger on bottom-right
                  Positioned(
                    bottom: 24 + MediaQuery.of(context).padding.bottom,
                    right: 24,
                    child: FloatingActionButton.extended(
                      onPressed: () => _showStatusInputDialog(currentStatus, widget.loveId),
                      backgroundColor: const Color(0xFFF43F5E),
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                      label: Text(
                        txaLang.getText('status_bubble_hint'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Heart ClipPath implementation
class HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double width = size.width;
    double height = size.height;
    
    path.moveTo(width / 2, height / 5);
    
    // Upper left curves
    path.cubicTo(
        5 * width / 14, 0,
        0, height / 15,
        0, 2 * height / 5);
        
    // Lower left curves
    path.cubicTo(
        0, 4 * height / 7,
        width / 7, 5 * height / 7,
        width / 2, height);
        
    // Lower right curves
    path.cubicTo(
        6 * width / 7, 5 * height / 7,
        width, 4 * height / 7,
        width, 2 * height / 5);
        
    // Upper right curves
    path.cubicTo(
        width, height / 15,
        9 * width / 14, 0,
        width / 2, height / 5);
        
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
