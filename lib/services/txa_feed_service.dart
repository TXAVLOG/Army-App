import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'txa_cloudinary_service.dart';
import 'txa_auth_service.dart';
import 'txa_language.dart';
import 'txa_streak_service.dart';
import 'txa_notification_service.dart';
import 'txa_analytics.dart';

class LocketPostModel {
  final String id;
  final String senderUsername;
  final String senderAvatar;
  final String senderAvatarColor;
  final String photoPath; // Local path or Firebase Storage URL
  final String? voicePath; // Audio recording M4A path/URL if present
  final int? voiceDuration; // Audio duration in seconds
  final String caption;
  final String moodEmoji;
  final String? stickerBgColor;   // hex '0xFFD61CFF' hoặc null
  final String? stickerGradient;  // 'hex1,hex2' hoặc null
  final String? stickerTextColor; // hex hoặc null
  final String aspectRatio;
  final String timestampText;
  final List<String> recipients; // ['all'], ['best_friends'], ['lover'], ['private'], or friend IDs
  final List<String> readBy; // List of usernames who read this post
  final List<Map<String, String>> reactions; // [{'sender': '@hoa', 'emoji': '❤️'}]
  final List<String> quickEmojisOrder; // ['❤️', '🔥', '😮', '😂']
  final String createdTime;
  final bool isBlurOverlay;
  final bool isRollcall;

