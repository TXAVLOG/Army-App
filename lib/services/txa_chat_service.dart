import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: currentUsername)
        .snapshots()
        .listen((snap) async {
      _allUserMessages.clear();
      final batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;

      for (var doc in snap.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final msg = TXAChatMessageModel.fromJson(data);
        _allUserMessages.add(msg);

        // Tự động cập nhật isDelivered = true nếu người nhận là tôi và tin nhắn chưa được delivered
        if (msg.receiverUsername == currentUsername && !msg.isDelivered) {
          batch.update(doc.reference, {'isDelivered': true});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        try {
          await batch.commit();
        } catch (e) {
          debugPrint('TXAChatService batch update isDelivered error: $e');
        }
      }

      // Sắp xếp theo thứ tự thời gian tăng dần
      _allUserMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    }, onError: (e) {
      debugPrint('TXAChatService listen error: $e');
    });
  }

  /// Gửi tin nhắn thực tế lên Firestore
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

    final docRef = FirebaseFirestore.instance.collection('messages').doc();
    await docRef.set({
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
    });

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
          'messageId': docRef.id,
        },
      );
    } catch (e) {
      debugPrint('FCM background push notify error: $e');
    }

    // Đồng bộ Firestore Notification document
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': type,
        'sender': senderUsername,
        'receiver': receiverUsername,
        'content': text,
        'messageId': docRef.id,
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
      final snap = await FirebaseFirestore.instance
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('receiverUsername', isEqualTo: currentUsername)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;
      for (var doc in snap.docs) {
        final data = doc.data();
        final read = data['isRead'] as bool? ?? false;
        final delivered = data['isDelivered'] as bool? ?? false;
        if (!read || !delivered) {
          batch.update(doc.reference, {'isRead': true, 'isDelivered': true});
          hasUpdates = true;
        }
      }
      if (hasUpdates) {
        await batch.commit();
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
    return FirebaseFirestore.instance
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TXAChatMessageModel.fromJson(data);
      }).toList();
      // Sắp xếp thời gian tăng dần (local để tránh yêu cầu Firestore Index)
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

  /// Cập nhật cảm xúc (reaction) của tin nhắn lên Firestore và trigger notification
  Future<void> updateMessageReaction({
    required String messageId,
    required String username,
    required String emoji,
    required String receiverUsername,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('messages').doc(messageId);
    await docRef.set({
      'reactions': {
        username: emoji,
      }
    }, SetOptions(merge: true));

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
      await FirebaseFirestore.instance.collection('notifications').add({
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
