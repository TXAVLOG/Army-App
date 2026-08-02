import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as gsiap;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'txa_supabase_service.dart';
import 'txa_chat_service.dart';
import 'txa_language.dart';
import 'txa_streak_service.dart';
import 'txa_config.dart';
import 'txa_logger.dart';
import 'txa_notification_service.dart';
import 'txa_analytics.dart';

class UserModel {
  final String id;
  final String email;
  final String username;
  final String dob;
  final String avatar;
  final String avatarBgColor;
  final String? googlePhotoUrl;
  final bool isGoogleAccount;
  final String createdTime;
  final String role; // 'admin' or 'user'
  final String? lastActive;
  final Map<String, String> monthlyMemories; // { "2026_07": "Chuyến đi Đà Lạt" }
  final String? loveId;
  final String? loverUsername;
  final bool isVipActive;
  final String? displayName;
  final bool isOnline;
  final String? fcmToken;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.dob,
    required this.avatar,
    required this.avatarBgColor,
    this.googlePhotoUrl,
    this.isGoogleAccount = false,
    required this.createdTime,
    this.role = 'user',
    this.lastActive,
    this.monthlyMemories = const {},
    this.loveId,
    this.loverUsername,
    this.isVipActive = false,
    this.displayName,
    this.isOnline = false,
    this.fcmToken,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'dob': dob,
        'avatar': avatar,
        'avatarBgColor': avatarBgColor,
        'googlePhotoUrl': googlePhotoUrl,
        'isGoogleAccount': isGoogleAccount,
        'createdTime': createdTime,
        'role': role,
        'lastActive': lastActive,
        'monthlyMemories': monthlyMemories,
        'loveId': loveId,
        'loverUsername': loverUsername,
        'isVipActive': isVipActive,
        'displayName': displayName,
        'isOnline': isOnline,
        'fcmToken': fcmToken,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final Map<String, String> memories = {};
    try {
      final rawMemories = json['monthlyMemories'];
      if (rawMemories is Map) {
        rawMemories.forEach((k, v) {
          memories[k.toString()] = v.toString();
        });
      }
    } catch (_) {}

    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      dob: json['dob'] ?? '',
      avatar: json['avatar'] ?? '🦊',
      avatarBgColor: json['avatarBgColor'] ?? '0xFFF57C00',
      googlePhotoUrl: json['googlePhotoUrl'],
      isGoogleAccount: json['isGoogleAccount'] ?? false,
      createdTime: json['createdTime'] ?? '',
      role: json['role'] ?? 'user',
      lastActive: json['lastActive'] as String?,
      monthlyMemories: memories,
      loveId: json['loveId'] as String?,
      loverUsername: json['loverUsername'] as String?,
      isVipActive: json['isVipActive'] ?? false,
      displayName: json['displayName'] as String?,
      isOnline: json['isOnline'] ?? false,
      fcmToken: json['fcmToken'] as String?,
    );
  }
}

class TXAAuthService extends ChangeNotifier {
  static final TXAAuthService instance = TXAAuthService._internal();
  TXAAuthService._internal();

  static String? pendingInviteUsername;

  static const String _keyAccounts = 'txa_registered_accounts';
  static const String _keyActiveUser = 'txa_active_user_session';

  UserModel? _currentUser;
  StreamSubscription<List<Map<String, dynamic>>>? _userSubscription;
  Timer? _presenceTimer;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  String? _highlightRequestId;
  String? get highlightRequestId => _highlightRequestId;
  void setHighlightRequestId(String? val) {
    _highlightRequestId = val;
    notifyListeners();
  }

  String _feedGridMode = 'image'; // 'image' or 'thought_bubble'
  String get feedGridMode => _feedGridMode;

  Future<void> setFeedGridMode(String mode) async {
    _feedGridMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('txa_feed_grid_mode', mode);
    notifyListeners();
  }

  static const List<Map<String, String>> presetAvatars = [
    {'emoji': '🦊', 'color': '0xFFF57C00', 'name': 'Cáo cam'},
    {'emoji': '🐯', 'color': '0xFFFFB300', 'name': 'Hổ vàng'},
    {'emoji': '🐼', 'color': '0xFF37474F', 'name': 'Gấu trúc'},
    {'emoji': '🦁', 'color': '0xFFFF8F00', 'name': 'Sư tử'},
    {'emoji': '🦄', 'color': '0xFF8E24AA', 'name': 'Kỳ lân'},
    {'emoji': '⚡', 'color': '0xFF00ACC1', 'name': 'Sét xanh'},
    {'emoji': '🚀', 'color': '0xFF1E88E5', 'name': 'Tên lửa'},
    {'emoji': '💎', 'color': '0xFF00B0FF', 'name': 'Kim cương'},
    {'emoji': '👑', 'color': '0xFFFFC107', 'name': 'Vương miện'},
    {'emoji': '🎯', 'color': '0xFFE53935', 'name': 'Hồng tâm'},
  ];

