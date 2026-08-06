import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/txa_festival_manager.dart';
import '../widgets/txa_marquee.dart';
import '../widgets/txa_tet_countdown_widget.dart';
import '../widgets/txa_blur_dots_overlay.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_format.dart';
import '../services/txa_analytics.dart';
import '../services/txa_badword.dart';
import '../services/txa_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/txa_feed_service.dart';
import '../services/txa_google_play_services.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_network_image.dart';
import '../services/txa_weather_service.dart';

class AppMouseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class PhotoPreviewScreen extends StatefulWidget {
  final String? imagePath;
  final bool isRollcall;

  const PhotoPreviewScreen({super.key, this.imagePath, this.isRollcall = false});

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final bool _isPrivate = true;
  bool _isBlurOverlay = false;
  int _reviewRating = 5;
  String? _selectedMoodEmoji;
  String? _selectedCustomSticker;
  dynamic _selectedStickerIcon;
  Color? _selectedStickerColor;
  List<Color>? _selectedStickerGradient;
  Color? _selectedStickerTextColor;
  bool _isUploading = false;

  TXAWeatherData? _weatherData;
  bool _isFetchingWeather = false;

  Future<void> _getWeather({bool force = false}) async {
    if (_isFetchingWeather) return;
    setState(() {
      _isFetchingWeather = true;
    });
    try {
      final weather = await TXAWeatherService.instance.fetchCurrentWeather(forceRefresh: force);
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isFetchingWeather = false;
        });
        if (force) {
          TXAToast.show(
            context,
            TXALanguage.instance.getText('weather_updated_toast'),
            icon: Icons.thermostat_rounded,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingWeather = false;
        });
      }
    }
  }

  Map<String, dynamic> _getWeatherTheme(TXAWeatherData weather) {
    final code = weather.weatherCode;

    if (code == 0 || code == 1) {
      return {
        'gradient': [const Color(0xFFFF8F00), const Color(0xFFFFC107)],
        'textColor': Colors.black,
      };
    }
    if (code == 2 || code == 3 || code == 45 || code == 48) {
      return {
        'gradient': [const Color(0xFF37474F), const Color(0xFF607D8B)],
        'textColor': Colors.white,
      };
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return {
        'gradient': [const Color(0xFF1565C0), const Color(0xFF0288D1)],
        'textColor': Colors.white,
      };
    }
    if (code >= 95 && code <= 99) {
      return {
        'gradient': [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
        'textColor': Colors.white,
      };
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return {
        'gradient': [const Color(0xFF00838F), const Color(0xFF00ACC1)],
        'textColor': Colors.white,
      };
    }
    return {
      'gradient': [const Color(0xFFFF8F00), const Color(0xFFFFC107)],
      'textColor': Colors.black,
    };
  }

  List<Map<String, dynamic>> get _customizationSections {
    final isVi = TXALanguage.instance.currentLanguage == 'vi';
    final langCode = TXALanguage.instance.currentLanguage;
    final formattedTime = TXAFormat.formatTime(DateTime.now());
    final now = DateTime.now();
    final username = TXAAuthService.instance.currentUser?.username ?? '';

    final specialItems = <Map<String, dynamic>>[
      {
        'label': 'Snow ❄️ 👑',
        'color': const Color(0xFF42A5F5),
      },
      {
        'label': 'Snow ❄️ 👑',
        'color': const Color(0xFFD32F2F),
      },
    ];

    // Tết caption: Hiện cả năm trước Tết, ẩn sau Tết (sau ngày 6/2/2027)
    if (now.isBefore(DateTime(2027, 2, 7))) {
      specialItems.add({
        'label': '__tet_lunar_2027__',
        'displayText': TXAFestivalManager.getTetCountdownText(langCode, now),
        'color': const Color(0xFFD32F2F),
        'gradient': [const Color(0xFFD32F2F), const Color(0xFFFFC72C)],
        'textColor': Colors.white,
      });
    }

    // Tết wishes: Chỉ hiển thị trong mùng 1 đến mùng 5 Tết
    if (TXAFestivalManager.isMung1to5Tet(now)) {
      final activeTet = TXAFestivalManager.getActiveTetDate(now);
      final tetName = TXAFestivalManager.getTetNameForDate(activeTet, langCode);
      for (int i = 1; i <= 12; i++) {
        specialItems.add({
          'label': '__tet_wish_${i}__',
          'displayText': TXALanguage.instance.getText('tet_wish_$i')
              .replaceAll('%user%', username)
              .replaceAll('%name%', tetName),
          'color': const Color(0xFFD32F2F),
          'gradient': [const Color(0xFFD32F2F), const Color(0xFFFFC72C)],
          'textColor': Colors.white,
        });
      }
    }

    // 30/4 & 1/5 caption: Gần ngày mới hiện (25/4 đến 5/5)
    if (TXAFestivalManager.isNationalDayPeriod(now)) {
      specialItems.add({
        'label': '__holiday_30_4_1_5__',
        'displayText': TXAFestivalManager.getHolidayCaption('__holiday_30_4_1_5__', langCode),
        'color': const Color(0xFFD32F2F),
        'gradient': [const Color(0xFFD32F2F), const Color(0xFFFFC72C)],
        'textColor': Colors.white,
      });
    }

    // 2/9 caption: Gần ngày mới hiện (26/8 đến 3/9)
    if (TXAFestivalManager.isNationalDay29Period(now)) {
      specialItems.add({
        'label': '__holiday_2_9__',
        'displayText': TXAFestivalManager.getHolidayCaption('__holiday_2_9__', langCode),
        'color': const Color(0xFFD32F2F),
        'gradient': [const Color(0xFFD32F2F), const Color(0xFFFFC72C)],
        'textColor': Colors.white,
      });
    }

    // 20/11 caption: Gần ngày mới hiện (13/11 đến 21/11)
    if (TXAFestivalManager.isTeachersDayPeriod(now)) {
      specialItems.add({
        'label': '__holiday_20_11__',
        'displayText': TXAFestivalManager.getHolidayCaption('__holiday_20_11__', langCode),
        'color': const Color(0xFFEC407A),
        'gradient': [const Color(0xFFEC407A), const Color(0xFFAB47BC)],
        'textColor': Colors.white,
      });
    }

    // Cung hoàng đạo caption
    final dob = TXAAuthService.instance.currentUser?.dob ?? '';
    if (dob.isNotEmpty) {
      final zodiac = TXAFestivalManager.getZodiacInfo(dob);
      specialItems.add({
        'label': '__zodiac_${zodiac.key}__',
        'displayText': TXALanguage.instance.getText('zodiac_${zodiac.key}').replaceAll('%user%', username),
        'color': zodiac.baseColor,
        'gradient': zodiac.gradient,
        'textColor': Colors.white,
      });
    }

    return [
      {
        'title': isVi ? '✨ CƠ BẢN' : '✨ BASIC',
        'icon': Icons.auto_awesome_rounded,
        'items': [
          {
            'label': formattedTime,
            'icon': Icons.access_time_filled_rounded,
            'color': const Color(0xFF343238),
          },
          {
            'label': isVi ? 'Vị trí' : 'Location',
            'icon': Icons.location_on_outlined,
            'color': const Color(0xFF343238),
          },
          {
            'label': '__review__',
            'displayText': isVi ? '⭐ Review' : '⭐ Review',
            'icon': Icons.star_border_rounded,
            'gradient': [const Color(0xFFFF9100), const Color(0xFFFF3D00)],
          },
          {
            'label': isVi ? 'Streak' : 'Streak',
            'icon': Icons.local_fire_department_rounded,
            'color': const Color(0xFFFFC94A),
            'textColor': Colors.black,
          },
        ]
      },
      {
        'title': isVi ? '🎨 GỢI Ý THEME' : '🎨 THEME SUGGESTIONS',
        'icon': Icons.palette_rounded,
        'items': [
          {
            'label': isVi ? 'Đang học bài... 📚' : 'Studying... 📚',
            'color': const Color(0xFFD61CFF),
            'gradient': [const Color(0xFF7C4DFF), const Color(0xFFFF2DA8)],
          },
          {
            'label': isVi ? 'Đang chiến game 🎮' : 'Gaming Time 🎮',
            'gradient': [const Color(0xFF00E5FF), const Color(0xFF2979FF)],
          },
          {
            'label': isVi ? 'Cuối tuần vui vẻ 🎉' : 'Happy Weekend 🎉',
            'gradient': [const Color(0xFFFF4081), const Color(0xFFFFD54F)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Ngắm hoàng hôn 🌇' : 'Watching Sunset 🌇',
            'gradient': [const Color(0xFFFF5722), const Color(0xFFFFC107)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Đang ăn cơm... 🍚' : 'Eating... 🍚',
            'color': const Color(0xFFFF3F7F),
            'gradient': [const Color(0xFFFF7A18), const Color(0xFFFF1E8A)],
          },
          {
            'label': isVi ? 'Đi chơi thui... 🚗' : 'Going out... 🚗',
            'color': const Color(0xFFFF9D00),
            'gradient': [const Color(0xFFFF512F), const Color(0xFFFFD200)],
          },
          {
            'label': isVi ? 'Nhớ cậu... 💖' : 'Miss you... 💖',
            'color': const Color(0xFF35D6FF),
            'gradient': [const Color(0xFF42E695), const Color(0xFF3BB2FF)],
          },
          {
            'label': isVi ? 'Ngủ ngon nhé! 😴' : 'Good night! 😴',
            'color': const Color(0xFFFFC8C8),
            'textColor': Colors.black87,
          },
          {
            'label': isVi ? 'Cà phê sáng thui ☕' : 'Morning Coffee ☕',
            'gradient': [const Color(0xFFFF9100), const Color(0xFFFF5722)],
          },
          {
            'label': isVi ? 'Thức khuya chạy deadline 💻' : 'Late Night Work 💻',
            'gradient': [const Color(0xFF5E35B1), const Color(0xFF1E88E5)],
          },
          {
            'label': isVi ? 'Gym time sung sức 💪' : 'Workout Time 💪',
            'gradient': [const Color(0xFFFF1744), const Color(0xFFFF9100)],
          },
          {
            'label': isVi ? 'Trà sữa trân đường đen 🧋' : 'Boba Time 🧋',
            'gradient': [const Color(0xFF8D6E63), const Color(0xFFD7CCC8)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Thư giãn nghe nhạc 🎧' : 'Chill Vibes 🎧',
            'gradient': [const Color(0xFF00E5FF), const Color(0xFF1DE9B6)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Nấu ăn ngon chuẩn vị 🍳' : 'Cooking Master 🍳',
            'gradient': [const Color(0xFFFF6D00), const Color(0xFFFFAB00)],
          },
          {
            'label': isVi ? 'Dạo phố chiều mưa 🌧️' : 'Rainy Street Walk 🌧️',
            'gradient': [const Color(0xFF455A64), const Color(0xFF90A4AE)],
          },
          {
            'label': isVi ? 'Xem phim rạp hay cực 🍿' : 'Movie Night 🍿',
            'gradient': [const Color(0xFFD500F9), const Color(0xFF651FFF)],
          },
          {
            'label': isVi ? 'Chụp ảnh sống ảo 📸' : 'Aesthetic Shot 📸',
            'gradient': [const Color(0xFFF50057), const Color(0xFFFF4081)],
          },
          {
            'label': isVi ? 'Tán phét cùng cạ cứng 🗣️' : 'Chilling with BFFs 🗣️',
            'gradient': [const Color(0xFF00E676), const Color(0xFF00B0FF)],
          },
          {
            'label': isVi ? 'Nằm ươn lướt phone 📱' : 'Lazy Bed Time 📱',
            'gradient': [const Color(0xFFAA00FF), const Color(0xFFEA80FC)],
          },
          {
            'label': isVi ? 'Chữa lành tâm hồn 🍃' : 'Healing Soul 🍃',
            'gradient': [const Color(0xFF4CAF50), const Color(0xFF81C784)],
          },
        ]
      },
      {
        'title': isVi ? '⭐ CAPTION ĐẶC BIỆT' : '⭐ SPECIAL CAPTION',
        'icon': Icons.star_rounded,
        'items': specialItems,
      },
      {
        'title': isVi ? '🎭 TRANG TRÍ TỪ LOCKET' : '🎭 DECORATIONS FROM LOCKET',
        'icon': Icons.palette_rounded,
        'items': [
          {
            'label': isVi ? '☘️ St. Patty\'s Day' : '☘️ St. Patty\'s Day',
            'color': const Color(0xFF12A64A),
          },
          {
            'label': isVi ? '❄️ \'Tis the season' : '❄️ \'Tis the season',
            'color': const Color(0xFF64B5F6),
          },
          {
            'label': isVi ? '💟 Tình yêu của mình' : '💟 Our Love',
            'color': const Color(0xFFE91E63),
          },
          {
            'label': isVi ? '🌸 Mùa hoa nở rộ' : '🌸 Blooming Season',
            'gradient': [const Color(0xFFF48FB1), const Color(0xFFF06292)],
          },
          {
            'label': isVi ? '🎃 Đêm hội Halloween' : '🎃 Spooky Halloween',
            'gradient': [const Color(0xFFFF6D00), const Color(0xFF37474F)],
          },
          {
            'label': isVi ? '🎆 Pháo hoa rực rỡ' : '🎆 Sparkling Fireworks',
            'gradient': [const Color(0xFFFF1744), const Color(0xFFFFEA00)],
          },
          {
            'label': isVi ? '☀️ Mùa hè rực nắng' : '☀️ Sunny Summer',
            'gradient': [const Color(0xFFFFAB00), const Color(0xFFFF3D00)],
          },
          {
            'label': isVi ? '🍁 Mùa thu lá bay' : '🍁 Autumn Leaf Fall',
            'gradient': [const Color(0xFFD84315), const Color(0xFFFF8F00)],
          },
          {
            'label': isVi ? '🎈 Tiệc sinh nhật vui' : '🎈 Birthday Party',
            'gradient': [const Color(0xFFE91E63), const Color(0xFFFF9800)],
          },
          {
            'label': isVi ? '🍾 Tiệc mừng thành công' : '🍾 Celebration Time',
            'gradient': [const Color(0xFFFFD700), const Color(0xFFFFAB00)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? '🏖️ Nghỉ mát bãi biển' : '🏖️ Beach Vacation',
            'gradient': [const Color(0xFF00B0FF), const Color(0xFF00E5FF)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? '🏕️ Cắm trại đêm sao' : '🏕️ Starlight Camping',
            'gradient': [const Color(0xFF1A237E), const Color(0xFF4A148C)],
          },
          {
            'label': isVi ? '🎁 Quà tặng bất ngờ' : '🎁 Surprise Gift',
            'gradient': [const Color(0xFFEC407A), const Color(0xFFAB47BC)],
          },
          {
            'label': isVi ? '🎡 Công viên giải trí' : '🎡 Theme Park Fun',
            'gradient': [const Color(0xFFFF4081), const Color(0xFF7C4DFF)],
          },
          {
            'label': isVi ? '🧸 Góc nhỏ bình yên' : '🧸 Cozy Corner',
            'gradient': [const Color(0xFFA1887F), const Color(0xFF8D6E63)],
          },
        ]
      },
      {
        'title': isVi ? '☕ ĐỜI THƯỜNG & HẰNG NGÀY' : '☕ DAILY VIBES',
        'icon': Icons.wb_sunny_rounded,
        'items': [
          {
            'label': isVi ? 'Sáng thức giấc xinh tươi 🌅' : 'Fresh Morning 🌅',
            'gradient': [const Color(0xFFFF9800), const Color(0xFFFFC107)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Hết pin năng lượng 🔋' : 'Low Battery 🔋',
            'color': const Color(0xFFD32F2F),
          },
          {
            'label': isVi ? 'Đang nạp năng lượng 🔌' : 'Recharging Energy 🔌',
            'gradient': [const Color(0xFF00E676), const Color(0xFF69F0AE)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Cuối tuần xả xì trét 🎉' : 'Weekend Party 🎉',
            'gradient': [const Color(0xFFFF1744), const Color(0xFFD500F9)],
          },
          {
            'label': isVi ? 'Thứ hai là ngày đầu tuần 🗓️' : 'Monday Mood 🗓️',
            'color': const Color(0xFF5C6BC0),
          },
          {
            'label': isVi ? 'Phút giây yên bình 🕊️' : 'Peaceful Moment 🕊️',
            'gradient': [const Color(0xFF80DEEA), const Color(0xFF4DD0E1)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Đói bụng quá đi thôi 🍔' : 'Super Hungry 🍔',
            'gradient': [const Color(0xFFFF3D00), const Color(0xFFFF9100)],
          },
          {
            'label': isVi ? 'Trời đẹp rủ nhau đi chơi 🌤️' : 'Beautiful Weather 🌤️',
            'gradient': [const Color(0xFF29B6F6), const Color(0xFF81D4FA)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Trút bỏ mọi lo âu 💆' : 'Stress Free 💆',
            'gradient': [const Color(0xFFAED581), const Color(0xFF81C784)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Niềm vui nho nhỏ 🥰' : 'Simple Joy 🥰',
            'gradient': [const Color(0xFFFF80AB), const Color(0xFFFF4081)],
          },
          {
            'label': isVi ? 'Một ngày bận rộn ⏳' : 'Busy Day ⏳',
            'color': const Color(0xFF78909C),
          },
          {
            'label': isVi ? 'Gió lạnh đầu mùa 🌬️' : 'Chilly Breeze 🌬️',
            'gradient': [const Color(0xFF90CAF9), const Color(0xFF64B5F6)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Cuộc sống ngọt ngào 🍯' : 'Sweet Life 🍯',
            'gradient': [const Color(0xFFFFC107), const Color(0xFFFF8F00)],
            'textColor': Colors.black,
          },
        ]
      },
      {
        'title': isVi ? '🎧 MOOD & CẢM XÚC' : '🎧 MOOD & EMOTIONS',
        'icon': Icons.sentiment_satisfied_alt_rounded,
        'items': [
          {
            'label': isVi ? 'Vui vẻ không quạu 😊' : 'Keep Smiling 😊',
            'gradient': [const Color(0xFFFFEB3B), const Color(0xFFFFC107)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Suy tư mộng mơ 💭' : 'Daydreaming 💭',
            'gradient': [const Color(0xFFB388FF), const Color(0xFF7C4DFF)],
          },
          {
            'label': isVi ? 'Tràn đầy tự tin 🔥' : 'Pure Confidence 🔥',
            'gradient': [const Color(0xFFFF3D00), const Color(0xFFDD2C00)],
          },
          {
            'label': isVi ? 'Ngập tràn yêu thương ❤️' : 'Full of Love ❤️',
            'gradient': [const Color(0xFFFF1744), const Color(0xFFF50057)],
          },
          {
            'label': isVi ? 'Thèm đi du lịch ✈️' : 'Wanderlust ✈️',
            'gradient': [const Color(0xFF00B0FF), const Color(0xFF304FFE)],
          },
          {
            'label': isVi ? 'Bình tĩnh sống 🧘' : 'Stay Calm 🧘',
            'gradient': [const Color(0xFF26A69A), const Color(0xFF80CBC4)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Đang chốt đơn 🛍️' : 'Shopping Spree 🛍️',
            'gradient': [const Color(0xFFE91E63), const Color(0xFFFF4081)],
          },
          {
            'label': isVi ? 'Lắng nghe con tim 🎶' : 'Listen to Heart 🎶',
            'gradient': [const Color(0xFF7C4DFF), const Color(0xFF651FFF)],
          },
          {
            'label': isVi ? 'Muốn đi ngủ ngay 💤' : 'Need Sleep 💤',
            'color': const Color(0xFF3F51B5),
          },
          {
            'label': isVi ? 'Nụ cười tỏa nắng ☀️' : 'Radiant Smile ☀️',
            'gradient': [const Color(0xFFFFD600), const Color(0xFFFF9100)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Không gian riêng tư 🤫' : 'My Private Space 🤫',
            'gradient': [const Color(0xFF37474F), const Color(0xFF263238)],
          },
          {
            'label': isVi ? 'Cực kỳ may mắn 🍀' : 'Super Lucky 🍀',
            'gradient': [const Color(0xFF00C853), const Color(0xFF64DD17)],
            'textColor': Colors.black,
          },
          {
            'label': isVi ? 'Tuổi trẻ rực rỡ ✨' : 'Forever Young ✨',
            'gradient': [const Color(0xFFFFD700), const Color(0xFFFF4081)],
          },
        ]
      },
    ];
  }

  // Voice Recording state (15s Countdown)
  bool _isRecordingVoice = false;
  int _voiceSeconds = 15;
  Timer? _voiceTimer;
  String? _recordedVoicePath;

  // Location state (GMS Services)
  bool _isLocationPermissionGranted = false;
  bool _isFetchingLocation = false;

  // Multi-select recipient selection state
  Set<String> _selectedFriendIds = {'all'};

  List<Map<String, dynamic>> get _friendsData => TXAAuthService.instance.friendsList;

  List<Map<String, dynamic>> get _bestFriends => _friendsData.where((f) => f['isBestFriend'] == true).toList();
  List<Map<String, dynamic>> get _lovers {
    final loverUsername = TXAAuthService.instance.currentUser?.loverUsername;
    if (loverUsername == null) return [];
    return _friendsData.where((f) => f['username'] == loverUsername).toList();
  }

  bool get _isAllSelected => _selectedFriendIds.contains('all');

  bool get _isBestFriendsGroupSelected =>
      _selectedFriendIds.contains('best_friends') ||
      (_bestFriends.isNotEmpty &&
          _bestFriends.every((f) => _selectedFriendIds.contains(f['id'])) &&
          _selectedFriendIds.every((id) => id == 'best_friends' || _bestFriends.any((f) => f['id'] == id)));

  bool get _isLoverGroupSelected =>
      _selectedFriendIds.contains('lover') ||
      (_lovers.isNotEmpty &&
          _lovers.every((f) => _selectedFriendIds.contains(f['id'])) &&
          _selectedFriendIds.every((id) => id == 'lover' || _lovers.any((f) => f['id'] == id)));

  bool get _isPrivateGroupSelected => _selectedFriendIds.contains('private');

  void _onSelectAllGroup() {
    setState(() {
      _selectedFriendIds = {'all'};
    });
  }

  void _onSelectPrivateGroup() {
    setState(() {
      _selectedFriendIds = {'private'};
    });
  }

  void _onSelectBestFriendsGroup() {
    setState(() {
      if (_isBestFriendsGroupSelected) {
        _selectedFriendIds.removeWhere((id) => id == 'best_friends' || _bestFriends.any((f) => f['id'] == id));
        if (_selectedFriendIds.isEmpty) _selectedFriendIds = {'all'};
      } else {
        // Clear all and select ONLY best friends
        _selectedFriendIds.clear();
        for (var f in _bestFriends) {
          _selectedFriendIds.add(f['id'] as String);
        }
      }
    });
  }

  void _onSelectLoverGroup() {
    setState(() {
      if (_isLoverGroupSelected) {
        _selectedFriendIds.removeWhere((id) => id == 'lover' || _lovers.any((f) => f['id'] == id));
        if (_selectedFriendIds.isEmpty) _selectedFriendIds = {'all'};
      } else {
        // Clear all and select ONLY lovers
        _selectedFriendIds.clear();
        for (var f in _lovers) {
          _selectedFriendIds.add(f['id'] as String);
        }
      }
    });
  }

  void _toggleFriendSelection(String friendId) {
    setState(() {
      _selectedFriendIds.remove('all');
      _selectedFriendIds.remove('private');
      _selectedFriendIds.remove('best_friends');
      _selectedFriendIds.remove('lover');

      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }

      if (_selectedFriendIds.isEmpty) {
        _selectedFriendIds = {'all'};
      }
    });
  }

  AudioRecorder? _audioRecorder;
  AudioPlayer? _audioPlayer;
  bool _isPlayingVoice = false;

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenPhotoPreview);
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _audioPlayer?.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingVoice = false;
        });
      }
    });
    _captionFocusNode.addListener(() {
      setState(() {});
    });
    _checkAndAutoFetchLocation();
    _getWeather();
  }

  void _checkAndAutoFetchLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final isGranted = prefs.getBool('txa_location_permission_granted') ?? false;
    if (isGranted) {
      _isLocationPermissionGranted = true;
      _getGMSLocation(applyAsSticker: false);
    }
  }

  @override
  void dispose() {
    _audioRecorder?.dispose();
    _audioPlayer?.dispose();
    _captionController.dispose();
    _captionFocusNode.dispose();
    _pageController.dispose();
    _voiceTimer?.cancel();
    super.dispose();
  }

  void _startVoiceRecording() async {
    if (_isRecordingVoice) return;

    final hasPermission = await _audioRecorder?.hasPermission() ?? false;
    if (!hasPermission) {
      if (mounted) {
        final txaLang = TXALanguage.instance;
        TXAToast.show(context, txaLang.getText('mic_permission_denied'), icon: Icons.mic_off_rounded);
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder?.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filePath,
    );

    setState(() {
      _isRecordingVoice = true;
      _voiceSeconds = 15;
      _recordedVoicePath = filePath;
    });

    _voiceTimer?.cancel();
    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_voiceSeconds > 1) {
        setState(() {
          _voiceSeconds--;
        });
      } else {
        _stopVoiceRecording();
      }
    });
  }

  void _stopVoiceRecording() async {
    _voiceTimer?.cancel();
    final realPath = await _audioRecorder?.stop();
    final txaLang = TXALanguage.instance;

    setState(() {
      _isRecordingVoice = false;
      if (realPath != null && realPath.isNotEmpty) {
        _recordedVoicePath = realPath;
      }
    });

    if (mounted) {
      TXAToast.show(
        context,
        txaLang.getText('voice_recording_done').replaceAll('%sec%', '${15 - _voiceSeconds}'),
        icon: Icons.mic_rounded,
      );
    }
  }

  void _togglePlayVoice() async {
    if (_recordedVoicePath == null) return;

    if (_isPlayingVoice) {
      await _audioPlayer?.stop();
      setState(() => _isPlayingVoice = false);
    } else {
      if (_recordedVoicePath!.startsWith('assets/')) {
        await _audioPlayer?.play(AssetSource(_recordedVoicePath!.replaceFirst('assets/', '')));
      } else {
        await _audioPlayer?.play(DeviceFileSource(_recordedVoicePath!));
      }
      setState(() => _isPlayingVoice = true);
    }
  }

  void _getGMSLocation({bool applyAsSticker = true}) async {
    if (_isFetchingLocation) return;
    final txaLang = TXALanguage.instance;

    setState(() {
      _isFetchingLocation = true;
    });

    // 1. Get position based on granted permission
    if (!_isLocationPermissionGranted) {
      await Future.delayed(const Duration(milliseconds: 400));
      _isLocationPermissionGranted = true;
      if (mounted) {
        TXAToast.show(
          context,
          txaLang.getText('location_permission_granted'),
          icon: Icons.security_rounded,
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('txa_location_permission_granted', true);

    // 2. GMS services get exact location
    final String locationResult = await TXAGooglePlayServices.instance.getCurrentLocation();

    if (mounted) {
      setState(() {
        _isFetchingLocation = false;

        if (applyAsSticker) {
          _selectedCustomSticker = locationResult;
          _selectedStickerColor = const Color(0xFF343238); // Grey background
          _selectedStickerGradient = null;
          _selectedStickerTextColor = const Color(0xFFD6D6D6); // Grey caption text
          _selectedStickerIcon = Icons.location_on_rounded;
        }
      });

      TXAToast.show(
        context,
        txaLang.getText('gms_location_fetched_toast').replaceAll('%location%', locationResult),
        icon: Icons.location_on_rounded,
        backgroundColor: const Color(0xFF343238),
      );
    }
  }

  Future<void> _onSend() async {
    if (_isUploading) return;
    FocusScope.of(context).unfocus();

    final caption = _captionController.text.trim();
    final txaLang = TXALanguage.instance;
    final txaFormat = TXAFormat.instance;
    final currentUser = TXAAuthService.instance.currentUser;

    final detectedBadWord = TXABadWord.findFirstBadWord(caption);
    if (detectedBadWord != null) {
      // DO NOT CLOSE PREVIEW SCREEN! Show red toast immediately.
      TXAToast.show(
        context,
        txaLang.getText('bad_word_error').replaceAll('%word%', detectedBadWord),
        icon: Icons.block_rounded,
        backgroundColor: TXATheme.statusRed,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Simulated network/service post creation
      await Future.delayed(const Duration(milliseconds: 600));

      final List<String> recipientList = [];
      if (_selectedFriendIds.contains('all')) {
        recipientList.add('all');
      } else if (_selectedFriendIds.contains('private')) {
        recipientList.add('private');
      } else {
        for (var id in _selectedFriendIds) {
          if (id == 'best_friends') {
            recipientList.add('best_friends');
          } else if (id == 'lover') {
            recipientList.add('lover');
          } else {
            final friend = _friendsData.firstWhere(
              (f) => f['id'] == id,
              orElse: () => <String, dynamic>{},
            );
            if (friend.containsKey('username')) {
              recipientList.add(friend['username'] as String);
            }
          }
        }
      }

      final formattedTime = TXAFormat.formatTime(DateTime.now());

      int? voiceDuration;
      if (_recordedVoicePath != null && _currentPage == 1) {
        voiceDuration = 15 - _voiceSeconds;
        if (voiceDuration < 1) voiceDuration = 1;
      }

      String finalCaption = caption;
      String? finalMoodEmoji = _selectedCustomSticker == '__review__'
          ? '__review_${_reviewRating}__'
          : (_selectedMoodEmoji ?? _selectedCustomSticker ?? '');
      Color? finalStickerColor = _selectedStickerColor;
      List<Color>? finalStickerGradient = _selectedStickerGradient;
      Color? finalStickerTextColor = _selectedStickerTextColor;

      if (_currentPage == 2) {
        final locText = (_selectedCustomSticker != null && _selectedCustomSticker!.startsWith('📍'))
            ? _selectedCustomSticker!
            : (txaLang.currentLanguage == 'vi' ? '📍 Hà Nội, Việt Nam' : '📍 Hanoi, Vietnam');
        finalCaption = caption.isNotEmpty ? '$locText $caption' : locText;
        finalMoodEmoji = locText;
        finalStickerColor = const Color(0xFF343238);
        finalStickerGradient = null;
        finalStickerTextColor = const Color(0xFFD6D6D6);
      } else if (_currentPage == 3) {
        final w = _weatherData ?? TXAWeatherData(
          temperature: 25.0,
          tempString: '25°C',
          emoji: '🌤️',
          label: '🌤️ 25°C',
          weatherCode: 2,
          isDay: true,
          timestamp: DateTime.now(),
        );
        final theme = _getWeatherTheme(w);
        final weatherLabel = '${w.emoji} ${w.tempString}';
        finalCaption = caption.isNotEmpty ? '$weatherLabel • $caption' : weatherLabel;
        finalMoodEmoji = weatherLabel;
        finalStickerGradient = (theme['gradient'] as List<dynamic>).cast<Color>();
        finalStickerTextColor = theme['textColor'] as Color;
      }

      final String effectiveSenderAvatar = (currentUser?.avatar != null && currentUser!.avatar.startsWith('http'))
          ? currentUser.avatar
          : (currentUser?.googlePhotoUrl != null && currentUser!.googlePhotoUrl!.startsWith('http'))
              ? currentUser.googlePhotoUrl!
              : (currentUser?.avatar ?? '🦊');

      await TXAFeedService.instance.createPost(
        senderUsername: currentUser?.username ?? '@tienndaii19',
        senderAvatar: effectiveSenderAvatar,
        senderAvatarColor: currentUser?.avatarBgColor ?? '0xFFF57C00',
        photoPath: widget.imagePath ?? '',
        caption: finalCaption,
        moodEmoji: finalMoodEmoji,
        stickerBgColor: finalStickerColor != null
            ? '0x${finalStickerColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}'
            : null,
        stickerGradient: finalStickerGradient
            ?.map((c) => '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}')
            .join(','),
        stickerTextColor: finalStickerTextColor != null
            ? '0x${finalStickerTextColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}'
            : null,
        aspectRatio: txaFormat.aspectRatio,
        timestampText: formattedTime,
        recipients: recipientList,
        voicePath: _currentPage == 1 ? _recordedVoicePath : null,
        voiceDuration: voiceDuration,
        isBlurOverlay: _isBlurOverlay,
        isRollcall: widget.isRollcall,
      );

      if (mounted) {
        TXAToast.show(context, txaLang.getText('photo_sent'), icon: Icons.send_rounded);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        TXAToast.show(
          context,
          txaLang.getText('upload_error').replaceAll('%error%', '$e'),
          icon: Icons.error_outline_rounded,
          backgroundColor: TXATheme.statusRed,
        );
      }
    }
  }

  void _onSave() {
    final txaLang = TXALanguage.instance;
    TXAToast.show(context, txaLang.getText('photo_saved'), icon: Icons.download_rounded);
  }

  void _showEmojiPicker(BuildContext context) {
    final txaLang = TXALanguage.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TXATheme.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    setState(() {
                      _selectedMoodEmoji = emoji.emoji;
                      _selectedCustomSticker = null;
                      _selectedStickerIcon = null;
                      _selectedStickerColor = Colors.black.withAlpha(180);
                      _selectedStickerGradient = null;
                      _selectedStickerTextColor = Colors.white;
                    });
                    Navigator.pop(context);
                    TXAToast.show(
                      context,
                      txaLang.getText('mood_selected').replaceAll('%emoji%', emoji.emoji),
                      icon: Icons.sentiment_satisfied_alt_rounded,
                    );
                  },
                  config: Config(
                    height: 280,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      backgroundColor: TXATheme.cardBg,
                      columns: 7,
                      emojiSizeMax: 28,
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      backgroundColor: TXATheme.background,
                      iconColorSelected: TXATheme.primaryYellow,
                      indicatorColor: TXATheme.primaryYellow,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomizationOptionsDialog(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final isVi = txaLang.currentLanguage == 'vi';
    showModalBottomSheet(
      context: context,
      backgroundColor: TXATheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TXATheme.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sentiment_satisfied_alt_rounded, color: TXATheme.primaryYellow),
                title: Text(
                  isVi ? 'Chọn Emoji cảm xúc' : 'Choose Mood Emoji',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEmojiPicker(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF42A5F5)),
                title: Text(
                  isVi ? 'Tùy chỉnh nhãn dán' : 'Customize Sticker',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomizationSheet(context);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showCustomizationSheet(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final isVi = txaLang.currentLanguage == 'vi';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setModalState) {
            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.7,
              decoration: BoxDecoration(
                color: TXATheme.cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isVi ? 'Tùy chỉnh' : 'Customize',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(builderContext),
                          icon: const Icon(Icons.close_rounded, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._customizationSections.map((section) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 5, bottom: 12),
                                    child: Row(
                                      children: [
                                        Icon(section['icon'] as IconData, color: Colors.white38, size: 14),
                                        const SizedBox(width: 8),
                                        Text(
                                          section['title'] as String,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (section['items'] as List).map<Widget>((item) {
                                      final labelText = item['label'] as String;
                                      final displayText = item['displayText'] as String? ?? labelText;
                                      final Color? itemColor = item['color'] as Color?;

                                      if (labelText == '__tet_lunar_2027__') {
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedMoodEmoji = null;
                                              _selectedCustomSticker = labelText;
                                              _selectedStickerColor = itemColor ?? const Color(0xFFD32F2F);
                                              _selectedStickerGradient = item['gradient'] as List<Color>?;
                                              _selectedStickerTextColor = item['textColor'] as Color? ?? Colors.white;
                                              _selectedStickerIcon = item['icon'];
                                            });
                                            if (_pageController.hasClients) {
                                              _pageController.animateToPage(
                                                0,
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                            Navigator.pop(builderContext);
                                            TXAToast.show(
                                              context,
                                              isVi ? 'Đã áp dụng nhãn dán!' : 'Sticker applied!',
                                              icon: Icons.check_circle_rounded,
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: itemColor ?? const Color(0xFFD32F2F),
                                              gradient: item['gradient'] != null
                                                  ? LinearGradient(colors: item['gradient'] as List<Color>)
                                                  : null,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: TXATetCountdownWidget(
                                              style: TextStyle(
                                                color: item['textColor'] as Color? ?? Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      return _buildModernPill(
                                        item['icon'],
                                        displayText,
                                        itemColor,
                                        textColor: item['textColor'] as Color? ?? Colors.white,
                                        gradient: item['gradient'] as List<Color>?,
                                        onSelect: (label, color, gradient, textColor, icon) {
                                          setState(() {
                                            _selectedMoodEmoji = null;
                                            _selectedCustomSticker = labelText;
                                            _selectedStickerColor = color;
                                            _selectedStickerGradient = gradient;
                                            _selectedStickerTextColor = textColor;
                                            _selectedStickerIcon = icon;
                                          });
                                          if (_pageController.hasClients) {
                                            _pageController.animateToPage(
                                              0,
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                          Navigator.pop(builderContext);
                                          TXAToast.show(
                                            context,
                                            isVi ? 'Đã áp dụng nhãn dán!' : 'Sticker applied!',
                                            icon: Icons.check_circle_rounded,
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernPill(
    dynamic icon,
    String text,
    Color? color, {
    Color textColor = Colors.white,
    List<Color>? gradient,
    required Function(String, Color?, List<Color>?, Color, dynamic) onSelect,
  }) {
    final effectiveColor = color ?? (gradient != null && gradient.isNotEmpty ? gradient.first : const Color(0xFF343238));
    return GestureDetector(
      onTap: () => onSelect(text, effectiveColor, gradient, textColor, icon),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: gradient == null ? effectiveColor : null,
          gradient: gradient == null
              ? null
              : LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              if (icon is IconData)
                Icon(icon, color: textColor.withValues(alpha: 0.9), size: 18)
              else
                Text(icon.toString(), style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaFormat = TXAFormat.instance;
    final username = TXAAuthService.instance.currentUser?.username ?? '';
    final activeTet = TXAFestivalManager.getActiveTetDate(DateTime.now());
    final tetName = TXAFestivalManager.getTetNameForDate(activeTet, txaLang.currentLanguage);
    final isSquare = txaFormat.aspectRatio == '1:1';
    final formattedTime = TXAFormat.formatTime(DateTime.now());

    return AnimatedBuilder(
      animation: Listenable.merge([txaLang, txaFormat]),
      builder: (context, _) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: TXATheme.background,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 44),
                      Text(
                        txaLang.getText('send_to'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: TXATheme.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: _onSave,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: const Icon(
                            Icons.file_download_outlined,
                            color: TXATheme.textPrimary,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Photo Viewfinder Frame with Swipeable Pages (Page 0: Caption, Page 1: Voice)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 350,
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: AspectRatio(
                        aspectRatio: isSquare ? 1.0 : 3 / 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                          child: PageView(
                            controller: _pageController,
                            scrollBehavior: AppMouseScrollBehavior(),
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            children: [
                              // --- PAGE 0: Text Caption View (xem trước.png) ---
                              Stack(
                                alignment: Alignment.center,
                                fit: StackFit.expand,
                                children: [
                                  // Captured Image
                                  (() {
                                    final mainImage = widget.imagePath != null && File(widget.imagePath!).existsSync()
                                        ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                                        : Container(
                                            color: const Color(0xFF1C1C26),
                                            child: const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.image_rounded,
                                                    size: 64,
                                                    color: TXATheme.primaryYellow,
                                                  ),
                                                  SizedBox(height: 10),
                                                  Text(
                                                    'Army Captured Photo',
                                                    style: TextStyle(
                                                      color: TXATheme.textSecondary,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                    if (_isBlurOverlay) {
                                      return TXABlurDotsOverlay(
                                        blur: 15.0,
                                        child: mainImage,
                                      );
                                    }
                                    return mainImage;
                                  })(),



                                  // Privacy Eye Toggle
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isBlurOverlay = !_isBlurOverlay;
                                        });
                                        TXAToast.show(
                                          context,
                                          txaLang.getText(_isBlurOverlay ? 'blur_overlay_enabled' : 'blur_overlay_disabled'),
                                          icon: _isBlurOverlay ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        );
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(128),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isBlurOverlay ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Timestamp Overlay
                                  if (txaFormat.showTimestamp)
                                    Positioned(
                                      top: 14,
                                      left: 14,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(128),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          formattedTime,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Bottom Center: Sticker Pill OR Text Caption Input
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    bottom: 16.0,
                                    left: 20,
                                    right: 20,
                                    child: (_selectedMoodEmoji != null || _selectedCustomSticker != null)
                                        // --- Sticker/Emoji Pill (thay thế ô caption khi có nhãn dán) ---
                                        ? (_selectedCustomSticker == '__review__'
                                            ? Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: _selectedStickerGradient == null
                                                      ? (_selectedStickerColor ?? const Color(0xFFFF9100))
                                                      : null,
                                                  gradient: _selectedStickerGradient != null
                                                      ? LinearGradient(
                                                          colors: _selectedStickerGradient!,
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        )
                                                      : const LinearGradient(
                                                          colors: [Color(0xFFFF9100), Color(0xFFFF3D00)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                  borderRadius: BorderRadius.circular(26),
                                                  border: Border.all(color: Colors.white30, width: 1.2),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withAlpha(120),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        const SizedBox(width: 20),
                                                        FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: List.generate(5, (starIdx) {
                                                              final starVal = starIdx + 1;
                                                              final isFilled = starVal <= _reviewRating;
                                                              return GestureDetector(
                                                                onTap: () {
                                                                  setState(() {
                                                                    _reviewRating = starVal;
                                                                  });
                                                                },
                                                                child: Padding(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                                                  child: Icon(
                                                                    isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                                                                    color: isFilled ? const Color(0xFFFFD700) : Colors.white60,
                                                                    size: 24,
                                                                  ),
                                                                ),
                                                              );
                                                            }),
                                                          ),
                                                        ),
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              _selectedCustomSticker = null;
                                                              _selectedMoodEmoji = null;
                                                            });
                                                          },
                                                          child: Container(
                                                            padding: const EdgeInsets.all(2),
                                                            decoration: const BoxDecoration(
                                                              color: Colors.black26,
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        const Text(
                                                          '“',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 28,
                                                            fontWeight: FontWeight.bold,
                                                            height: 0.9,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: TextField(
                                                            controller: _captionController,
                                                            focusNode: _captionFocusNode,
                                                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                                            textAlign: TextAlign.center,
                                                            inputFormatters: [
                                                              LengthLimitingTextInputFormatter(
                                                                (TXAAuthService.instance.currentUser?.role == 'admin') ? 500 : 50,
                                                              ),
                                                            ],
                                                            decoration: const InputDecoration(
                                                              hintText: '.....',
                                                              hintStyle: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.bold),
                                                              border: InputBorder.none,
                                                              isDense: true,
                                                              contentPadding: EdgeInsets.zero,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        const Text(
                                                          '”',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 28,
                                                            fontWeight: FontWeight.bold,
                                                            height: 0.9,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : GestureDetector(
                                                onTap: () {
                                                  // Bấm vào nhãn dán -> xoá và quay về ô nhập chữ
                                                  setState(() {
                                                    _selectedMoodEmoji = null;
                                                    _selectedCustomSticker = null;
                                                    _selectedStickerIcon = null;
                                                    _selectedStickerColor = null;
                                                    _selectedStickerGradient = null;
                                                    _selectedStickerTextColor = null;
                                                  });
                                                },
                                                child: Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: _selectedStickerGradient == null
                                                        ? (_selectedStickerColor ?? Colors.black.withAlpha(200))
                                                        : null,
                                                    gradient: _selectedStickerGradient != null
                                                        ? LinearGradient(
                                                            colors: _selectedStickerGradient!,
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                          )
                                                        : null,
                                                    borderRadius: BorderRadius.circular(24),
                                                    border: Border.all(
                                                      color: Colors.white24,
                                                      width: 1.0,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withAlpha(100),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 3),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    mainAxisSize: MainAxisSize.max,
                                                    children: [
                                                      if (_selectedStickerIcon != null) ...[
                                                        if (_selectedStickerIcon is IconData)
                                                          Icon(_selectedStickerIcon as IconData, color: _selectedStickerTextColor ?? Colors.white, size: 18)
                                                        else
                                                          Text(_selectedStickerIcon.toString(), style: const TextStyle(fontSize: 16)),
                                                        const SizedBox(width: 8),
                                                      ],
                                                      Flexible(
                                                        child: _selectedCustomSticker == '__tet_lunar_2027__'
                                                            ? TXATetCountdownWidget(
                                                                style: TextStyle(
                                                                  color: _selectedStickerTextColor ?? Colors.white,
                                                                  fontSize: 15,
                                                                  fontWeight: FontWeight.bold,
                                                                  letterSpacing: -0.3,
                                                                ),
                                                              )
                                                            : (_selectedCustomSticker != null && _selectedCustomSticker!.startsWith('__tet_wish_'))
                                                                ? TXAMarquee(
                                                                    text: txaLang.getText(_selectedCustomSticker!.replaceAll('__', '')).replaceAll('%user%', username).replaceAll('%name%', tetName),
                                                                    style: TextStyle(
                                                                      color: _selectedStickerTextColor ?? Colors.white,
                                                                      fontSize: 15,
                                                                      fontWeight: FontWeight.bold,
                                                                      letterSpacing: -0.3,
                                                                    ),
                                                                  )
                                                                : (_selectedCustomSticker != null && _selectedCustomSticker!.startsWith('__zodiac_'))
                                                                    ? TXAMarquee(
                                                                        text: txaLang.getText(_selectedCustomSticker!.replaceAll('__', '')).replaceAll('%user%', username).replaceAll('%name%', tetName),
                                                                        style: TextStyle(
                                                                          color: _selectedStickerTextColor ?? Colors.white,
                                                                          fontSize: 15,
                                                                          fontWeight: FontWeight.bold,
                                                                          letterSpacing: -0.3,
                                                                        ),
                                                                      )
                                                                    : (_selectedCustomSticker != null && _selectedCustomSticker!.startsWith('__holiday_'))
                                                                        ? TXAMarquee(
                                                                            text: TXAFestivalManager.getHolidayCaption(_selectedCustomSticker!, txaLang.currentLanguage),
                                                                            style: TextStyle(
                                                                              color: _selectedStickerTextColor ?? Colors.white,
                                                                              fontSize: 15,
                                                                              fontWeight: FontWeight.bold,
                                                                              letterSpacing: -0.3,
                                                                            ),
                                                                          )
                                                                        : Text(
                                                                            _selectedMoodEmoji ?? _selectedCustomSticker ?? '',
                                                                            textAlign: TextAlign.center,
                                                                            style: TextStyle(
                                                                              color: _selectedStickerTextColor ?? Colors.white,
                                                                              fontSize: 15,
                                                                              fontWeight: FontWeight.bold,
                                                                              letterSpacing: -0.3,
                                                                            ),
                                                                          ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Icon(
                                                        Icons.close_rounded,
                                                        color: (_selectedStickerTextColor ?? Colors.white).withAlpha(150),
                                                        size: 16,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ))
                                        // --- Text Input Pill (mặc định glassmorphism tinh tế) ---
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withAlpha(130),
                                              borderRadius: BorderRadius.circular(24),
                                              border: Border.all(
                                                color: _captionFocusNode.hasFocus
                                                    ? TXATheme.primaryYellow.withAlpha(220)
                                                    : Colors.white.withAlpha(35),
                                                width: _captionFocusNode.hasFocus ? 1.2 : 0.8,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(60),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: TextField(
                                              controller: _captionController,
                                              focusNode: _captionFocusNode,
                                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                              textAlign: TextAlign.center,
                                              inputFormatters: [
                                                LengthLimitingTextInputFormatter(
                                                  (TXAAuthService.instance.currentUser?.role == 'admin') ? 500 : 50,
                                                ),
                                              ],
                                              decoration: InputDecoration(
                                                hintText: txaLang.getText('add_message_caption'),
                                                hintStyle: TextStyle(color: Colors.white.withAlpha(130), fontSize: 14),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),

                              // --- PAGE 1: Voice Note View (xem trươcs voice.png) ---
                              Stack(
                                alignment: Alignment.center,
                                fit: StackFit.expand,
                                children: [
                                  // Captured Image
                                  (() {
                                    final mainImage = widget.imagePath != null && File(widget.imagePath!).existsSync()
                                        ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                                        : Container(
                                            color: const Color(0xFF1C1C26),
                                            child: const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.image_rounded,
                                                    size: 64,
                                                    color: TXATheme.primaryYellow,
                                                  ),
                                                  SizedBox(height: 10),
                                                  Text(
                                                    'Army Captured Photo',
                                                    style: TextStyle(
                                                      color: TXATheme.textSecondary,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                    if (_isBlurOverlay) {
                                      return TXABlurDotsOverlay(
                                        blur: 15.0,
                                        child: mainImage,
                                      );
                                    }
                                    return mainImage;
                                  })(),

                                  // Sticker Pill trên nút Voice (Page 1)
                                  if (_selectedMoodEmoji != null || _selectedCustomSticker != null)
                                    Positioned(
                                      top: 16,
                                      left: 20,
                                      right: 20,
                                      child: _selectedCustomSticker == '__review__'
                                          ? Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _selectedStickerGradient == null
                                                    ? (_selectedStickerColor ?? const Color(0xFFFF9100))
                                                    : null,
                                                gradient: _selectedStickerGradient != null
                                                    ? LinearGradient(
                                                        colors: _selectedStickerGradient!,
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      )
                                                    : const LinearGradient(
                                                        colors: [Color(0xFFFF9100), Color(0xFFFF3D00)],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      ),
                                                borderRadius: BorderRadius.circular(26),
                                                border: Border.all(color: Colors.white30, width: 1.2),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withAlpha(120),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const SizedBox(width: 20),
                                                      FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: List.generate(5, (starIdx) {
                                                            final starVal = starIdx + 1;
                                                            final isFilled = starVal <= _reviewRating;
                                                            return Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                                              child: Icon(
                                                                isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                                                                color: isFilled ? const Color(0xFFFFD700) : Colors.white60,
                                                                size: 24,
                                                              ),
                                                            );
                                                          }),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedCustomSticker = null;
                                                            _selectedMoodEmoji = null;
                                                          });
                                                        },
                                                        child: Container(
                                                          padding: const EdgeInsets.all(2),
                                                          decoration: const BoxDecoration(
                                                            color: Colors.black26,
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (_captionController.text.trim().isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      _captionController.text.trim(),
                                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            )
                                          : GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _selectedMoodEmoji = null;
                                                  _selectedCustomSticker = null;
                                                  _selectedStickerIcon = null;
                                                  _selectedStickerColor = null;
                                                  _selectedStickerGradient = null;
                                                  _selectedStickerTextColor = null;
                                                });
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: _selectedStickerGradient == null
                                                      ? (_selectedStickerColor ?? Colors.black.withAlpha(200))
                                                      : null,
                                                  gradient: _selectedStickerGradient != null
                                                      ? LinearGradient(
                                                          colors: _selectedStickerGradient!,
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        )
                                                      : null,
                                                  borderRadius: BorderRadius.circular(24),
                                                  border: Border.all(color: Colors.white24),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withAlpha(100),
                                                      blurRadius: 10,
                                                      offset: const Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (_selectedStickerIcon != null) ...[
                                                      if (_selectedStickerIcon is IconData)
                                                        Icon(_selectedStickerIcon as IconData, color: _selectedStickerTextColor ?? Colors.white, size: 18)
                                                      else
                                                        Text(_selectedStickerIcon.toString(), style: const TextStyle(fontSize: 16)),
                                                      const SizedBox(width: 8),
                                                    ],
                                                    Flexible(
                                                      child: _selectedCustomSticker == '__tet_lunar_2027__'
                                                          ? TXATetCountdownWidget(
                                                              style: TextStyle(
                                                                color: _selectedStickerTextColor ?? Colors.white,
                                                                fontSize: 15,
                                                                fontWeight: FontWeight.bold,
                                                                letterSpacing: -0.3,
                                                              ),
                                                            )
                                                          : (_selectedCustomSticker != null && _selectedCustomSticker!.startsWith('__tet_wish_'))
                                                              ? TXAMarquee(
                                                                  text: txaLang.getText(_selectedCustomSticker!.replaceAll('__', '')).replaceAll('%user%', username).replaceAll('%name%', tetName),
                                                                  style: TextStyle(
                                                                    color: _selectedStickerTextColor ?? Colors.white,
                                                                    fontSize: 15,
                                                                    fontWeight: FontWeight.bold,
                                                                    letterSpacing: -0.3,
                                                                  ),
                                                                )
                                                              : (_selectedCustomSticker != null && _selectedCustomSticker!.startsWith('__zodiac_'))
                                                                  ? TXAMarquee(
                                                                      text: txaLang.getText(_selectedCustomSticker!.replaceAll('__', '')).replaceAll('%user%', username).replaceAll('%name%', tetName),
                                                                      style: TextStyle(
                                                                        color: _selectedStickerTextColor ?? Colors.white,
                                                                        fontSize: 15,
                                                                        fontWeight: FontWeight.bold,
                                                                        letterSpacing: -0.3,
                                                                      ),
                                                                    )
                                                                  : (_selectedCustomSticker != null && _selectedCustomSticker!.startsWith('__holiday_'))
                                                                      ? TXAMarquee(
                                                                          text: TXAFestivalManager.getHolidayCaption(_selectedCustomSticker!, txaLang.currentLanguage),
                                                                          style: TextStyle(
                                                                            color: _selectedStickerTextColor ?? Colors.white,
                                                                            fontSize: 15,
                                                                            fontWeight: FontWeight.bold,
                                                                            letterSpacing: -0.3,
                                                                          ),
                                                                        )
                                                                      : Text(
                                                                          _selectedMoodEmoji ?? _selectedCustomSticker ?? '',
                                                                          textAlign: TextAlign.center,
                                                                          style: TextStyle(
                                                                            color: _selectedStickerTextColor ?? Colors.white,
                                                                            fontSize: 15,
                                                                            fontWeight: FontWeight.bold,
                                                                            letterSpacing: -0.3,
                                                                          ),
                                                                        ),
                                                    ),
                                                    const SizedBox(width: 20),
                                                    Icon(
                                                      Icons.close_rounded,
                                                      color: (_selectedStickerTextColor ?? Colors.white).withAlpha(150),
                                                      size: 16,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                    ),

                                  // Privacy Eye Toggle
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isBlurOverlay = !_isBlurOverlay;
                                        });
                                        TXAToast.show(
                                          context,
                                          txaLang.getText(_isBlurOverlay ? 'blur_overlay_enabled' : 'blur_overlay_disabled'),
                                          icon: _isBlurOverlay ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        );
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(128),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isBlurOverlay ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Voice Recording Button Overlay
                                  Positioned(
                                    bottom: 24,
                                    left: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _isRecordingVoice
                                          ? _stopVoiceRecording
                                          : _recordedVoicePath != null
                                              ? _togglePlayVoice
                                              : _startVoiceRecording,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _isRecordingVoice
                                              ? TXATheme.statusRed.withAlpha(220)
                                              : _isPlayingVoice
                                                  ? TXATheme.actionBlue.withAlpha(220)
                                                  : Colors.black.withAlpha(190),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: _isRecordingVoice
                                                ? TXATheme.statusRed
                                                : _isPlayingVoice
                                                    ? TXATheme.actionBlue
                                                    : TXATheme.primaryYellow,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(80),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isRecordingVoice
                                                  ? Icons.stop_rounded
                                                  : _recordedVoicePath != null
                                                      ? (_isPlayingVoice ? Icons.pause_rounded : Icons.play_arrow_rounded)
                                                      : Icons.mic_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _isRecordingVoice
                                                  ? txaLang.getText('voice_recording_in_progress').replaceAll('%sec%', '$_voiceSeconds')
                                                  : _recordedVoicePath != null
                                                      ? (_isPlayingVoice
                                                          ? txaLang.getText('pause_voice')
                                                          : txaLang.getText('play_voice').replaceAll('%sec%', '${15 - _voiceSeconds}'))
                                                      : txaLang.getText('add_voice'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // --- PAGE 2: Location View (Vị trí - GMS Service) ---
                              Stack(
                                alignment: Alignment.center,
                                fit: StackFit.expand,
                                children: [
                                  // Captured Image
                                  (() {
                                    final mainImage = widget.imagePath != null && File(widget.imagePath!).existsSync()
                                        ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                                        : Container(
                                            color: const Color(0xFF1C1C26),
                                            child: const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.image_rounded,
                                                    size: 64,
                                                    color: TXATheme.primaryYellow,
                                                  ),
                                                  SizedBox(height: 10),
                                                  Text(
                                                    'Army Captured Photo',
                                                    style: TextStyle(
                                                      color: TXATheme.textSecondary,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                    if (_isBlurOverlay) {
                                      return TXABlurDotsOverlay(
                                        blur: 15.0,
                                        child: mainImage,
                                      );
                                    }
                                    return mainImage;
                                  })(),

                                  // Privacy Eye Toggle
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isBlurOverlay = !_isBlurOverlay;
                                        });
                                        TXAToast.show(
                                          context,
                                          txaLang.getText(_isBlurOverlay ? 'blur_overlay_enabled' : 'blur_overlay_disabled'),
                                          icon: _isBlurOverlay ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        );
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(128),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isBlurOverlay ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Timestamp Overlay
                                  if (txaFormat.showTimestamp)
                                    Positioned(
                                      top: 14,
                                      left: 14,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(128),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          formattedTime,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Location Sticker Card Overlay (Clickable to fetch location)
                                  Positioned(
                                    bottom: 24,
                                    left: 20,
                                    right: 20,
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () => _getGMSLocation(applyAsSticker: true),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF343238).withAlpha(230),
                                            borderRadius: BorderRadius.circular(26),
                                            border: Border.all(color: Colors.white30, width: 1.2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(120),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _isFetchingLocation
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child: CircularProgressIndicator(color: TXATheme.primaryYellow, strokeWidth: 2),
                                                    )
                                                  : const Icon(
                                                      Icons.location_on_rounded,
                                                      color: Color(0xFF42A5F5),
                                                      size: 22,
                                                    ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  _selectedCustomSticker != null && _selectedCustomSticker!.startsWith('📍')
                                                      ? _selectedCustomSticker!
                                                      : (txaLang.currentLanguage == 'vi' ? '📍 Hà Nội, Việt Nam' : '📍 Hanoi, Vietnam'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: -0.3,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
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

                              // --- PAGE 3: Weather View (Thời tiết - OpenMeteo) ---
                              Stack(
                                alignment: Alignment.center,
                                fit: StackFit.expand,
                                children: [
                                  // Captured Image
                                  (() {
                                    final mainImage = widget.imagePath != null && File(widget.imagePath!).existsSync()
                                        ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                                        : Container(
                                            color: const Color(0xFF1C1C26),
                                            child: const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.image_rounded,
                                                    size: 64,
                                                    color: TXATheme.primaryYellow,
                                                  ),
                                                  SizedBox(height: 10),
                                                  Text(
                                                    'Army Captured Photo',
                                                    style: TextStyle(
                                                      color: TXATheme.textSecondary,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                    if (_isBlurOverlay) {
                                      return TXABlurDotsOverlay(
                                        blur: 15.0,
                                        child: mainImage,
                                      );
                                    }
                                    return mainImage;
                                  })(),

                                  // Privacy Eye Toggle
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isBlurOverlay = !_isBlurOverlay;
                                        });
                                        TXAToast.show(
                                          context,
                                          txaLang.getText(_isBlurOverlay ? 'blur_overlay_enabled' : 'blur_overlay_disabled'),
                                          icon: _isBlurOverlay ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        );
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(128),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isBlurOverlay ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Timestamp Overlay
                                  if (txaFormat.showTimestamp)
                                    Positioned(
                                      top: 14,
                                      left: 14,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(128),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          formattedTime,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Weather Sticker Card Overlay (Directly Clickable to Refresh)
                                  Positioned(
                                    bottom: 24,
                                    left: 20,
                                    right: 20,
                                    child: Builder(builder: (context) {
                                      final weather = _weatherData;
                                      final txaLang = TXALanguage.instance;

                                      if (_isFetchingWeather && weather == null) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withAlpha(180),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(color: Colors.white24),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(color: TXATheme.primaryYellow, strokeWidth: 2),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                txaLang.getText('weather_loading'),
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      final w = weather ?? TXAWeatherData(
                                        temperature: 25.0,
                                        tempString: '25°C',
                                        emoji: '🌤️',
                                        label: '🌤️ 25°C',
                                        weatherCode: 2,
                                        isDay: true,
                                        timestamp: DateTime.now(),
                                      );

                                      final theme = _getWeatherTheme(w);
                                      final List<Color> gradient = theme['gradient'];
                                      final Color textColor = theme['textColor'];

                                      return Center(
                                        child: GestureDetector(
                                          onTap: () => _getWeather(force: true),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: gradient,
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(26),
                                              border: Border.all(color: Colors.white30, width: 1.2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(120),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _isFetchingWeather
                                                    ? Container(
                                                        margin: const EdgeInsets.only(right: 8),
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(
                                                          color: textColor,
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : Text(
                                                        w.emoji, // Icon đằng trước
                                                        style: const TextStyle(fontSize: 22),
                                                      ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  w.tempString, // Hiện nhiệt độ
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

                const SizedBox(height: 10),

                // Animated Page Indicators (Page 0: Text, Page 1: Voice, Page 2: Location, Page 3: Weather)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isCurrent = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isCurrent ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isCurrent ? Colors.white : TXATheme.textMuted,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 20),

                // 3. Action Buttons Row (Discard ✕, Send ✈ with Loading Spinner, Mood 😊)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Discard / Close Button with Dark Translucent Background
                      GestureDetector(
                        onTap: _isUploading ? null : () => Navigator.pop(context),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(40), width: 1),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: TXATheme.textPrimary,
                            size: 28,
                          ),
                        ),
                      ),

                      // Large Send Paper Plane Button (Replaced by Spinner during upload)
                      GestureDetector(
                        onTap: _isUploading ? null : _onSend,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: TXATheme.actionBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: TXATheme.actionBlue.withAlpha(128),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: _isUploading
                              ? const Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                        ),
                      ),

                      // Mood Customization Button with Dark Translucent Background
                      GestureDetector(
                        onTap: _isUploading ? null : () => _showCustomizationOptionsDialog(context),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(40), width: 1),
                          ),
                          child: Center(
                            child: _selectedMoodEmoji != null
                                ? Text(_selectedMoodEmoji!, style: const TextStyle(fontSize: 24))
                                : _selectedCustomSticker != null
                                    ? (_selectedStickerIcon != null && _selectedStickerIcon is String
                                        ? Text(_selectedStickerIcon as String, style: const TextStyle(fontSize: 24))
                                        : const Icon(Icons.auto_awesome_rounded, color: TXATheme.primaryYellow, size: 26))
                                    : const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: TXATheme.textPrimary,
                                        size: 26,
                                      ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. Recipient Selector Carousel Bar (Responsive & Multi-Select with Smart Grouping)
                SizedBox(
                  height: 76,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // --- 1. Mọi người (Everyone) Group ---
                        _buildRecipientItem(
                          name: txaLang.getText('all_friends'),
                          iconWidget: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
                          isSelected: _isAllSelected,
                          activeBgColor: TXATheme.actionBlue,
                          activeBorderColor: TXATheme.actionBlue,
                          onTap: _onSelectAllGroup,
                        ),

                        // --- 2. Chỉ mình tôi (Private / Only Me) Group (Only if Privacy Mode Enabled) ---
                        if (_isPrivate) ...[
                          const SizedBox(width: 14),
                          _buildRecipientItem(
                            name: txaLang.getText('private_only'),
                            iconWidget: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                            isSelected: _isPrivateGroupSelected,
                            activeBgColor: TXATheme.cardBorder,
                            activeBorderColor: Colors.white,
                            onTap: _onSelectPrivateGroup,
                          ),
                        ],

                        // --- 3. Bạn thân (Best Friends) Group (Only if _bestFriends is not empty) ---
                        if (_bestFriends.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          _buildRecipientItem(
                            name: txaLang.getText('best_friend'),
                            iconWidget: const Icon(Icons.star_rounded, color: TXATheme.primaryYellow, size: 24),
                            isSelected: _isBestFriendsGroupSelected,
                            activeBgColor: TXATheme.primaryYellow.withAlpha(80),
                            activeBorderColor: TXATheme.primaryYellow,
                            onTap: _onSelectBestFriendsGroup,
                          ),
                        ],

                        // --- 4. Người yêu 💖 (Lover) Group (Only if _lovers is not empty) ---
                        if (_lovers.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          _buildRecipientItem(
                            name: txaLang.getText('lover'),
                            iconWidget: const Icon(Icons.favorite_rounded, color: TXATheme.statusRed, size: 22),
                            isSelected: _isLoverGroupSelected,
                            activeBgColor: TXATheme.statusRed.withAlpha(80),
                            activeBorderColor: TXATheme.statusRed,
                            onTap: _onSelectLoverGroup,
                          ),
                        ],

                        // --- 5. Individual Friends List ---
                        ..._friendsData.map((friend) {
                          final String fId = friend['id'];
                          final bool isSelected = !_isAllSelected && _selectedFriendIds.contains(fId);
                          final bool isBestFriend = friend['isBestFriend'] == true;
                          final bool isLover = friend['username'] == TXAAuthService.instance.currentUser?.loverUsername;

                          Color activeBorder = TXATheme.actionBlue;
                          if (isBestFriend) activeBorder = TXATheme.primaryYellow;
                          if (isLover) activeBorder = TXATheme.statusRed;

                          final bgColorInt = friend['bgColor'] as int? ?? 0xFF37474F;

                          return Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: _buildRecipientItem(
                              name: friend['name'],
                              iconWidget: ClipOval(
                                child: (friend['avatar'] as String? ?? 'U').startsWith('http')
                                    ? SizedBox(width: 44, height: 44, child: TXANetworkImage(url: friend['avatar'], fit: BoxFit.cover))
                                    : Center(
                                        child: Text(
                                          friend['avatar'] ?? 'U',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                              ),
                              isSelected: isSelected,
                              activeBgColor: Color(bgColorInt),
                              activeBorderColor: activeBorder,
                              onTap: () => _toggleFriendSelection(fId),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipientItem({
    required String name,
    required Widget iconWidget,
    required bool isSelected,
    required Color activeBgColor,
    required Color activeBorderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 50 : 46,
            height: isSelected ? 50 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? activeBgColor : TXATheme.cardBg,
              border: Border.all(
                color: isSelected ? activeBorderColor : TXATheme.cardBorder,
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeBorderColor.withAlpha(120),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Center(child: iconWidget),
          ),
          const SizedBox(height: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? TXATheme.textPrimary : TXATheme.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
