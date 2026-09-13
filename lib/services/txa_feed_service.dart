import 'dart:io';
import 'package:flutter/material.dart';
import 'txa_supabase_service.dart';
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
      final rawRead = json['readBy'] ?? json['readby'];
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
      final rawEmojis = json['quickEmojisOrder'] ?? json['quickemojisorder'];
      if (rawEmojis is List && rawEmojis.isNotEmpty) {
        parsedQuickEmojis = rawEmojis.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return LocketPostModel(
      id: json['id']?.toString() ?? '',
      senderUsername: (json['senderUsername'] ?? json['senderusername'])?.toString() ?? '@user',
      senderAvatar: (json['senderAvatar'] ?? json['senderavatar'])?.toString() ?? '🦊',
      senderAvatarColor: (json['senderAvatarColor'] ?? json['senderavatarcolor'])?.toString() ?? '0xFFF57C00',
      photoPath: (json['photoPath'] ?? json['photopath'])?.toString() ?? '',
      voicePath: (json['voicePath'] ?? json['voicepath'])?.toString(),
      voiceDuration: (json['voiceDuration'] ?? json['voiceduration']) as int?,
      caption: json['caption']?.toString() ?? '',
      moodEmoji: (json['moodEmoji'] ?? json['moodemoji'])?.toString() ?? '😊',
      stickerBgColor: (json['stickerBgColor'] ?? json['stickerbgcolor'])?.toString(),
      stickerGradient: (json['stickerGradient'] ?? json['stickergradient'])?.toString(),
      stickerTextColor: (json['stickerTextColor'] ?? json['stickertextcolor'])?.toString(),
      aspectRatio: (json['aspectRatio'] ?? json['aspectratio'])?.toString() ?? '1:1',
      timestampText: (json['timestampText'] ?? json['timestamptext'])?.toString() ?? 'Vừa xong',
      recipients: parsedRecipients,
      readBy: parsedReadBy,
      reactions: parsedReactions,
      quickEmojisOrder: parsedQuickEmojis,
      createdTime: (json['createdTime'] ?? json['createdtime'])?.toString() ?? '',
      isBlurOverlay: json['isBlurOverlay'] == true || json['isbluroverlay'] == true,
      isRollcall: json['isRollcall'] == true || json['isrollcall'] == true,
    );
  }

  /// Avatar có hiệu lực thời gian thực (luôn ưu tiên profile mới nhất thay vì cache cũ)
  String get effectiveSenderAvatar {
    final txaAuth = TXAAuthService.instance;
    final curUser = txaAuth.currentUser;
    if (curUser != null && senderUsername == curUser.username) {
      if (curUser.avatar.isNotEmpty) return curUser.avatar;
    }
    final friend = txaAuth.getFriendByUsername(senderUsername);
    if (friend != null) {
      final fAv = friend['avatar']?.toString();
      if (fAv != null && fAv.isNotEmpty && fAv != '👤') return fAv;
    }
    return senderAvatar.isNotEmpty ? senderAvatar : '🦊';
  }

  /// Màu nền Avatar có hiệu lực thời gian thực
  String get effectiveSenderAvatarColor {
    final txaAuth = TXAAuthService.instance;
    final curUser = txaAuth.currentUser;
    if (curUser != null && senderUsername == curUser.username) {
      if (curUser.avatarBgColor.isNotEmpty) return curUser.avatarBgColor;
    }
    final friend = txaAuth.getFriendByUsername(senderUsername);
    if (friend != null) {
      final fCol = friend['bgColor'];
      if (fCol != null) {
        if (fCol is int) return '0x${fCol.toRadixString(16).toUpperCase()}';
        return fCol.toString();
      }
    }
    return senderAvatarColor.isNotEmpty ? senderAvatarColor : '0xFFF57C00';
  }

  LocketPostModel copyWith({
    String? id,
    String? senderUsername,
    String? senderAvatar,
    String? senderAvatarColor,
    String? photoPath,
    String? voicePath,
    int? voiceDuration,
    String? caption,
    String? moodEmoji,
    String? stickerBgColor,
    String? stickerGradient,
    String? stickerTextColor,
    String? aspectRatio,
    String? timestampText,
    List<String>? recipients,
    List<String>? readBy,
    List<Map<String, String>>? reactions,
    List<String>? quickEmojisOrder,
    String? createdTime,
    bool? isBlurOverlay,
    bool? isRollcall,
  }) {
    return LocketPostModel(
      id: id ?? this.id,
      senderUsername: senderUsername ?? this.senderUsername,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      senderAvatarColor: senderAvatarColor ?? this.senderAvatarColor,
      photoPath: photoPath ?? this.photoPath,
      voicePath: voicePath ?? this.voicePath,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      caption: caption ?? this.caption,
      moodEmoji: moodEmoji ?? this.moodEmoji,
      stickerBgColor: stickerBgColor ?? this.stickerBgColor,
      stickerGradient: stickerGradient ?? this.stickerGradient,
      stickerTextColor: stickerTextColor ?? this.stickerTextColor,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      timestampText: timestampText ?? this.timestampText,
      recipients: recipients ?? this.recipients,
      readBy: readBy ?? this.readBy,
      reactions: reactions ?? this.reactions,
      quickEmojisOrder: quickEmojisOrder ?? this.quickEmojisOrder,
      createdTime: createdTime ?? this.createdTime,
      isBlurOverlay: isBlurOverlay ?? this.isBlurOverlay,
      isRollcall: isRollcall ?? this.isRollcall,
    );
  }
}

