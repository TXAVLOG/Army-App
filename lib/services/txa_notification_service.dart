import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'txa_language.dart';
import 'txa_auth_service.dart';
import 'txa_chat_service.dart';
import 'txa_config.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_network_image.dart';
import '../main.dart'; // Import navigatorKey

// Top-level background handler bắt buộc đối với FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Chạy isolate riêng khi app ở background hoặc bị kill.
  debugPrint("Handling a background message: ${message.messageId}");
}

class TXANotificationService extends ChangeNotifier {
  static final TXANotificationService instance = TXANotificationService._internal();
  TXANotificationService._internal();

  static const String _keyPermissionGranted = 'txa_permission_granted';
  static const String _keyFCMToken = 'txa_fcm_token';

  bool _permissionsGranted = false;
  bool get permissionsGranted => _permissionsGranted;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  final List<Map<String, dynamic>> _notificationLogs = [];
  List<Map<String, dynamic>> get notificationLogs => List.unmodifiable(_notificationLogs);

  String? _highlightMessageId;
  String? get highlightMessageId => _highlightMessageId;

  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  void setHighlightMessageId(String? msgId) {
    _highlightMessageId = msgId;
    notifyListeners();
  }

  void clearHighlightMessageId() {
    _highlightMessageId = null;
    notifyListeners();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _permissionsGranted = prefs.getBool(_keyPermissionGranted) ?? false;

    final isSupported = kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

    if (isSupported) {
      try {
        // 1. Đăng ký background message handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // 2. Lấy FCM Token thực tế
        _fcmToken = await FirebaseMessaging.instance.getToken();
        if (_fcmToken != null) {
          await prefs.setString(_keyFCMToken, _fcmToken!);
        }

        // 3. Lắng nghe thông báo khi app đang mở (Foreground)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.data.isNotEmpty) {
            handleFCMIncomingPayload(message.data);
          }
        });

