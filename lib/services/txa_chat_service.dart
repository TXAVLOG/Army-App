import 'package:flutter/material.dart';
import 'txa_supabase_service.dart';
import 'txa_notification_service.dart';
import 'txa_language.dart';
import 'txa_analytics.dart';

class TXAChatMessageModel {
  final String id;
  final String senderUsername;
  final String receiverUsername;
  final String conversationId;
  final List<String> participants;
  final String text;
  final String timestamp; // ISO String
  final String? postId;
  final String? postPhotoPath;
  final String? postCaption;
  final String? postSenderUsername;
  final String? replyToId;
  final String? replyToSender;
  final String? replyToText;
  final Map<String, String> reactions; // { "username": "emoji" }
  final bool isDelivered;
  final bool isRead;

  TXAChatMessageModel({
    required this.id,
    required this.senderUsername,
    required this.receiverUsername,
    required this.conversationId,
    required this.participants,
    required this.text,
    required this.timestamp,
    this.postId,
    this.postPhotoPath,
    this.postCaption,
    this.postSenderUsername,
    this.replyToId,
    this.replyToSender,
    this.replyToText,
    this.reactions = const {},
    this.isDelivered = false,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderUsername': senderUsername,
        'receiverUsername': receiverUsername,
        'conversationId': conversationId,
        'participants': participants,
        'text': text,
        'timestamp': timestamp,
        'postId': postId,
        'postPhotoPath': postPhotoPath,
        'postCaption': postCaption,
        'postSenderUsername': postSenderUsername,
        'replyToId': replyToId,
        'replyToSender': replyToSender,
        'replyToText': replyToText,
        'reactions': reactions,
        'isDelivered': isDelivered,
        'isRead': isRead,
      };

  factory TXAChatMessageModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> parsedReactions = {};
    try {
      final rawReactions = json['reactions'];
      if (rawReactions is Map) {
        rawReactions.forEach((key, val) {
          parsedReactions[key.toString()] = val.toString();
        });
      }
    } catch (_) {}

    return TXAChatMessageModel(
      id: json['id'] ?? '',
      senderUsername: json['senderUsername'] ?? '',
      receiverUsername: json['receiverUsername'] ?? '',
      conversationId: json['conversationId'] ?? '',
      participants: (json['participants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      text: json['text'] ?? '',
      timestamp: json['timestamp'] ?? '',
      postId: json['postId'] as String?,
      postPhotoPath: json['postPhotoPath'] as String?,
      postCaption: json['postCaption'] as String?,
      postSenderUsername: json['postSenderUsername'] as String?,
      replyToId: json['replyToId'] as String?,
      replyToSender: json['replyToSender'] as String?,
      replyToText: json['replyToText'] as String?,
      reactions: parsedReactions,
      isDelivered: json['isDelivered'] ?? false,
      isRead: json['isRead'] ?? false,
    );
  }
}

class TXAChatService extends ChangeNotifier {
  static final TXAChatService instance = TXAChatService._internal();
  TXAChatService._internal();

  static String? activeChatFriendUsername;

  final List<TXAChatMessageModel> _allUserMessages = [];
  List<TXAChatMessageModel> get allUserMessages => List.unmodifiable(_allUserMessages);



  /// Lấy conversationId chuẩn hóa (sắp xếp bảng chữ cái)
  static String getConversationId(String u1, String u2) {
    final list = [u1, u2]..sort();
    return list.join('_');
  }

  /// Khởi tạo và lắng nghe toàn bộ tin nhắn liên quan đến user hiện tại
  Future<void> init(String currentUsername) async {
    if (currentUsername.isEmpty) return;
    _allUserMessages.clear();

    TXASupabaseService.instance.client
        .from('txa_messages')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) async {
      _allUserMessages.clear();

      for (var row in data) {
        final msg = TXAChatMessageModel.fromJson(row);
        // Lọc client side để chỉ hiển thị tin nhắn của tôi
        if (msg.senderUsername == currentUsername || msg.receiverUsername == currentUsername) {
          _allUserMessages.add(msg);

          // Tự động cập nhật isDelivered = true nếu người nhận là tôi và tin nhắn chưa được delivered
          if (msg.receiverUsername == currentUsername && !msg.isDelivered) {
            await TXASupabaseService.instance.client
                .from('txa_messages')
                .update({'isDelivered': true})
                .eq('id', msg.id);
          }
        }
      }

      // Sắp xếp theo thứ tự thời gian tăng dần
      _allUserMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    }, onError: (e) {
      debugPrint('TXAChatService listen error: $e');
    });
  }

