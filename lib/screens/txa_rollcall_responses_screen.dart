import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_format.dart';
import '../services/txa_analytics.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_feed_service.dart';
import '../widgets/txa_network_image.dart';
import 'dart:io';

class TXARollcallResponsesScreen extends StatefulWidget {
  final VoidCallback onTriggerCapture; // Callback to enter Rollcall Mode on camera

  const TXARollcallResponsesScreen({super.key, required this.onTriggerCapture});

  @override
  State<TXARollcallResponsesScreen> createState() => _TXARollcallResponsesScreenState();
}

class _TXARollcallResponsesScreenState extends State<TXARollcallResponsesScreen> {
  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenRollcall);
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final txaFeed = TXAFeedService.instance;
    final currentUser = txaAuth.currentUser;
    final currentUsername = currentUser?.username ?? '@user';

    // Get all visible posts
    final allPosts = txaFeed.getVisiblePostsForUser(currentUsername).whereType<LocketPostModel>().toList();

    // Filter today's Rollcall posts
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayRollcalls = allPosts.where((post) {
      if (!post.isRollcall) return false;
      try {
        final postDate = DateTime.parse(post.createdTime);
        final postDay = DateTime(postDate.year, postDate.month, postDate.day);
        return postDay.isAtSameMomentAs(today);
      } catch (_) {
        return false;
      }
    }).toList();

    // Check if current user has answered today's Rollcall
    final hasUserResponded = todayRollcalls.any((post) => post.senderUsername == currentUsername);

    return Scaffold(
      backgroundColor: TXATheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          txaLang.getText('rollcall_responses_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Daily Challenge Header Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withAlpha(80),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('📣', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          txaLang.getText('rollcall_prompt_label').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Show me what you are eating today! 🍲',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Responses Grid/List
            Expanded(
              child: todayRollcalls.isEmpty
                  ? Center(
                      child: Text(
                        txaLang.getText('rollcall_no_responses'),
                        style: TextStyle(color: TXATheme.textMuted, fontSize: 14),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        // Scrollable responses
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: todayRollcalls.length,
                          itemBuilder: (context, index) {
                            final post = todayRollcalls[index];
                            final isFriendPost = post.senderUsername != currentUsername;
                            final shouldBlur = isFriendPost && !hasUserResponded;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: TXATheme.cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: TXATheme.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Image with optional blur
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _buildPostImage(post.photoPath),
                                          if (shouldBlur)
                                            Positioned.fill(
                                              child: ClipRect(
                                                child: ImageFiltered(
                                                  imageFilter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                                                  child: _buildPostImage(post.photoPath),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Sender Header
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Color(int.tryParse(post.senderAvatarColor) ?? 0xFF42A5F5),
                                          radius: 14,
                                          child: ClipOval(
                                            child: post.senderAvatar.startsWith('http')
                                                ? TXANetworkImage(url: post.senderAvatar, fit: BoxFit.cover)
                                                : Center(
                                                    child: Text(
                                                      post.senderAvatar,
                                                      style: TextStyle(fontSize: 14),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          post.senderUsername,
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.access_time_rounded, color: TXATheme.textMuted, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          TXAFormat.formatPostTime(post.createdTime.isNotEmpty ? post.createdTime : post.timestampText),
                                          style: TextStyle(color: TXATheme.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Blur Overlay Lock Screen if user hasn't posted
                        if (!hasUserResponded)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withAlpha(80),
                              child: Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 32),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E24).withAlpha(240),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: Colors.white10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(128),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_rounded, color: Color(0xFFFFB300), size: 48),
                                      const SizedBox(height: 16),
                                      Text(
                                        txaLang.getText('rollcall_join'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          widget.onTriggerCapture();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFFB300),
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                        child: Text(
                                          txaLang.getText('rollcall_btn_join'),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostImage(String photoPath) {
    if (photoPath.startsWith('assets/')) {
      return Image.asset(photoPath, fit: BoxFit.cover);
    }
    if (photoPath.startsWith('http')) {
      return TXANetworkImage(url: photoPath, fit: BoxFit.cover);
    }
    return Image.file(File(photoPath), fit: BoxFit.cover);
  }
}