  LocketPostModel({
    required this.id,
    required this.senderUsername,
    required this.senderAvatar,
    required this.senderAvatarColor,
    required this.photoPath,
    this.voicePath,
    this.voiceDuration,
    required this.caption,
    required this.moodEmoji,
    this.stickerBgColor,
    this.stickerGradient,
    this.stickerTextColor,
    required this.aspectRatio,
    required this.timestampText,
    required this.recipients,
    required this.readBy,
    required this.reactions,
    required this.quickEmojisOrder,
    required this.createdTime,
    this.isBlurOverlay = false,
    this.isRollcall = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderUsername': senderUsername,
        'senderAvatar': senderAvatar,
        'senderAvatarColor': senderAvatarColor,
        'photoPath': photoPath,
        'voicePath': voicePath,
        'voiceDuration': voiceDuration,
        'caption': caption,
        'moodEmoji': moodEmoji,
        'stickerBgColor': stickerBgColor,
        'stickerGradient': stickerGradient,
        'stickerTextColor': stickerTextColor,
        'aspectRatio': aspectRatio,
        'timestampText': timestampText,
        'recipients': recipients,
        'readBy': readBy,
        'reactions': reactions,
        'quickEmojisOrder': quickEmojisOrder,
        'createdTime': createdTime,
        'isBlurOverlay': isBlurOverlay,
        'isRollcall': isRollcall,
      };

  factory LocketPostModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedRecipients = ['all'];
    try {
      final rawRec = json['recipients'];
      if (rawRec is List) {
        parsedRecipients = rawRec.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    List<String> parsedReadBy = [];
    try {
      final rawRead = json['readBy'];
      if (rawRead is List) {
        parsedReadBy = rawRead.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    List<Map<String, String>> parsedReactions = [];
    try {
      final rawReacts = json['reactions'];
      if (rawReacts is List) {
        for (var item in rawReacts) {
          if (item is Map) {
            final Map<String, String> m = {};
            item.forEach((k, v) {
              m[k.toString()] = v.toString();
            });
            parsedReactions.add(m);
          }
        }
      }
    } catch (_) {}

    List<String> parsedQuickEmojis = ['❤️', '🔥', '😮', '😂', '😢', '👍'];
    try {
      final rawEmojis = json['quickEmojisOrder'];
      if (rawEmojis is List && rawEmojis.isNotEmpty) {
        parsedQuickEmojis = rawEmojis.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return LocketPostModel(
      id: json['id'] ?? '',
      senderUsername: json['senderUsername'] ?? '@user',
      senderAvatar: json['senderAvatar'] ?? '🦊',
      senderAvatarColor: json['senderAvatarColor'] ?? '0xFFF57C00',
      photoPath: json['photoPath'] ?? '',
      voicePath: json['voicePath'],
      voiceDuration: json['voiceDuration'] as int?,
      caption: json['caption'] ?? '',
      moodEmoji: json['moodEmoji'] ?? '😊',
      stickerBgColor: json['stickerBgColor'] as String?,
      stickerGradient: json['stickerGradient'] as String?,
      stickerTextColor: json['stickerTextColor'] as String?,
      aspectRatio: json['aspectRatio'] ?? '1:1',
      timestampText: json['timestampText'] ?? 'Vừa xong',
      recipients: parsedRecipients,
      readBy: parsedReadBy,
      reactions: parsedReactions,
      quickEmojisOrder: parsedQuickEmojis,
      createdTime: json['createdTime'] ?? '',
      isBlurOverlay: json['isBlurOverlay'] == true,
      isRollcall: json['isRollcall'] == true,
    );
  }
}

class TXAFeedService extends ChangeNotifier {
  static final TXAFeedService instance = TXAFeedService._internal();
  TXAFeedService._internal();

  final List<LocketPostModel> _posts = [];
  List<LocketPostModel> get posts => List.unmodifiable(_posts);

  Future<void> init() async {
    FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdTime', descending: true)
        .snapshots()
        .listen((snapshot) async {
      _posts.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final photoPath = data['photoPath'] as String? ?? '';
        if (photoPath.startsWith('assets/')) {
          FirebaseFirestore.instance.collection('posts').doc(doc.id).delete();
          continue;
        }
        data['id'] = doc.id;
        _posts.add(LocketPostModel.fromJson(data));
      }

      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore listen error: $e');
    });
  }

  // Get posts visible to current user based on recipient permissions
  List<LocketPostModel> getVisiblePostsForUser(String currentUsername) {
    final txaAuth = TXAAuthService.instance;
    final friendsList = txaAuth.friendsList;
    final bestFriendsList = txaAuth.bestFriendsList;
    final loversList = txaAuth.loversList;

    final friendUsernames = friendsList.map((f) => f['username'] as String).toSet();
    final bestFriendUsernames = bestFriendsList.map((f) => f['username'] as String).toSet();
    final loverUsernames = loversList.map((f) => f['username'] as String).toSet();

    final filtered = _posts.where((post) {
      // Luôn thấy bài của chính mình
      if (post.senderUsername == currentUsername) return true;

      // Bài riêng tư → chỉ người đăng thấy, trừ trường hợp gửi cho người yêu (lover) và người đọc chính là người yêu đó
      if (post.recipients.contains('private')) {
        final isLoverRecipient = post.recipients.contains('lover');
        final isReaderLover = loverUsernames.contains(post.senderUsername);
        if (!(isLoverRecipient && isReaderLover)) {
          return false;
        }
      }

      // Gửi cho tất cả → chỉ người nằm trong danh sách bạn bè mới thấy
      if (post.recipients.contains('all')) {
        return friendUsernames.contains(post.senderUsername);
      }

      // Gửi cho bạn thân → phải là bạn thân của sender
      if (post.recipients.contains('best_friends')) {
        return bestFriendUsernames.contains(post.senderUsername);
      }

      // Gửi cho người yêu → phải là lover của sender
      if (post.recipients.contains('lover')) {
        return loverUsernames.contains(post.senderUsername);
      }

      // Gửi đích danh username
      if (post.recipients.contains(currentUsername)) return true;

      return false;
    }).toList();

    // Sắp xếp theo thứ tự: Bài đăng của mình trước -> Bạn thân -> Người yêu -> Bạn bình thường
    // Trong mỗi nhóm xếp theo thời gian mới nhất lên đầu.
    filtered.sort((a, b) {
      final isOwnA = a.senderUsername == currentUsername;
      final isOwnB = b.senderUsername == currentUsername;
      
      if (isOwnA != isOwnB) {
        return isOwnA ? -1 : 1;
      }
      
      final isBestA = txaAuth.bestFriendsList.any((f) => f['username'] == a.senderUsername);
      final isBestB = txaAuth.bestFriendsList.any((f) => f['username'] == b.senderUsername);
      
      if (isBestA != isBestB) {
        return isBestA ? -1 : 1;
      }

      final isLoverA = txaAuth.loversList.any((f) => f['username'] == a.senderUsername);
      final isLoverB = txaAuth.loversList.any((f) => f['username'] == b.senderUsername);
      
      if (isLoverA != isLoverB) {
        return isLoverA ? -1 : 1;
      }
      
      return b.createdTime.compareTo(a.createdTime);
    });

    return filtered;
  }


  // Get unread count for current user
  int getUnreadCountForUser(String currentUsername) {
    final visible = getVisiblePostsForUser(currentUsername);
    return visible.where((p) => !p.readBy.contains(currentUsername) && p.senderUsername != currentUsername).length;
  }

  // Mark post as read by current user
  Future<void> markPostAsRead(String postId, String currentUsername) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('posts').doc(postId);
      final doc = await docRef.get();
      if (doc.exists) {
        final readBy = List<String>.from(doc.data()?['readBy'] ?? []);
        if (!readBy.contains(currentUsername)) {
          readBy.add(currentUsername);
          await docRef.update({'readBy': readBy});
        }
      }
    } catch (e) {
      debugPrint('markPostAsRead error: $e');
    }
  }

  // Mark all unread posts as read for the user
  Future<void> markAllPostsAsRead(String currentUsername) async {
    try {
      final visible = getVisiblePostsForUser(currentUsername);
      final unreadPosts = visible.where((p) => !p.readBy.contains(currentUsername) && p.senderUsername != currentUsername).toList();
      
      if (unreadPosts.isEmpty) return;

      // Optimistic UI updates
      for (final post in unreadPosts) {
        if (!post.readBy.contains(currentUsername)) {
          post.readBy.add(currentUsername);
        }
      }
      notifyListeners();

      // Firestore updates
      final batch = FirebaseFirestore.instance.batch();
      for (final post in unreadPosts) {
        final docRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
        batch.update(docRef, {
          'readBy': FieldValue.arrayUnion([currentUsername])
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('markAllPostsAsRead error: $e');
    }
  }

  // Create new Locket photo/voice post
  Future<void> createPost({
    required String senderUsername,
    required String senderAvatar,
    required String senderAvatarColor,
    required String photoPath,
    String? voicePath,
    int? voiceDuration,
    required String caption,
    required String moodEmoji,
    String? stickerBgColor,
    String? stickerGradient,
    String? stickerTextColor,
    required String aspectRatio,
    required String timestampText,
    List<String> recipients = const ['all'],
    bool isBlurOverlay = false,
    bool isRollcall = false,
  }) async {
    String finalPhotoUrl = photoPath;
    String? finalVoiceUrl = voicePath;

    // 1. Upload photo to Cloudinary if it's a local file path
    if (photoPath.isNotEmpty && !photoPath.startsWith('assets/') && !photoPath.startsWith('http')) {
      final file = File(photoPath);
      if (!await file.exists()) {
        throw Exception('Không tìm thấy file ảnh: $photoPath');
      }
      try {
        finalPhotoUrl = await TXACloudinaryService.instance.uploadPostPhoto(file);
      } catch (e) {
        debugPrint('Upload photo error: $e');
        rethrow; // Không ghi Firestore khi upload thất bại
      }
    }

    // 2. Upload voice note to Cloudinary if it's a local file path
    if (voicePath != null && !voicePath.startsWith('assets/') && !voicePath.startsWith('http')) {
      final file = File(voicePath);
      if (await file.exists()) {
        try {
          finalVoiceUrl = await TXACloudinaryService.instance.uploadPostVoice(file);
        } catch (e) {
          debugPrint('Upload voice error: $e');
          // Voice là optional, không rethrow → tiếp tục đăng không có voice
        }
      }
    }

    // 3. Write document to Firestore
    await FirebaseFirestore.instance.collection('posts').add({
      'senderUsername': senderUsername,
      'senderAvatar': senderAvatar,
      'senderAvatarColor': senderAvatarColor,
      'photoPath': finalPhotoUrl,
      'voicePath': finalVoiceUrl,
      'voiceDuration': voiceDuration,
      'caption': caption,
      'moodEmoji': moodEmoji,
      'stickerBgColor': stickerBgColor,
      'stickerGradient': stickerGradient,
      'stickerTextColor': stickerTextColor,
      'aspectRatio': aspectRatio,
      'timestampText': timestampText,
      'recipients': recipients,
      'readBy': [senderUsername],
      'reactions': [],
      'createdTime': DateTime.now().toIso8601String(),
      'isBlurOverlay': isBlurOverlay,
      'isRollcall': isRollcall,
    });

    // Ghi nhận tính toán Streak cho tác giả
    await TXAStreakService.instance.recordNewPost(senderUsername);

    // Log event to Analytics safely
    try {
      await TXAAnalytics.logEvent(
        'create_post',
        parameters: {
          'sender': senderUsername,
          'has_voice': finalVoiceUrl != null ? 'true' : 'false',
          'has_caption': caption.isNotEmpty ? 'true' : 'false',
          'is_rollcall': isRollcall ? 'true' : 'false',
        },
      );
    } catch (_) {}
  }

  // Add reaction to post (cho phép thả cảm xúc liên tục nhiều lần)
  Future<void> addReaction({
    required String postId,
    required String senderUsername,
    required String emoji,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('posts').doc(postId);
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data();
        final postSender = data?['senderUsername'] as String? ?? '';
        final reactions = List<Map<String, dynamic>>.from(
            data?['reactions']?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []);

        final existingIdx = reactions.indexWhere((r) => r['sender'] == senderUsername);
        if (existingIdx != -1) {
          reactions[existingIdx]['emoji'] = emoji;
        } else {
          reactions.add({'sender': senderUsername, 'emoji': emoji});
        }

        await docRef.update({'reactions': reactions});

        // Log event to Analytics safely
        try {
          await TXAAnalytics.logEvent(
            'add_reaction',
            parameters: {
              'sender': senderUsername,
              'emoji': emoji,
              'postId': postId,
            },
          );
        } catch (_) {}

        // Gửi thông báo đến tác giả bài đăng nếu người thả cảm xúc không phải là tác giả
        if (postSender.isNotEmpty && postSender != senderUsername) {
          final txaLang = TXALanguage.instance;
          final notificationContent = txaLang
              .getText('noti_reaction_body')
              .replaceAll('%sender%', '@$senderUsername');

          final bodyText = '$emoji $notificationContent';
          
          // Trigger background push notification qua FCM API
          try {
            await TXANotificationService.instance.sendBackgroundPushNotification(
              targetUsername: postSender,
              title: senderUsername,
              body: bodyText,
              data: {
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'type': 'reaction',
                'postId': postId,
                'sender': senderUsername,
              },
            );
          } catch (e) {
             debugPrint('Reaction background push error: $e');
          }

          // Ghi nhận notification vào Firestore collection notifications
          try {
            await FirebaseFirestore.instance.collection('notifications').add({
              'type': 'reaction',
              'sender': senderUsername,
              'receiver': postSender,
              'content': bodyText,
              'postId': postId,
              'createdTime': DateTime.now().toIso8601String(),
              'read': false,
            });
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('addReaction error: $e');
    }
  }

  // Cập nhật thứ tự dải reaction emoji nhanh của bài viết trên Firestore
  Future<void> updateQuickEmojisOrder({
    required String postId,
    required List<String> newOrder,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .update({'quickEmojisOrder': newOrder});
    } catch (e) {
      debugPrint('updateQuickEmojisOrder error: $e');
    }
  }

  // Delete post
  Future<void> deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
    } catch (e) {
      debugPrint('deletePost error: $e');
    }
  }

  // Report post
  Future<void> reportPost({
    required String postId,
    required String reporterUsername,
  }) async {
    try {
      final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
      final postSnapshot = await postRef.get();
      if (postSnapshot.exists) {
        final data = postSnapshot.data();
        final postSender = data?['senderUsername'] ?? '@unknown';

        await FirebaseFirestore.instance.collection('reports').add({
          'postId': postId,
          'postSender': postSender,
          'reporter': reporterUsername,
          'status': 'pending',
          'photoPath': data?['photoPath'] ?? '',
          'caption': data?['caption'] ?? '',
          'createdTime': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('reportPost error: $e');
    }
  }

  // Get reports (Admin only)
  Future<List<Map<String, dynamic>>> getReportsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('reports').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('getReportsFromFirestore error: $e');
      return [];
    }
  }

  // Resolve/process report (Admin only)
  Future<void> resolveReport({
    required String reportId,
    required String reporterUsername,
  }) async {
    try {
      // 1. Update report status
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({'status': 'resolved'});

      // 2. Add firestore notification document for reporter
      final txaLang = TXALanguage.instance;
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientUsername': reporterUsername,
        'title': txaLang.getText('report_resolved_title'),
        'body': txaLang.getText('report_resolved_body'),
        'createdTime': DateTime.now().toIso8601String(),
        'read': false,
      });
    } catch (e) {
      debugPrint('resolveReport error: $e');
    }
  }
}
