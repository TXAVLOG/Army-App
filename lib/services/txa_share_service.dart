import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'txa_format.dart';
import 'txa_language.dart';
import 'txa_feed_service.dart';
import '../theme/txa_theme.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_avatar_frame.dart';
import '../widgets/txa_network_image.dart';

class TXAShareService {
  static final TXAShareService instance = TXAShareService._internal();
  TXAShareService._internal();

  /// Share a post by creating a beautiful info card image and opening the system share tray
  Future<void> sharePost(BuildContext context, LocketPostModel post) async {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _ShareCardDialog(post: post);
      },
    );
  }
}

class _ShareCardDialog extends StatefulWidget {
  final LocketPostModel post;

  const _ShareCardDialog({required this.post});

  @override
  State<_ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<_ShareCardDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  late String _statusText;

  @override
  void initState() {
    super.initState();
    _statusText = TXALanguage.instance.getText('share_loading_image');
    // Wait a brief moment to ensure image renders fully and boundary is laid out
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _statusText = TXALanguage.instance.getText('share_rendering_card');
        });
        _captureAndShare();
      }
    });
  }

  Future<void> _captureAndShare() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Không tìm thấy Render Boundary');
      }

      // Convert boundary to Image
      final image = await boundary.toImage(pixelRatio: 3.0); // 3x pixel ratio for high quality
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Không thể chuyển đổi ảnh thành byte data');
      }
      final pngBytes = byteData.buffer.asUint8List();

      // Write to temp directory
      final tempDir = await getTemporaryDirectory();
      final shareFile = File('${tempDir.path}/army_share_${widget.post.id}.png');
      await shareFile.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.pop(context); // Close the loading/rendering dialog
        // Trigger system sharing sheet
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(shareFile.path)],
            text: TXALanguage.instance.getText('share_text_caption'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating share card: $e');
      if (mounted) {
        Navigator.pop(context);
        TXAToast.show(
          context,
          TXALanguage.instance
              .getText('share_error_prefix')
              .replaceAll('%error%', e.toString()),
          icon: Icons.error_outline_rounded,
          backgroundColor: TXATheme.statusRed,
        );
      }
    }
  }

  Widget _buildImageWidget(String photoPath) {
    if (photoPath.startsWith('assets/')) {
      return Image.asset(photoPath, fit: BoxFit.cover);
    }
    if (photoPath.startsWith('http')) {
      return TXANetworkImage(
        url: photoPath,
        fit: BoxFit.cover,
        loadingBuilder: (ctx) => const Center(
          child: CircularProgressIndicator(color: TXATheme.primaryYellow),
        ),
        errorBuilder: (ctx, err, st) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
        ),
      );
    }
    return Image.file(
      File(photoPath),
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, st) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    
    // Parse time
    final parsedTime = DateTime.tryParse(post.createdTime);
    final formattedTime = parsedTime != null ? TXAFormat.formatTime(parsedTime) : post.createdTime;

    // Parse avatar color
    final avatarColorVal = int.tryParse(post.senderAvatarColor) ?? 0xFFF57C00;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Offscreen Repaint Boundary (but visible during rendering, so it gets drawn)
            RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                width: 380,
                height: 380, // Render as a beautiful square card
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0B0E), // Locket dark background
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background post image
                      _buildImageWidget(post.photoPath),

                      // Translucent bottom shadow for legibility
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 160,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withAlpha(230),
                                Colors.black.withAlpha(160),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // CAPTION: Center-bottom, slightly above bottom info bar
                      if (post.caption.isNotEmpty)
                        Positioned(
                          bottom: 74,
                          left: 24,
                          right: 24,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(150),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                post.caption,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  shadows: [
                                    Shadow(color: Colors.black45, blurRadius: 4),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),

                      // BOTTOM INFO BAR: Avatar & Name & Time (Left) and Logo (Right)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Bottom-Left Info: User profile and timestamp
                            Expanded(
                              child: Row(
                                children: [
                                  // User Avatar
                                  TXAAvatarFrame(
                                    username: post.senderUsername,
                                    radius: 20,
                                    tier: TXAFriendTier.normal,
                                    showStreakBadge: false,
                                    overrideStreak: 0,
                                    child: Container(
                                      color: Color(avatarColorVal),
                                      child: Center(
                                        child: Text(
                                          post.senderAvatar,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  
                                  // Name and formatted time
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          post.senderUsername,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          formattedTime,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Bottom-Right Info: App Logo branding
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(120),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TXATheme.primaryYellow.withAlpha(100), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: TXATheme.primaryYellow,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text(
                                      '🐜',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'ARMY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Rendering status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: TXATheme.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TXATheme.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: TXATheme.primaryYellow,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
