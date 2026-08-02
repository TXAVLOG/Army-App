import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_format.dart';
import '../services/txa_analytics.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_chat_service.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_network_image.dart';
import '../services/txa_badword.dart';
import '../services/txa_notification_service.dart';

class TXAChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> friend;

  const TXAChatDetailScreen({super.key, required this.friend});

  @override
  State<TXAChatDetailScreen> createState() => _TXAChatDetailScreenState();
}

class _TXAChatDetailScreenState extends State<TXAChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Tin nhắn đang được trả lời (quote)
  TXAChatMessageModel? _replyingMessage;

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenChatDetail);
    final currentUser = TXAAuthService.instance.currentUser;
    final fUser = widget.friend['username'] as String;
    if (currentUser != null) {
      TXAChatService.activeChatFriendUsername = fUser;
      TXAChatService.instance.markMessagesAsRead(currentUser.username, fUser);
    }
  }

  @override
  void dispose() {
    TXAChatService.activeChatFriendUsername = null;
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final currentUser = TXAAuthService.instance.currentUser;
    final fUser = widget.friend['username'] as String;

    if (currentUser == null) return;

    // Kiểm tra từ cấm Bad Word
    final detectedBadWord = TXABadWord.findFirstBadWord(text);
    if (detectedBadWord != null) {
      TXAToast.show(
        context,
        TXALanguage.instance.getText('bad_word_error').replaceAll('%word%', detectedBadWord),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final replyMessageToSubmit = _replyingMessage;
    
    // Clear input và state trả lời trước khi submit async
    _textController.clear();
    setState(() {
      _replyingMessage = null;
    });

    try {
      await TXAChatService.instance.sendMessage(
        senderUsername: currentUser.username,
        receiverUsername: fUser,
        text: text,
        replyToId: replyMessageToSubmit?.id,
        replyToSender: replyMessageToSubmit?.senderUsername,
        replyToText: replyMessageToSubmit?.text,
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending chat message: $e');
    }
  }

  void _showChatOptions(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final fName = widget.friend['name'] as String? ?? widget.friend['username'];

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
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TXATheme.cardBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.outlined_flag_rounded, color: Colors.white70),
                  ),
                  title: Text(
                    txaLang.getText('report_title'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    TXAToast.show(
                      context,
                      txaLang.getText('report_sent_success'),
                      icon: Icons.flag_rounded,
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TXATheme.statusRed.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block_rounded, color: TXATheme.statusRed),
                  ),
                  title: Text(
                    txaLang.getText('block_title'),
                    style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    TXAToast.show(
                      context,
                      txaLang.getText('blocked_user_success').replaceAll('%user%', fName),
                      icon: Icons.block_rounded,
                      backgroundColor: TXATheme.statusRed,
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostImage(String photoPath, {BoxFit fit = BoxFit.cover}) {
    if (photoPath.startsWith('assets/')) {
      return Image.asset(photoPath, fit: fit);
    }
    if (photoPath.startsWith('http')) {
      return TXANetworkImage(
        url: photoPath,
        fit: fit,
        loadingBuilder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF42A5F5), strokeWidth: 2),
        ),
        errorBuilder: (ctx, err, st) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white30, size: 24),
        ),
      );
    }
    return Image.file(
      File(photoPath),
      fit: fit,
      errorBuilder: (ctx, err, st) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white30, size: 24),
      ),
    );
  }

  /// Card hiển thị Bài Đăng được trả lời CĂN GIỮA DÒNG CHAT
  Widget _buildPostCentralCard(TXAChatMessageModel msg) {
    if (msg.postPhotoPath == null || msg.postPhotoPath!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        constraints: const BoxConstraints(maxWidth: 190),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(100),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(19),
                bottom: (msg.postCaption != null && msg.postCaption!.isNotEmpty)
                    ? Radius.zero
                    : const Radius.circular(19),
              ),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _buildPostImage(msg.postPhotoPath!),
              ),
            ),
            if (msg.postCaption != null && msg.postCaption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  msg.postCaption!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Trả về DateTime.toLocal() từ ISO string, null nếu lỗi
  DateTime? _parseTs(String ts) {
    try { return DateTime.parse(ts).toLocal(); } catch (_) { return null; }
  }

  /// Format giờ: HH:mm
  String _fmtTime(DateTime dt) =>
      '${TXAFormat.formatNumber(dt.hour)}:${TXAFormat.formatNumber(dt.minute)}';

  /// Format nhãn ngày giữa các nhóm tin nhắn
  String _fmtDayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return 'Hôm nay';
    if (msgDay == yesterday) return 'Hôm qua';
    return '${TXAFormat.formatNumber(dt.day)}/${TXAFormat.formatNumber(dt.month)}/${dt.year}';
  }

  /// Kiểm tra xem 2 tin nhắn có khác ngày không
  bool _isDifferentDay(TXAChatMessageModel a, TXAChatMessageModel b) {
    final dtA = _parseTs(a.timestamp);
    final dtB = _parseTs(b.timestamp);
    if (dtA == null || dtB == null) return false;
    return dtA.year != dtB.year || dtA.month != dtB.month || dtA.day != dtB.day;
  }

  // ─── Date separator ───────────────────────────────────────────────────────
  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withAlpha(18), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7A99),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withAlpha(18), thickness: 1)),
        ],
      ),
    );
  }

  // ─── Timestamp nhỏ bên dưới bubble ────────────────────────────────────────
  Widget _buildBubbleTimestamp(DateTime dt, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMe ? 0 : 12,
          right: isMe ? 12 : 0,
          bottom: 4,
          top: 2,
        ),
        child: Text(
          _fmtTime(dt),
          style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 10.5),
        ),
      ),
    );
  }

  // ─── Sent / Seen status ────────────────────────────────────────────────────
  Widget _buildMessageStatus(bool isRead, bool isDelivered) {
    IconData icon;
    Color color;
    String label;

    if (isRead) {
      icon = Icons.done_all_rounded;
      color = const Color(0xFF42A5F5); // Xanh dương
      label = 'Đã xem';
    } else if (isDelivered) {
      icon = Icons.done_all_rounded;
      color = const Color(0xFF6B7A99); // Xám
      label = 'Đã nhận';
    } else {
      icon = Icons.done_rounded;
      color = const Color(0xFF6B7A99); // Xám
      label = 'Đã gửi';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreviewBanner() {
    if (_replyingMessage == null) return const SizedBox.shrink();
    
    final txaLang = TXALanguage.instance;
    final isSelf = _replyingMessage!.senderUsername == TXAAuthService.instance.currentUser?.username;
    
    final title = isSelf 
        ? txaLang.getText('replying_to_self')
        : txaLang.getText('replying_to').replaceAll('%user%', '@${_replyingMessage!.senderUsername}');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: Color(0xFF42A5F5), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF42A5F5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingMessage!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withAlpha(160),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
            onPressed: () {
              setState(() {
                _replyingMessage = null;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // Tọa độ click/chạm hiện tại
  Offset? _tapPosition;
  // ID của tin nhắn đang mở menu để kích hoạt viền sáng
  String? _activeMenuMessageId;

  void _showContextMenu(BuildContext context, TXAChatMessageModel msg, Offset? position) async {
    final txaLang = TXALanguage.instance;
    final RenderBox? overlay = Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    
    final isMe = msg.senderUsername == TXAAuthService.instance.currentUser?.username;
    final Offset targetOffset = position ?? const Offset(200, 200);
    
    // Lệch menu xuống dưới bóng tin nhắn và lệch nhẹ ngang để menu trỏ đúng vị trí thoáng
    final double adjustedX = isMe ? (targetOffset.dx - 140.0).clamp(16.0, overlay.size.width) : targetOffset.dx;
    final double adjustedY = targetOffset.dy + 25.0; // Dịch chuyển xuống phía dưới tin nhắn

    final RelativeRect positionRect = RelativeRect.fromRect(
      Rect.fromLTWH(adjustedX, adjustedY, 40, 40),
      Offset.zero & overlay.size,
    );

    setState(() {
      _activeMenuMessageId = msg.id;
    });

    final navigator = Navigator.of(context);
    final result = await showMenu<String>(
      context: context,
      position: positionRect,
      elevation: 8,
      color: const Color(0xFF1A1A24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      items: [
        PopupMenuItem<String>(
          enabled: true,
          onTap: null, // Bỏ qua sự kiện tap của cả row
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['❤️', '😆', '😮', '😢', '👍'].map((emoji) {
              return GestureDetector(
                onTap: () {
                  navigator.pop('react_$emoji');
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              const Icon(Icons.reply_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Text(txaLang.getText('reply_label'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.content_copy_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 12),
              Text(txaLang.getText('copy_label'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ],
    );

    setState(() {
      _activeMenuMessageId = null;
    });

    if (result == null) return;

    if (result.startsWith('react_')) {
      final emoji = result.substring(6);
      final currentUser = TXAAuthService.instance.currentUser;
      if (currentUser != null) {
        await TXAChatService.instance.updateMessageReaction(
          messageId: msg.id,
          username: currentUser.username,
          emoji: emoji,
          receiverUsername: widget.friend['username'] as String,
        );
      }
    } else if (result == 'reply') {
      setState(() {
        _replyingMessage = msg;
      });
    } else if (result == 'copy') {
      Clipboard.setData(ClipboardData(text: msg.text));
      if (context.mounted) {
        TXAToast.show(context, txaLang.getText('message_copied_toast'), icon: Icons.copy);
      }
    }
  }

  void _scrollToMessage(String msgId, List<TXAChatMessageModel> msgs) {
    final index = msgs.indexWhere((m) => m.id == msgId);
    if (index != -1 && _scrollController.hasClients) {
      final double targetOffset = index * 75.0;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final safeOffset = targetOffset.clamp(0.0, maxScroll);
      
      _scrollController.animateTo(
        safeOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

      TXANotificationService.instance.setHighlightMessageId(msgId);
    }
  }

  // ─── Message bubble ────────────────────────────────────────────────────────
  Widget _buildMessageBubble(
    TXAChatMessageModel msg,
    bool isMe, {
    bool isFirst = true,   // đầu group (bo góc trên đầy)
    bool isLast = true,    // cuối group (bo góc dưới nhỏ hơn)
    bool showAvatar = false,
    String fAvatar = '👤',
    int fColor = 0xFF607D8B,
    required List<TXAChatMessageModel> allMsgs,
    bool isHighlighted = false,
  }) {
    final txaLang = TXALanguage.instance;
    final hasPost = msg.postPhotoPath != null && msg.postPhotoPath!.isNotEmpty;
    final hasQuote = msg.replyToId != null && msg.replyToId!.isNotEmpty;

    // Border radius kiểu Messenger
    final double topLeft  = isMe ? 20 : (isFirst ? 20 : 6);
    final double topRight = isMe ? (isFirst ? 20 : 6) : 20;
    final double botLeft  = isMe ? 20 : (isLast ? 4 : 6);
    final double botRight = isMe ? (isLast ? 4 : 6) : 20;

    final bubble = _HighlightMessageWrapper(
      isHighlighted: isHighlighted,
      onHighlightComplete: TXANotificationService.instance.clearHighlightMessageId,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(
          top: isFirst ? 2 : 1,
          bottom: isLast ? 2 : 1,
          left: isMe ? 0 : (showAvatar ? 0 : 32),
          right: 0,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
      transform: isHighlighted 
          ? (Matrix4.translationValues(0.0, -3.0, 0.0)..multiply(Matrix4.diagonal3Values(1.03, 1.03, 1.0))) 
          : Matrix4.identity(),
      transformAlignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF42A5F5) : const Color(0xFF1E1E24),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topLeft),
          topRight: Radius.circular(topRight),
          bottomLeft: Radius.circular(botLeft),
          bottomRight: Radius.circular(botRight),
        ),
        border: Border.all(
          color: isHighlighted 
              ? TXATheme.primaryYellow.withAlpha(220) 
              : (isMe ? Colors.transparent : Colors.white10),
          width: isHighlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted 
                ? TXATheme.primaryYellow.withAlpha(140) 
                : Colors.black.withAlpha(isMe ? 50 : 30),
            blurRadius: isHighlighted ? 12 : 6,
            spreadRadius: isHighlighted ? 1.5 : 0,
            offset: isHighlighted ? const Offset(0, 4) : const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Phản hồi Locket Post
          if (hasPost) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply_rounded, size: 13,
                    color: isMe ? Colors.white70 : TXATheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  txaLang.getText('replied_to_post'),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : TXATheme.textMuted,
                    fontSize: 11, fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // 2. Khung quote phản hồi tin nhắn khác (Quote Box click để cuộn)
          if (hasQuote) ...[
            GestureDetector(
              onTap: () => _scrollToMessage(msg.replyToId!, allMsgs),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(isMe ? 25 : 12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: isMe ? Colors.white70 : const Color(0xFF42A5F5),
                      width: 3.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg.replyToSender == TXAAuthService.instance.currentUser?.username
                          ? txaLang.getText('friendship_me')
                          : msg.replyToSender ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : const Color(0xFF42A5F5),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      msg.replyToText ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(190),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Văn bản tin nhắn chính
          Text(
            msg.text,
            style: const TextStyle(
              color: Colors.white, fontSize: 14.5,
              fontWeight: FontWeight.w500, height: 1.25,
            ),
          ),
        ],
      ),
    ));

    final hasReactions = msg.reactions.isNotEmpty;
    final bubbleWithReactions = Stack(
      clipBehavior: Clip.none,
      children: [
        bubble,
        if (hasReactions)
          Positioned(
            bottom: -6,
            right: isMe ? 10 : null,
            left: isMe ? null : 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(20), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: msg.reactions.values.toSet().map((emoji) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.0),
                    child: Text(emoji, style: const TextStyle(fontSize: 11)),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );

    if (isMe) {
      return Align(alignment: Alignment.centerRight, child: bubbleWithReactions);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Color(fColor).withAlpha(180),
              child: ClipOval(
                child: fAvatar.startsWith('http')
                    ? SizedBox(width: 26, height: 26, child: TXANetworkImage(url: fAvatar, fit: BoxFit.cover))
                    : Center(child: Text(fAvatar, style: const TextStyle(fontSize: 12))),
              ),
            ),
          )
        else
          const SizedBox(width: 32),
        Flexible(child: bubbleWithReactions),
      ],
    );
  }

  Widget _buildChatSkeletonLoading() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.3, end: 0.85),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Date Pill Skeleton
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 90,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Bubble 1 (Left - Friend)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 220,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                ),
              ),
              // Bubble 2 (Right - Me)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 160,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withAlpha(100),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              // Bubble 3 (Left - Friend Post Reply Card Skeleton)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                ),
              ),
              // Bubble 4 (Right - Me)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 240,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withAlpha(100),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              // Bubble 5 (Left - Friend)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 140,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final fUser = widget.friend['username'] as String;
    final fName = widget.friend['name'] as String? ?? fUser;
    final fAvatar = widget.friend['avatar'] as String? ?? '👤';
    final fColor = widget.friend['bgColor'] as int? ?? 0xFF607D8B;

    final currentUser = txaAuth.currentUser;
    final currentUsername = currentUser?.username ?? '';

    return Scaffold(
      backgroundColor: TXATheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(fColor).withAlpha(180),
              child: ClipOval(
                child: fAvatar.startsWith('http')
                    ? SizedBox(width: 36, height: 36, child: TXANetworkImage(url: fAvatar, fit: BoxFit.cover))
                    : Center(child: Text(fAvatar, style: const TextStyle(fontSize: 16))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fName,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  // Firebase Query để fetch online status dùng TXAFormat
                  StreamBuilder<UserModel?>(
                    stream: txaAuth.listenToUser(fUser),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data == null) {
                        return Text(
                          txaLang.getText('offline'),
                          style: const TextStyle(color: TXATheme.textMuted, fontSize: 11),
                        );
                      }
                      final userModel = snapshot.data!;
                      if (userModel.lastActive == null) {
                        return Text(
                          txaLang.getText('offline'),
                          style: const TextStyle(color: TXATheme.textMuted, fontSize: 11),
                        );
                      }
                      final lastActiveTime = DateTime.parse(userModel.lastActive!).toLocal();
                      final isOnline = userModel.isOnline;
                      final activityText = TXAFormat.formatActivity(lastActiveTime, isOnline: isOnline);

                      return Text(
                        activityText,
                        style: TextStyle(
                          color: isOnline ? Colors.greenAccent : TXATheme.textMuted,
                          fontSize: 11,
                          fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => _showChatOptions(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SafeArea(
            child: Column(
              children: [
            Expanded(
              child: StreamBuilder<List<TXAChatMessageModel>>(
                stream: TXAChatService.instance.listenMessages(currentUsername, fUser),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildChatSkeletonLoading();
                  }

                  final msgs = snapshot.data ?? [];

                  if (msgs.isNotEmpty) {
                    final hasUnread = msgs.any((m) => m.receiverUsername == currentUsername && !m.isRead);
                    if (hasUnread) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        TXAChatService.instance.markMessagesAsRead(currentUsername, fUser);
                      });
                    }
                  }

                  if (msgs.isEmpty) {
                    // Giao diện trống (Placeholder) theo chat details.png
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFF18181C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: Color(0xFF42A5F5),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              txaLang.getText('start_conversation_title'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              txaLang.getText('start_conversation_desc'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: TXATheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Tự động cuộn xuống khi có tin nhắn mới
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  final notiService = TXANotificationService.instance;
                  final targetHighlightId = notiService.highlightMessageId;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: msgs.length,
                    itemBuilder: (context, idx) {
                      final msg = msgs[idx];
                      final isMe = msg.senderUsername == currentUsername;
                      final hasPost = msg.postPhotoPath != null && msg.postPhotoPath!.isNotEmpty;
                      final isHighlighted = msg.id.isNotEmpty && msg.id == targetHighlightId;

                      // ─── Grouping logic ───────────────────────────────────
                      final prevMsg = idx > 0 ? msgs[idx - 1] : null;
                      final nextMsg = idx < msgs.length - 1 ? msgs[idx + 1] : null;

                      final sameSenderAsPrev = prevMsg != null && prevMsg.senderUsername == msg.senderUsername;
                      final sameSenderAsNext = nextMsg != null && nextMsg.senderUsername == msg.senderUsername;

                      // Tin đầu group nếu người gửi trước khác hoặc khác ngày
                      final isFirst = prevMsg == null || !sameSenderAsPrev || _isDifferentDay(prevMsg, msg);
                      // Tin cuối group nếu người gửi sau khác hoặc khác ngày
                      final isLast = nextMsg == null || !sameSenderAsNext || _isDifferentDay(msg, nextMsg);

                      // Chỉ hiện timestamp bên dưới nếu là tin CUỐI của group
                      final msgDt = _parseTs(msg.timestamp);
                      final showTimestamp = isLast && msgDt != null;

                      // Avatar friend chỉ hiện ở tin cuối của group bên trái
                      final showFriendAvatar = !isMe && isLast;

                      // Tin nhắn cuối cùng của mình → hiện status Đã gửi/Đã xem
                      final isLastOfAll = idx == msgs.length - 1;
                      final showStatus = isMe && isLastOfAll;

                      // Date separator: hiện nếu tin đầu tiên hoặc khác ngày với tin trước
                      final showDateSep = idx == 0 ||
                          (prevMsg != null && _isDifferentDay(prevMsg, msg));

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Date separator ─────────────────────────────────
                          if (showDateSep && msgDt != null)
                            _buildDateSeparator(_fmtDayLabel(msgDt)),

                          // ── Post card (centered) ───────────────────────────
                          if (hasPost) _buildPostCentralCard(msg),

                          // ── Message bubble ─────────────────────────────────
                          GestureDetector(
                            onTapDown: (details) {
                              _tapPosition = details.globalPosition;
                            },
                            onLongPress: () => _showContextMenu(context, msg, _tapPosition),
                            onSecondaryTapDown: (details) {
                              _tapPosition = details.globalPosition;
                              _showContextMenu(context, msg, _tapPosition);
                            },
                            child: Dismissible(
                              key: Key('msg_${msg.id}_$idx'),
                              direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
                              confirmDismiss: (dir) async {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _replyingMessage = msg;
                                });
                                return false;
                              },
                              background: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Icon(Icons.reply_rounded, color: Colors.white.withAlpha(120), size: 18),
                                ),
                              ),
                              secondaryBackground: Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Icon(Icons.reply_rounded, color: Colors.white.withAlpha(120), size: 18),
                                ),
                              ),
                              child: _buildMessageBubble(
                                msg, isMe,
                                isFirst: isFirst,
                                isLast: isLast,
                                showAvatar: showFriendAvatar,
                                fAvatar: fAvatar,
                                fColor: fColor,
                                allMsgs: msgs,
                                isHighlighted: isHighlighted || (_activeMenuMessageId == msg.id),
                              ),
                            ),
                          ),

                          // ── Timestamp dưới bubble ──────────────────────────
                          if (showTimestamp)
                            _buildBubbleTimestamp(msgDt, isMe),

                          // ── Sent / Seen status ─────────────────────────────
                          if (showStatus)
                            _buildMessageStatus(msg.isRead, msg.isDelivered),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            
            // Hộp nhập tin nhắn & Nút chụp nhanh Locket ("Double Tap")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thanh hiển thị quote đang trả lời tin nhắn
                  _buildReplyPreviewBanner(),
                  
                  // Ô nhập văn bản
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withAlpha(10)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: Colors.white, fontSize: 14.5),
                            decoration: InputDecoration(
                              hintText: txaLang.getText('type_message_hint'),
                              hintStyle: const TextStyle(color: TXATheme.textMuted, fontSize: 14.5),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFF42A5F5), size: 22),
                          onPressed: _sendMessage,
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
    );
  }
}

/// Animated wrapper làm sáng nổi bật tin nhắn vừa nhận từ thông báo trong vài giây rồi mờ dần
class _HighlightMessageWrapper extends StatefulWidget {
  final Widget child;
  final bool isHighlighted;
  final VoidCallback? onHighlightComplete;

  const _HighlightMessageWrapper({
    required this.child,
    required this.isHighlighted,
    this.onHighlightComplete,
  });

  @override
  State<_HighlightMessageWrapper> createState() => _HighlightMessageWrapperState();
}

class _HighlightMessageWrapperState extends State<_HighlightMessageWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isHighlighted) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant _HighlightMessageWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _controller.forward(from: 0.0).then((_) {
      if (mounted) {
        widget.onHighlightComplete?.call();
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
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowVal = _glowAnimation.value;
        if (glowVal <= 0.001) return widget.child;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: TXATheme.primaryYellow.withAlpha((glowVal * 200).round()),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: TXATheme.primaryYellow.withAlpha((glowVal * 120).round()),
                blurRadius: 10 * glowVal,
                spreadRadius: 1 * glowVal,
              ),
            ],
          ),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}
