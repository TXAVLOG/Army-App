import 'package:flutter/material.dart';

class TXAVersion extends ChangeNotifier {
  static final TXAVersion instance = TXAVersion._internal();
  TXAVersion._internal();

  static const String appName = 'Army';
  static const String currentVersion = '1.0.1';
  static const int buildNumber = 2;
  static const String releaseDate = '01/08/2026';
  static const String fullVersionString = 'Bản 1.0.1+2';

  static const List<Map<String, dynamic>> changelogData = [
    {
      'version': '1.0.1+2',
      'date': '01/08/2026',
      'title': 'Cải tiến Profile & Sửa lỗi Đăng xuất 🛠️',
      'subtitle': 'Tối ưu hóa trải nghiệm tải dữ liệu cá nhân, sửa lỗi kẹt session khi logout và cập nhật tài khoản.',
      'badge': 'BẢN CẬP NHẬT',
      'features': [
        {
          'icon': '🚪',
          'title': 'Sửa lỗi Đăng xuất triệt để',
          'description': 'Reset hoàn toàn trạng thái cache profile khi bấm đăng xuất, ngăn ngừa tình trạng kẹt session hoặc hiển thị thông tin ảo của tài khoản cũ.',
        },
        {
          'icon': '⏳',
          'title': 'Cơ chế Tải Profile 2 giai đoạn',
          'description': 'Tải thông tin bạn bè và streak lập tức để mở giao diện nhanh chóng, sau đó dựng timeline và precache ảnh ngầm cùng banner hiển thị trạng thái.',
        },
        {
          'icon': '👤',
          'title': 'Đồng bộ & tạo lại tài khoản @txavltj1',
          'description': 'Tạo và đồng bộ hóa thành công tài khoản chính chủ @txavltj1 lên Cloud Firestore với mật khẩu mới.',
        },
      ],
    },
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
