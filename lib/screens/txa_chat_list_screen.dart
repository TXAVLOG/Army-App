import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_analytics.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_chat_service.dart';
import 'txa_chat_detail_screen.dart';
import '../widgets/txa_network_image.dart';

class TXAChatListScreen extends StatefulWidget {
  const TXAChatListScreen({super.key});

  @override
  State<TXAChatListScreen> createState() => _TXAChatListScreenState();
}

class _TXAChatListScreenState extends State<TXAChatListScreen> {
  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenChatList);
    final currentUser = TXAAuthService.instance.currentUser;
    if (currentUser != null) {
      TXAChatService.instance.init(currentUser.username);
    }
  }

  String _formatMsgTime(String timestampStr) {
    if (timestampStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestampStr).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final hr = dt.hour.toString().padLeft(2, '0');
        final mn = dt.minute.toString().padLeft(2, '0');
        return '$hr:$mn';
      }
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d/$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final txaChat = TXAChatService.instance;

    final currentUser = txaAuth.currentUser;
    final currentUsername = currentUser?.username ?? '';

    return AnimatedBuilder(
      animation: Listenable.merge([txaLang, txaAuth, txaChat]),
      builder: (context, _) {
        final friends = txaAuth.friendsList;

        return Scaffold(
          backgroundColor: TXATheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: const Text(
              'Tin nhắn',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: friends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 54, color: TXATheme.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        txaLang.getText('add_friend_to_chat_hint'),
                        style: const TextStyle(color: TXATheme.textMuted, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hãy kết bạn để bắt đầu trò chuyện nhé.',
                        style: TextStyle(color: Colors.white30, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: friends.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, idx) {
                    final friend = friends[idx];
                    final fUser = friend['username'] as String;
                    final fName = friend['name'] as String? ?? fUser;
                    final fAvatar = friend['avatar'] as String? ?? '👤';
                    final fColor = friend['bgColor'] as int? ?? 0xFF607D8B;

                    // Lấy tin nhắn cuối cùng với bạn này
                    final lastMsg = txaChat.getLastMessageForFriend(fUser, currentUsername);
                    final hasMsg = lastMsg != null;
                    
                    String lastMsgText = 'Chưa có tin nhắn nào';
                    if (hasMsg) {
                      final friendReaction = lastMsg.reactions.containsKey(fUser) ? lastMsg.reactions[fUser] : null;
                      if (friendReaction != null) {
                        // Hiển thị: ❤️ abc đã thả cảm xúc vào tin nhắn
                        final reactedLabel = txaLang.getText('friend_reacted_message').replaceAll('%sender%', fName);
                        lastMsgText = '$friendReaction $reactedLabel';
                      } else if (lastMsg.text.isNotEmpty) {
                        lastMsgText = lastMsg.text;
                      } else if (lastMsg.postId != null) {
                        lastMsgText = '📷 ${txaLang.getText('replied_to_post')}';
                      } else {
                        lastMsgText = '';
                      }
                    }

                    final timeStr = hasMsg ? _formatMsgTime(lastMsg.timestamp) : '';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TXAChatDetailScreen(friend: friend),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            // Avatar tròn
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(fColor).withAlpha(180),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: ClipOval(
                                child: fAvatar.startsWith('http')
                                    ? SizedBox(width: 52, height: 52, child: TXANetworkImage(url: fAvatar, fit: BoxFit.cover))
                                    : Center(
                                        child: Text(
                                          fAvatar,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Thông tin tên và tin nhắn cuối
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    lastMsgText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: hasMsg ? Colors.white70 : TXATheme.textMuted,
                                      fontSize: 13,
                                      fontWeight: hasMsg ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Thời gian tin nhắn cuối
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
