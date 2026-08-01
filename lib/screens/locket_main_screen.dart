import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_format.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_chat_service.dart';
import '../services/txa_battery_service.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_changelog_modal.dart';
import '../services/txa_feed_service.dart';
import '../services/txa_camera_theme_service.dart';
import '../services/txa_friend_order_validator.dart';
import 'txa_profile_screen.dart';
import 'txa_chat_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/txa_avatar_frame.dart';
import '../widgets/txa_coach_mark.dart';
import 'photo_preview_screen.dart';
import 'locket_feed_screen.dart';
import '../services/txa_deep_link_service.dart';
import '../services/txa_notification_service.dart';
import 'txa_love_setup_screen.dart';
import 'txa_love_invitation_screen.dart';
import 'txa_love_dashboard_screen.dart';
import 'txa_love_feed_screen.dart';
import 'txa_rollcall_responses_screen.dart';

class LocketMainScreen extends StatefulWidget {
  const LocketMainScreen({super.key});

  @override
  State<LocketMainScreen> createState() => _LocketMainScreenState();
}

class _LocketMainScreenState extends State<LocketMainScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  String? _cameraErrorMsg;
  double? _bubbleDragX;
  double? _bubbleDragY;
  bool _isBubbleDragging = false;
  StreamSubscription? _incomingReqSub;
  StreamSubscription? _acceptedReqSub;
  final Set<String> _notifiedRequestIds = {};
  final Set<String> _notifiedAcceptedIds = {};
  int _selectedCameraIndex = 0;
  int _flashModeIndex = 0; // 0: off, 1: torch (always on), 2: auto (capture flash)
  bool _isFlashPillOpen = false;
  final List<IconData> _flashIcons = [
    Icons.flash_off_rounded,
    Icons.flash_on_rounded,
    Icons.flash_auto_rounded,
  ];

  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  List<double> _zoomLevels = [0.5, 1.0, 1.5, 2.0, 3.0];
  int _zoomIndex = 1;
  bool _isZoomPillOpen = false;
  final FocusNode _focusNode = FocusNode();
  Timer? _activeTimer;
  bool _isHoveringViewfinder = false;
  UserModel? _lastListenedUser;
  bool _isRollcallMode = false;
  DateTime? _lastPressedAt;

  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _friendsKey = GlobalKey();
  final GlobalKey _shutterKey = GlobalKey();

  Future<void> _checkAndShowCoachMarkTour({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final tourCompleted = prefs.getBool('txa_armi_coachmark_seen') ?? false;
    if (tourCompleted && !force) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final txaLang = TXALanguage.instance;

    TXACoachMark.show(
      context: context,
      steps: [
        TXACoachMarkStep(
          targetKey: _profileKey,
          dialogueText: txaLang.getText('coachmark_step_1'),
          expression: ArmiExpression.happy,
        ),
        TXACoachMarkStep(
          targetKey: _friendsKey,
          dialogueText: txaLang.getText('coachmark_step_2'),
          expression: ArmiExpression.pointing,
        ),
        TXACoachMarkStep(
          targetKey: _shutterKey,
          dialogueText: txaLang.getText('coachmark_step_3'),
          expression: ArmiExpression.surprised,
        ),
      ],
      onFinished: () async {
        final p = await SharedPreferences.getInstance();
        await p.setBool('txa_armi_coachmark_seen', true);

        if (mounted) {
          TXAToast.show(
            context,
            txaLang.getText('coachmark_completed'),
            icon: Icons.celebration_rounded,
          );
        }
      },
    );
  }

  void _setZoomValue(double zoomValue) async {
    final isRearCamera = _cameras.isNotEmpty &&
        _selectedCameraIndex < _cameras.length &&
        _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.back;

    if (!isRearCamera && _cameras.isNotEmpty) {
      return;
    }

    // 1. Dùng camera góc rộng (ultra-wide) nếu người dùng chọn 0.5x
    if (zoomValue == 0.5) {
      int? wideCameraIndex;
      int backCount = 0;
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.back) {
          backCount++;
          if (backCount == 2) {
            wideCameraIndex = i;
            break;
          }
        }
      }

      if (wideCameraIndex != null) {
        if (_selectedCameraIndex != wideCameraIndex) {
          _selectedCameraIndex = wideCameraIndex;
          await _setupCamera(wideCameraIndex);
        }
        setState(() {
          _currentZoom = 0.5;
          _zoomIndex = 0;
        });
        if (_cameraController != null && _isCameraInitialized) {
          try {
            await _cameraController!.setZoomLevel(1.0);
          } catch (_) {}
        }
        return;
      }
    } else {
      // Nếu zoomValue >= 1.0, đảm bảo dùng camera sau chính (first back camera)
      int? primaryBackIndex;
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.back) {
          primaryBackIndex = i;
          break;
        }
      }
      if (primaryBackIndex != null && _selectedCameraIndex != primaryBackIndex && _selectedCameraIndex != 1) { // 1 là camera trước
        _selectedCameraIndex = primaryBackIndex;
        await _setupCamera(primaryBackIndex);
      }
    }

    double minZoom = 1.0;
    double maxZoom = 8.0;
    if (_cameraController != null && _isCameraInitialized) {
      try {
        minZoom = await _cameraController!.getMinZoomLevel();
        maxZoom = await _cameraController!.getMaxZoomLevel();
      } catch (_) {}
    }

    final targetZoom = zoomValue.clamp(minZoom, maxZoom);

    int closestIdx = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < _zoomLevels.length; i++) {
      final diff = (targetZoom - _zoomLevels[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = i;
      }
    }

    setState(() {
      _currentZoom = targetZoom;
      _zoomIndex = closestIdx;
    });

    if (_cameraController != null && _isCameraInitialized) {
      try {
        await _cameraController!.setZoomLevel(targetZoom);
      } catch (e) {
        debugPrint('Zoom set level error: $e');
      }
    }
  }

  void _changeZoom(bool zoomIn) {
    if (zoomIn) {
      _zoomIndex = (_zoomIndex + 1) % _zoomLevels.length;
    } else {
      _zoomIndex = (_zoomIndex - 1 + _zoomLevels.length) % _zoomLevels.length;
    }
    _setZoomValue(_zoomLevels[_zoomIndex]);
  }

  void _selectZoomPreset(int index) {
    final txaLang = TXALanguage.instance;
    if (index >= 0 && index < _zoomLevels.length) {
      _setZoomValue(_zoomLevels[index]);
      setState(() {
        _isZoomPillOpen = false;
      });
      if (mounted) {
        TXAToast.show(
          context,
          txaLang.getText('zoom_preset_toast').replaceAll('%zoom%', _zoomLevels[index].toStringAsFixed(1)),
          icon: Icons.zoom_in_rounded,
        );
      }
    }
  }

  void _toggleZoomPill() {
    final isRearCamera = _cameras.isNotEmpty &&
        _selectedCameraIndex < _cameras.length &&
        _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.back;

    if (!isRearCamera && _cameras.isNotEmpty) {
      TXAToast.show(context, TXALanguage.instance.getText('zoom_rear_only'), icon: Icons.camera_front_rounded);
      return;
    }

    setState(() {
      _isZoomPillOpen = !_isZoomPillOpen;
    });
  }

  void _goToFeed() {
    final txaAuth = TXAAuthService.instance;
    final currentUsername = txaAuth.currentUser?.username ?? '';
    final visiblePosts = TXAFeedService.instance.getVisiblePostsForUser(currentUsername);
    
    int initialIndex = 0;
    if (currentUsername.isNotEmpty) {
      final unreadIndex = visiblePosts.indexWhere(
        (p) => !p.readBy.contains(currentUsername) && p.senderUsername != currentUsername
      );
      if (unreadIndex != -1) {
        initialIndex = unreadIndex;
      } else {
        final friendIndex = visiblePosts.indexWhere((p) => p.senderUsername != currentUsername);
        if (friendIndex != -1) {
          initialIndex = friendIndex;
        }
      }
    }

    Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => LocketFeedScreen(initialIndex: initialIndex),
      ),
    ).then((result) {
      _focusNode.requestFocus();
      if (result == 'show_friends_modal') {
        if (mounted) {
          _showFriendsModal(context);
        }
      }
    });
  }

  void _goToChatList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TXAChatListScreen(),
      ),
    ).then((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shownChangelog = await _checkAndShowChangelog();
      if (shownChangelog) {
        // Chờ modal Changelog đóng xong 500ms mới khởi chạy Tour Coachmark
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _checkAndShowCoachMarkTour();
      TXADeepLinkService.instance.checkPendingInvite();
      _focusNode.requestFocus();
      if (mounted) {
        await TXANotificationService.instance.requestPermissions(context);
      }
    });
    _activeTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted && TXAAuthService.instance.isLoggedIn) {
        TXAAuthService.instance.updateLastActive();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeTimer?.cancel();
    _focusNode.dispose();
    TXAAuthService.instance.removeListener(_onAuthServiceChanged);
    _incomingReqSub?.cancel();
    _acceptedReqSub?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authService = TXAAuthService.instance;
    if (state == AppLifecycleState.resumed) {
      authService.updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached) {
      authService.updateOnlineStatus(false);
    }
  }

  void _setupRealtimeNotificationListeners() {
    final txaAuth = TXAAuthService.instance;
    final currentUser = txaAuth.currentUser;

    if (currentUser == _lastListenedUser) return;

    _incomingReqSub?.cancel();
    _acceptedReqSub?.cancel();
    _notifiedRequestIds.clear();
    _notifiedAcceptedIds.clear();

    _lastListenedUser = currentUser;
    if (currentUser == null) return;

    // Lắng nghe khi click notification đổi highlightRequestId -> mở modal bạn bè
    txaAuth.addListener(_onAuthServiceChanged);

    // 1. Lắng nghe lời mời kết bạn mới gửi đến
    _incomingReqSub = txaAuth.listenIncomingRequests().listen((requests) {
      if (!mounted) return;
      for (final req in requests) {
        final requestId = req['id'] as String;
        final fromUser = req['from'] as String;

        // Chỉ hiện thông báo một lần duy nhất cho mỗi ID lời mời
        if (!_notifiedRequestIds.contains(requestId)) {
          _notifiedRequestIds.add(requestId);

          TXAToast.showFriendRequestNotification(
            context,
            name: fromUser,
            username: fromUser,
            avatar: req['fromAvatar'] as String? ?? '👤',
            avatarColor: req['fromAvatarColor'] as String? ?? '0xFF607D8B',
            onAccept: () async {
              await txaAuth.acceptFriendRequest(requestId, req);
              if (mounted) {
                TXAToast.show(
                  context,
                  TXALanguage.instance.getText('friend_added').replaceAll('%user%', fromUser),
                  icon: Icons.people_alt_rounded,
                );
              }
            },
            onDecline: () async {
              await txaAuth.declineFriendRequest(requestId);
            },
            onTap: () {
              // Mở modal friend và highlight
              txaAuth.setHighlightRequestId(requestId);
              _showFriendsModal(context);
            },
          );
        }
      }
    });

    // 2. Lắng nghe thông báo khi đối phương chấp nhận lời mời của mình
    _acceptedReqSub = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('to', isEqualTo: currentUser.username)
        .where('status', isEqualTo: 'accepted_auto')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          for (final doc in snap.docs) {
            final docId = doc.id;
            final data = doc.data();
            final fromUser = data['from'] as String;

            if (!_notifiedAcceptedIds.contains(docId)) {
              _notifiedAcceptedIds.add(docId);

              // Hiện banner thông báo đối phương đã đồng ý
              TXAToast.showFriendAcceptedNotification(
                context,
                name: fromUser,
                avatar: data['fromAvatar'] as String? ?? '👤',
                avatarColor: data['fromAvatarColor'] as String? ?? '0xFF607D8B',
                onTap: () {
                  _showFriendsModal(context);
                },
              );

              // Đánh dấu đã đọc/xác nhận
              FirebaseFirestore.instance
                  .collection('friend_requests')
                  .doc(docId)
                  .update({'status': 'accepted_acknowledged'});

              // Thêm đối phương vào danh sách bạn bè local của mình
              txaAuth.addFriendLocally(
                username: fromUser,
                avatar: data['fromAvatar'] as String? ?? '👤',
                avatarColor: data['fromAvatarColor'] as String? ?? '0xFF607D8B',
              );
            }
          }
        });
  }

  Future<bool> _checkAndShowChangelog() async {
    final prefs = await SharedPreferences.getInstance();
    const currentVer = '1.1.9+0';
    final shown = prefs.getBool('txa_changelog_shown_$currentVer') ?? false;
    if (!shown) {
      if (mounted) {
        await TXAChangelogModal.show(context);
        await prefs.setBool('txa_changelog_shown_$currentVer', true);
        return true;
      }
    }
    return false;
  }

  Future<void> _initCamera() async {
    if (mounted) {
      setState(() {
        _cameraErrorMsg = null;
      });
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _setupCamera(_selectedCameraIndex);
      } else {
        if (mounted) {
          setState(() {
            _cameraErrorMsg = TXALanguage.instance.getText('no_camera_found');
            _isCameraInitialized = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _cameraErrorMsg = '${TXALanguage.instance.getText('camera_in_use_error')}\n($e)';
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _setupCamera(int index) async {
    if (_cameras.isEmpty) return;

    if (mounted) {
      setState(() {
        _cameraErrorMsg = null;
        _isCameraInitialized = false;
      });
    }

    // Giải phóng camera cũ một cách an toàn
    if (_cameraController != null) {
      final oldController = _cameraController;
      _cameraController = null;
      // Chạy dispose bất đồng bộ để tránh treo native UI thread của Windows
      oldController!.dispose().catchError((e) {
        debugPrint('Error disposing old camera controller: $e');
      });
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      double minZoom = 1.0;
      try {
        minZoom = await controller.getMinZoomLevel();
      } catch (_) {}

      // Tự động bật mốc 0.5x nếu phần cứng thiết bị hỗ trợ camera góc rộng (Ultra-Wide)
      final List<double> newZoomLevels = minZoom <= 0.6
          ? [0.5, 1.0, 1.5, 2.0, 3.0]
          : [0.5, 1.0, 1.5, 2.0, 3.0]; // Luôn bật 0.5x trên danh sách cho thiết bị hỗ trợ

      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isCameraInitialized = true;
          _cameraErrorMsg = null;
          _zoomLevels = newZoomLevels;
          _zoomIndex = newZoomLevels.contains(1.0) ? newZoomLevels.indexOf(1.0) : 0;
          _currentZoom = 1.0;
        });
      }
    } on CameraException catch (e) {
      debugPrint('Camera setup CameraException: code=${e.code}, desc=${e.description}');
      try {
        await controller.dispose();
      } catch (_) {}
      if (mounted) {
        String msg = TXALanguage.instance.getText('camera_in_use_error');
        if (e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt') {
          msg = TXALanguage.instance.getText('camera_access_denied');
        } else if (e.description != null && e.description!.isNotEmpty) {
          msg = '${TXALanguage.instance.getText('camera_in_use_error')}\n(${e.description})';
        }
        setState(() {
          _cameraController = null;
          _isCameraInitialized = false;
          _cameraErrorMsg = msg;
        });
      }
    } catch (e) {
      debugPrint('Camera setup generic error: $e');
      try {
        await controller.dispose();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _cameraController = null;
          _isCameraInitialized = false;
          _cameraErrorMsg = '${TXALanguage.instance.getText('camera_in_use_error')}\n($e)';
        });
      }
    }
  }

  void _toggleCamera() {
    final txaLang = TXALanguage.instance;
    if (_cameras.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      _setupCamera(_selectedCameraIndex);
    } else {
      TXAToast.show(context, txaLang.getText('single_camera_found'), icon: Icons.camera);
    }
  }

  void _setFlashMode(int index) async {
    final txaLang = TXALanguage.instance;
    setState(() {
      _flashModeIndex = index;
      _isFlashPillOpen = false;
    });

    if (_cameraController != null && _isCameraInitialized) {
      try {
        if (index == 1) {
          // Always On / Torch Mode (bật sáng liên tục trợ sáng)
          await _cameraController!.setFlashMode(FlashMode.torch);
        } else if (index == 2) {
          // Auto Flash Mode (tự động chớp khi bấm chụp)
          await _cameraController!.setFlashMode(FlashMode.auto);
        } else {
          // Off
          await _cameraController!.setFlashMode(FlashMode.off);
        }
      } catch (e) {
        debugPrint('Flash mode error: $e');
      }
    }

    if (mounted) {
      final labels = [
        txaLang.getText('flash_off_toast'),
        txaLang.getText('flash_on_toast'),
        txaLang.getText('flash_auto_toast'),
      ];
      TXAToast.show(context, labels[index], icon: _flashIcons[index]);
    }
  }

  void _toggleFlashPill() {
    setState(() {
      _isFlashPillOpen = !_isFlashPillOpen;
    });
  }

  void _toggleFlash() {
    _setFlashMode((_flashModeIndex + 1) % 3);
  }

  void _capturePhoto() async {
    String? path;
    if (_cameraController != null && _isCameraInitialized) {
      try {
        final xFile = await _cameraController!.takePicture();
        path = xFile.path;
      } catch (e) {
        debugPrint('Take picture error: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhotoPreviewScreen(imagePath: path, isRollcall: _isRollcallMode),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isRollcallMode = false;
          });
        }
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhotoPreviewScreen(imagePath: image.path),
        ),
      );
    } catch (e) {
      debugPrint('Gallery picker error: $e');
    }
  }

  Future<void> _pickImageFromGalleryForRollcall() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhotoPreviewScreen(imagePath: image.path, isRollcall: true),
        ),
      );
    } catch (e) {
      debugPrint('Gallery picker error: $e');
    }
  }



  void _onAuthServiceChanged() {
    final txaAuth = TXAAuthService.instance;
    if (txaAuth.highlightRequestId != null) {
      _showFriendsModal(context);
    }
  }



  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
        _capturePhoto();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.pageUp ||
          key == LogicalKeyboardKey.pageDown) {
        _goToFeed();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyF) {
        _toggleFlash();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyC) {
        _toggleCamera();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyG) {
        _pickImageFromGallery();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd) {
        _changeZoom(true);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
        _changeZoom(false);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaFormat = TXAFormat.instance;

    final txaAuth = TXAAuthService.instance;
    final txaFeed = TXAFeedService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([txaLang, txaFormat, txaAuth, txaFeed, TXACameraThemeService.instance, TXABatteryService.instance, TXAChatService.instance]),
      builder: (context, _) {
        _setupRealtimeNotificationListeners();
        final isRearCamera = _cameras.isNotEmpty &&
            _selectedCameraIndex < _cameras.length &&
            _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.back;
        final currentUser = txaAuth.currentUser;
        final loveId = currentUser?.loveId;
        final loverUsername = currentUser?.loverUsername;
        final avatarEmoji = currentUser?.avatar ?? '🦊';
        final avatarColorVal = int.tryParse(currentUser?.avatarBgColor ?? '0xFFF57C00') ?? 0xFFF57C00;
        final screenSize = MediaQuery.of(context).size;
        final screenWidth = screenSize.width;
        final screenHeight = screenSize.height;

        // ignore: deprecated_member_use
        return PopScope(
          canPop: false,
          // ignore: deprecated_member_use
          onPopInvoked: (didPop) async {
            if (didPop) return;
            final now = DateTime.now();
            if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
              _lastPressedAt = now;
              TXAToast.show(
                context,
                txaLang.getText('press_back_again_to_exit'),
                icon: Icons.exit_to_app_rounded,
              );
              return;
            }
            await SystemNavigator.pop();
          },
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent && !_isHoveringViewfinder) {
                if (pointerSignal.scrollDelta.dy.abs() > 20) {
                  _goToFeed();
                }
              }
            },
            child: Scaffold(
              backgroundColor: TXATheme.background,
              body: Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                // 1. Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Avatar / Profile Button
                      Tooltip(
                        message: txaLang.getText('profile_settings_tooltip').replaceAll('%user%', currentUser?.username ?? ''),
                        waitDuration: const Duration(milliseconds: 250),
                        child: GestureDetector(
                          key: _profileKey,
                          onTap: () async {
                            final result = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(builder: (_) => const TXAProfileScreen()),
                            );
                            if (result == 'show_friends_modal') {
                              if (context.mounted) {
                                _showFriendsModal(context);
                              }
                            } else {
                              _checkAndShowCoachMarkTour();
                            }
                          },
                          child: TXAAvatarFrame(
                            username: currentUser?.username ?? '@user',
                            radius: 20,
                            tier: TXAFriendTier.normal,
                            child: Container(
                              color: Color(avatarColorVal).withAlpha(200),
                              child: avatarEmoji.startsWith('http')
                                  ? Image.network(avatarEmoji, fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        avatarEmoji,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // Center: Friends Pill Button
                      Flexible(
                        child: Tooltip(
                          message: txaLang.getText('friends_list_tooltip').replaceAll('%count%', '${txaAuth.friendsList.length}'),
                          waitDuration: const Duration(milliseconds: 250),
                          child: GestureDetector(
                            key: _friendsKey,
                            onTap: () => _showFriendsModal(context),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: TXATheme.cardBg,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: TXATheme.cardBorder, width: 2.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: TXATheme.cardBorder.withAlpha(50),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_alt_rounded, size: 18, color: TXATheme.accentColor),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      txaLang.getText('friends_count')
                                          .replaceAll('%count%', '${txaAuth.friendsList.length}'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: TXATheme.textPrimary,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Right: Chat Button
                      Tooltip(
                        message: txaLang.getText('chat_messages_tooltip'),
                        waitDuration: const Duration(milliseconds: 250),
                        child: GestureDetector(
                          onTap: _goToChatList,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: TXATheme.cardBg,
                              border: Border.all(color: TXATheme.cardBorder, width: 2.0),
                              boxShadow: [
                                BoxShadow(
                                  color: TXATheme.cardBorder.withAlpha(50),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: TXATheme.accentColor,
                                  size: 22,
                                ),
                                Builder(
                                  builder: (context) {
                                    final currentUsername = txaAuth.currentUser?.username ?? '';
                                    final unreadCount = TXAChatService.instance.getUnreadMessageCount(currentUsername);
                                    if (unreadCount <= 0) return const SizedBox.shrink();
                                    return Positioned(
                                      top: -3,
                                      right: -3,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$unreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: GestureDetector(
                    onDoubleTap: _goToFeed,
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
                        _goToFeed();
                      }
                    },
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: screenWidth - 24, // Widen to screen width (leaving 12px margins)
                          maxHeight: screenHeight * 0.65, // Heighten the maximum layout constraint
                        ),
                        child: AspectRatio(
                          aspectRatio: 3 / 4, // Change aspect ratio to 3:4 portrait
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Builder(builder: (context) {
                              final camTheme = TXACameraThemeService.instance;
                              final themeAccent = camTheme.getAccentColor();
                              final themeBg = camTheme.getBgColor();
                              final frameDec = camTheme.getFrameDecoration();
                              final themeRadius = (frameDec.borderRadius as BorderRadius?)?.topLeft.x ?? 28.0;
                              // Subtraction of 1.0 to fit inside the border lines without visual bleed
                              final clipRadius = (themeRadius - 1.0).clamp(0.0, 100.0);

                              return MouseRegion(
                                onEnter: (_) => setState(() => _isHoveringViewfinder = true),
                                onExit: (_) => setState(() => _isHoveringViewfinder = false),
                                child: Listener(
                                  onPointerSignal: (pointerSignal) {
                                    if (pointerSignal is PointerScrollEvent) {
                                      if (pointerSignal.scrollDelta.dy < 0) {
                                        _changeZoom(true);
                                      } else if (pointerSignal.scrollDelta.dy > 0) {
                                        _changeZoom(false);
                                      }
                                    }
                                  },
                                  child: Container(
                                    decoration: _isRollcallMode
                                        ? BoxDecoration(
                                            borderRadius: BorderRadius.circular(themeRadius),
                                            border: Border.all(
                                              color: Colors.amber,
                                              width: 3.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.amber.withAlpha(180),
                                                blurRadius: 16,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          )
                                        : frameDec,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(clipRadius),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onScaleStart: (details) {
                                      _baseZoom = _currentZoom;
                                    },
                                    onScaleUpdate: (details) {
                                      if (details.scale != 1.0) {
                                        _setZoomValue(_baseZoom * details.scale);
                                      }
                                    },
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Rollcall Mode badge inside viewfinder
                                        if (_isRollcallMode)
                                          Positioned(
                                            top: 14,
                                            left: 0,
                                            right: 0,
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.amber.withAlpha(100),
                                                      blurRadius: 8,
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Text('📣', style: TextStyle(fontSize: 12)),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      txaLang.getText('rollcall_title'),
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                        // Camera Live Stream or Viewfinder Placeholder
                                        _isCameraInitialized && _cameraController != null
                                            ? SizedBox.expand(
                                                child: FittedBox(
                                                  fit: BoxFit.cover,
                                                  child: Builder(
                                                    builder: (context) {
                                                      final previewSize = _cameraController!.value.previewSize;
                                                      final isDesktop = !Platform.isAndroid && !Platform.isIOS;
                                                      final width = isDesktop
                                                          ? (previewSize?.width ?? 1.0)
                                                          : (previewSize?.height ?? 1.0);
                                                      final height = isDesktop
                                                          ? (previewSize?.height ?? 1.0)
                                                          : (previewSize?.width ?? 1.0);
                                                      return SizedBox(
                                                        width: width,
                                                        height: height,
                                                        child: CameraPreview(_cameraController!),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: themeBg,
                                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                                child: Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        _cameraErrorMsg != null
                                                            ? Icons.videocam_off_rounded
                                                            : Icons.camera_rounded,
                                                        size: 54,
                                                        color: _cameraErrorMsg != null
                                                            ? Colors.amber
                                                            : themeAccent.withAlpha(100),
                                                      ),
                                                      const SizedBox(height: 12),
                                                      Text(
                                                        _cameraErrorMsg ?? txaLang.getText('camera_viewfinder'),
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                          color: _cameraErrorMsg != null
                                                              ? TXATheme.textPrimary
                                                              : TXATheme.textMuted,
                                                          fontSize: 14,
                                                          fontWeight: _cameraErrorMsg != null
                                                              ? FontWeight.w600
                                                              : FontWeight.normal,
                                                        ),
                                                      ),
                                                      if (_cameraErrorMsg != null || !_isCameraInitialized) ...[
                                                        const SizedBox(height: 16),
                                                        ElevatedButton.icon(
                                                          onPressed: _initCamera,
                                                          icon: const Icon(Icons.refresh_rounded, size: 18),
                                                          label: Text(
                                                            txaLang.getText('camera_retry_btn'),
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: TXATheme.primaryYellow,
                                                            foregroundColor: Colors.black,
                                                            elevation: 4,
                                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(20),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),

                                        // ── Theme Overlay (color filter phủ lên camera preview) ──
                                        if (_isCameraInitialized && camTheme.buildOverlay() != null)
                                          camTheme.buildOverlay()!,

                                        // Top Left: Zoom Indicator & Animated Horizontal Pill Bar
                                        if (isRearCamera)
                                          Positioned(
                                            top: 14,
                                            left: 14,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Tooltip(
                                                  message: txaLang.getText('zoom_tooltip'),
                                                  child: GestureDetector(
                                                    onTap: _toggleZoomPill,
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 200),
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: _isZoomPillOpen
                                                            ? TXATheme.primaryYellow
                                                            : Colors.black.withAlpha(160),
                                                        borderRadius: BorderRadius.circular(14),
                                                        border: Border.all(
                                                          color: _isZoomPillOpen
                                                              ? TXATheme.primaryYellow
                                                              : themeAccent.withAlpha(160),
                                                          width: 1.5,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: (_isZoomPillOpen ? TXATheme.primaryYellow : themeAccent).withAlpha(80),
                                                            blurRadius: 8,
                                                          ),
                                                        ],
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '${_currentZoom.toStringAsFixed(1)}x',
                                                            style: TextStyle(
                                                              color: _isZoomPillOpen ? Colors.black : themeAccent,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 2),
                                                          Icon(
                                                            _isZoomPillOpen ? Icons.chevron_left_rounded : Icons.unfold_more_rounded,
                                                            size: 14,
                                                            color: _isZoomPillOpen ? Colors.black : themeAccent,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                AnimatedCrossFade(
                                                  duration: const Duration(milliseconds: 200),
                                                  crossFadeState: _isZoomPillOpen
                                                      ? CrossFadeState.showSecond
                                                      : CrossFadeState.showFirst,
                                                  firstChild: const SizedBox.shrink(),
                                                  secondChild: Container(
                                                    margin: const EdgeInsets.only(left: 6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withAlpha(200),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: Colors.white.withAlpha(50),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: List.generate(_zoomLevels.length, (idx) {
                                                        final level = _zoomLevels[idx];
                                                        final isSelected = _zoomIndex == idx;
                                                        return Tooltip(
                                                          message: 'Zoom ${level.toStringAsFixed(1)}x',
                                                          child: GestureDetector(
                                                            onTap: () => _selectZoomPreset(idx),
                                                            child: AnimatedContainer(
                                                              duration: const Duration(milliseconds: 150),
                                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: isSelected
                                                                    ? TXATheme.primaryYellow
                                                                    : Colors.white.withAlpha(20),
                                                                borderRadius: BorderRadius.circular(10),
                                                                border: Border.all(
                                                                  color: isSelected
                                                                      ? TXATheme.primaryYellow
                                                                      : Colors.transparent,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                '${level.toStringAsFixed(1)}x',
                                                                style: TextStyle(
                                                                  color: isSelected ? Colors.black : Colors.white,
                                                                  fontSize: 11,
                                                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Top Right: Flash Indicator & Horizontal Animated Flash Pill Bar (Chỉ hiện ở Camera sau)
                                        if (isRearCamera)
                                          Positioned(
                                            top: 14,
                                            right: 14,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Horizontal Flash Presets Pill Slider Bar
                                                AnimatedCrossFade(
                                                  duration: const Duration(milliseconds: 200),
                                                  crossFadeState: _isFlashPillOpen
                                                      ? CrossFadeState.showSecond
                                                      : CrossFadeState.showFirst,
                                                  firstChild: const SizedBox.shrink(),
                                                  secondChild: Container(
                                                    margin: const EdgeInsets.only(right: 6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withAlpha(200),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: Colors.white.withAlpha(50),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        // 1. Off (Tắt)
                                                        Tooltip(
                                                          message: txaLang.getText('flash_off_tooltip'),
                                                          child: GestureDetector(
                                                            onTap: () => _setFlashMode(0),
                                                            child: AnimatedContainer(
                                                              duration: const Duration(milliseconds: 150),
                                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                                              padding: const EdgeInsets.all(6),
                                                              decoration: BoxDecoration(
                                                                color: _flashModeIndex == 0
                                                                    ? TXATheme.primaryYellow
                                                                    : Colors.white.withAlpha(20),
                                                                shape: BoxShape.circle,
                                                                border: Border.all(
                                                                  color: _flashModeIndex == 0 ? TXATheme.primaryYellow : Colors.transparent,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Icon(
                                                                Icons.flash_off_rounded,
                                                                color: _flashModeIndex == 0 ? Colors.black : Colors.white,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                        // 2. Torch (Luôn bật)
                                                        Tooltip(
                                                          message: txaLang.getText('flash_on_tooltip'),
                                                          child: GestureDetector(
                                                            onTap: () => _setFlashMode(1),
                                                            child: AnimatedContainer(
                                                              duration: const Duration(milliseconds: 150),
                                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                                              padding: const EdgeInsets.all(6),
                                                              decoration: BoxDecoration(
                                                                color: _flashModeIndex == 1
                                                                    ? TXATheme.primaryYellow
                                                                    : Colors.white.withAlpha(20),
                                                                shape: BoxShape.circle,
                                                                border: Border.all(
                                                                  color: _flashModeIndex == 1 ? TXATheme.primaryYellow : Colors.transparent,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Icon(
                                                                Icons.flash_on_rounded,
                                                                color: _flashModeIndex == 1 ? Colors.black : Colors.white,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                        // 3. Auto (Tự động khi chụp)
                                                        Tooltip(
                                                          message: txaLang.getText('flash_auto_tooltip'),
                                                          child: GestureDetector(
                                                            onTap: () => _setFlashMode(2),
                                                            child: AnimatedContainer(
                                                              duration: const Duration(milliseconds: 150),
                                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                                              padding: const EdgeInsets.all(6),
                                                              decoration: BoxDecoration(
                                                                color: _flashModeIndex == 2
                                                                    ? TXATheme.primaryYellow
                                                                    : Colors.white.withAlpha(20),
                                                                shape: BoxShape.circle,
                                                                border: Border.all(
                                                                  color: _flashModeIndex == 2 ? TXATheme.primaryYellow : Colors.transparent,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Icon(
                                                                Icons.flash_auto_rounded,
                                                                color: _flashModeIndex == 2 ? Colors.black : Colors.white,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),

                                                // Flash Main Pill Button
                                                Tooltip(
                                                  message: _flashModeIndex == 0
                                                      ? txaLang.getText('flash_off_tooltip')
                                                      : _flashModeIndex == 1
                                                          ? txaLang.getText('flash_on_tooltip')
                                                          : txaLang.getText('flash_auto_tooltip'),
                                                  child: GestureDetector(
                                                    onTap: _toggleFlashPill,
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 200),
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: _isFlashPillOpen
                                                            ? TXATheme.primaryYellow
                                                            : (_flashModeIndex > 0 ? TXATheme.primaryYellow.withAlpha(50) : Colors.black.withAlpha(160)),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: _isFlashPillOpen || _flashModeIndex > 0
                                                              ? TXATheme.primaryYellow
                                                              : themeAccent.withAlpha(160),
                                                          width: 1.5,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: (_isFlashPillOpen || _flashModeIndex > 0 ? TXATheme.primaryYellow : themeAccent).withAlpha(80),
                                                            blurRadius: 8,
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        _flashIcons[_flashModeIndex],
                                                        color: _isFlashPillOpen ? Colors.black : (_flashModeIndex > 0 ? TXATheme.primaryYellow : themeAccent),
                                                        size: 20,
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
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),


                // 3. Main Shutter Control Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Gallery Button
                      Builder(
                        builder: (ctx) {
                          final activeTheme = TXACameraThemeService.instance.currentThemeData;
                          final accent = activeTheme.accentColor;
                          return Tooltip(
                            message: txaLang.getText('gallery_tooltip'),
                            waitDuration: const Duration(milliseconds: 250),
                            child: GestureDetector(
                              onTap: _pickImageFromGallery,
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: TXATheme.cardBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: TXATheme.cardBorder, width: 2.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: TXATheme.cardBorder.withAlpha(60),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                                child: Icon(
                                  Icons.photo_library_outlined,
                                  color: accent,
                                  size: 26,
                                ),
                              ),
                            ),
                          );
                        }
                      ),

                      // Signature Locket Shutter Button
                      Builder(
                        builder: (ctx) {
                          final canCapture = _isCameraInitialized && _cameraErrorMsg == null;
                          final activeTheme = TXACameraThemeService.instance.currentThemeData;
                          final shutterBorder = activeTheme.shutterBorderColor ?? activeTheme.accentColor;
                          final shutterFill = activeTheme.shutterFillColor ?? activeTheme.accentColor;
                          final shutterIconText = activeTheme.shutterInnerIcon;

                          return Tooltip(
                            message: txaLang.getText('shutter_tooltip'),
                            waitDuration: const Duration(milliseconds: 250),
                            child: GestureDetector(
                              key: _shutterKey,
                              onTap: canCapture ? _capturePhoto : null,
                              child: Opacity(
                                opacity: canCapture ? 1.0 : 0.4,
                                child: Container(
                                  width: 88,
                                  height: 88,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: shutterBorder,
                                      width: 4.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: shutterBorder.withAlpha(120),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: shutterFill,
                                      shape: BoxShape.circle,
                                    ),
                                    child: shutterIconText != null
                                        ? Center(
                                            child: Text(
                                              shutterIconText,
                                              style: const TextStyle(fontSize: 32),
                                            ),
                                          )
                                        : Center(
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: shutterBorder.withAlpha(90),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      ),

                      // Flip Camera Button
                      Builder(
                        builder: (ctx) {
                          final activeTheme = TXACameraThemeService.instance.currentThemeData;
                          final accent = activeTheme.accentColor;
                          return Tooltip(
                            message: txaLang.getText('flip_camera_tooltip'),
                            waitDuration: const Duration(milliseconds: 250),
                            child: GestureDetector(
                              onTap: _toggleCamera,
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: TXATheme.cardBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: TXATheme.cardBorder, width: 2.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: TXATheme.cardBorder.withAlpha(60),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                                child: Icon(
                                  Icons.autorenew_rounded,
                                  color: accent,
                                  size: 28,
                                ),
                              ),
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 4. Dynamic History Feed Trigger
                AnimatedBuilder(
                  animation: Listenable.merge([txaLang, TXAFeedService.instance]),
                  builder: (context, _) {
                    final unreadCount = TXAFeedService.instance.getUnreadCountForUser(txaAuth.currentUser?.username ?? '');
                    return Tooltip(
                      message: txaLang.getText('feed_trigger_tooltip'),
                      waitDuration: const Duration(milliseconds: 250),
                      child: GestureDetector(
                        onTap: _goToFeed,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pill History / Double Tap
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: TXATheme.cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: TXATheme.cardBorder,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: TXATheme.cardBorder.withAlpha(40),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Icon lấp lánh màu vàng cam
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    txaLang.getText('history_label'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  if (unreadCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: TXATheme.statusRed,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Mũi tên chỉ xuống v
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white.withAlpha(179),
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 5. Rollcall Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TXARollcallResponsesScreen(
                            onTriggerCapture: () {
                              setState(() {
                                _isRollcallMode = true;
                              });
                              TXAToast.show(
                                context,
                                txaLang.getText('rollcall_activated'),
                                icon: Icons.notifications_active_rounded,
                              );
                            },
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isRollcallMode ? Colors.amber.withAlpha(40) : TXATheme.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isRollcallMode ? Colors.amber : TXATheme.cardBorder,
                          width: _isRollcallMode ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Text('📣', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    txaLang.getText('rollcall_title'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: TXATheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _pickImageFromGalleryForRollcall,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: TXATheme.primaryYellow,
                              side: const BorderSide(
                                color: TXATheme.primaryYellow,
                                style: BorderStyle.solid,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              txaLang.getText('select_photo'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                      ],
                    ),
                  ),

                  // ── Lover Status Bubble (Full Screen Draggable) ──
                  if (loveId != null && loverUsername != null)
                    StreamBuilder<Map<String, dynamic>?>(
                      stream: txaAuth.listenToLoveConnection(loveId),
                      builder: (context, loveSnap) {
                        final loveData = loveSnap.data;
                        if (loveData == null) return const SizedBox.shrink();
                        final currentStatus = loveData['statusText'] as String? ?? '';
                        final double xPos = loveData['bubblePositionX'] as double? ?? 0.5;
                        final double yPos = loveData['bubblePositionY'] as double? ?? 0.4;

                        return StreamBuilder<UserModel?>(
                          stream: txaAuth.listenToUser(loverUsername),
                          builder: (context, userSnap) {
                            final loverUser = userSnap.data;
                            if (loverUser == null) return const SizedBox.shrink();
                            final avatar = loverUser.avatar;
                            final bgColor = int.tryParse(loverUser.avatarBgColor) ?? 0xFFF43F5E;

                            // Determine coordinate to use (local if dragging, firebase otherwise)
                            final xBubble = _isBubbleDragging ? (_bubbleDragX ?? xPos) : xPos;
                            final yBubble = _isBubbleDragging ? (_bubbleDragY ?? yPos) : yPos;

                            // Absolute pixel positions computed from screen dimensions
                            final double posX = xBubble * (screenWidth - 80);
                            final double posY = yBubble * (screenHeight - 100);

                            return Positioned(
                              left: posX.clamp(0.0, screenWidth - 80),
                              top: posY.clamp(0.0, screenHeight - 100),
                              child: GestureDetector(
                                onPanStart: (details) {
                                  setState(() {
                                    _isBubbleDragging = true;
                                    _bubbleDragX = xPos;
                                    _bubbleDragY = yPos;
                                  });
                                },
                                onPanUpdate: (details) {
                                  setState(() {
                                    _bubbleDragX = (_bubbleDragX ?? xPos) + details.delta.dx / (screenWidth - 80);
                                    _bubbleDragY = (_bubbleDragY ?? yPos) + details.delta.dy / (screenHeight - 100);
                                    _bubbleDragX = _bubbleDragX!.clamp(0.0, 1.0);
                                    _bubbleDragY = _bubbleDragY!.clamp(0.0, 1.0);
                                  });
                                },
                                onPanEnd: (details) async {
                                  setState(() {
                                    _isBubbleDragging = false;
                                  });
                                  if (_bubbleDragX != null && _bubbleDragY != null) {
                                    await txaAuth.updateBubblePosition(
                                      loveId,
                                      _bubbleDragX!,
                                      _bubbleDragY!,
                                      currentStatus,
                                    );
                                  }
                                },
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TXALoveFeedScreen(loveId: loveId),
                                    ),
                                  );
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (currentStatus.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        margin: const EdgeInsets.only(bottom: 4),
                                        constraints: const BoxConstraints(maxWidth: 120),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(50),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          currentStatus,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Color(bgColor),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFF43F5E), width: 2.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF43F5E).withAlpha(100),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          avatar,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  if (TXABatteryService.instance.isBatteryCritical)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withAlpha(240),
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: Colors.white10,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.battery_alert_rounded,
                                  color: TXATheme.statusRed,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                txaLang.getText('battery_critical_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                txaLang.getText('battery_critical_desc'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showFriendsModal(BuildContext context) {
    TXAAuthService.instance.syncFriendsFromFirestore();
    String searchQ = '';
    final Set<String> processingRequestIds = {};
    bool isProcessingAll = false;

    // Xoá highlight sau 3 giây để tắt hiệu ứng phát sáng viền vàng
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        TXAAuthService.instance.setHighlightRequestId(null);
      }
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        final txaLang = TXALanguage.instance;
        final txaAuth = TXAAuthService.instance;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                maxChildSize: 0.95,
                minChildSize: 0.5,
                expand: false,
                builder: (context, scrollController) {
                  return AnimatedBuilder(
                    animation: Listenable.merge([txaLang, txaAuth]),
                    builder: (context, _) {
                    final filteredFriends = txaAuth.friendsList.where((friend) {
                      final name = (friend['name'] ?? '').toString().toLowerCase();
                      final username = (friend['username'] ?? '').toString().toLowerCase();
                      final q = searchQ.toLowerCase();
                      return name.contains(q) || username.contains(q);
                    }).toList();

                    // Sắp xếp danh sách bạn bè theo độ ưu tiên
                    filteredFriends.sort((a, b) {
                      final scoreA = txaAuth.getFriendPriorityScore(a['username']);
                      final scoreB = txaAuth.getFriendPriorityScore(b['username']);
                      return scoreA.compareTo(scoreB);
                    });

                    final filteredBestFriends = filteredFriends.where((f) => f['isBestFriend'] == true).toList();

                    return SafeArea(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Title Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                txaLang.getText('friends_title'),
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showAddFriendBottomSheet(context);
                                },
                                icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Search bar
                          TextField(
                            onChanged: (val) {
                              setModalState(() {
                                searchQ = val;
                              });
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: txaLang.getText('search_friend_placeholder'),
                              hintStyle: TextStyle(color: TXATheme.textMuted, fontSize: 14),
                              prefixIcon: Icon(Icons.search_rounded, color: TXATheme.textMuted),
                              filled: true,
                              fillColor: Colors.white.withAlpha(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: ReorderableListView(
                              scrollController: scrollController,
                              buildDefaultDragHandles: false,
                              onReorderItem: (oldIndex, newIndex) async {
                                if (searchQ.isNotEmpty) return;
                                if (oldIndex < 0 || oldIndex >= filteredFriends.length) return;
                                if (newIndex < 0 || newIndex >= filteredFriends.length) return;

                                // Kiểm tra luật kéo thả thông qua validator riêng biệt (txa_friend_order_validator.dart)
                                final validationKey = TXAFriendOrderValidator.instance.validateReorder(
                                  friendsList: filteredFriends,
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                  isPremiumUser: false, // Sau này check gói thuê bao tại đây
                                );

                                if (validationKey != null) {
                                  if (context.mounted) {
                                    TXAToast.show(
                                      context,
                                      txaLang.getText(validationKey),
                                      icon: Icons.warning_amber_rounded,
                                      backgroundColor: TXATheme.statusRed,
                                    );
                                  }
                                  return;
                                }

                                final draggedFriend = filteredFriends[oldIndex];
                                final actualOldIndex = txaAuth.friendsList.indexOf(draggedFriend);
                                final targetFriend = filteredFriends[newIndex];
                                final actualNewIndex = txaAuth.friendsList.indexOf(targetFriend);

                                if (actualOldIndex != -1 && actualNewIndex != -1) {
                                  await txaAuth.updateFriendOrder(actualOldIndex, actualNewIndex);
                                  if (context.mounted) {
                                    TXAToast.show(
                                      context,
                                      txaLang.getText('friend_order_updated'),
                                      icon: Icons.check_circle_rounded,
                                    );
                                  }
                                }
                              },
                              header: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. Lời mời đã nhận (Incoming)
                                  StreamBuilder<List<Map<String, dynamic>>>(
                                    stream: txaAuth.listenIncomingRequests(),
                                    builder: (ctx, snap) {
                                      final requests = snap.data ?? [];
                                      if (requests.isEmpty) return const SizedBox.shrink();
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildSectionHeader(
                                                  txaLang.getText('invites_title'),
                                                  count: requests.length,
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: isProcessingAll
                                                    ? null
                                                    : () async {
                                                        setModalState(() {
                                                          isProcessingAll = true;
                                                        });
                                                        try {
                                                          final futures = requests.map((req) {
                                                            return txaAuth.acceptFriendRequest(req['id'], req);
                                                          });
                                                          await Future.wait(futures);
                                                          if (context.mounted) {
                                                            TXAToast.show(
                                                              context,
                                                              txaLang.getText('admin_friend_success').replaceAll('%user%', txaLang.getText('all_friends')),
                                                              icon: Icons.people_alt_rounded,
                                                            );
                                                          }
                                                        } catch (e) {
                                                          debugPrint('Accept all error: $e');
                                                        } finally {
                                                          if (context.mounted) {
                                                            setModalState(() {
                                                              isProcessingAll = false;
                                                            });
                                                          }
                                                        }
                                                      },
                                                icon: isProcessingAll
                                                    ? const SizedBox(
                                                        width: 12,
                                                        height: 12,
                                                        child: CircularProgressIndicator(strokeWidth: 1.5, color: TXATheme.actionBlue),
                                                      )
                                                    : const Icon(Icons.done_all_rounded, size: 14, color: TXATheme.actionBlue),
                                                label: Text(
                                                  '${txaLang.getText('accept_all')} (${TXAFormat.formatNumber(requests.length)})',
                                                  style: const TextStyle(fontSize: 12, color: TXATheme.actionBlue, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              TextButton.icon(
                                                onPressed: isProcessingAll
                                                    ? null
                                                    : () async {
                                                        setModalState(() {
                                                          isProcessingAll = true;
                                                        });
                                                        try {
                                                          final futures = requests.map((req) {
                                                            return txaAuth.declineFriendRequest(req['id']);
                                                          });
                                                          await Future.wait(futures);
                                                        } catch (e) {
                                                          debugPrint('Decline all error: $e');
                                                        } finally {
                                                          if (context.mounted) {
                                                            setModalState(() {
                                                              isProcessingAll = false;
                                                            });
                                                          }
                                                        }
                                                      },
                                                icon: const Icon(Icons.close_rounded, size: 14, color: TXATheme.statusRed),
                                                label: Text(
                                                  txaLang.getText('reject_all'),
                                                  style: const TextStyle(fontSize: 12, color: TXATheme.statusRed, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          ...requests.map((req) => _buildInviteTile(
                                            req['id'],
                                            req['from'],
                                            req['from'],
                                            req,
                                            processingRequestIds,
                                            isProcessingAll,
                                            setModalState,
                                          )),
                                          const SizedBox(height: 20),
                                        ],
                                      );
                                    },
                                  ),
                                  // 2. Lời mời đã gửi (Sent)
                                  StreamBuilder<List<Map<String, dynamic>>>(
                                    stream: txaAuth.listenSentRequests(),
                                    builder: (ctx, snap) {
                                      final requests = snap.data ?? [];
                                      if (requests.isEmpty) return const SizedBox.shrink();
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionHeader(
                                            txaLang.getText('sent_invites'),
                                            count: requests.length,
                                          ),
                                          ...requests.map((req) => _buildSentInviteTile(
                                            req['id'],
                                            req['to'],
                                            req,
                                          )),
                                          const SizedBox(height: 20),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  _buildSectionHeader(
                                    txaLang.getText('friends_title'),
                                    count: filteredFriends.length,
                                    bestFriendsCount: filteredBestFriends.length,
                                    isStar: true,
                                  ),
                                ],
                              ),
                              children: List.generate(filteredFriends.length, (index) {
                                final friend = filteredFriends[index];
                                return _buildFriendTile(
                                  friend,
                                  index,
                                  searchQ: searchQ,
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            ),
          );
        },
      );
    },
  );
}

  Widget _buildSectionHeader(String title, {required int count, int bestFriendsCount = 0, bool isStar = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TXATheme.textPrimary),
          ),
          if (isStar) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TXATheme.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: TXATheme.primaryYellow),
                  const SizedBox(width: 4),
                  Text(
                    '$bestFriendsCount',
                    style: const TextStyle(fontSize: 12, color: TXATheme.primaryYellow, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String highlight, {bool isSubtitle = false}) {
    final baseStyle = isSubtitle
        ? const TextStyle(color: Colors.white54, fontSize: 12)
        : const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15);

    if (highlight.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    int start = 0;
    int indexOfHighlight;

    while ((indexOfHighlight = lowerText.indexOf(lowerHighlight, start)) != -1) {
      if (indexOfHighlight > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfHighlight)));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfHighlight, indexOfHighlight + highlight.length),
        style: const TextStyle(
          color: TXATheme.primaryYellow,
          fontWeight: FontWeight.w900,
        ),
      ));
      start = indexOfHighlight + highlight.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
    );
  }

  void _showFriendOptions(BuildContext context, Map<String, dynamic> friend) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final name = friend['name'] as String? ?? friend['username'] as String;
    final username = friend['username'] as String;
    final avatarEmoji = friend['avatar'] as String? ?? '👤';
    final avatarColorInt = friend['bgColor'] as int? ?? 0xFF607D8B;
    final avatarColor = Color(avatarColorInt);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Material(
        color: TXATheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: avatarColor.withAlpha(180),
                  child: Text(avatarEmoji, style: const TextStyle(fontSize: 20)),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(username, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              const Divider(color: Colors.white10),
              // Best friend toggle
              ListTile(
                leading: Icon(
                  friend['isBestFriend'] == true ? Icons.star_rounded : Icons.star_border_rounded,
                  color: friend['isBestFriend'] == true ? TXATheme.primaryYellow : Colors.white,
                ),
                title: Text(
                  friend['isBestFriend'] == true ? txaLang.getText('remove_best_friend') : txaLang.getText('add_best_friend'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await txaAuth.toggleBestFriend(friend['id']);
                  if (context.mounted) {
                    final isNowBest = txaAuth.friendsList.any((f) => f['id'] == friend['id'] && f['isBestFriend'] == true);
                    TXAToast.show(
                      context,
                      isNowBest
                          ? txaLang.getText('added_best_friend_success').replaceAll('%user%', name)
                          : txaLang.getText('removed_best_friend_success').replaceAll('%user%', name),
                      icon: isNowBest ? Icons.star_rounded : Icons.star_border_rounded,
                    );
                  }
                },
              ),
              const Divider(color: Colors.white10),
              // ─── Chế độ Cặp đôi ──────────────────────────────────────────
              Builder(
                builder: (context) {
                  final currentUser = txaAuth.currentUser;
                  final loveId = currentUser?.loveId;
                  final isLover = currentUser?.loverUsername == username;

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: txaAuth.listenIncomingLoveRequests(),
                    builder: (context, inviteSnapshot) {
                      final invites = inviteSnapshot.data ?? [];
                      // Find if this specific friend has sent an invitation
                      final myInvite = invites.where((inv) => inv['sender'] == username).toList();
                      final hasInviteFromThisFriend = myInvite.isNotEmpty;

                       String subtitleText = txaLang.getText('set_love_date');
                      if (isLover) {
                        subtitleText = txaLang.getText('love_status_coupled');
                      } else if (hasInviteFromThisFriend) {
                        subtitleText = txaLang.getText('love_status_pending_received');
                      }

                      return ListTile(
                        leading: Icon(
                          Icons.favorite_rounded,
                          color: isLover || hasInviteFromThisFriend ? const Color(0xFFF43F5E) : Colors.white,
                        ),
                        title: Text(
                          txaLang.getText('love_menu_title'),
                          style: TextStyle(
                            color: isLover || hasInviteFromThisFriend ? const Color(0xFFF43F5E) : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          subtitleText,
                          style: TextStyle(
                            color: hasInviteFromThisFriend ? const Color(0xFFF43F5E) : Colors.white60,
                            fontSize: 12,
                            fontWeight: hasInviteFromThisFriend ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context); // Close bottom sheet
                          if (isLover && loveId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TXALoveDashboardScreen(loveId: loveId),
                              ),
                            );
                          } else if (hasInviteFromThisFriend) {
                            final invite = myInvite.first;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TXALoveInvitationScreen(
                                  invitationId: invite['id'] as String,
                                  senderUsername: invite['sender'] as String,
                                  startDate: invite['startDate'] as String,
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TXALoveSetupScreen(preselectedUsername: username),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
              const Divider(color: Colors.white10),
              // Block option
              ListTile(
                leading: const Icon(Icons.block_rounded, color: TXATheme.statusRed),
                title: Text(
                  txaLang.getText('block_title'),
                  style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: TXATheme.cardBg,
                      title: Text(txaLang.getText('block_confirm_title').replaceAll('%user%', name)),
                      content: Text(txaLang.getText('block_confirm_desc')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(txaLang.getText('cancel'), style: const TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(txaLang.getText('block_title'), style: const TextStyle(color: TXATheme.statusRed)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await txaAuth.removeFriend(friend['id']);
                    if (context.mounted) {
                      TXAToast.show(
                        context,
                        txaLang.getText('blocked_user_success').replaceAll('%user%', name),
                        icon: Icons.block_rounded,
                        backgroundColor: TXATheme.statusRed,
                      );
                    }
                  }
                },
              ),
              const Divider(color: Colors.white10),
              // Delete option
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: TXATheme.statusRed),
                title: Text(
                  txaLang.getText('remove_friend'),
                  style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: TXATheme.cardBg,
                      title: Text(txaLang.getText('remove_friend_confirm_title').replaceAll('%user%', name)),
                      content: Text(txaLang.getText('remove_friend_confirm_desc')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(txaLang.getText('cancel'), style: const TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(txaLang.getText('remove_friend'), style: const TextStyle(color: TXATheme.statusRed)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await txaAuth.removeFriend(friend['id']);
                    if (context.mounted) {
                      TXAToast.show(
                        context,
                        txaLang.getText('unfriend_success').replaceAll('%user%', name),
                        icon: Icons.person_remove_rounded,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFriendBottomSheet(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final currentUser = txaAuth.currentUser;
    if (currentUser == null) return;

    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    
    // Sets of usernames to track friend status
    Set<String> sentUsernames = {};
    Set<String> incomingUsernames = {};

    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Fetch sent/incoming requests initially
            Future<void> fetchRequestStatus() async {
              try {
                final sentSnap = await FirebaseFirestore.instance
                    .collection('friend_requests')
                    .where('from', isEqualTo: currentUser.username)
                    .where('status', isEqualTo: 'pending')
                    .get();
                final incomingSnap = await FirebaseFirestore.instance
                    .collection('friend_requests')
                    .where('to', isEqualTo: currentUser.username)
                    .where('status', isEqualTo: 'pending')
                    .get();

                setModalState(() {
                  sentUsernames = sentSnap.docs.map((d) => d.data()['to'] as String).toSet();
                  incomingUsernames = incomingSnap.docs.map((d) => d.data()['from'] as String).toSet();
                });
              } catch (_) {}
            }

            // Call once when sheet loads
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (sentUsernames.isEmpty && incomingUsernames.isEmpty) {
                fetchRequestStatus();
              }
            });

            Timer? debounce;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                maxChildSize: 0.95,
                minChildSize: 0.5,
                expand: false,
                builder: (context, scrollController) {
                  return SafeArea(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            txaLang.getText('add_friend'),
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search box
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (val) {
                          if (debounce?.isActive ?? false) debounce?.cancel();
                          debounce = Timer(const Duration(milliseconds: 350), () async {
                            final q = val.trim();
                            if (q.isEmpty) {
                              setModalState(() {
                                searchResults = [];
                                isSearching = false;
                              });
                              return;
                            }
                            setModalState(() {
                              isSearching = true;
                            });

                            try {
                              final querySnapshot = await FirebaseFirestore.instance
                                  .collection('users')
                                  .limit(100)
                                  .get();

                              final cleanQ = q.toLowerCase().replaceAll('@', '');
                              final matched = querySnapshot.docs.map((doc) {
                                final data = doc.data();
                                data['id'] = doc.id;
                                return data;
                              }).where((u) {
                                final email = (u['email'] ?? '').toString().toLowerCase();
                                final username = (u['username'] ?? '').toString().toLowerCase().replaceAll('@', '');
                                return email.contains(cleanQ) || username.contains(cleanQ);
                              }).take(10).toList();

                              setModalState(() {
                                searchResults = matched;
                                isSearching = false;
                              });
                            } catch (_) {
                              setModalState(() {
                                isSearching = false;
                              });
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: txaLang.getText('search_friend_placeholder'),
                          hintStyle: TextStyle(color: TXATheme.textMuted, fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded, color: TXATheme.textMuted),
                          filled: true,
                          fillColor: Colors.white.withAlpha(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.content_paste_rounded, color: TXATheme.textMuted, size: 20),
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null) {
                                searchController.text = data!.text!;
                                searchController.selection = TextSelection.fromPosition(TextPosition(offset: searchController.text.length));
                                final q = data.text!.trim();
                                if (q.isEmpty) return;
                                setModalState(() {
                                  isSearching = true;
                                });
                                try {
                                  final querySnapshot = await FirebaseFirestore.instance
                                      .collection('users')
                                      .limit(100)
                                      .get();

                                  final cleanQ = q.toLowerCase().replaceAll('@', '');
                                  final matched = querySnapshot.docs.map((doc) {
                                    final data = doc.data();
                                    data['id'] = doc.id;
                                    return data;
                                  }).where((u) {
                                    final email = (u['email'] ?? '').toString().toLowerCase();
                                    final username = (u['username'] ?? '').toString().toLowerCase().replaceAll('@', '');
                                    return email.contains(cleanQ) || username.contains(cleanQ);
                                  }).take(10).toList();

                                  setModalState(() {
                                    searchResults = matched;
                                    isSearching = false;
                                  });
                                } catch (_) {
                                  setModalState(() {
                                    isSearching = false;
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: isSearching
                            ? const Center(
                                child: CircularProgressIndicator(color: TXATheme.primaryYellow),
                              )
                            : searchResults.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_search_rounded, color: Colors.white.withAlpha(20), size: 80),
                                        const SizedBox(height: 12),
                                        Text(
                                          txaLang.getText('search_start_hint'),
                                          style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    itemCount: searchResults.length,
                                    itemBuilder: (context, index) {
                                      final user = searchResults[index];
                                      final uUsername = user['username'] as String;
                                      final uAvatar = user['avatar'] as String? ?? '👤';
                                      final uColorStr = user['avatarBgColor'] as String? ?? '0xFF607D8B';
                                      final uColor = Color(int.tryParse(uColorStr) ?? 0xFF607D8B);

                                      final isMe = uUsername == currentUser.username;
                                      final isFriend = txaAuth.friendsList.any((f) => f['username'] == uUsername);
                                      final isSent = sentUsernames.contains(uUsername);
                                      final isIncoming = incomingUsernames.contains(uUsername);

                                      Widget trailingWidget;
                                      if (isMe) {
                                        trailingWidget = Text(txaLang.getText('friendship_me'), style: const TextStyle(color: Colors.white30));
                                      } else if (isFriend) {
                                        trailingWidget = Text(txaLang.getText('friendship_friends'), style: const TextStyle(color: Colors.white30));
                                      } else if (isSent || isIncoming) {
                                        trailingWidget = Text(txaLang.getText('friendship_pending'), style: const TextStyle(color: TXATheme.primaryYellow, fontWeight: FontWeight.bold, fontSize: 13));
                                      } else {
                                        trailingWidget = ElevatedButton(
                                          onPressed: () async {
                                            final res = await txaAuth.sendFriendRequest(uUsername);
                                            final success = res['success'] == true;
                                            if (context.mounted) {
                                              TXAToast.show(
                                                context,
                                                res['message'] ?? '',
                                                icon: success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                                backgroundColor: success ? null : TXATheme.statusRed,
                                              );
                                            }
                                            if (success) {
                                              setModalState(() {
                                                sentUsernames.add(uUsername);
                                              });
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: TXATheme.primaryYellow,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          ),
                                          child: Text(txaLang.getText('friendship_add'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                        );
                                      }

                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: uColor.withAlpha(180),
                                          child: Text(uAvatar, style: const TextStyle(fontSize: 20)),
                                        ),
                                        title: _buildHighlightedText(uUsername, searchController.text),
                                        subtitle: _buildHighlightedText(user['email'] ?? '', searchController.text, isSubtitle: true),
                                        trailing: trailingWidget,
                                      );
                                    },
                                  ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(txaLang.getText('my_username_label'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: currentUser.username));
                                HapticFeedback.mediumImpact();
                                TXAToast.show(context, txaLang.getText('username_copied').replaceAll('%user%', currentUser.username));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(10),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: TXATheme.primaryYellow.withAlpha(50)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentUser.username,
                                      style: const TextStyle(color: TXATheme.primaryYellow, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.copy_rounded, color: TXATheme.primaryYellow, size: 16),
                                  ],
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
            },
          ),
        );
      },
    );
  },
);
}

  Widget _buildInviteTile(
    String requestId,
    String name,
    String username,
    Map<String, dynamic> requestData,
    Set<String> processingRequestIds,
    bool isProcessingAll,
    StateSetter setModalState,
  ) {
    final txaLang = TXALanguage.instance;
    final isHighlighted = requestId == TXAAuthService.instance.highlightRequestId;
    final avatarEmoji = requestData['fromAvatar'] as String? ?? '👤';
    final avatarColorStr = requestData['fromAvatarColor'] as String? ?? '0xFF607D8B';
    final avatarColor = Color(int.tryParse(avatarColorStr) ?? 0xFF607D8B);

    final isThisProcessing = processingRequestIds.contains(requestId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TXATheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? TXATheme.primaryYellow : Colors.transparent,
          width: 2.0,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: TXATheme.primaryYellow.withAlpha(100),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: avatarColor.withAlpha(180),
            child: Text(avatarEmoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(username, style: TextStyle(color: TXATheme.textMuted, fontSize: 13)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isThisProcessing || isProcessingAll
                ? null
                : () async {
                    setModalState(() {
                      processingRequestIds.add(requestId);
                    });
                    try {
                      await TXAAuthService.instance.acceptFriendRequest(requestId, requestData);
                      if (mounted) {
                        TXAToast.show(
                          context,
                          TXALanguage.instance.getText('friend_added').replaceAll('%user%', name),
                          icon: Icons.people_alt_rounded,
                        );
                      }
                    } catch (e) {
                      debugPrint('accept error: $e');
                    } finally {
                      if (mounted) {
                        setModalState(() {
                          processingRequestIds.remove(requestId);
                        });
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: TXATheme.actionBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: isThisProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                  )
                : Text(txaLang.getText('accept'), style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: isThisProcessing || isProcessingAll
                ? null
                : () async {
                    setModalState(() {
                      processingRequestIds.add(requestId);
                    });
                    try {
                      await TXAAuthService.instance.declineFriendRequest(requestId);
                    } catch (e) {
                      debugPrint('decline error: $e');
                    } finally {
                      if (mounted) {
                        setModalState(() {
                          processingRequestIds.remove(requestId);
                        });
                      }
                    }
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: TXATheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(txaLang.getText('decline'), style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend, int index, {String searchQ = ''}) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final id = friend['id'] as String;
    final name = friend['name'] as String? ?? friend['username'] as String;
    final username = friend['username'] as String;
    final isBestFriend = friend['isBestFriend'] == true;
    
    final currentUser = txaAuth.currentUser;
    final isLover = currentUser?.loverUsername == username;
    
    final avatarEmoji = friend['avatar'] as String? ?? '👤';
    final avatarColorInt = friend['bgColor'] as int? ?? 0xFF607D8B;
    final avatarColor = Color(avatarColorInt);

    return Material(
      key: ValueKey(id),
      color: Colors.transparent,
      child: ListTile(
        onLongPress: () => _showFriendOptions(context, friend),
        leading: Stack(
          children: [
            TXAAvatarFrame(
              username: username,
              radius: 20,
              tier: isLover
                  ? TXAFriendTier.lover
                  : (isBestFriend ? TXAFriendTier.bestFriend : TXAFriendTier.normal),
              child: Container(
                color: avatarColor.withAlpha(180),
                child: Center(
                  child: Text(avatarEmoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: TXATheme.statusGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: TXATheme.background, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: _buildHighlightedText(name, searchQ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHighlightedText(username, searchQ, isSubtitle: true),
            if (isBestFriend)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: TXATheme.primaryYellow.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('⭐ ${txaLang.getText('best_friend')}', style: const TextStyle(color: TXATheme.primaryYellow, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            Builder(
              builder: (context) {
                if (isLover) {
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E).withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('💖 ${txaLang.getText('lover')}', style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 11, fontWeight: FontWeight.bold)),
                  );
                }

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: txaAuth.listenIncomingLoveRequests(),
                  builder: (context, incomingSnapshot) {
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: txaAuth.listenSentLoveRequests(),
                      builder: (context, sentSnapshot) {
                        final incoming = incomingSnapshot.data ?? [];
                        final sent = sentSnapshot.data ?? [];

                        final hasIncomingFromThisFriend = incoming.any((inv) => inv['sender'] == username);
                        final hasSentToThisFriend = sent.any((inv) => inv['receiver'] == username);

                        if (hasSentToThisFriend) {
                          return Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: TXATheme.actionBlue.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('🕓 ${txaLang.getText('love_invite_sent')}', style: const TextStyle(color: TXATheme.actionBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                          );
                        } else if (hasIncomingFromThisFriend) {
                          return Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E).withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('📬 Lời mời yêu chờ bạn trả lời', style: TextStyle(color: Color(0xFFF43F5E), fontSize: 11, fontWeight: FontWeight.bold)),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isBestFriend ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isBestFriend ? TXATheme.primaryYellow : TXATheme.textMuted,
              ),
              onPressed: () => TXAAuthService.instance.toggleBestFriend(id),
            ),
            const SizedBox(width: 4),
            Theme.of(context).platform == TargetPlatform.windows
                ? ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Icon(Icons.menu_rounded, color: TXATheme.textMuted),
                    ),
                  )
                : ReorderableDelayedDragStartListener(
                    index: index,
                    child: IconButton(
                      icon: Icon(Icons.menu_rounded, color: TXATheme.textMuted),
                      onPressed: () => _showFriendOptions(context, friend),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentInviteTile(String requestId, String toUsername, Map<String, dynamic> requestData) {
    final txaLang = TXALanguage.instance;
    final avatarEmoji = requestData['toAvatar'] as String? ?? '👤';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TXATheme.cardBg.withAlpha(128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TXATheme.cardBorder, width: 1.0),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: TXATheme.cardBorder,
            child: Text(avatarEmoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Row(
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: TXATheme.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Text(txaLang.getText('pending_acceptance'),
                        style: TextStyle(color: TXATheme.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              await TXAAuthService.instance.cancelFriendRequest(requestId);
              if (mounted) {
                TXAToast.show(
                  context,
                  txaLang.getText('request_cancelled'),
                  icon: Icons.delete_outline_rounded,
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: TXATheme.statusRed,
              side: const BorderSide(color: TXATheme.statusRed),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(txaLang.getText('cancel_request'), style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
