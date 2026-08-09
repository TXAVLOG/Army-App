import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/txa_festival_manager.dart';
import '../widgets/txa_marquee.dart';
import '../widgets/txa_fireworks.dart';
import '../widgets/txa_tet_countdown_widget.dart';
import '../widgets/txa_blur_dots_overlay.dart';
import '../widgets/txa_snow_effect.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_format.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_feed_service.dart';
import '../services/txa_chat_service.dart';
import '../services/txa_streak_service.dart';
import '../services/txa_analytics.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_network_image.dart';
import 'txa_profile_screen.dart';
import 'txa_chat_list_screen.dart';
import '../widgets/txa_avatar_frame.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../services/txa_share_service.dart';
import '../widgets/txa_native_ad_feed_card.dart';
import '../services/txa_iap_service.dart';
class AppMouseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class LocketFeedScreen extends StatefulWidget {
  final int initialIndex;

  const LocketFeedScreen({super.key, this.initialIndex = 0});

  @override
  State<LocketFeedScreen> createState() => _LocketFeedScreenState();
}


class _LocketFeedScreenState extends State<LocketFeedScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isPoppingToCamera = false; // tránh gọi pop nhiều lần khi vuốt xuống
  final Set<String> _revealedPostIds = {};

  AudioPlayer? _feedAudioPlayer;
  String? _playingPostId;

  void _openGoogleMaps(String locationText) async {
    final cleanLocation = locationText.replaceAll('📍', '').trim();
    if (cleanLocation.isEmpty) return;

    final String mapsUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cleanLocation)}';
    final Uri uri = Uri.parse(mapsUrl);

    try {
      if (!kIsWeb && Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', mapsUrl]);
      } else {
        bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(uri);
        }
      }
      if (mounted) {
        TXAToast.show(
          context,
          '🗺️ Đang mở Google Maps cho "$cleanLocation"...',
          icon: Icons.map_rounded,
        );
      }
    } catch (e) {
      debugPrint('Open maps error: $e');
      if (mounted) {
        TXAToast.show(
          context,
          'Không thể mở ứng dụng Bản đồ: $e',
          icon: Icons.error_outline_rounded,
          backgroundColor: TXATheme.statusRed,
        );
      }
    }
  }

  Future<void> _downloadAndSavePhoto(BuildContext context, String photoPath, String senderUsername) async {
    final txaLang = TXALanguage.instance;
    try {
      final myUser = TXAAuthService.instance.currentUser;
      final isVip = myUser?.isVipActive == true || myUser?.role == 'admin';

      // 1. Get original bytes
      List<int> bytes;
      if (photoPath.startsWith('http')) {
        final response = await http.get(Uri.parse(photoPath));
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
        } else {
          throw Exception('Failed to download image: HTTP ${response.statusCode}');
        }
      } else if (photoPath.startsWith('assets/')) {
        final data = await rootBundle.load(photoPath);
        bytes = data.buffer.asUint8List();
      } else {
        final file = File(photoPath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        } else {
          throw Exception('File not found');
        }
      }

      // 2. Decode the image
      img.Image? originalImage = img.decodeImage(Uint8List.fromList(bytes));
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // 3. Apply watermark if not VIP
      final bool shouldWatermark = !isVip;

      if (shouldWatermark) {
        final text = "Armi @$senderUsername";
        final font = img.arial24; // Built-in bitmap font
        final textWidth = text.length * 14; // Approximate width in pixels
        
        final x = (originalImage.width - textWidth - 30).clamp(0, originalImage.width);
        final y = (originalImage.height - 50).clamp(0, originalImage.height);
        
        // Draw black background rect for contrast
        img.fillRect(
          originalImage,
          x1: x - 10,
          y1: y - 10,
          x2: originalImage.width - 10,
          y2: originalImage.height - 10,
          color: img.ColorRgb8(0, 0, 0),
        );
        
        // Draw the text (Armi yellow color: #FFC72C)
        img.drawString(
          originalImage,
          text,
          font: font,
          x: x,
          y: y,
          color: img.ColorRgb8(255, 199, 44),
        );
      }

      // 4. Encode and save the image
      final encodedBytes = img.encodePng(originalImage);

      // Save depending on platform
      String savePath;
      if (!kIsWeb && Platform.isWindows) {
        final shell = Platform.environment['USERPROFILE'];
        final downloadsDir = Directory('$shell\\Downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        savePath = '${downloadsDir.path}\\army_${DateTime.now().millisecondsSinceEpoch}.png';
      } else {
        final appDocDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        final galleryDir = Directory('${appDocDir.path}/ArmyPictures');
        if (!await galleryDir.exists()) {
          await galleryDir.create(recursive: true);
        }
        savePath = '${galleryDir.path}/army_${DateTime.now().millisecondsSinceEpoch}.png';
      }

      final savedFile = File(savePath);
      await savedFile.writeAsBytes(encodedBytes);

      if (context.mounted) {
        TXAToast.show(
          context,
          txaLang.getText('image_saved_success'),
          icon: Icons.download_done_rounded,
        );
      }
    } catch (e) {
      debugPrint('Error saving photo: $e');
      if (context.mounted) {
        TXAToast.show(
          context,
          '⚠️ ${txaLang.getText('share_error_prefix').replaceAll('%error%', e.toString())}',
          icon: Icons.error_outline_rounded,
          backgroundColor: TXATheme.statusRed,
        );
      }
    }
  }

  // Cấu hình hiển thị và bộ lọc nâng cao
  bool _isGridView = false;
  String _filterType = 'all'; // 'all', 'best_friends', 'friends', hoặc username cụ thể

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenFeed);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _feedAudioPlayer = AudioPlayer();
    _feedAudioPlayer?.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingPostId = null;
        });
      }
    });

    TXAFeedService.instance.init();

    final username = TXAAuthService.instance.currentUser?.username ?? '';
    final visiblePosts = TXAFeedService.instance.getVisiblePostsForUser(username);
    final bool isVip = TXAIAPService.instance.isVipActive;
    final List<dynamic> feedItems = [];
    if (isVip) {
      feedItems.addAll(visiblePosts);
    } else {
      int nextAdOffset = 3;
      int postCounter = 0;
      for (var post in visiblePosts) {
        feedItems.add(post);
        postCounter++;
        if (postCounter == nextAdOffset) {
          feedItems.add('ad_slot');
          postCounter = 0;
          nextAdOffset = nextAdOffset == 3 ? 5 : 3;
        }
      }
    }
    _markCurrentAsRead(feedItems);
  }

  @override
  void dispose() {
    _feedAudioPlayer?.dispose();
    _pageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _togglePlayFeedVoice(LocketPostModel post) async {
    if (post.voicePath == null) return;

    if (_playingPostId == post.id) {
      await _feedAudioPlayer?.stop();
      setState(() => _playingPostId = null);
    } else {
      await _feedAudioPlayer?.stop();
      if (post.voicePath!.startsWith('assets/')) {
        await _feedAudioPlayer?.play(AssetSource(post.voicePath!.replaceFirst('assets/', '')));
      } else {
        await _feedAudioPlayer?.play(DeviceFileSource(post.voicePath!));
      }
      setState(() => _playingPostId = post.id);
    }
  }

  /// Helper: render ảnh post đúng cách bất kể path loại nào (assets/http/local)
  Widget _buildPostImage(String photoPath, {BoxFit fit = BoxFit.cover}) {
    if (photoPath.startsWith('assets/')) {
      return Image.asset(photoPath, fit: fit);
    }
    if (photoPath.startsWith('http')) {
      return TXANetworkImage(
        url: photoPath,
        fit: fit,
        loadingBuilder: (ctx) {
          return Container(
            color: const Color(0xFF1E1E24),
            child: const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5), strokeWidth: 2)),
          );
        },
        
      );
    }
    // Local file path (ảnh chụp từ thiết bị chưa upload xong)
    return Image.file(
      File(photoPath),
      fit: fit,
      errorBuilder: (ctx, err, st) => Container(
        color: const Color(0xFF1E1E24),
        child: const Center(child: Icon(Icons.broken_image_outlined, color: Color(0xFF42A5F5), size: 24)),
      ),
    );
  }

  void _showAuthorReactionsModal(BuildContext context, LocketPostModel post) {
    final txaLang = TXALanguage.instance;
    final reactions = post.reactions;

    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Handle Indicator
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TXATheme.cardBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      txaLang.getText('author_reactions_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: TXATheme.primaryYellow.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${reactions.length}',
                        style: TextStyle(
                          color: TXATheme.primaryYellow,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (reactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      txaLang.getText('no_reactions_yet'),
                      style: TextStyle(color: TXATheme.textMuted, fontSize: 14),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: reactions.length,
                      separatorBuilder: (context, index) => Divider(color: TXATheme.cardBorder, height: 12),
                      itemBuilder: (context, index) {
                        final item = reactions[index];
                        final sender = item['sender'] ?? '@friend';
                        final emoji = item['emoji'] ?? '❤️';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: TXATheme.actionBlue,
                            child: Text(
                              sender.isNotEmpty ? sender[0].toUpperCase() : '👤',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            sender,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(txaLang.getText('reacted_status'), style: TextStyle(color: TXATheme.textMuted, fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(120),
                              shape: BoxShape.circle,
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _markCurrentAsRead(List<dynamic> feedItems) {
    final currentUser = TXAAuthService.instance.currentUser;
    final username = currentUser?.username ?? '@user';

    if (_currentIndex >= 0 && _currentIndex < feedItems.length) {
      final item = feedItems[_currentIndex];
      if (item is LocketPostModel) {
        if (!item.readBy.contains(username) && item.senderUsername != username) {
          TXAFeedService.instance.markAllPostsAsRead(username);
        } else {
          TXAFeedService.instance.markPostAsRead(item.id, username);
        }
      }
    }
  }

  void _onAddReaction(LocketPostModel post, String emoji) {
    final txaLang = TXALanguage.instance;
    final currentUser = TXAAuthService.instance.currentUser;
    final username = currentUser?.username ?? '@user';

    // 1. Thả cảm xúc
    TXAFeedService.instance.addReaction(postId: post.id, senderUsername: username, emoji: emoji);

    // 2. Đưa emoji này lên đầu danh sách dải emoji và lưu lên Firestore (luôn đảm bảo đi kèm bộ emoji gốc phía sau)
    final defaultEmojis = ['❤️', '🔥', '😮', '😂', '😢', '👍'];
    final List<String> newOrder = [emoji];
    for (var def in defaultEmojis) {
      if (def != emoji) {
        newOrder.add(def);
      }
    }
    TXAFeedService.instance.updateQuickEmojisOrder(postId: post.id, newOrder: newOrder);

    TXAToast.show(
      context,
      txaLang.getText('reaction_sent').replaceAll('%emoji%', emoji),
      icon: Icons.favorite_rounded,
    );
  }

  void _showSystemEmojiPickerBottomSheet(BuildContext context, LocketPostModel post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 320,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              Navigator.pop(ctx);
              _onAddReaction(post, emoji.emoji);
            },
          ),
        );
      },
    );
  }

  void _onSendComment(LocketPostModel post) async {
    final txaLang = TXALanguage.instance;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    FocusScope.of(context).unfocus();

    final currentUser = TXAAuthService.instance.currentUser;
    if (currentUser == null) return;

    try {
      await TXAChatService.instance.sendMessage(
        senderUsername: currentUser.username,
        receiverUsername: post.senderUsername,
        text: text,
        postId: post.id,
        postPhotoPath: post.photoPath,
        postCaption: post.caption,
        postSenderUsername: post.senderUsername,
      );
      if (mounted) {
        TXAToast.show(
          context,
          txaLang.getText('message_sent_to').replaceAll('%user%', post.senderUsername),
          icon: Icons.send_rounded,
        );
      }
    } catch (e) {
      debugPrint('Error sending feed reply: $e');
    }
  }

  void _showFeedOptionsModal(BuildContext context, LocketPostModel post) {
    final txaLang = TXALanguage.instance;
    final currentUser = TXAAuthService.instance.currentUser;
    final isAuthor = currentUser?.username == post.senderUsername;

    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Handle Indicator
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TXATheme.cardBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  txaLang.getText('post_options_of').replaceAll('%user%', post.senderUsername),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TXATheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.download_rounded, color: Color(0xFF42A5F5)),
                  title: Text(
                    txaLang.getText('download_photo'),
                    style: TextStyle(color: TXATheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadAndSavePhoto(context, post.photoPath, post.senderUsername);
                  },
                ),
                if (!isAuthor)
                  ListTile(
                    leading: const Icon(Icons.outlined_flag_rounded, color: TXATheme.statusRed),
                    title: Text(
                      txaLang.getText('report_post'),
                      style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      final currentUser = TXAAuthService.instance.currentUser;
                      final reporterUsername = currentUser?.username ?? '@user';
                      TXAFeedService.instance.reportPost(
                        postId: post.id,
                        reporterUsername: reporterUsername,
                      );
                      TXAToast.show(
                        context,
                        txaLang.getText('report_sent_success'),
                        icon: Icons.flag_rounded,
                        backgroundColor: TXATheme.statusRed,
                      );
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.share_rounded, color: Color(0xFF42A5F5)),
                  title: Text(
                    txaLang.getText('share_post'),
                    style: TextStyle(color: TXATheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    TXAShareService.instance.sharePost(context, post);
                  },
                ),
                if (isAuthor)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: TXATheme.statusRed),
                    title: Text(
                      txaLang.getText('delete_post_this'),
                      style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold),
                    ),
                    onTap: () async {
                      final nav = Navigator.of(context);
                      nav.pop();
                      await TXAFeedService.instance.deletePost(post.id);
                      if (context.mounted) {
                        TXAToast.show(
                          context,
                          txaLang.getText('post_deleted_success'),
                          icon: Icons.delete_forever_rounded,
                        );
                        if (TXAFeedService.instance.getVisiblePostsForUser(currentUser?.username ?? '').isEmpty) {
                          nav.pop();
                        }
                      }
                    },
                  ),
                if (!isAuthor) ...[
                  Divider(color: TXATheme.cardBorder),
                  // Nút Chặn (Block) - feed option drop.png
                  ListTile(
                    leading: const Icon(Icons.block_rounded, color: TXATheme.statusRed),
                    title: Text(
                      txaLang.getText('block_user'),
                      style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      TXAToast.show(
                        context,
                        'Đã chặn ${post.senderUsername}!',
                        icon: Icons.block_rounded,
                        backgroundColor: TXATheme.statusRed,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterDropdownSheet(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;

    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        bool isLoadingFriends = true;
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isLoadingFriends) {
              txaAuth.syncFriendsFromFirestore().then((_) {
                if (context.mounted) {
                  setModalState(() {
                    isLoadingFriends = false;
                  });
                }
              }).catchError((_) {
                if (context.mounted) {
                  setModalState(() {
                    isLoadingFriends = false;
                  });
                }
              });
            }

            return SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    ListTile(
                      leading: const Icon(Icons.people_rounded, color: Colors.white70),
                      title: Text(txaLang.getText('filter_everyone'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: _filterType == 'all' ? const Icon(Icons.check_circle_rounded, color: Color(0xFF42A5F5)) : null,
                      onTap: () {
                        setState(() => _filterType = 'all');
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_rounded, color: Color(0xFF42A5F5)),
                      title: Text(txaLang.currentLanguage == 'vi' ? 'Tôi' : 'Me', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: _filterType == 'me' ? const Icon(Icons.check_circle_rounded, color: Color(0xFF42A5F5)) : null,
                      onTap: () {
                        setState(() => _filterType = 'me');
                        Navigator.pop(context);
                      },
                    ),
                    if (txaAuth.bestFriendsList.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.star_rounded, color: Colors.amber),
                        title: Text(txaLang.getText('filter_best_friends'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: _filterType == 'best_friends' ? const Icon(Icons.check_circle_rounded, color: Color(0xFF42A5F5)) : null,
                        onTap: () {
                          setState(() => _filterType = 'best_friends');
                          Navigator.pop(context);
                        },
                      ),
                    ListTile(
                      leading: Icon(Icons.people_alt_rounded, color: TXATheme.primaryYellow),
                      title: Text(txaLang.currentLanguage == 'vi' ? 'Bạn bè' : 'Friends', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: _filterType == 'friends' ? Icon(Icons.check_circle_rounded, color: Color(0xFF42A5F5)) : null,
                      onTap: () {
                        setState(() => _filterType = 'friends');
                        Navigator.pop(context);
                      },
                    ),
                    Divider(color: TXATheme.cardBorder),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('BẠN BÈ', style: TextStyle(color: TXATheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    if (isLoadingFriends)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const TXASpinningIcon(
                              icon: Icons.sync_rounded,
                              size: 18,
                              color: TXATheme.primaryYellow,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              txaLang.getText('loading_friends_list'),
                              style: TextStyle(color: TXATheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    else if (txaAuth.friendsList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          txaLang.getText('no_friends_yet'),
                          style: TextStyle(color: TXATheme.textMuted, fontSize: 13),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: txaAuth.friendsList.length,
                          itemBuilder: (context, idx) {
                            final friend = txaAuth.friendsList[idx];
                            final fUser = friend['username'] as String;
                            final fAvatar = friend['avatar'] as String? ?? '👤';
                            final fColor = friend['bgColor'] as int? ?? 0xFF607D8B;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(fColor),
                                child: ClipOval(
                                  child: fAvatar.startsWith('http')
                                      ? SizedBox(width: 40, height: 40, child: TXANetworkImage(url: fAvatar, fit: BoxFit.cover))
                                      : Center(child: Text(fAvatar, style: const TextStyle(fontSize: 16))),
                                ),
                              ),
                              title: Text(fUser, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              trailing: _filterType == fUser ? const Icon(Icons.check_circle_rounded, color: Color(0xFF42A5F5)) : null,
                              onTap: () {
                                setState(() => _filterType = fUser);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txaAuth = TXAAuthService.instance;
    final txaLang = TXALanguage.instance;
    final currentUser = txaAuth.currentUser;
    final username = currentUser?.username ?? '@user';

    return AnimatedBuilder(
      animation: Listenable.merge([TXAFeedService.instance, txaLang, txaAuth]),
      builder: (context, _) {
        var visiblePosts = TXAFeedService.instance.getVisiblePostsForUser(
          username,
        );

        // Áp dụng bộ lọc dropdown
        if (_filterType == 'me') {
          visiblePosts = visiblePosts
              .where((p) => p.senderUsername == username)
              .toList();
        } else if (_filterType == 'best_friends') {
          final bestFriendsUsernames = txaAuth.bestFriendsList
              .map((f) => f['username'] as String)
              .toSet();
          visiblePosts = visiblePosts
              .where((p) => bestFriendsUsernames.contains(p.senderUsername))
              .toList();
        } else if (_filterType == 'friends') {
          final friendUsernames = txaAuth.friendsList
              .map((f) => f['username'] as String)
              .toSet();
          visiblePosts = visiblePosts
              .where(
                (p) =>
                    friendUsernames.contains(p.senderUsername) &&
                    p.senderUsername != username,
              )
              .toList();
        } else if (_filterType != 'all') {
          visiblePosts = visiblePosts
              .where((p) => p.senderUsername == _filterType)
              .toList();
        }

        final bool isVip = TXAIAPService.instance.isVipActive;
        final List<dynamic> feedItems = [];
        if (isVip) {
          feedItems.addAll(visiblePosts);
        } else {
          int postCounter = 0;
          for (var post in visiblePosts) {
            feedItems.add(post);
            postCounter++;
            if (postCounter == 4) {
              feedItems.add('ad_slot');
              postCounter = 0;
            }
          }
          // Nếu số bài đăng chưa đủ 4 (chưa có ad nào được chèn) và không phải VIP, bắt buộc chèn 1 ad_slot
          if (visiblePosts.isNotEmpty && !feedItems.contains('ad_slot')) {
            feedItems.add('ad_slot');
          }
        }

        // Widget tiêu đề bộ lọc dropdown
        Widget buildFilterDropdownPill() {
          String filterLabel = txaLang.getText('filter_everyone');
          IconData filterIcon = Icons.people_rounded;
          if (_filterType == 'me') {
            filterLabel = txaLang.currentLanguage == 'vi' ? 'Tôi' : 'Me';
            filterIcon = Icons.person_rounded;
          } else if (_filterType == 'best_friends') {
            filterLabel = txaLang.getText('filter_best_friends');
            filterIcon = Icons.star_rounded;
          } else if (_filterType == 'friends') {
            filterLabel = txaLang.currentLanguage == 'vi'
                ? 'Bạn bè'
                : 'Friends';
            filterIcon = Icons.people_alt_rounded;
          } else if (_filterType != 'all') {
            filterLabel = _filterType;
            filterIcon = Icons.account_circle_rounded;
          }

          return GestureDetector(
            onTap: () => _showFilterDropdownSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filterIcon,
                    color: _filterType == 'best_friends'
                        ? Colors.amber
                        : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      filterLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        }

        if (visiblePosts.isEmpty) {
          return Scaffold(
            backgroundColor: TXATheme.background,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight + 8),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    centerTitle: true,
                    title: buildFilterDropdownPill(),
                  ),
                ),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: TXATheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    txaLang.getText('no_posts_yet'),
                    style: TextStyle(
                      color: TXATheme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // RENDER CHẾ ĐỘ LƯỚI (Grid View)
        if (_isGridView) {
          final isThoughtBubbleMode = txaAuth.feedGridMode == 'thought_bubble';

          return Scaffold(
            backgroundColor: TXATheme.background,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight + 8),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => setState(() => _isGridView = false),
                    ),
                    centerTitle: true,
                    title: buildFilterDropdownPill(),
                  ),
                ),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: (() {
                        final w = MediaQuery.of(context).size.width;
                        if (w >= 900) return 4;
                        if (w >= 600) return 3;
                        return 3;
                      })(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 16,
                      childAspectRatio: isThoughtBubbleMode ? 0.62 : 1.0,
                    ),
                    itemCount: visiblePosts.length,
                    itemBuilder: (context, idx) {
                      final post = visiblePosts[idx];

                      if (isThoughtBubbleMode) {
                        // CHẾ ĐỘ BONG BÓNG SUY NGHĨ — giống Locket gốc
                        // Bong bóng lớn (chứa ảnh thật + caption), avatar nhỏ bên dưới
                        final String reactionEmoji = post.reactions.isNotEmpty
                            ? (post.reactions.last['emoji'] ?? '😊').toString()
                            : '😊';
                        final avatarColor = Color(
                          int.tryParse(post.senderAvatarColor) ?? 0xFF42A5F5,
                        );

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentIndex = idx;
                              _isGridView = false;
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ═══ BONG BÓNG LỚN ═══
                              Expanded(
                                flex: 65,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Bong bóng chính — bo góc lớn, chứa ảnh thật
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: Container(
                                        width: double.infinity,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1C1C1E),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // Ảnh post thật
                                            _buildPostImage(
                                              post.photoPath,
                                              fit: BoxFit.cover,
                                            ),
                                            // Gradient mờ phía dưới để caption dễ đọc
                                            if (post.caption.isNotEmpty)
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment
                                                          .bottomCenter,
                                                      end: Alignment.topCenter,
                                                      colors: [
                                                        Colors.black.withValues(
                                                          alpha: 0.75,
                                                        ),
                                                        Colors.transparent,
                                                      ],
                                                      stops: const [0.0, 1.0],
                                                    ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        8,
                                                        16,
                                                        8,
                                                        8,
                                                      ),
                                                  child: Text(
                                                    post.caption.replaceAll(
                                                      RegExp(r'Còn\s+19[0-9]'),
                                                      'Còn ${TXAFestivalManager.getDaysToTet2027(DateTime.now())}',
                                                    ),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.3,
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.black54,
                                                          blurRadius: 4,
                                                        ),
                                                      ],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Reaction emoji nổi góc trên trái
                                    Positioned(
                                      top: -8,
                                      left: -6,
                                      child: Text(
                                        reactionEmoji,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Đuôi bong bóng (tam giác nhỏ giữa)
                              CustomPaint(
                                size: const Size(18, 10),
                                painter: _BubbleTailPainter(),
                              ),

                              // ═══ AVATAR NHỎ ═══
                              TXAAvatarFrame(
                                username: post.senderUsername,
                                radius: 20,
                                tier: _getFriendTier(post.senderUsername),
                                showStreakBadge: true,
                                child: Container(
                                  color: avatarColor.withValues(alpha: 0.2),
                                  child: post.senderAvatar.startsWith('http')
                                      ? TXANetworkImage(
                                          url: post.senderAvatar,
                                          fit: BoxFit.cover,
                                        )
                                      : Center(
                                          child: Text(
                                            post.senderAvatar,
                                            style: const TextStyle(
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 4),

                              // ═══ TÊN USER ═══
                              Text(
                                post.senderUsername.replaceAll('@', ''),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        );
                      } else {
                        // CHẾ ĐỘ LƯỚI ẢNH TIÊU CHUẨN
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentIndex = idx;
                              _isGridView = false;
                            });
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _buildPostImage(post.photoPath),
                          ),
                        );
                      }
                    },
                  ),
                ),
                // Thanh bottom bar của Grid View
                _buildBottomNavigationBar(context, visiblePosts, feedItems),
              ],
            ),
          );
        }

        // RENDER CHẾ ĐỘ VUỐT (Swipe View)
        final safeIndex = _currentIndex.clamp(0, visiblePosts.length - 1);
        final post = visiblePosts[safeIndex];
        final avatarColorVal =
            int.tryParse(post.senderAvatarColor) ?? 0xFFF57C00;

        return Scaffold(
          backgroundColor: TXATheme.background,
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (_currentIndex == 0 &&
                  !_isPoppingToCamera &&
                  notification is ScrollUpdateNotification &&
                  notification.dragDetails != null &&
                  notification.scrollDelta != null &&
                  notification.scrollDelta! < -10) {
                _isPoppingToCamera = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    final nav = Navigator.of(context);
                    if (nav.canPop()) {
                      nav.pop();
                    }
                  }
                  _isPoppingToCamera = false;
                });
                return true;
              }
              return false;
            },
            child: SafeArea(
              child: Column(
                children: [
                  // 1. Top Bar (Avatar trỏ sang profile, Filter Dropdown, Tin nhắn)
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: (MediaQuery.of(context).padding.top > 0
                          ? 8.0
                          : 12.0),
                      bottom: 10.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Current user avatar (mở màn hình Profile)
                        GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TXAProfileScreen(),
                              ),
                            );
                            if (result == 'show_friends_modal') {
                              if (context.mounted) {
                                Navigator.pop(context, 'show_friends_modal');
                              }
                            }
                          },
                          child: TXARealtimeStreakTooltip(
                            username: currentUser?.username ?? '@user',
                            streakCount: TXAStreakService.instance.getStreak(
                              currentUser?.username ?? '',
                            ),
                            child: TXAAvatarFrame(
                              username: currentUser?.username ?? '@user',
                              radius: 18,
                              tier: _getFriendTier(currentUser?.username ?? ''),
                              child: Container(
                                color: Color(
                                  int.tryParse(
                                        currentUser?.avatarBgColor ??
                                            '0xFF42A5F5',
                                      ) ??
                                      0xFF42A5F5,
                                ),
                                child:
                                    (currentUser?.avatar ?? '🦊').startsWith(
                                      'http',
                                    )
                                    ? TXANetworkImage(
                                        url: currentUser!.avatar,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Text(
                                          currentUser?.avatar ?? '🦊',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        // Center: Filter Dropdown Pill
                        buildFilterDropdownPill(),
                        // Right: Tin nhắn (Icon chat)
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TXAChatListScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      scrollBehavior: AppMouseScrollBehavior(),
                      scrollDirection: Axis.vertical,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                          _revealedPostIds.clear();
                        });
                        _markCurrentAsRead(feedItems);
                      },
                      itemCount: feedItems.length,
                      itemBuilder: (context, index) {
                        final item = feedItems[index];
                        if (item == 'ad_slot') {
                          return const TXANativeAdFeedCard();
                        }
                        final currentPost = item as LocketPostModel;
                        final currentIsSquare =
                            currentPost.aspectRatio == '1:1';
                        final isSnow =
                            currentPost.caption.toLowerCase().contains(
                              'snow',
                            ) ||
                            currentPost.moodEmoji.toLowerCase().contains(
                              'snow',
                            ) ||
                            currentPost.caption.contains('❄️') ||
                            currentPost.moodEmoji.contains('❄️');
                        final Widget postItem = Column(
                          children: [
                            const Spacer(flex: 1),
                            // Khung ngắm xem ảnh
                            Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: 350,
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.55,
                                ),
                                child: AspectRatio(
                                  aspectRatio: currentIsSquare ? 1.0 : 3 / 4,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          (() {
                                            final Widget mainImageWidget =
                                                currentPost.photoPath
                                                    .startsWith('assets/')
                                                ? Image.asset(
                                                    currentPost.photoPath,
                                                    fit: BoxFit.cover,
                                                  )
                                                : currentPost.photoPath
                                                      .startsWith('http')
                                                ? TXANetworkImage(
                                                    url: currentPost.photoPath,
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (ctx) {
                                                      return Container(
                                                        color: const Color(
                                                          0xFF1E1E24,
                                                        ),
                                                        child: const Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                color: Color(
                                                                  0xFF42A5F5,
                                                                ),
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    
                                                  )
                                                : Image.file(
                                                    File(currentPost.photoPath),
                                                    fit: BoxFit.cover,
                                                  );

                                            if (currentPost.isBlurOverlay ==
                                                    true &&
                                                !_revealedPostIds.contains(
                                                  currentPost.id,
                                                )) {
                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _revealedPostIds.add(
                                                      currentPost.id,
                                                    );
                                                  });
                                                },
                                                child: TXABlurDotsOverlay(
                                                  blur: 15.0,
                                                  child: mainImageWidget,
                                                ),
                                              );
                                            }
                                            return mainImageWidget;
                                          })(),

                                          // Pháo hoa Tết Đinh Mùi 2027
                                          if (currentPost.moodEmoji ==
                                                  '__tet_lunar_2027__' ||
                                              TXAFestivalManager.isMung1to5Tet(
                                                DateTime.tryParse(
                                                      currentPost.createdTime,
                                                    ) ??
                                                    DateTime.now(),
                                              ) ||
                                              TXAFestivalManager.isMung1to5Tet(
                                                DateTime.now(),
                                              ))
                                            Positioned.fill(
                                              child: TXAFireworks(
                                                isPlaying:
                                                    _currentIndex == index,
                                              ),
                                            ),

                                          // Reaction emoji đè góc trên phải ảnh (chỉ khi là emoji đơn, không phải sticker text)
                                          if (currentPost
                                                  .moodEmoji
                                                  .isNotEmpty &&
                                              currentPost.moodEmoji.length <=
                                                  4 &&
                                              currentPost.stickerBgColor ==
                                                  null &&
                                              currentPost.stickerGradient ==
                                                  null)
                                            Positioned(
                                              top: 14,
                                              right: 14,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black45,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white10,
                                                  ),
                                                ),
                                                child: Text(
                                                  currentPost.moodEmoji,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Voice Note Player nếu có
                                          if (currentPost.voicePath != null)
                                            Positioned(
                                              bottom: 16,
                                              left: 16,
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _togglePlayFeedVoice(
                                                      currentPost,
                                                    ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _playingPostId ==
                                                            currentPost.id
                                                        ? const Color(
                                                            0xFF42A5F5,
                                                          ).withAlpha(220)
                                                        : Colors.black
                                                              .withAlpha(190),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          _playingPostId ==
                                                              currentPost.id
                                                          ? const Color(
                                                              0xFF42A5F5,
                                                            )
                                                          : const Color(
                                                              0xFF42A5F5,
                                                            ),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        _playingPostId ==
                                                                currentPost.id
                                                            ? Icons
                                                                  .pause_rounded
                                                            : Icons
                                                                  .play_arrow_rounded,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        _playingPostId ==
                                                                currentPost.id
                                                            ? txaLang.getText(
                                                                'pause_voice',
                                                              )
                                                            : txaLang
                                                                  .getText(
                                                                    'play_voice',
                                                                  )
                                                                  .replaceAll(
                                                                    '%sec%',
                                                                    '${currentPost.voiceDuration ?? 15}',
                                                                  ),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Caption text bubble (chỉ hiện khi caption không rỗng VÀ không có sticker)
                                          if (currentPost.caption.isNotEmpty &&
                                              currentPost.stickerBgColor ==
                                                  null &&
                                              currentPost.stickerGradient ==
                                                  null &&
                                              currentPost.moodEmoji.length <= 4)
                                            Positioned(
                                              bottom: 16,
                                              right: 16,
                                              left:
                                                  currentPost.voicePath != null
                                                  ? 180
                                                  : 16,
                                              child: Builder(
                                                builder: (_) {
                                                  final isLoc =
                                                      currentPost.caption
                                                          .contains('📍') ||
                                                      currentPost.caption
                                                          .contains(
                                                            'Việt Nam',
                                                          ) ||
                                                      currentPost.caption
                                                          .contains('Hà Nội') ||
                                                      currentPost.caption
                                                          .contains(
                                                            'Hồ Chí Minh',
                                                          ) ||
                                                      currentPost.caption
                                                          .contains(
                                                            'Đà Nẵng',
                                                          ) ||
                                                      currentPost.caption
                                                          .contains('GPS');
                                                  return GestureDetector(
                                                    onTap: isLoc
                                                        ? () => _openGoogleMaps(
                                                            currentPost.caption,
                                                          )
                                                        : null,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isLoc
                                                            ? const Color(
                                                                0xFF343238,
                                                              ).withAlpha(230)
                                                            : Colors.black54,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        border: isLoc
                                                            ? Border.all(
                                                                color: Colors
                                                                    .white30,
                                                                width: 1.0,
                                                              )
                                                            : null,
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          if (isLoc) ...[
                                                            const Icon(
                                                              Icons.map_rounded,
                                                              color: Color(
                                                                0xFF42A5F5,
                                                              ),
                                                              size: 14,
                                                            ),
                                                            const SizedBox(
                                                              width: 6,
                                                            ),
                                                          ],
                                                          Flexible(
                                                            child: Text(
                                                              currentPost
                                                                  .caption,
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),

                                          // Sticker pill: hiện khi có màu sticker HOẶC moodEmoji là text dài/review (bài cũ)
                                          if (currentPost.stickerBgColor !=
                                                  null ||
                                              currentPost.stickerGradient !=
                                                  null ||
                                              currentPost.moodEmoji.length >
                                                  4 ||
                                              currentPost.moodEmoji.startsWith(
                                                '__review',
                                              ))
                                            Positioned(
                                              bottom: 16,
                                              left: 16,
                                              right: 16,
                                              child: Builder(
                                                builder: (_) {
                                                  final postDate =
                                                      DateTime.tryParse(
                                                        currentPost.createdTime,
                                                      ) ??
                                                      DateTime.now();
                                                  final activeTet =
                                                      TXAFestivalManager.getActiveTetDate(
                                                        postDate,
                                                      );
                                                  final tetName =
                                                      TXAFestivalManager.getTetNameForDate(
                                                        activeTet,
                                                        txaLang.currentLanguage,
                                                      );
                                                  List<Color>? gradColors;
                                                  Color bgColor = Colors.black
                                                      .withAlpha(200);

                                                  if (currentPost.moodEmoji
                                                      .startsWith(
                                                        '__zodiac_',
                                                      )) {
                                                    final zKey = currentPost
                                                        .moodEmoji
                                                        .replaceAll('__', '')
                                                        .replaceFirst(
                                                          'zodiac_',
                                                          '',
                                                        );
                                                    final zInfo =
                                                        TXAFestivalManager.getZodiacInfoByKey(
                                                          zKey,
                                                        );
                                                    if (zInfo != null) {
                                                      bgColor = zInfo.baseColor;
                                                      gradColors =
                                                          zInfo.gradient;
                                                    }
                                                  }

                                                  if (currentPost.moodEmoji
                                                      .startsWith('__review')) {
                                                    gradColors = [
                                                      const Color(0xFFFF9100),
                                                      const Color(0xFFFF3D00),
                                                    ];
                                                  }

                                                  if (currentPost
                                                          .stickerGradient !=
                                                      null) {
                                                    gradColors = currentPost
                                                        .stickerGradient!
                                                        .split(',')
                                                        .map((hex) {
                                                          final val =
                                                              int.tryParse(
                                                                hex,
                                                              ) ??
                                                              0xFF000000;
                                                          return Color(val);
                                                        })
                                                        .toList();
                                                  }
                                                  if (currentPost
                                                          .stickerBgColor !=
                                                      null) {
                                                    final val =
                                                        int.tryParse(
                                                          currentPost
                                                              .stickerBgColor!,
                                                        ) ??
                                                        0xFF000000;
                                                    bgColor = Color(val);
                                                  }
                                                  Color textColor =
                                                      Colors.white;
                                                  if (currentPost
                                                          .stickerTextColor !=
                                                      null) {
                                                    final val =
                                                        int.tryParse(
                                                          currentPost
                                                              .stickerTextColor!,
                                                        ) ??
                                                        0xFFFFFFFF;
                                                    textColor = Color(val);
                                                  }
                                                  final isReview = currentPost
                                                      .moodEmoji
                                                      .startsWith('__review');
                                                  final isLoc =
                                                      currentPost.moodEmoji
                                                          .contains('📍') ||
                                                      currentPost.moodEmoji
                                                          .contains(
                                                            'Việt Nam',
                                                          ) ||
                                                      currentPost.moodEmoji
                                                          .contains('Hà Nội') ||
                                                      currentPost.moodEmoji
                                                          .contains(
                                                            'Hồ Chí Minh',
                                                          ) ||
                                                      currentPost.moodEmoji
                                                          .contains(
                                                            'Đà Nẵng',
                                                          ) ||
                                                      currentPost.moodEmoji
                                                          .contains('GPS') ||
                                                      currentPost.caption
                                                          .contains('GPS') ||
                                                      currentPost.caption
                                                          .contains('📍') ||
                                                      currentPost.caption
                                                          .contains(
                                                            'Việt Nam',
                                                          ) ||
                                                      currentPost.caption
                                                          .contains('Hà Nội') ||
                                                      currentPost.caption
                                                          .contains(
                                                            'Hồ Chí Minh',
                                                          );

                                                  final String locQuery =
                                                      currentPost.moodEmoji
                                                              .contains(
                                                                'Việt Nam',
                                                              ) ||
                                                          currentPost.moodEmoji
                                                              .contains(
                                                                'Hà Nội',
                                                              ) ||
                                                          currentPost.moodEmoji
                                                              .contains(
                                                                'Hồ Chí Minh',
                                                              )
                                                      ? currentPost.moodEmoji
                                                      : currentPost
                                                            .caption
                                                            .isNotEmpty
                                                      ? currentPost.caption
                                                      : currentPost.moodEmoji;

                                                  return GestureDetector(
                                                    onTap: isLoc
                                                        ? () => _openGoogleMaps(
                                                            locQuery,
                                                          )
                                                        : null,
                                                    child: Center(
                                                      child: Container(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 18,
                                                              vertical: isReview
                                                                  ? 13
                                                                  : 11,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              gradColors == null
                                                              ? bgColor
                                                              : null,
                                                          gradient:
                                                              gradColors != null
                                                              ? LinearGradient(
                                                                  colors:
                                                                      gradColors,
                                                                  begin: Alignment
                                                                      .topLeft,
                                                                  end: Alignment
                                                                      .bottomRight,
                                                                )
                                                              : null,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                24,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                Colors.white24,
                                                            width: isReview
                                                                ? 1.2
                                                                : 1.0,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withAlpha(
                                                                    90,
                                                                  ),
                                                              blurRadius: 10,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    3,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            if (isLoc) ...[
                                                              Icon(
                                                                Icons
                                                                    .map_rounded,
                                                                color: textColor
                                                                    .withAlpha(
                                                                      200,
                                                                    ),
                                                                size: 16,
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                            ],
                                                            Flexible(
                                                              child:
                                                                  (currentPost.moodEmoji ==
                                                                          '__tet_lunar_2027__' ||
                                                                      currentPost
                                                                          .moodEmoji
                                                                          .contains(
                                                                            'đến Tết',
                                                                          ) ||
                                                                      currentPost
                                                                          .moodEmoji
                                                                          .contains(
                                                                            'Còn 190',
                                                                          ) ||
                                                                      currentPost
                                                                          .moodEmoji
                                                                          .contains(
                                                                            'Còn 189',
                                                                          ) ||
                                                                      currentPost
                                                                          .moodEmoji
                                                                          .contains(
                                                                            'Còn 19',
                                                                          ))
                                                                  ? TXATetCountdownWidget(
                                                                      style: TextStyle(
                                                                        color:
                                                                            textColor,
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        letterSpacing:
                                                                            -0.3,
                                                                      ),
                                                                    )
                                                                  : currentPost
                                                                        .moodEmoji
                                                                        .startsWith(
                                                                          '__tet_wish_',
                                                                        )
                                                                  ? TXAMarquee(
                                                                      text: txaLang
                                                                          .getText(
                                                                            currentPost.moodEmoji.replaceAll(
                                                                              '__',
                                                                              '',
                                                                            ),
                                                                          )
                                                                          .replaceAll(
                                                                            '%user%',
                                                                            currentPost.senderUsername,
                                                                          )
                                                                          .replaceAll(
                                                                            '%name%',
                                                                            tetName,
                                                                          ),
                                                                      style: TextStyle(
                                                                        color:
                                                                            textColor,
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        letterSpacing:
                                                                            -0.3,
                                                                      ),
                                                                    )
                                                                  : currentPost
                                                                        .moodEmoji
                                                                        .startsWith(
                                                                          '__zodiac_',
                                                                        )
                                                                  ? TXAMarquee(
                                                                      text: txaLang
                                                                          .getText(
                                                                            currentPost.moodEmoji.replaceAll(
                                                                              '__',
                                                                              '',
                                                                            ),
                                                                          )
                                                                          .replaceAll(
                                                                            '%user%',
                                                                            currentPost.senderUsername,
                                                                          )
                                                                          .replaceAll(
                                                                            '%name%',
                                                                            tetName,
                                                                          ),
                                                                      style: TextStyle(
                                                                        color:
                                                                            textColor,
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        letterSpacing:
                                                                            -0.3,
                                                                      ),
                                                                    )
                                                                  : currentPost
                                                                        .moodEmoji
                                                                        .startsWith(
                                                                          '__holiday_',
                                                                        )
                                                                  ? TXAMarquee(
                                                                      text: TXAFestivalManager.getHolidayCaption(
                                                                        currentPost
                                                                            .moodEmoji,
                                                                        txaLang
                                                                            .currentLanguage,
                                                                      ),
                                                                      style: TextStyle(
                                                                        color:
                                                                            textColor,
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        letterSpacing:
                                                                            -0.3,
                                                                      ),
                                                                    )
                                                                  : currentPost
                                                                        .moodEmoji
                                                                        .startsWith(
                                                                          '__review',
                                                                        )
                                                                  ? Builder(
                                                                      builder: (_) {
                                                                        final starsStr = currentPost.moodEmoji.replaceAll(
                                                                          RegExp(
                                                                            r'[^0-9]',
                                                                          ),
                                                                          '',
                                                                        );
                                                                        final stars =
                                                                            int.tryParse(
                                                                              starsStr,
                                                                            ) ??
                                                                            5;
                                                                        return Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            FittedBox(
                                                                              fit: BoxFit.scaleDown,
                                                                              child: Row(
                                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: List.generate(
                                                                                  5,
                                                                                  (
                                                                                    starIdx,
                                                                                  ) {
                                                                                    final isFilled =
                                                                                        starIdx <
                                                                                        stars;
                                                                                    return Padding(
                                                                                      padding: const EdgeInsets.symmetric(
                                                                                        horizontal: 3,
                                                                                      ),
                                                                                      child: Icon(
                                                                                        isFilled
                                                                                            ? Icons.star_rounded
                                                                                            : Icons.star_border_rounded,
                                                                                        color: isFilled
                                                                                            ? const Color(
                                                                                                0xFFFFD700,
                                                                                              )
                                                                                            : Colors.white60,
                                                                                        size: 22,
                                                                                      ),
                                                                                    );
                                                                                  },
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            if (currentPost.caption.isNotEmpty) ...[
                                                                              const SizedBox(
                                                                                height: 6,
                                                                              ),
                                                                              Text(
                                                                                currentPost.caption,
                                                                                textAlign: TextAlign.center,
                                                                                style: TextStyle(
                                                                                  color: textColor,
                                                                                  fontSize: 14,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  letterSpacing: -0.3,
                                                                                ),
                                                                                maxLines: 3,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ],
                                                                          ],
                                                                        );
                                                                      },
                                                                    )
                                                                  : Text(
                                                                      currentPost
                                                                              .caption
                                                                              .isNotEmpty
                                                                          ? currentPost.caption
                                                                          : currentPost.moodEmoji,
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                        color:
                                                                            textColor,
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        letterSpacing:
                                                                            -0.3,
                                                                      ),
                                                                      maxLines:
                                                                          2,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
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
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),

                            // Dòng thông tin người gửi: Avatar, Tên, Thời gian
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TXAAvatarFrame(
                                    username: currentPost.senderUsername,
                                    radius: 14,
                                    tier: _getFriendTier(currentPost.senderUsername),
                                    showStreakBadge: true,
                                    child: Container(
                                      color: Color(avatarColorVal),
                                      child: currentPost.senderAvatar.startsWith('http')
                                          ? TXANetworkImage(url: currentPost.senderAvatar, fit: BoxFit.cover)
                                          : Center(
                                              child: Text(
                                                currentPost.senderAvatar,
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${currentPost.senderUsername} • ${TXAFormat.formatPostTime(currentPost.createdTime.isNotEmpty ? currentPost.createdTime : currentPost.timestampText)}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),

                            // Thanh tóm tắt cảm xúc (Chỉ hiển thị nếu LÀ bài viết của chính mình) - Giống TLocket
                            if (currentUser?.username == currentPost.senderUsername) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _showAuthorReactionsModal(context, currentPost),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(20),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.white.withAlpha(30)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentPost.reactions.isEmpty
                                            ? txaLang.getText('no_reactions_summary')
                                            : txaLang.getText('reactions_summary_count').replaceAll('%count%', currentPost.reactions.length.toString()),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (currentPost.reactions.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        // Hiển thị tối đa 3 emoji phản hồi nhanh
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: currentPost.reactions
                                              .map((r) => r['emoji'] ?? '❤️')
                                              .toSet()
                                              .take(3)
                                              .map((emoji) => Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 1),
                                                    child: Text(emoji, style: const TextStyle(fontSize: 14)),
                                                  ))
                                              .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const Spacer(flex: 1),

                            // Thanh Reaction Shortcut (Chỉ hiển thị nếu KHÔNG PHẢI bài đăng của chính họ)
                            if (currentUser?.username != currentPost.senderUsername)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Các phím tắt cảm xúc nhanh bên trái
                                    Row(
                                      children: [
                                        ...currentPost.quickEmojisOrder.take(4).map((emoji) {
                                          final count = currentPost.reactions.where((r) => r['emoji'] == emoji).length;
                                          return GestureDetector(
                                            onTap: () {
                                              _onAddReaction(currentPost, emoji);
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withAlpha(15),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: Colors.white.withAlpha(20)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Text(emoji, style: const TextStyle(fontSize: 16)),
                                                  if (count > 0) ...[
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$count',
                                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                        
                                        // Nút dấu cộng mở bảng chọn emoji hệ thống
                                        GestureDetector(
                                          onTap: () {
                                            _showSystemEmojiPickerBottomSheet(context, currentPost);
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 4),
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withAlpha(15),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white.withAlpha(20)),
                                            ),
                                            child: const Icon(
                                              Icons.add_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Phím "Trả lời" (Reply) bên phải
                                    GestureDetector(
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          backgroundColor: TXATheme.cardBg,
                                          isScrollControlled: true,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                          ),
                                          builder: (context) {
                                            return SafeArea(
                                              child: Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: MediaQuery.of(context).viewInsets.bottom,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // Hàng tiêu đề & ảnh preview của post được trả lời
                                                      Row(
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius: BorderRadius.circular(8),
                                                            child: SizedBox(
                                                              width: 40,
                                                              height: 40,
                                                              child: _buildPostImage(currentPost.photoPath),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 10),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  'Trả lời bài đăng của ${currentPost.senderUsername}',
                                                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                                                ),
                                                                if (currentPost.caption.isNotEmpty)
                                                                  Text(
                                                                    currentPost.caption,
                                                                    style: TextStyle(color: TXATheme.textMuted, fontSize: 11),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 12),
                                                      // Ô nhập tin nhắn
                                                      Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withAlpha(10),
                                                          borderRadius: BorderRadius.circular(24),
                                                          border: Border.all(color: Colors.white.withAlpha(15)),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: TextField(
                                                                controller: _commentController,
                                                                autofocus: true,
                                                                style: TextStyle(color: Colors.white, fontSize: 14),
                                                                decoration: InputDecoration(
                                                                  hintText: txaLang.getText('type_message_hint'),
                                                                  hintStyle: TextStyle(color: TXATheme.textMuted, fontSize: 14),
                                                                  border: InputBorder.none,
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.send_rounded, color: Color(0xFF42A5F5), size: 22),
                                                              onPressed: () {
                                                                _onSendComment(currentPost);
                                                                Navigator.pop(context);
                                                              },
                                                            ),
                                                          ],
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
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(20),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withAlpha(30)),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text('Trả lời', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                          ],
                        );

                        if (isSnow) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              postItem,
                              IgnorePointer(
                                child: TXASnowEffect(
                                  isPlaying: _currentIndex == index,
                                ),
                              ),
                            ],
                          );
                        }
                        return postItem;
                      },
                    ),
                  ),

                  // Bottom navigation bar chứa: Nút Lưới, Nút Thêm ảnh, Nút Option (...)
                  _buildBottomNavigationBar(context, visiblePosts, feedItems),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, List<LocketPostModel> visiblePosts, List<dynamic> feedItems) {
    final bool isAd = _currentIndex < feedItems.length && feedItems[_currentIndex] == 'ad_slot';

    final safeIndex = _currentIndex.clamp(0, feedItems.length - 1);
    final currentPost = (feedItems.isNotEmpty && feedItems[safeIndex] is LocketPostModel)
        ? feedItems[safeIndex] as LocketPostModel
        : (visiblePosts.isNotEmpty ? visiblePosts.first : null);

    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 12, left: 24, right: 24),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Nút chuyển chế độ Lưới / Cuộn
          GestureDetector(
            onTap: isAd
                ? null
                : () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
            child: Opacity(
              opacity: isAd ? 0.3 : 1.0,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                child: Icon(
                  _isGridView ? Icons.format_list_bulleted_rounded : Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // Center: Nút Thêm ảnh (+) quay về Camera chụp
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFF42A5F5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

          // Right: Nút tùy chọn 3 chấm (...) - ẩn đi trong chế độ lưới bong bóng
          TXAAuthService.instance.feedGridMode == 'thought_bubble' && _isGridView
              ? const SizedBox(width: 52)
              : GestureDetector(
                  onTap: (isAd || currentPost == null)
                      ? null
                      : () => _showFeedOptionsModal(context, currentPost),
                  child: Opacity(
                    opacity: (isAd || currentPost == null) ? 0.3 : 1.0,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  TXAFriendTier _getFriendTier(String username) {
    final txaAuth = TXAAuthService.instance;
    if (txaAuth.loversList.any((f) => f['username'] == username)) {
      return TXAFriendTier.lover;
    }
    if (txaAuth.bestFriendsList.any((f) => f['username'] == username)) {
      return TXAFriendTier.bestFriend;
    }
    return TXAFriendTier.normal;
  }
}

/// Đuôi nhỏ hình tam giác bên dưới bong bóng suy nghĩ
class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.7, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..close();

    // Fill sáng hơn nền để rõ nét
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3A3A3E)
        ..style = PaintingStyle.fill,
    );

    // Viền trắng mỏng để tạo độ tương phản
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) => false;
}

class TXASpinningIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;

  const TXASpinningIcon({
    super.key,
    required this.icon,
    this.size = 18,
    this.color = TXATheme.primaryYellow,
  });

  @override
  State<TXASpinningIcon> createState() => _TXASpinningIconState();
}

class _TXASpinningIconState extends State<TXASpinningIcon> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spinController,
      child: Icon(
        widget.icon,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}