class TXAFeedService extends ChangeNotifier {
  static final TXAFeedService instance = TXAFeedService._internal();
  TXAFeedService._internal();

  final List<LocketPostModel> _posts = [];
  List<LocketPostModel> get posts => List.unmodifiable(_posts);

  List<LocketPostModel>? _cachedVisiblePosts;
  String? _cachedUsername;

  void clearVisiblePostsCache() {
    _cachedVisiblePosts = null;
    _cachedUsername = null;
  }

  /// Cập nhật ngay lập tức avatar của toàn bộ bài đăng cũ thuộc về user trong RAM
  void updateSenderAvatar(String username, String newAvatar, String newColorHex) {
    bool changed = false;
    for (int i = 0; i < _posts.length; i++) {
      if (_posts[i].senderUsername == username) {
        _posts[i] = _posts[i].copyWith(
          senderAvatar: newAvatar,
          senderAvatarColor: newColorHex,
        );
        changed = true;
      }
    }
    if (changed) {
      clearVisiblePostsCache();
      notifyListeners();
    }
  }

  Future<void> init() async {
    TXASupabaseService.instance.client
        .from('txa_posts')
        .stream(primaryKey: ['id'])
        .order('createdTime', ascending: false)
        .listen((List<Map<String, dynamic>> data) {
      _posts.clear();
      clearVisiblePostsCache();
      for (var row in data) {
        final photoPath = row['photoPath'] as String? ?? '';
        if (photoPath.startsWith('assets/')) {
          TXASupabaseService.instance.client.from('txa_posts').delete().eq('id', row['id'] as String);
          continue;
        }
        _posts.add(LocketPostModel.fromJson(row));
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Supabase listen error: $e');
    });
  }

  // Get posts visible to current user based on recipient permissions
  List<LocketPostModel> getVisiblePostsForUser(String currentUsername) {
    if (_cachedVisiblePosts != null && _cachedUsername == currentUsername) {
      return _cachedVisiblePosts!;
    }

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

    final loverUsername = txaAuth.currentUser?.loverUsername ?? '';
    bool isLover(String u) =>
        (loverUsername.isNotEmpty && u == loverUsername) ||
        loversList.any((f) => f['username'] == u);

    bool isBestFriend(String u) => bestFriendUsernames.contains(u);

    // Bảng index thứ tự bạn bè theo danh sách kéo thả trong modal bạn bè
    final friendOrderMap = <String, int>{};
    for (int i = 0; i < friendsList.length; i++) {
      final uname = friendsList[i]['username'] as String?;
      if (uname != null && uname.isNotEmpty) {
        friendOrderMap[uname] = i;
      }
    }

    // Tách 2 nhóm:
    // 1. Nhóm bài CHƯA XEM (và bài vừa đăng của chính mình nếu mới hơn bài chưa xem):
    //    Sắp xếp chuẩn theo dòng thời gian tạo: b.createdTime.compareTo(a.createdTime). Bài nào đăng mới nhất sẽ luôn xuất hiện ở đầu bảng tin.
    // 2. Nhóm bài ĐÃ XEM RỒI:
    //    Sắp xếp theo thứ tự toàn danh sách bạn bè (kéo thả trong modal), ưu tiên lover -> best friend -> thứ tự friendsList -> thời gian.
    final unreadPosts = <LocketPostModel>[];
    final readPosts = <LocketPostModel>[];

    // Tìm bài chưa xem của bạn bè để xác định mốc thời gian bài chưa xem cũ nhất
    for (final post in filtered) {
      final isFriendUnread = !post.readBy.contains(currentUsername) && post.senderUsername != currentUsername;
      if (isFriendUnread) {
        unreadPosts.add(post);
      }
    }

    String oldestUnreadTime = '';
    if (unreadPosts.isNotEmpty) {
      unreadPosts.sort((a, b) => a.createdTime.compareTo(b.createdTime));
      oldestUnreadTime = unreadPosts.first.createdTime;
    }
    unreadPosts.clear();

    for (final post in filtered) {
      final isFriendUnread = !post.readBy.contains(currentUsername) && post.senderUsername != currentUsername;
      final isOwnNewPost = post.senderUsername == currentUsername &&
          (oldestUnreadTime.isEmpty || post.createdTime.compareTo(oldestUnreadTime) >= 0);

      if (isFriendUnread || isOwnNewPost) {
        unreadPosts.add(post);
      } else {
        readPosts.add(post);
      }
    }

    // 1. Nhóm chưa xem: Sắp xếp theo dòng thời gian chuẩn (Timeline Chronological Order)
    // Bài mới nhất luôn xuất hiện ở đầu bảng tin
    unreadPosts.sort((a, b) {
      return b.createdTime.compareTo(a.createdTime);
    });

    // 2. Nhóm đã xem: Sắp xếp theo thứ tự danh sách bạn bè (kéo thả trong modal), ưu tiên lover -> best friend -> friendsList order
    int getReadPriority(LocketPostModel p) {
      if (p.senderUsername == currentUsername) return 0; // Bài của chính mình
      if (isLover(p.senderUsername)) return 1;          // Ưu tiên 1: Người yêu
      if (isBestFriend(p.senderUsername)) return 2;     // Ưu tiên 2: Bạn thân
      final order = friendOrderMap[p.senderUsername];
      if (order != null) {
        return 3 + order;                               // Ưu tiên 3: Theo thứ tự kéo thả trong modal bạn bè
      }
      return 999999;                                   // Bạn bè khác
    }

    readPosts.sort((a, b) {
      final prioA = getReadPriority(a);
      final prioB = getReadPriority(b);
      if (prioA != prioB) {
        return prioA.compareTo(prioB);
      }
      // Trong cùng 1 người bạn / cùng mức ưu tiên: bài mới hơn xếp trước
      return b.createdTime.compareTo(a.createdTime);
    });

    final sorted = [...unreadPosts, ...readPosts];

    _cachedVisiblePosts = sorted;
    _cachedUsername = currentUsername;
    return sorted;
  }


  // Get unread count for current user
  int getUnreadCountForUser(String currentUsername) {
    final visible = getVisiblePostsForUser(currentUsername);
    return visible.where((p) => !p.readBy.contains(currentUsername) && p.senderUsername != currentUsername).length;
  }

  // Mark post as read by current user
  Future<void> markPostAsRead(String postId, String currentUsername) async {
    try {
      // 1. Cập nhật lạc quan (Optimistic update) trong RAM ngay lập tức
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        if (!_posts[postIndex].readBy.contains(currentUsername)) {
          final updatedReadBy = List<String>.from(_posts[postIndex].readBy)..add(currentUsername);
          _posts[postIndex] = _posts[postIndex].copyWith(readBy: updatedReadBy);
          clearVisiblePostsCache();
          notifyListeners();
        }
      }

      // 2. Cập nhật trên Supabase database
      final supabase = TXASupabaseService.instance.client;
      final doc = await supabase.from('txa_posts').select().eq('id', postId).maybeSingle();
      if (doc != null) {
        final readBy = List<String>.from(doc['readBy'] ?? []);
        if (!readBy.contains(currentUsername)) {
          readBy.add(currentUsername);
          await supabase.from('txa_posts').update({'readBy': readBy}).eq('id', postId);
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

      // Supabase updates
      final supabase = TXASupabaseService.instance.client;
      for (final post in unreadPosts) {
        await supabase.from('txa_posts').update({
          'readBy': post.readBy,
        }).eq('id', post.id);
      }
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

    // 3. Write document to Supabase
    final nowIso = DateTime.now().toIso8601String();
    await TXASupabaseService.instance.client.from('txa_posts').insert({
      'senderUsername': senderUsername,
      'senderusername': senderUsername,
      'senderAvatar': senderAvatar,
      'senderavatar': senderAvatar,
      'senderAvatarColor': senderAvatarColor,
      'senderavatarcolor': senderAvatarColor,
      'photoPath': finalPhotoUrl,
      'photopath': finalPhotoUrl,
      'voicePath': finalVoiceUrl,
      'voicepath': finalVoiceUrl,
      'voiceDuration': voiceDuration,
      'voiceduration': voiceDuration,
      'caption': caption,
      'moodEmoji': moodEmoji,
      'moodemoji': moodEmoji,
      'stickerBgColor': stickerBgColor,
      'stickerbgcolor': stickerBgColor,
      'stickerGradient': stickerGradient,
      'stickergradient': stickerGradient,
      'stickerTextColor': stickerTextColor,
      'stickertextcolor': stickerTextColor,
      'aspectRatio': aspectRatio,
      'aspectratio': aspectRatio,
      'timestampText': timestampText,
      'timestamptext': timestampText,
      'recipients': recipients,
      'readBy': [senderUsername],
      'readby': [senderUsername],
      'reactions': [],
      'quickemojisorder': ['❤️', '🔥', '😮', '😂', '😢', '👍'],
      'createdTime': nowIso,
      'createdtime': nowIso,
      'isBlurOverlay': isBlurOverlay,
      'isbluroverlay': isBlurOverlay,
      'isRollcall': isRollcall,
      'isrollcall': isRollcall,
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
      final supabase = TXASupabaseService.instance.client;
      final doc = await supabase.from('txa_posts').select().eq('id', postId).maybeSingle();
      if (doc != null) {
        final postSender = doc['senderUsername'] as String? ?? '';
        // Không cho phép tự thả cảm xúc vào bài viết của chính mình
        if (postSender.isNotEmpty && postSender == senderUsername) {
          debugPrint('TXAFeedService: Blocked self-reaction by $senderUsername on post $postId');
          return;
        }

        final reactions = List<Map<String, dynamic>>.from(
            doc['reactions']?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []);

        final existingIdx = reactions.indexWhere((r) => r['sender'] == senderUsername);
        if (existingIdx != -1) {
          reactions[existingIdx]['emoji'] = emoji;
        } else {
          reactions.add({'sender': senderUsername, 'emoji': emoji});
        }

        await supabase.from('txa_posts').update({'reactions': reactions}).eq('id', postId);

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

          // Ghi nhận notification vào Supabase table txa_notifications
          try {
             await supabase.from('txa_notifications').insert({
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

  // Cập nhật thứ tự dải reaction emoji nhanh của bài viết trên Supabase
  Future<void> updateQuickEmojisOrder({
    required String postId,
    required List<String> newOrder,
  }) async {
    try {
      await TXASupabaseService.instance.client
          .from('txa_posts')
          .update({'quickEmojisOrder': newOrder})
          .eq('id', postId);
    } catch (e) {
      debugPrint('updateQuickEmojisOrder error: $e');
    }
  }

  // Delete post
  Future<void> deletePost(String postId) async {
    try {
      await TXASupabaseService.instance.client.from('txa_posts').delete().eq('id', postId);
    } catch (e) {
      debugPrint('deletePost error: $e');
    }
  }

  // Report post
  Future<void> reportPost({
    required String postId,
    required String reporterUsername,
    String? reason,
  }) async {
    try {
      final supabase = TXASupabaseService.instance.client;
      final postSnapshot = await supabase.from('txa_posts').select().eq('id', postId).maybeSingle();
      if (postSnapshot != null) {
        final postSender = postSnapshot['senderUsername'] ?? '@unknown';
        final originalCaption = (postSnapshot['caption'] as String?)?.trim() ?? '';
        final reasonStr = (reason != null && reason.trim().isNotEmpty) ? reason.trim() : 'Nội dung không phù hợp';
        final photoUrl = postSnapshot['photoPath'] ?? '';
        final formattedCaption = originalCaption.isNotEmpty
            ? '🚩 [LÝ DO: $reasonStr]\n• Caption gốc: "$originalCaption"\n• Ảnh đính kèm: $photoUrl'
            : '🚩 [LÝ DO: $reasonStr]\n• Bài viết ảnh khoảnh khắc (không có chữ)\n• Ảnh đính kèm: $photoUrl';

        await supabase.from('txa_reports').insert({
          'postId': postId,
          'postid': postId,
          'postSender': postSender,
          'postsender': postSender,
          'reporter': reporterUsername,
          'status': 'pending',
          'photoPath': photoUrl,
          'photopath': photoUrl,
          'caption': formattedCaption,
          'createdTime': DateTime.now().toIso8601String(),
          'createdtime': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('reportPost error: $e');
    }
  }

  // Get reports (Admin only)
  Future<List<Map<String, dynamic>>> getReportsFromFirestore() async {
    try {
      final data = await TXASupabaseService.instance.client.from('txa_reports').select();
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('getReportsFromFirestore error: $e');
      return [];
    }
  }

  // Resolve/process report (Admin only)
  Future<void> resolveReport({
    required String reportId,
    required String reporterUsername,
    String? targetUsername,
  }) async {
    try {
      final supabase = TXASupabaseService.instance.client;
      // 1. Update report status
      await supabase.from('txa_reports').update({'status': 'resolved'}).eq('id', reportId);

      // 2. Determine target user to notify
      final effectiveTarget = (targetUsername != null && targetUsername.isNotEmpty && targetUsername != 'anonymous' && targetUsername != '@unknown')
          ? targetUsername
          : ((reporterUsername != 'TXALogger' && reporterUsername != 'anonymous' && reporterUsername != '@unknown') ? reporterUsername : null);

      if (effectiveTarget != null && effectiveTarget.isNotEmpty) {
        final txaLang = TXALanguage.instance;
        final title = txaLang.getText('report_resolved_title');
        final body = txaLang.getText('report_resolved_body');

        // Add to txa_notifications table with both receiver and recipientUsername fields
        await supabase.from('txa_notifications').insert({
          'recipientUsername': effectiveTarget,
          'receiver': effectiveTarget,
          'sender': '@admin',
          'type': 'report_resolved',
          'title': title,
          'body': body,
          'content': body,
          'createdTime': DateTime.now().toIso8601String(),
          'read': false,
        });

        // Send real FCM push notification
        try {
          await TXANotificationService.instance.sendBackgroundPushNotification(
            targetUsername: effectiveTarget,
            title: title,
            body: body,
            data: {
              'type': 'report_resolved',
              'reportId': reportId,
            },
          );
        } catch (e) {
          debugPrint('Error sending FCM push for resolved report: $e');
        }
      }
    } catch (e) {
      debugPrint('resolveReport error: $e');
    }
  }
}