  Future<void> _syncGooglePhotoUrl() async {
    try {
      await _ensureFirebaseInitialized();
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && firebaseUser.photoURL != null && firebaseUser.photoURL!.isNotEmpty) {
        final newPhotoUrl = firebaseUser.photoURL!;
        if (_currentUser != null && _currentUser!.googlePhotoUrl != newPhotoUrl) {
          final oldPhotoUrl = _currentUser!.googlePhotoUrl;
          final shouldUpdateActiveAvatar = _currentUser!.avatar == oldPhotoUrl;

          final updatedUser = UserModel(
            id: _currentUser!.id,
            email: _currentUser!.email,
            username: _currentUser!.username,
            dob: _currentUser!.dob,
            avatar: shouldUpdateActiveAvatar ? newPhotoUrl : _currentUser!.avatar,
            avatarBgColor: _currentUser!.avatarBgColor,
            googlePhotoUrl: newPhotoUrl,
            isGoogleAccount: true,
            createdTime: _currentUser!.createdTime,
            role: _currentUser!.role,
          );

          // Update local cache
          await _setActiveUser(updatedUser);

          // Update Supabase
          final updates = <String, dynamic>{
            'googlePhotoUrl': newPhotoUrl,
          };
          if (shouldUpdateActiveAvatar) {
            updates['avatar'] = newPhotoUrl;
          }
          await TXASupabaseService.instance.client
              .from('txa_users')
              .update(updates)
              .eq('id', _currentUser!.id);

          // Update local accounts fallback
          final prefs = await SharedPreferences.getInstance();
          final accountsMap = _getStoredAccounts(prefs);
          if (accountsMap.containsKey(_currentUser!.id)) {
            accountsMap[_currentUser!.id]!['user'] = updatedUser.toJson();
            await prefs.setString(_keyAccounts, jsonEncode(accountsMap));
          }

          debugPrint('🔄 Synchronized Google photo URL: $newPhotoUrl');
        }
      }
    } catch (e) {
      debugPrint('Sync Google Photo URL error: $e');
    }
  }

  Future<void> syncFriendsFromFirestore() async {
    final username = _currentUser?.username ?? '';
    if (username.isEmpty) return;

    try {
      final supabase = TXASupabaseService.instance.client;
      final sentData = await supabase
          .from('txa_friend_requests')
          .select()
          .eq('from', username);
          
      final receivedData = await supabase
          .from('txa_friend_requests')
          .select()
          .eq('to', username);

      final Set<String> friendUsernames = {};
      final List<Map<String, dynamic>> newFriends = [];

      void addFriendInfo(String fUsername, String avatar, String avatarColor) {
        if (friendUsernames.contains(fUsername)) return;
        friendUsernames.add(fUsername);
        
        final existingIdx = _friends.indexWhere((f) => f['username'] == fUsername);
        final isBest = existingIdx != -1 ? (_friends[existingIdx]['isBestFriend'] == true) : false;
        final isLover = existingIdx != -1 ? (_friends[existingIdx]['isLover'] == true) : false;

        newFriends.add({
          'id': existingIdx != -1 ? _friends[existingIdx]['id'] : 'txa_${DateTime.now().millisecondsSinceEpoch}_${newFriends.length}',
          'name': fUsername,
          'username': fUsername,
          'avatar': avatar,
          'bgColor': int.tryParse(avatarColor) ?? 0xFF607D8B,
          'isBestFriend': isBest,
          'isLover': isLover,
        });
      }

      for (var row in sentData) {
        final status = row['status'] as String?;
        if (status != null && status.startsWith('accepted')) {
          final toUser = row['to'] as String;
          final toAvatar = row['toAvatar'] as String? ?? '👤';
          final toAvatarColor = row['toAvatarColor'] as String? ?? '0xFF607D8B';
          addFriendInfo(toUser, toAvatar, toAvatarColor);
        }
      }

      for (var row in receivedData) {
        final status = row['status'] as String?;
        if (status != null && status.startsWith('accepted')) {
          final fromUser = row['from'] as String;
          final fromAvatar = row['fromAvatar'] as String? ?? '👤';
          final fromAvatarColor = row['fromAvatarColor'] as String? ?? '0xFF607D8B';
          addFriendInfo(fromUser, fromAvatar, fromAvatarColor);
        }
      }

      _friends.clear();
      _friends.addAll(newFriends);
      await _saveFriendsToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint('Sync friends from Supabase error: $e');
    }
  }

  Future<void> syncUserFromFirestore() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final data = await TXASupabaseService.instance.client
          .from('txa_users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data != null) {
        final updatedUser = UserModel.fromJson(data);
        _currentUser = updatedUser;
        notifyListeners();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyActiveUser, jsonEncode(updatedUser.toJson()));
        
        await syncFriendsFromFirestore();
        
        // Đồng bộ cả streak thực tế từ DB vào StreakService
        await TXAStreakService.instance.syncStreakFromFirestore(updatedUser.username);
      }
    } catch (e) {
      debugPrint('Sync user from Supabase error: $e');
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('txa_feed_grid_mode') ?? 'image';
    _feedGridMode = savedMode;

    final userJsonStr = prefs.getString(_keyActiveUser);
    if (userJsonStr != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userJsonStr));
        if (_currentUser != null) {
          TXAChatService.instance.init(_currentUser!.username);
          updateOnlineStatus(true);
          _startPresenceTimer();
          try {
            TXANotificationService.instance.startListeningNotifications(_currentUser!.username);
          } catch (_) {}
          syncUserFromFirestore();
          _startUserListener();
          startFriendsListener();
        }
        if (_currentUser?.isGoogleAccount == true) {
          _syncGooglePhotoUrl();
        }
      } catch (_) {}
    }

    await _loadFriendsFromPrefs();
    notifyListeners();
  }

  // Register New User
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    required String dob,
    required String avatar,
    required String avatarBgColor,
    String? displayName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim().startsWith('@') ? username.trim() : '@${username.trim()}';

    try {
      final supabase = TXASupabaseService.instance.client;
      
      // Check duplicate email
      final emailQuery = await supabase.from('txa_users').select('id').eq('email', cleanEmail).maybeSingle();
      if (emailQuery != null) {
        return {'success': false, 'errorField': 'email', 'message': TXALanguage.instance.getText('email_in_use_error')};
      }

      // Check duplicate username
      final usernameQuery = await supabase.from('txa_users').select('id').eq('username', cleanUsername).maybeSingle();
      if (usernameQuery != null) {
        return {'success': false, 'errorField': 'username', 'message': TXALanguage.instance.getText('username_exists_error')};
      }

      final newUserId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final newUser = UserModel(
        id: newUserId,
        email: cleanEmail,
        username: cleanUsername,
        dob: dob,
        avatar: avatar,
        avatarBgColor: avatarBgColor,
        createdTime: DateTime.now().toIso8601String(),
        role: 'user',
        displayName: displayName,
      );

      // Save to Supabase
      await supabase.from('txa_users').insert({
        ...newUser.toJson(),
        'password': password,
      });

      // Save to local fallback SharedPreferences
      await _saveAccountToPrefs(newUser, password);
      await _setActiveUser(newUser);

      return {'success': true, 'user': newUser};
    } catch (e) {
      debugPrint('Supabase register error: $e');
      return {'success': false, 'message': 'Lỗi đăng ký: $e'};
    }
  }

  // Login User
  Future<Map<String, dynamic>> login({
    required String identity, // Email or Username
    required String password,
  }) async {
    final cleanIdentity = identity.trim().toLowerCase();

    try {
      final supabase = TXASupabaseService.instance.client;
      final List<dynamic> users = await supabase
          .from('txa_users')
          .select()
          .or('email.ilike.$cleanIdentity,username.ilike.$cleanIdentity,username.ilike.@$cleanIdentity');

      if (users.isNotEmpty) {
        final data = users.first as Map<String, dynamic>;
        final storedPassword = data['password']?.toString();
        if (storedPassword == password) {
          final user = UserModel.fromJson(data);
          await _setActiveUser(user);
          try {
            TXAAnalytics.logLogin(loginMethod: 'email_username');
          } catch (_) {}
          return {'success': true, 'user': user};
        } else {
          return {'success': false, 'errorField': 'password', 'message': TXALanguage.instance.getText('incorrect_password_error')};
        }
      }
    } catch (e) {
      debugPrint('Supabase login error: $e. Falling back to SharedPreferences.');
    }

    // Fallback to local accounts
    final prefs = await SharedPreferences.getInstance();
    final accountsMap = _getStoredAccounts(prefs);

    for (var entry in accountsMap.entries) {
      final acc = entry.value;
      final storedEmail = acc['email'].toString().toLowerCase();
      final storedUsername = acc['username'].toString().toLowerCase();
      final storedPassword = acc['password'].toString();

      if (storedEmail == cleanIdentity || storedUsername == cleanIdentity || storedUsername == '@$cleanIdentity') {
        if (storedPassword == password) {
          final user = UserModel.fromJson(acc['user']);
          await _setActiveUser(user);
          try {
            TXAAnalytics.logLogin(loginMethod: 'email_username_local');
          } catch (_) {}
          return {'success': true, 'user': user};
        } else {
          return {'success': false, 'errorField': 'password', 'message': TXALanguage.instance.getText('incorrect_password_error')};
        }
      }
    }

    return {'success': false, 'errorField': 'identity', 'message': TXALanguage.instance.getText('account_not_found_error')};
  }

  /// Username Generator: 3 prefix chars + 7 alphanumeric characters (total length <= 12 with '@')
  static String generateShortGoogleUsername(String displayName, String email, String uid) {
    String raw = displayName.isNotEmpty ? displayName : (email.contains('@') ? email.split('@').first : email);
    raw = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (raw.isEmpty) raw = 'usr';

    final prefix = raw.length >= 3 ? raw.substring(0, 3) : raw.padRight(3, 'x');
    
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffixList = List.generate(7, (index) => chars[rand.nextInt(chars.length)]);
    final suffix = suffixList.join('');
    
    return '@$prefix$suffix';
  }

  Future<void> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: TXAConfig.currentFirebaseOptions,
        );
      }
    } catch (_) {}
  }

  // Login With Google (REAL GoogleSignIn and FirebaseAuth authentication pipeline)
  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      await _ensureFirebaseInitialized();

      String userEmail = '';
      String displayName = '';
      String googleId = '';
      String? photoUrl;

      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        // Xóa cache phiên cũ → luôn mở bảng chọn tài khoản Google
        try { await _getDesktopSignIn.signOut(); } catch (_) {}
        final googleCred = await _getDesktopSignIn.signIn();
        if (googleCred == null) {
          return {'success': false, 'message': TXALanguage.instance.getText('google_login_cancelled')};
        }

        final idToken = googleCred.idToken;
        final accessToken = googleCred.accessToken;

        if (idToken != null && idToken.isNotEmpty) {
          try {
            final parts = idToken.split('.');
            if (parts.length == 3) {
              final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
              final Map<String, dynamic> data = jsonDecode(payload);
              userEmail = data['email'] ?? '';
              displayName = data['name'] ?? '';
              googleId = data['sub'] ?? '';
              photoUrl = data['picture'];
            }
          } catch (_) {}

          try {
            final OAuthCredential credential = GoogleAuthProvider.credential(
              idToken: idToken,
              accessToken: accessToken,
            );

            final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            final user = userCredential.user;

            if (user != null) {
              userEmail = user.email ?? userEmail;
              displayName = user.displayName ?? displayName;
              googleId = user.uid;
              photoUrl = user.photoURL ?? photoUrl;
            }
          } catch (fbErr) {
            debugPrint('Firebase Auth credential info on Windows (fallback to Google Session): $fbErr');
          }
        }
      } else if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        final user = userCredential.user;

        if (user == null) {
          return {'success': false, 'message': TXALanguage.instance.getText('google_account_error')};
        }

        userEmail = user.email ?? '';
        displayName = user.displayName ?? '';
        googleId = user.uid;
        photoUrl = user.photoURL;
      } else {
        // Mobile (Android / iOS) Native Google Sign-In
        try {
          await GoogleSignIn.instance.initialize(serverClientId: TXAConfig.googleWebClientId);
        } catch (_) {}

        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final user = userCredential.user;

        if (user == null) {
          return {'success': false, 'message': TXALanguage.instance.getText('google_auth_failed')};
        }

        userEmail = user.email ?? googleUser.email;
        displayName = user.displayName ?? googleUser.displayName ?? '';
        googleId = user.uid;
        photoUrl = user.photoURL ?? googleUser.photoUrl;
      }

      final supabase = TXASupabaseService.instance.client;
      final docSnap = await supabase
          .from('txa_users')
          .select()
          .eq('id', 'user_google_$googleId')
          .maybeSingle();

      UserModel googleUserAccount;
      if (docSnap != null) {
        googleUserAccount = UserModel.fromJson(docSnap);
        // Cập nhật googlePhotoUrl và displayName nếu có thay đổi từ Google OAuth
        await supabase.from('txa_users').update({
          'googlePhotoUrl': photoUrl ?? googleUserAccount.googlePhotoUrl ?? 'https://lh3.googleusercontent.com/a/default-user',
          'displayName': displayName.isNotEmpty ? displayName : googleUserAccount.displayName,
        }).eq('id', googleUserAccount.id);
        // Tải lại để lấy dữ liệu mới nhất
        final updatedDoc = await supabase.from('txa_users').select().eq('id', googleUserAccount.id).single();
        googleUserAccount = UserModel.fromJson(updatedDoc);
      } else {
        final cleanUsername = generateShortGoogleUsername(displayName, userEmail, googleId);
        googleUserAccount = UserModel(
          id: 'user_google_$googleId',
          email: userEmail.isEmpty ? 'user@gmail.com' : userEmail,
          username: cleanUsername,
          dob: '19/10/2000',
          avatar: '🦊',
          avatarBgColor: '0xFFF57C00',
          googlePhotoUrl: photoUrl ?? 'https://lh3.googleusercontent.com/a/default-user',
          isGoogleAccount: true,
          createdTime: DateTime.now().toIso8601String(),
          role: 'user',
          displayName: displayName,
        );

        await supabase.from('txa_users').insert({
          ...googleUserAccount.toJson(),
          'password': 'google_oauth_bypass',
        });
      }

      await _setActiveUser(googleUserAccount);
      try {
        TXAAnalytics.logLogin(loginMethod: 'google');
      } catch (_) {}
      return {'success': true, 'user': googleUserAccount};
    } catch (e, stack) {
      TXALogger.logError(
        e,
        stackTrace: stack,
        extraInfo: {
          'feature': 'Google Sign-In Authentication',
          'platform': kIsWeb ? 'Web' : Platform.operatingSystem,
        },
      );

      final txaLang = TXALanguage.instance;
      final errStr = e.toString();
      final errStrLower = errStr.toLowerCase();
      if (errStrLower.contains('cancelled') || errStrLower.contains('canceled') || errStrLower.contains('12501')) {
        return {'success': false, 'message': txaLang.getText('google_login_cancelled')};
      }
      if (errStr.contains('clientConfigurationError') || errStr.contains('serverClientId')) {
        return {'success': false, 'message': txaLang.getText('google_client_config_error')};
      }
      return {'success': false, 'message': txaLang.getText('google_login_error').replaceFirst('%error%', errStr)};
    }
  }

  // Get all users (Admin only)
  Future<List<UserModel>> getAllUsersFromFirestore() async {
    try {
      final data = await TXASupabaseService.instance.client.from('txa_users').select();
      return data
          .where((row) => row['username'] != null && row['username'].toString().isNotEmpty)
          .map((row) => UserModel.fromJson(row))
          .toList();
    } catch (e) {
      debugPrint('getAllUsersFromFirestore error: $e');
      return [];
    }
  }

  // Delete user (Admin only)
  Future<void> deleteUserFromFirestore(String userId) async {
    try {
      await TXASupabaseService.instance.client.from('txa_users').delete().eq('id', userId);
    } catch (e) {
      debugPrint('deleteUserFromFirestore error: $e');
    }
  }

  // Update user avatar & background color
  Future<void> updateAvatar(String newAvatar, String newColorHex) async {
    if (_currentUser == null) return;
    final updatedUser = UserModel(
      id: _currentUser!.id,
      email: _currentUser!.email,
      username: _currentUser!.username,
      dob: _currentUser!.dob,
      avatar: newAvatar,
      avatarBgColor: newColorHex,
      googlePhotoUrl: _currentUser!.googlePhotoUrl,
      isGoogleAccount: _currentUser!.isGoogleAccount,
      createdTime: _currentUser!.createdTime,
      role: _currentUser!.role,
    );

    // Update local cache
    await _setActiveUser(updatedUser);

    // Update database
    try {
      await TXASupabaseService.instance.client.from('txa_users').update({
        'avatar': newAvatar,
        'avatarBgColor': newColorHex,
      }).eq('id', _currentUser!.id);

      // Update local accounts fallback
      final prefs = await SharedPreferences.getInstance();
      final accountsMap = _getStoredAccounts(prefs);
      if (accountsMap.containsKey(_currentUser!.id)) {
        accountsMap[_currentUser!.id]!['user'] = updatedUser.toJson();
        await prefs.setString(_keyAccounts, jsonEncode(accountsMap));
      }
    } catch (e) {
      debugPrint('Update avatar DB error: $e');
    }
  }

  Future<void> logout() async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    if (_currentUser != null) {
      await updateOnlineStatus(false);
    }
    _userSubscription?.cancel();
    cancelFriendsListener();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveUser);
    try {
      TXANotificationService.instance.stopListeningNotifications();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateOnlineStatus(bool online) async {
    if (_currentUser == null) return;
    final nowStr = DateTime.now().toIso8601String();
    
    _currentUser = UserModel(
      id: _currentUser!.id,
      email: _currentUser!.email,
      username: _currentUser!.username,
      dob: _currentUser!.dob,
      avatar: _currentUser!.avatar,
      avatarBgColor: _currentUser!.avatarBgColor,
      googlePhotoUrl: _currentUser!.googlePhotoUrl,
      isGoogleAccount: _currentUser!.isGoogleAccount,
      createdTime: _currentUser!.createdTime,
      role: _currentUser!.role,
      lastActive: nowStr,
      monthlyMemories: _currentUser!.monthlyMemories,
      loveId: _currentUser!.loveId,
      loverUsername: _currentUser!.loverUsername,
      isVipActive: _currentUser!.isVipActive,
      displayName: _currentUser!.displayName,
      isOnline: online,
      fcmToken: _currentUser!.fcmToken,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveUser, jsonEncode(_currentUser!.toJson()));

    try {
      await TXASupabaseService.instance.client.from('txa_users').update({
        'isOnline': online,
        'lastActive': nowStr,
      }).eq('id', _currentUser!.id);
    } catch (e) {
      debugPrint('updateOnlineStatus Supabase error: $e');
    }
  }

  void _startPresenceTimer() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      updateOnlineStatus(true);
    });
  }

  Future<void> updateLastActive() async {
    await updateOnlineStatus(true);
  }

  Stream<UserModel?> listenToUser(String username) {
    return TXASupabaseService.instance.client
        .from('txa_users')
        .stream(primaryKey: ['id'])
        .eq('username', username)
        .limit(1)
        .map((rows) {
          if (rows.isEmpty) return null;
          return UserModel.fromJson(rows.first);
        });
  }

  void _startUserListener() {
    _userSubscription?.cancel();
    final user = _currentUser;
    if (user == null) return;
    
    _userSubscription = TXASupabaseService.instance.client
        .from('txa_users')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((rows) async {
      if (rows.isNotEmpty) {
        final updatedUser = UserModel.fromJson(rows.first);
        _currentUser = updatedUser;
        notifyListeners();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyActiveUser, jsonEncode(updatedUser.toJson()));
        
        // Rebuild friends list when user doc changes (e.g. bestFriends list updated)
        _rebuildFriendsListRealtime();
      }
    });
  }

  Future<void> _setActiveUser(UserModel user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveUser, jsonEncode(user.toJson()));
    TXAAnalytics.logEvent('login');
    TXAChatService.instance.init(user.username);
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await TXASupabaseService.instance.client.from('txa_users').update({
          'fcmToken': token,
        }).eq('id', user.id);
      }
    } catch (_) {}
    await updateOnlineStatus(true);
    _startPresenceTimer();
    try {
      TXANotificationService.instance.startListeningNotifications(user.username);
    } catch (_) {}
    notifyListeners();
    _startUserListener();
    startFriendsListener();
  }

  Map<String, Map<String, dynamic>> _getStoredAccounts(SharedPreferences prefs) {
    final rawStr = prefs.getString(_keyAccounts);
    if (rawStr == null) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(rawStr);
      return decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAccountToPrefs(UserModel user, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _getStoredAccounts(prefs);
    map[user.id] = {
      'user': user.toJson(),
      'email': user.email,
      'username': user.username,
      'password': password,
    };
    await prefs.setString(_keyAccounts, jsonEncode(map));
  }

  static const String _keyFriendsList = 'txa_friends_database';

  final List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> get friendsList => List.unmodifiable(_friends);
  List<Map<String, dynamic>> get bestFriendsList => _friends.where((f) => f['isBestFriend'] == true).toList();
  List<Map<String, dynamic>> get loversList => _friends.where((f) => f['isLover'] == true).toList();

  Future<void> _loadFriendsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJsonStr = prefs.getString(_keyFriendsList);

    if (rawJsonStr != null) {
      try {
        final List<dynamic> list = jsonDecode(rawJsonStr);
        _friends.clear();
        _friends.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }

    // Xóa mock friends cũ (id bắt đầu bằng 'f_') đã seed từ session trước
    final hadMock = _friends.any((f) => (f['id'] as String?)?.startsWith('f_') == true);
    if (hadMock) {
      _friends.removeWhere((f) => (f['id'] as String?)?.startsWith('f_') == true);
      await _saveFriendsToPrefs();
      debugPrint('🧹 Cleared ${_friends.length} remaining after removing mock friends');
    }

    // Danh sách bạn bè trống khi mới tạo tài khoản — người dùng tự thêm
  }

  Future<void> toggleBestFriend(String friendId) async {
    final index = _friends.indexWhere((f) => f['id'] == friendId);
    if (index != -1) {
      final friendUsername = _friends[index]['username'] as String;
      final current = _friends[index]['isBestFriend'] == true;

      final supabase = TXASupabaseService.instance.client;
      final userDoc = await supabase.from('txa_users').select('bestFriends').eq('id', _currentUser!.id).maybeSingle();
      if (userDoc != null) {
        final List<dynamic> bestFriendsListRaw = userDoc['bestFriends'] ?? [];
        final List<String> bestFriends = bestFriendsListRaw.map((e) => e.toString()).toList();
        if (current) {
          bestFriends.remove(friendUsername);
        } else {
          if (!bestFriends.contains(friendUsername)) {
            bestFriends.add(friendUsername);
          }
        }
        await supabase.from('txa_users').update({'bestFriends': bestFriends}).eq('id', _currentUser!.id);
      }
    }
  }

  Future<void> _saveFriendsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFriendsList, jsonEncode(_friends));
  }

  StreamSubscription<List<Map<String, dynamic>>>? _sentFriendsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _receivedFriendsSub;

  void startFriendsListener() {
    _sentFriendsSub?.cancel();
    _receivedFriendsSub?.cancel();

    final username = _currentUser?.username ?? '';
    if (username.isEmpty) return;

    final supabase = TXASupabaseService.instance.client;

    _sentFriendsSub = supabase
        .from('txa_friend_requests')
        .stream(primaryKey: ['id'])
        .eq('from', username)
        .listen((snap) {
      _rebuildFriendsListRealtime();
    });

    _receivedFriendsSub = supabase
        .from('txa_friend_requests')
        .stream(primaryKey: ['id'])
        .eq('to', username)
        .listen((snap) {
      _rebuildFriendsListRealtime();
    });
  }

  void cancelFriendsListener() {
    _sentFriendsSub?.cancel();
    _sentFriendsSub = null;
    _receivedFriendsSub?.cancel();
    _receivedFriendsSub = null;
  }

  Future<void> _rebuildFriendsListRealtime() async {
    final username = _currentUser?.username ?? '';
    if (username.isEmpty) return;

    try {
      final supabase = TXASupabaseService.instance.client;

      final sentData = await supabase
          .from('txa_friend_requests')
          .select()
          .eq('from', username);

      final receivedData = await supabase
          .from('txa_friend_requests')
          .select()
          .eq('to', username);

      final userDoc = await supabase.from('txa_users').select('bestFriends').eq('id', _currentUser!.id).maybeSingle();
      final List<dynamic> bestFriendsListRaw = userDoc?['bestFriends'] ?? [];
      final Set<String> bestFriends = bestFriendsListRaw.map((e) => e.toString()).toSet();

      final Set<String> friendUsernames = {};
      final List<Map<String, dynamic>> newFriends = [];

      void addFriendInfo(String fUsername, String avatar, String avatarColor) {
        if (friendUsernames.contains(fUsername)) return;
        friendUsernames.add(fUsername);

        final isBest = bestFriends.contains(fUsername);
        final isLover = _currentUser?.loverUsername == fUsername;

        newFriends.add({
          'id': 'txa_${fUsername}_${DateTime.now().millisecondsSinceEpoch}',
          'name': fUsername,
          'username': fUsername,
          'avatar': avatar,
          'bgColor': int.tryParse(avatarColor) ?? 0xFF607D8B,
          'isBestFriend': isBest,
          'isLover': isLover,
        });
      }

      for (var row in sentData) {
        final status = row['status'] as String?;
        if (status != null && status.startsWith('accepted')) {
          final toUser = row['to'] as String;
          final toAvatar = row['toAvatar'] as String? ?? '👤';
          final toAvatarColor = row['toAvatarColor'] as String? ?? '0xFF607D8B';
          addFriendInfo(toUser, toAvatar, toAvatarColor);
        }
      }

      for (var row in receivedData) {
        final status = row['status'] as String?;
        if (status != null && status.startsWith('accepted')) {
          final fromUser = row['from'] as String;
          final fromAvatar = row['fromAvatar'] as String? ?? '👤';
          final fromAvatarColor = row['fromAvatarColor'] as String? ?? '0xFF607D8B';
          addFriendInfo(fromUser, fromAvatar, fromAvatarColor);
        }
      }

      _friends.clear();
      _friends.addAll(newFriends);
      await _saveFriendsToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint('Rebuild friends list error: $e');
    }
  }

  // ─── Friend Requests (Firestore) ──────────────────────────────────────────

  /// Lắng nghe lời mời kết bạn đến cho user hiện tại (realtime)
  Stream<List<Map<String, dynamic>>> listenIncomingRequests() {
    final username = _currentUser?.username ?? '';
    if (username.isEmpty) return const Stream.empty();
    return TXASupabaseService.instance.client
        .from('txa_friend_requests')
        .stream(primaryKey: ['id'])
        .eq('to', username)
        .map((rows) => rows.where((row) => row['status'] == 'pending').toList());
  }

  /// Gửi lời mời kết bạn theo username
  Future<Map<String, dynamic>> sendFriendRequest(String toUsername) async {
    final fromUsername = _currentUser?.username ?? '';
    final txaLang = TXALanguage.instance;
    if (fromUsername.isEmpty) return {'success': false, 'message': txaLang.getText('not_logged_in_error')};
    if (toUsername == fromUsername) return {'success': false, 'message': txaLang.getText('cannot_friend_self')};

    final supabase = TXASupabaseService.instance.client;

    // Kiểm tra user tồn tại
    final userSnap = await supabase
        .from('txa_users')
        .select()
        .eq('username', toUsername)
        .maybeSingle();
    if (userSnap == null) {
      return {'success': false, 'message': txaLang.getText('friend_not_found').replaceFirst('%user%', toUsername)};
    }

    // Kiểm tra đã là bạn chưa
    final alreadyFriend = _friends.any((f) => f['username'] == toUsername);
    if (alreadyFriend) return {'success': false, 'message': txaLang.getText('already_friends')};

    // Kiểm tra đã có request pending chưa
    final existing = await supabase
        .from('txa_friend_requests')
        .select()
        .eq('from', fromUsername)
        .eq('to', toUsername)
        .eq('status', 'pending');
    if (existing.isNotEmpty) return {'success': false, 'message': txaLang.getText('friend_request_already_sent')};

    await supabase.from('txa_friend_requests').insert({
      'from': fromUsername,
      'fromAvatar': _currentUser?.avatar ?? '👤',
      'fromAvatarColor': _currentUser?.avatarBgColor ?? '0xFF607D8B',
      'to': toUsername,
      'toAvatar': userSnap['avatar'] ?? '👤',
      'status': 'pending',
      'createdTime': DateTime.now().toIso8601String(),
    });
    return {'success': true, 'message': txaLang.getText('friend_request_sent_to').replaceFirst('%user%', toUsername)};
  }

  /// Chấp nhận lời mời kết bạn
  Future<void> acceptFriendRequest(String requestId, Map<String, dynamic> requestData) async {
    final supabase = TXASupabaseService.instance.client;
    final fromUsername = requestData['from'] as String;
    final fromAvatar = requestData['fromAvatar'] as String? ?? '👤';
    final fromAvatarColor = requestData['fromAvatarColor'] as String? ?? '0xFF607D8B';

    // Thêm vào danh sách bạn bè local
    final newFriend = {
      'id': 'txa_${DateTime.now().millisecondsSinceEpoch}',
      'name': fromUsername,
      'username': fromUsername,
      'avatar': fromAvatar,
      'bgColor': int.tryParse(fromAvatarColor) ?? 0xFF607D8B,
      'isBestFriend': false,
      'isLover': false,
    };
    _friends.add(newFriend);
    await _saveFriendsToPrefs();

    // Cập nhật status request
    await supabase.from('txa_friend_requests').update({'status': 'accepted'}).eq('id', requestId);

    // Gửi ngược lại request accepted cho bên kia
    final toUsername = _currentUser?.username ?? '';
    await supabase.from('txa_friend_requests').insert({
      'from': toUsername,
      'fromAvatar': _currentUser?.avatar ?? '👤',
      'fromAvatarColor': _currentUser?.avatarBgColor ?? '0xFF607D8B',
      'to': fromUsername,
      'toAvatar': fromAvatar,
      'status': 'accepted_auto',
      'createdTime': DateTime.now().toIso8601String(),
    });

    notifyListeners();
  }

  /// Từ chối lời mời kết bạn
  Future<void> declineFriendRequest(String requestId) async {
    await TXASupabaseService.instance.client
        .from('txa_friend_requests')
        .update({'status': 'declined'})
        .eq('id', requestId);
  }

  /// Thêm đối phương vào danh sách bạn bè local của mình khi họ đã đồng ý (chạy realtime)
  Future<void> addFriendLocally({
    required String username,
    required String avatar,
    required String avatarColor,
  }) async {
    final exists = _friends.any((f) => f['username'] == username);
    if (exists) return;

    final newFriend = {
      'id': 'txa_${DateTime.now().millisecondsSinceEpoch}',
      'name': username,
      'username': username,
      'avatar': avatar,
      'bgColor': int.tryParse(avatarColor) ?? 0xFF607D8B,
      'isBestFriend': false,
      'isLover': false,
    };
    _friends.add(newFriend);
    await _saveFriendsToPrefs();
    notifyListeners();
  }

  /// Lắng nghe lời mời kết bạn do user hiện tại gửi đi (realtime)
  Stream<List<Map<String, dynamic>>> listenSentRequests() {
    final username = _currentUser?.username ?? '';
    if (username.isEmpty) return const Stream.empty();
    return TXASupabaseService.instance.client
        .from('txa_friend_requests')
        .stream(primaryKey: ['id'])
        .eq('from', username)
        .map((rows) => rows.where((row) => row['status'] == 'pending').toList());
  }

  /// Hủy yêu cầu kết bạn đã gửi
  Future<void> cancelFriendRequest(String requestId) async {
    await TXASupabaseService.instance.client
        .from('txa_friend_requests')
        .delete()
        .eq('id', requestId);
  }

  /// Xóa bạn bè
  Future<void> removeFriend(String friendId) async {
    _friends.removeWhere((f) => f['id'] == friendId);
    await _saveFriendsToPrefs();
    notifyListeners();
  }

  /// (Admin only) Thêm bạn ngay lập tức
  Future<void> addFriendInstantly(UserModel targetUser) async {
    final exists = _friends.any((f) => f['username'] == targetUser.username);
    if (exists) return;

    final newFriend = {
      'id': 'txa_${DateTime.now().millisecondsSinceEpoch}',
      'name': targetUser.username,
      'username': targetUser.username,
      'avatar': targetUser.avatar,
      'bgColor': int.tryParse(targetUser.avatarBgColor) ?? 0xFF607D8B,
      'isBestFriend': false,
      'isLover': false,
    };
    _friends.add(newFriend);
    await _saveFriendsToPrefs();

    try {
      // Sync sang Supabase để cả 2 bên hiển thị
      await TXASupabaseService.instance.client.from('txa_friend_requests').insert({
        'from': _currentUser?.username ?? 'admin',
        'fromAvatar': _currentUser?.avatar ?? '👤',
        'fromAvatarColor': _currentUser?.avatarBgColor ?? '0xFF607D8B',
        'to': targetUser.username,
        'toAvatar': targetUser.avatar,
        'status': 'accepted',
        'createdTime': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    notifyListeners();
  }

  /// (Admin only) Xóa bạn ngay lập tức theo username
  Future<void> deleteFriendInstantly(String targetUsername) async {
    _friends.removeWhere((f) => f['username'] == targetUsername);
    await _saveFriendsToPrefs();

    try {
      final myUsername = _currentUser?.username ?? 'admin';
      final supabase = TXASupabaseService.instance.client;
      await supabase.from('txa_friend_requests').delete().eq('from', myUsername).eq('to', targetUsername);
      await supabase.from('txa_friend_requests').delete().eq('from', targetUsername).eq('to', myUsername);
    } catch (_) {}

    notifyListeners();
  }

  /// (Admin/User) Cập nhật thứ tự sắp xếp bạn bè
  Future<void> updateFriendOrder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _friends.length) return;
    if (newIndex < 0 || newIndex >= _friends.length) return;

    final item = _friends.removeAt(oldIndex);
    _friends.insert(newIndex, item);
    await _saveFriendsToPrefs();
    notifyListeners();
  }

  /// Tính điểm ưu tiên sắp xếp của bạn bè
  int getFriendPriorityScore(String username) {
    if (username == _currentUser?.username) {
      return 5000;
    }
    final idx = _friends.indexWhere((f) => f['username'] == username);
    if (idx != -1) {
      final f = _friends[idx];
      if (f['isBestFriend'] == true) {
        return 1000 + idx;
      }
      if (f['isLover'] == true) {
        return 2000 + idx;
      }
      return 3000 + idx;
    }
    return 4000;
  }

  // Custom HTML post-auth setup
  static const String _kPostAuthHtml = '''
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Army - Đăng nhập thành công</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #0f0f1a 0%, #1a1a2e 50%, #16213e 100%);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      color: #fff;
    }
    .card {
      text-align: center;
      padding: 48px 56px;
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 24px;
      backdrop-filter: blur(20px);
      box-shadow: 0 32px 80px rgba(0,0,0,0.5);
    }
    .heart { font-size: 56px; margin-bottom: 16px; animation: pulse 1.5s infinite; }
    @keyframes pulse {
      0%, 100% { transform: scale(1); }
      50% { transform: scale(1.15); }
    }
    h1 { font-size: 24px; font-weight: 700; margin-bottom: 8px; }
    p { font-size: 15px; color: rgba(255,255,255,0.55); margin-bottom: 28px; }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: rgba(66,133,244,0.15);
      border: 1px solid rgba(66,133,244,0.3);
      border-radius: 999px;
      padding: 8px 20px;
      font-size: 14px;
      color: #74a7ff;
    }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: #4ade80; animation: blink 1s infinite; }
    @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.2; } }
  </style>
</head>
<body>
  <div class="card">
    <div class="heart">💛</div>
    <h1>Đăng nhập thành công!</h1>
    <p>Quay lại ứng dụng Army, cửa sổ này sẽ tự đóng...</p>
    <div class="badge">
      <div class="dot"></div>
      Đã kết nối Army ✓
    </div>
  </div>
  <script>
    window.history.replaceState({}, 'Army', '/');
    setTimeout(() => window.close(), 2000);
  </script>
</body>
</html>
''';

  static gsiap.GoogleSignIn? _desktopGoogleSignIn;
  static gsiap.GoogleSignIn get _getDesktopSignIn {
    _desktopGoogleSignIn ??= gsiap.GoogleSignIn(
      params: gsiap.GoogleSignInParams(
        clientId: TXAConfig.googleWebClientId,
        clientSecret: TXAConfig.googleWebClientSecret,
        customPostAuthPage: _kPostAuthHtml,
        redirectPort: 3636, // http://localhost:3636 — đã add vào Google Cloud Console
        scopes: const [
          'openid',
          'https://www.googleapis.com/auth/userinfo.profile',
          'https://www.googleapis.com/auth/userinfo.email',
        ],
      ),
    );
    return _desktopGoogleSignIn!;
  }

  /// Cập nhật tên kỷ niệm tháng của người dùng lên Firestore
  Future<void> updateMonthlyMemory(String yearMonthKey, String title) async {
    final user = _currentUser;
    if (user == null) return;

    final Map<String, String> newMemories = Map.from(user.monthlyMemories);
    if (title.isEmpty) {
      newMemories.remove(yearMonthKey);
    } else {
      newMemories[yearMonthKey] = title;
    }

    final updatedUser = UserModel(
      id: user.id,
      email: user.email,
      username: user.username,
      dob: user.dob,
      avatar: user.avatar,
      avatarBgColor: user.avatarBgColor,
      googlePhotoUrl: user.googlePhotoUrl,
      isGoogleAccount: user.isGoogleAccount,
      createdTime: user.createdTime,
      role: user.role,
      lastActive: user.lastActive,
      monthlyMemories: newMemories,
    );

    _currentUser = updatedUser;
    notifyListeners();

    try {
      await TXASupabaseService.instance.client
          .from('txa_users')
          .update({
            'monthlyMemories': newMemories,
          })
          .eq('id', user.id);
    } catch (_) {}
  }

  // ─── LOVE FEATURE METHODS ────────────────────────────────────────────────

  /// Lắng nghe lời mời yêu đến cho user hiện tại (realtime)
  Stream<List<Map<String, dynamic>>> listenIncomingLoveRequests() {
    final username = _currentUser?.username ?? '';
    if (username.isEmpty) return const Stream.empty();
    return TXASupabaseService.instance.client
        .from('txa_love_invitations')
        .stream(primaryKey: ['id'])
        .eq('receiver', username)
        .map((rows) => rows.where((row) => row['status'] == 'pending').toList());
  }

  /// Lắng nghe lời mời yêu đã gửi đi (realtime)
  Stream<List<Map<String, dynamic>>> listenSentLoveRequests() {
    final username = _currentUser?.username ?? '';
    if (username.isEmpty) return const Stream.empty();
    return TXASupabaseService.instance.client
        .from('txa_love_invitations')
        .stream(primaryKey: ['id'])
        .eq('sender', username)
        .map((rows) => rows.where((row) => row['status'] == 'pending').toList());
  }

  /// Lắng nghe thông tin kết đôi (loves)
  Stream<Map<String, dynamic>?> listenToLoveConnection(String loveId) {
    if (loveId.isEmpty) return Stream.value(null);
    return TXASupabaseService.instance.client
        .from('txa_loves')
        .stream(primaryKey: ['id'])
        .eq('id', loveId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  /// Đồng bộ user từ database về local
  Future<void> syncCurrentUserFromFirestore() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final snap = await TXASupabaseService.instance.client.from('txa_users').select().eq('id', user.id).maybeSingle();
      if (snap != null) {
        final updated = UserModel.fromJson(snap);
        await _setActiveUser(updated);
      }
    } catch (e) {
      debugPrint('syncCurrentUserFromSupabase error: $e');
    }
  }

  /// Gửi lời mời yêu
  Future<Map<String, dynamic>> sendLoveInvitation(String targetUsername, String startDate) async {
    final fromUsername = _currentUser?.username ?? '';
    final txaLang = TXALanguage.instance;
    if (fromUsername.isEmpty) return {'success': false, 'message': txaLang.getText('not_logged_in_error')};
    if (targetUsername == fromUsername) {
      return {'success': false, 'message': txaLang.getText('love_cannot_couple_self')};
    }

    // 1. Kiểm tra bản thân đã có người yêu hay chưa
    if (_currentUser?.loveId != null || _currentUser?.loverUsername != null) {
      return {'success': false, 'message': txaLang.getText('love_you_already_coupled')};
    }

    try {
      final supabase = TXASupabaseService.instance.client;

      // 2. Kiểm tra xem có lời mời yêu pending nào khác liên quan đến mình không
      final myPendingSent = await supabase
          .from('txa_love_invitations')
          .select()
          .eq('sender', fromUsername)
          .eq('status', 'pending');
      final myPendingReceived = await supabase
          .from('txa_love_invitations')
          .select()
          .eq('receiver', fromUsername)
          .eq('status', 'pending');

      if (myPendingSent.isNotEmpty || myPendingReceived.isNotEmpty) {
        return {
          'success': false,
          'message': txaLang.getText('love_you_have_pending')
        };
      }

      // 3. Kiểm tra user đối phương tồn tại
      final userSnap = await supabase
          .from('txa_users')
          .select()
          .eq('username', targetUsername)
          .maybeSingle();
      if (userSnap == null) {
        return {
          'success': false,
          'message': txaLang.getText('love_user_not_found').replaceFirst('%user%', targetUsername)
        };
      }

      final targetLoveId = userSnap['loveId'] as String?;
      final targetLoverUsername = userSnap['loverUsername'] as String?;

      if (targetLoveId != null || targetLoverUsername != null) {
        return {
          'success': false,
          'message': txaLang.getText('love_user_already_coupled').replaceFirst('%user%', targetUsername)
        };
      }

      // 4. Kiểm tra đối phương có đang có lời mời yêu pending nào khác không
      final targetPendingSent = await supabase
          .from('txa_love_invitations')
          .select()
          .eq('sender', targetUsername)
          .eq('status', 'pending');
      final targetPendingReceived = await supabase
          .from('txa_love_invitations')
          .select()
          .eq('receiver', targetUsername)
          .eq('status', 'pending');

      if (targetPendingSent.isNotEmpty || targetPendingReceived.isNotEmpty) {
        return {
          'success': false,
          'message': txaLang.getText('love_user_has_pending').replaceFirst('%user%', targetUsername)
        };
      }

      // 5. Thỏa mãn hết các điều kiện -> Tiến hành gửi lời mời yêu
      await supabase.from('txa_love_invitations').insert({
        'sender': fromUsername,
        'receiver': targetUsername,
        'status': 'pending',
        'startDate': startDate,
        'createdTime': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': txaLang.getText('love_invite_sent_success_to').replaceFirst('%user%', targetUsername)
      };
    } catch (e) {
      return {
        'success': false,
        'message': txaLang.getText('love_invite_send_error').replaceFirst('%error%', e.toString())
      };
    }
  }

  /// Chấp nhận lời mời yêu
  Future<Map<String, dynamic>> acceptLoveInvitation(
      String invitationId, String senderUsername, String startDate) async {
    final myUsername = _currentUser?.username ?? '';
    final txaLang = TXALanguage.instance;
    if (myUsername.isEmpty) return {'success': false, 'message': txaLang.getText('not_logged_in_error')};

    try {
      final supabase = TXASupabaseService.instance.client;

      // 1. Tạo ID kết đôi duy nhất (sắp xếp alphabet)
      final sortedUsernames = [myUsername, senderUsername]..sort();
      final loveId = 'love_${sortedUsernames[0]}_${sortedUsernames[1]}';

      // 2. Tạo document loves
      await supabase.from('txa_loves').upsert({
        'id': loveId,
        'user1': sortedUsernames[0],
        'user2': sortedUsernames[1],
        'startDate': startDate,
        'createdTime': DateTime.now().toIso8601String(),
        'statusText': '',
        'bubblePositionX': 0.5,
        'bubblePositionY': 0.4, // Căn giữa phía trên
        'statusUpdatedTime': DateTime.now().toIso8601String(),
      });

      // 3. Cập nhật thông tin User hiện tại (mình)
      await supabase.from('txa_users').update({
        'loveId': loveId,
        'loverUsername': senderUsername,
      }).eq('id', _currentUser!.id);

      // 4. Cập nhật thông tin đối phương (sender)
      final senderSnap = await supabase
          .from('txa_users')
          .select()
          .eq('username', senderUsername)
          .maybeSingle();
      if (senderSnap != null) {
        await supabase.from('txa_users').update({
          'loveId': loveId,
          'loverUsername': myUsername,
        }).eq('id', senderSnap['id'] as String);
      }

      // 5. Cập nhật trạng thái của lời mời thành accepted
      await supabase.from('txa_love_invitations').update({
        'status': 'accepted',
      }).eq('id', invitationId);

      // 6. Xóa/Từ chối các lời mời rác khác của cả 2 người (để làm sạch db)
      final pendingInvites = await supabase
          .from('txa_love_invitations')
          .select()
          .eq('status', 'pending');

      for (var row in pendingInvites) {
        final s = row['sender'] as String?;
        final r = row['receiver'] as String?;
        if (s == myUsername || r == myUsername || s == senderUsername || r == senderUsername) {
          await supabase.from('txa_love_invitations').update({'status': 'declined'}).eq('id', row['id'] as String);
        }
      }

      // 7. Đồng bộ lại dữ liệu local của mình
      await syncCurrentUserFromFirestore();

      return {'success': true, 'loveId': loveId};
    } catch (e) {
      final txaLang = TXALanguage.instance;
      return {
        'success': false,
        'message': txaLang.getText('love_accept_error').replaceFirst('%error%', e.toString())
      };
    }
  }

  /// Từ chối lời mời yêu
  Future<void> declineLoveInvitation(String invitationId) async {
    try {
      await TXASupabaseService.instance.client
          .from('txa_love_invitations')
          .update({'status': 'declined'})
          .eq('id', invitationId);
    } catch (e) {
      debugPrint('declineLoveInvitation error: $e');
    }
  }

  /// Cập nhật vị trí bong bóng và status text của người yêu
  Future<void> updateBubblePosition(String loveId, double x, double y, String statusText) async {
    try {
      await TXASupabaseService.instance.client.from('txa_loves').update({
        'bubblePositionX': x,
        'bubblePositionY': y,
        'statusText': statusText,
        'statusUpdatedTime': DateTime.now().toIso8601String(),
      }).eq('id', loveId);
    } catch (e) {
      debugPrint('updateBubblePosition error: $e');
    }
  }

  /// Hủy kết đôi (chia tay)
  Future<Map<String, dynamic>> breakLoveRelation(String loveId) async {
    final user = _currentUser;
    final txaLang = TXALanguage.instance;
    if (user == null) return {'success': false, 'message': txaLang.getText('not_logged_in_error')};
    final lover = user.loverUsername;

    try {
      final supabase = TXASupabaseService.instance.client;

      // 1. Reset user hiện tại
      await supabase.from('txa_users').update({
        'loveId': null,
        'loverUsername': null,
      }).eq('id', user.id);

      // 2. Reset đối phương
      if (lover != null && lover.isNotEmpty) {
        final partnerSnap = await supabase
            .from('txa_users')
            .select()
            .eq('username', lover)
            .maybeSingle();
        if (partnerSnap != null) {
          await supabase.from('txa_users').update({
            'loveId': null,
            'loverUsername': null,
          }).eq('id', partnerSnap['id'] as String);
        }
      }

      // 3. Xóa document loves
      await supabase.from('txa_loves').delete().eq('id', loveId);

      // 4. Đồng bộ lại dữ liệu local của mình
      await syncCurrentUserFromFirestore();

      return {'success': true};
    } catch (e) {
      final txaLang = TXALanguage.instance;
      return {
        'success': false,
        'message': txaLang.getText('break_up_error_toast').replaceFirst('%error%', e.toString())
      };
    }
  }
}
