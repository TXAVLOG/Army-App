import 'package:flutter/material.dart';

class TXAVersion extends ChangeNotifier {
  static final TXAVersion instance = TXAVersion._internal();
  TXAVersion._internal();

  static const String appName = 'Army';
  static const String currentVersion = '1.0.0';
  static const int buildNumber = 1;
  static const String releaseDate = '31/07/2026';
  static const String fullVersionString = 'Bản 1.0.0+1';

  static const List<Map<String, dynamic>> changelogData = [
    {
      'version': '1.0.0+1',
      'date': '26/07/2026',
      'title': 'Khởi chạy chính thức Army Locket UI 🚀',
      'subtitle': 'Phiên bản đầu tiên mang tới trải nghiệm Locket Dark mượt mà, camera chuyên nghiệp và chia sẻ ảnh bạn bè.',
      'badge': 'TÍNH NĂNG MỚI',
      'features': [
        {
          'icon': '📸',
          'title': 'Camera Locket & Zoom 3.0x',
          'description': 'Tùy chỉnh tỷ lệ 1:1, 4:3, Zoom cụm camera sau 1.0x -> 3.0x, bật tắt Flash và lật camera mượt mà.',
        },
        {
          'icon': '✂️',
          'title': 'Cắt ảnh Locket tương tác',
          'description': 'Bộ công cụ cắt ảnh từ thư viện với cử chỉ kéo thả, cuộn chuột, zoom và xem trước khung bo tròn 24px.',
        },
        {
          'icon': '😊',
          'title': 'Sticker Tâm trạng & Caption nảy',
          'description': 'Đính kèm sticker biểu cảm emoji hệ thống và ô nhập tin nhắn tự động trượt nảy nổi lên trên bàn phím ảo.',
        },
        {
          'icon': '🌐',
          'title': 'TXALanguage & TXAFormat',
          'description': 'Hỗ trợ đa ngôn ngữ Tiếng Việt & English đổi tức thì, cùng tiện ích định dạng dung lượng, thời gian và hoạt động.',
        },
        {
          'icon': '🔔',
          'title': 'FCM Push Notification & Xin quyền',
          'description': 'Hệ thống thông báo đẩy ngầm thả cảm xúc, nhắn tin, phản hồi feed và nhắc lịch cố định dí deadline.',
        },
        {
          'icon': '🏆',
          'title': 'Hệ thống Thành tựu Tiến cấp (TXAAchievement)',
          'description': 'Bộ danh hiệu 12+ chuỗi tiến cấp, bộ đếm % hoàn thành, phân loại mức độ Dễ/Trung bình/Khó/Đỉnh cao, đa ngôn ngữ & đồng bộ Cloud Firestore.',
        },
      ],
    },
  ];

  bool checkHasUpdate(String serverVersion) {
    return serverVersion != currentVersion;
  }
}