        // 4. Lắng nghe khi click vào thông báo để mở app (Background)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationClick(message.data);
        });

        // 5. Kiểm tra nếu app được mở từ trạng thái bị TERMINATED hoàn toàn qua click thông báo
        FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
          if (message != null && message.data.isNotEmpty) {
            _handleNotificationClick(message.data);
          }
        });
      } catch (e) {
        debugPrint('FCM init error: $e');
      }
    } else {
      debugPrint('ℹ️ FCM không được hỗ trợ trên nền tảng này (Windows). Sử dụng token giả lập.');
      _fcmToken = prefs.getString(_keyFCMToken) ?? 'fcm_token_army_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_keyFCMToken, _fcmToken!);
    }

    notifyListeners();
  }

  void startListeningNotifications(String currentUsername) {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('receiver', isEqualTo: currentUsername)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final sender = data['sender'] as String? ?? '';
            // Nếu người gửi trùng với activeChatFriendUsername (đang mở chat) thì skip hiển thị banner
            if (sender.isNotEmpty && sender == TXAChatService.activeChatFriendUsername) {
              change.doc.reference.update({'read': true});
              continue;
            }

            // Đánh dấu đã đọc trên Firestore
            change.doc.reference.update({'read': true});

            // Hiển thị Overlay banner trượt lên màn hình
            _showSlidingBannerNotification(
              senderUsername: sender,
              type: data['type'] as String? ?? 'message',
              content: data['content'] as String? ?? '',
            );
          }
        }
      }
    });
  }

  void stopListeningNotifications() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
  }

  /// Gửi push notification nền thật sự qua API FCM Legacy
  Future<void> sendBackgroundPushNotification({
    required String targetUsername,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Lấy FCM Token của người nhận từ Firestore
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: targetUsername)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) return;
      final fcmToken = userSnap.docs.first.data()['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('FCM Token of receiver is empty/null. Cannot send background push.');
        return;
      }

      // 2. Gửi request POST lên FCM Legacy API
      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
      
      // Hỗ trợ cấu hình Server Key động từ TXAConfig
      final serverKey = TXAConfig.fcmServerKey;
      if (serverKey.isEmpty || serverKey == 'YOUR_FCM_SERVER_KEY') {
        debugPrint('FCM Server Key is not configured in TXAConfig. Skipping REST call.');
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      };

      final payload = {
        'to': fcmToken,
        'priority': 'high',
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'badge': '1',
        },
        'data': data ?? {},
      };

      final response = await http.post(url, headers: headers, body: jsonEncode(payload));
      debugPrint('FCM push response: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('FCM sendBackgroundPushNotification error: $e');
    }
  }

  void _showSlidingBannerNotification({
    required String senderUsername,
    required String type,
    required String content,
  }) {
    // Lấy thông tin user của sender để vẽ avatar
    FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: senderUsername)
        .limit(1)
        .get()
        .then((userSnap) {
      if (userSnap.docs.isEmpty) return;
      final userModel = UserModel.fromJson(userSnap.docs.first.data());

      final overlayState = navigatorKey.currentState?.overlay;
      if (overlayState == null) return;

      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) {
          return _TXANotificationOverlayWidget(
            userModel: userModel,
            type: type,
            content: content,
            onDismiss: () {
              overlayEntry.remove();
            },
          );
        },
      );

      overlayState.insert(overlayEntry);
    }).catchError((e) {
      debugPrint('Error getting sender info for sliding banner: $e');
    });
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final requestId = data['requestId'] as String?;
    final messageId = data['messageId'] as String?;

    if (type == 'friend_request' && requestId != null) {
      TXAAuthService.instance.setHighlightRequestId(requestId);
    } else if (type == 'message' && messageId != null) {
      setHighlightMessageId(messageId);
    }
  }

  static const _batteryChannel = MethodChannel('vn.army.txa/battery_optimization');

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool isIgnoring = await _batteryChannel.invokeMethod('isIgnoringBatteryOptimizations') ?? true;
      return isIgnoring;
    } catch (_) {
      return true;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  Future<bool> isDndAccessGranted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool isGranted = await _batteryChannel.invokeMethod('isDndAccessGranted') ?? true;
      return isGranted;
    } catch (_) {
      return true;
    }
  }

  Future<void> requestDndAccess() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _batteryChannel.invokeMethod('requestDndAccess');
    } catch (_) {}
  }

  // Request Permissions (Camera, Photos, Push Notifications)
  Future<bool> requestPermissions(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Request FCM push notifications permission
    final isSupported = kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    if (isSupported) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        _permissionsGranted = settings.authorizationStatus == AuthorizationStatus.authorized || 
                             settings.authorizationStatus == AuthorizationStatus.provisional;
      } catch (e) {
        debugPrint('FCM requestPermission error: $e');
        _permissionsGranted = false;
      }
    } else {
      _permissionsGranted = true;
    }

    await prefs.setBool(_keyPermissionGranted, _permissionsGranted);

    // Request Android Do Not Disturb (DND) access and battery optimization bypass
    if (!kIsWeb && Platform.isAndroid) {
      final isDnd = await isDndAccessGranted();
      if (!isDnd) {
        await requestDndAccess();
      }
      
      final isIgnoring = await isIgnoringBatteryOptimizations();
      if (!isIgnoring) {
        await requestIgnoreBatteryOptimizations();
      }
    }

    if (context.mounted && _permissionsGranted) {
      final txaLang = TXALanguage.instance;
      TXAToast.show(
        context,
        txaLang.getText('permission_granted_toast'),
        icon: Icons.check_circle_rounded,
      );
    }

    notifyListeners();
    return _permissionsGranted;
  }

  // Handle FCM Remote Message Payload (Background & Foreground Entry Point)
  void handleFCMIncomingPayload(Map<String, dynamic> payload) {
    final type = payload['type'] as String? ?? 'general';
    final sender = payload['sender'] as String? ?? '@user';
    final content = payload['content'] as String? ?? '';
    final messageId = payload['messageId'] as String?;

    switch (type) {
      case 'reaction':
        triggerReactionNotification(sender: sender);
        break;
      case 'message':
        triggerMessageNotification(sender: sender, content: content, messageId: messageId);
        break;
      case 'reply':
        triggerReplyNotification(sender: sender);
        break;
      case 'reminder_morning':
        triggerScheduledDeadlineNotification(isMorning: true);
        break;
      case 'reminder_evening':
        triggerScheduledDeadlineNotification(isMorning: false);
        break;
      default:
        _addNotificationLog(
          type: type,
          title: payload['title'] ?? 'Army Notification',
          body: payload['body'] ?? '',
        );
    }
  }

  // 1. Push Notification Trigger: Reaction on Feed (Thả cảm xúc)
  void triggerReactionNotification({required String sender}) {
    final txaLang = TXALanguage.instance;
    final title = txaLang.getText('noti_reaction_title');
    final body = txaLang.getText('noti_reaction_body').replaceAll('%sender%', sender);

    _addNotificationLog(type: 'reaction', title: title, body: body);
  }

  // 2. Push Notification Trigger: Direct Message (Ai đó nhắn tin)
  void triggerMessageNotification({
    required String sender,
    required String content,
    String? messageId,
  }) {
    final txaLang = TXALanguage.instance;
    final title = txaLang.getText('noti_message_title');
    final body = txaLang.getText('noti_message_body')
        .replaceAll('%sender%', sender)
        .replaceAll('%content%', content);

    _addNotificationLog(
      type: 'message',
      title: title,
      body: body,
      data: {
        'type': 'message',
        'sender': sender,
        'messageId': messageId,
      },
    );
  }

  // 3. Push Notification Trigger: Feed Reply (Trả lời trên feed)
  void triggerReplyNotification({required String sender}) {
    final txaLang = TXALanguage.instance;
    final title = txaLang.getText('noti_reply_title');
    final body = txaLang.getText('noti_reply_body').replaceAll('%sender%', sender);

    _addNotificationLog(type: 'reply', title: title, body: body);
  }

  // 4. Scheduled Daily Reminders (Sáng sớm & Tối dí deadline)
  void triggerScheduledDeadlineNotification({required bool isMorning}) {
    final txaLang = TXALanguage.instance;
    final title = isMorning
        ? txaLang.getText('noti_morning_title')
        : txaLang.getText('noti_evening_title');
    final body = isMorning
        ? txaLang.getText('noti_morning_body')
        : txaLang.getText('noti_evening_body');

    _addNotificationLog(
      type: isMorning ? 'reminder_morning' : 'reminder_evening',
      title: title,
      body: body,
    );
  }

  void _addNotificationLog({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    final log = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    };

    _notificationLogs.insert(0, log);
    notifyListeners();
  }
}

class _TXANotificationOverlayWidget extends StatefulWidget {
  final UserModel userModel;
  final String type;
  final String content;
  final VoidCallback onDismiss;

  const _TXANotificationOverlayWidget({
    required this.userModel,
    required this.type,
    required this.content,
    required this.onDismiss,
  });

  @override
  State<_TXANotificationOverlayWidget> createState() => _TXANotificationOverlayWidgetState();
}

class _TXANotificationOverlayWidgetState extends State<_TXANotificationOverlayWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _dismiss();
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.userModel.avatar;
    final isUrl = avatar.startsWith('http');
    final avatarColor = int.tryParse(widget.userModel.avatarBgColor) ?? 0xFF607D8B;

    return Positioned(
      top: 50.0 + MediaQuery.of(context).padding.top,
      left: 16.0,
      right: 16.0,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(avatarColor),
                  child: ClipOval(
                    child: isUrl
                        ? SizedBox(width: 40, height: 40, child: TXANetworkImage(url: avatar, fit: BoxFit.cover))
                        : Center(child: Text(avatar, style: const TextStyle(fontSize: 18))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.userModel.displayName ?? widget.userModel.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: _dismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