  /// Gửi tin nhắn thực tế lên Supabase
  Future<void> sendMessage({
    required String senderUsername,
    required String receiverUsername,
    required String text,
    String? postId,
    String? postPhotoPath,
    String? postCaption,
    String? postSenderUsername,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  }) async {
    final conversationId = getConversationId(senderUsername, receiverUsername);
    final timestamp = DateTime.now().toIso8601String();

    final supabase = TXASupabaseService.instance.client;
    final inserted = await supabase.from('txa_messages').insert({
      'senderUsername': senderUsername,
      'receiverUsername': receiverUsername,
      'conversationId': conversationId,
      'participants': [senderUsername, receiverUsername],
      'text': text,
      'timestamp': timestamp,
      'postId': postId,
      'postPhotoPath': postPhotoPath,
      'postCaption': postCaption,
      'postSenderUsername': postSenderUsername,
      'replyToId': replyToId,
      'replyToSender': replyToSender,
      'replyToText': replyToText,
      'isDelivered': false,
      'isRead': false,
    }).select().single();

    final String messageId = inserted['id'] as String;
    final type = postId != null ? 'reply' : 'message';

    // Trigger Push Notification nền qua FCM API
    try {
      final title = senderUsername;
      final body = text;
      await TXANotificationService.instance.sendBackgroundPushNotification(
        targetUsername: receiverUsername,
        title: title,
        body: body,
        data: {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': type,
          'sender': senderUsername,
          'messageId': messageId,
        },
      );
    } catch (e) {
      debugPrint('FCM background push notify error: $e');
    }

    // Đồng bộ Supabase Notification
    try {
      await supabase.from('txa_notifications').insert({
        'type': type,
        'sender': senderUsername,
        'receiver': receiverUsername,
        'content': text,
        'messageId': messageId,
        'createdTime': timestamp,
        'read': false,
      });
    } catch (_) {}

    // Log event to Analytics safely
    try {
      await TXAAnalytics.logEvent(
        'send_message',
        parameters: {
          'sender': senderUsername,
          'is_reply': postId != null ? 'true' : 'false',
        },
      );
    } catch (_) {}
  }

  Future<void> markMessagesAsRead(String currentUsername, String friendUsername) async {
    final conversationId = getConversationId(currentUsername, friendUsername);
    try {
      final supabase = TXASupabaseService.instance.client;
      final data = await supabase
          .from('txa_messages')
          .select()
          .eq('conversationId', conversationId)
          .eq('receiverUsername', currentUsername);

      for (var row in data) {
        final read = row['isRead'] as bool? ?? false;
        final delivered = row['isDelivered'] as bool? ?? false;
        if (!read || !delivered) {
          await supabase.from('txa_messages').update({
            'isRead': true,
            'isDelivered': true,
          }).eq('id', row['id'] as String);
        }
      }
    } catch (e) {
      debugPrint('markMessagesAsRead error: $e');
    }
  }

  int getUnreadMessageCount(String currentUsername) {
    if (currentUsername.isEmpty) return 0;
    return _allUserMessages.where((m) => m.receiverUsername == currentUsername && !m.isRead).length;
  }

  /// Stream lấy danh sách tin nhắn của một cuộc hội thoại cụ thể
  Stream<List<TXAChatMessageModel>> listenMessages(String sender, String receiver) {
    final conversationId = getConversationId(sender, receiver);
    return TXASupabaseService.instance.client
        .from('txa_messages')
        .stream(primaryKey: ['id'])
        .eq('conversationId', conversationId)
        .map((rows) {
      final list = rows.map((row) => TXAChatMessageModel.fromJson(row)).toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// Lấy tin nhắn cuối cùng với bạn bè (trả về null nếu chưa nhắn)
  TXAChatMessageModel? getLastMessageForFriend(String friendUsername, String currentUsername) {
    final conversationId = getConversationId(currentUsername, friendUsername);
    final msgs = _allUserMessages.where((m) => m.conversationId == conversationId).toList();
    if (msgs.isEmpty) return null;
    return msgs.last; // Vì đã được sort tăng dần, phần tử cuối là mới nhất
  }

  /// Cập nhật cảm xúc (reaction) của tin nhắn lên Supabase và trigger notification
  Future<void> updateMessageReaction({
    required String messageId,
    required String username,
    required String emoji,
    required String receiverUsername,
  }) async {
    final supabase = TXASupabaseService.instance.client;
    final doc = await supabase.from('txa_messages').select('reactions').eq('id', messageId).maybeSingle();
    final Map<String, dynamic> reactions = Map<String, dynamic>.from(doc?['reactions'] ?? {});
    reactions[username] = emoji;

    await supabase.from('txa_messages').update({
      'reactions': reactions,
    }).eq('id', messageId);

    // Gửi thông báo reaction đa ngôn ngữ
    final txaLang = TXALanguage.instance;
    final notificationContent = txaLang
        .getText('noti_reaction_body')
        .replaceAll('%sender%', '@$username');

    TXANotificationService.instance.triggerMessageNotification(
      sender: username,
      content: '$emoji $notificationContent',
      messageId: messageId,
    );

    // Đồng bộ vào DB notifications
    try {
      await supabase.from('txa_notifications').insert({
        'type': 'reaction',
        'sender': username,
        'receiver': receiverUsername,
        'content': '$emoji $notificationContent',
        'messageId': messageId,
        'createdTime': DateTime.now().toIso8601String(),
        'read': false,
      });
    } catch (_) {}
  }
}
