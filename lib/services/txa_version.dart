import 'package:flutter/material.dart';

class TXAVersion extends ChangeNotifier {
  static final TXAVersion instance = TXAVersion._internal();
  TXAVersion._internal();

  static const String appName = 'Army';
  static const String currentVersion = '1.3.0';
  static const int buildNumber = 6;
  static const String releaseDate = '06/08/2026';
  static const String fullVersionString = 'Bản 1.3.0+6';

  static const List<Map<String, dynamic>> changelogData = [
    {
      'version': '1.3.0+6',
      'date': '06/08/2026',
      'title': 'Bản Cập Nhật Tối Ưu Feed & Đồng Bộ Tin Nhắn Siêu Mượt 🚀',
      'subtitle': 'Khắc phục hoàn toàn lỗi khung chat chi tiết, tối ưu khoảng cách quảng cáo 4 bài, mượt mà lướt feed và đồng bộ ảnh Google.',
      'badge': 'BẢN CẬP NHẬT',
      'features': [
        {
          'icon': '💬',
          'title': 'Sửa lỗi xem tin nhắn chi tiết',
          'description': 'Toàn bộ nội dung tin nhắn trong khung chat chi tiết giờ đây hiển thị đầy đủ và đồng bộ 100% với danh sách tin nhắn ngoài màn hình chat.',
        },
        {
          'icon': '📢',
          'title': 'Cân bằng hiển thị quảng cáo',
          'description': 'Cố định hiển thị quảng cáo sau mỗi 4 bài viết và luôn giữ 1 quảng cáo hợp lý ở cuối danh sách feed cho tài khoản Free (tài khoản VIP hoàn toàn không có quảng cáo).',
        },
        {
          'icon': '⚡',
          'title': 'Lướt feed siêu mượt & Không giật lag',
          'description': 'Tối ưu hóa tốc độ cuộn bảng tin Locket, giảm bớt tiến trình dựng lại giao diện giúp thao tác vuốt mượt mà và mượt pin.',
        },
        {
          'icon': '👤',
          'title': 'Đồng bộ Avatar Google & Bạn bè chuẩn xác',
          'description': 'Đăng nhập Google hiển thị đúng ảnh đại diện thật từ Google. Ảnh đại diện trong danh sách bạn bè được cập nhật mới nhất từ tài khoản thực.',
        },
        {
          'icon': '🔍',
          'title': 'Bộ lọc bài viết hoạt động chuẩn xác',
          'description': 'Bộ lọc Feed nâng cấp hoàn hảo: Dễ dàng xem tất cả, xem bài của Tôi (Me), Bạn thân, Bạn bè hoặc lọc riêng từng bạn bè cụ thể.',
        },
      ],
    },
    {
      'version': '1.2.0+5',
      'date': '05/08/2026',
      'title': 'Nâng Cấp Giao Diện Locket Mới & Trải Nghiệm Siêu Mượt ✨',
      'subtitle': 'Trải nghiệm chụp ảnh Locket đỉnh cao với tông màu tối sang trọng, gửi tin nhắn siêu tốc và giao diện được tối ưu hoàn hảo cho bạn.',
      'badge': 'TÍNH NĂNG MỚI',
      'features': [
        {
          'icon': '📸',
          'title': 'Giao diện Locket Widget Pitch Black Sang Trọng',
          'description': 'Khung camera bo góc mềm mại, tông nền đen tối mịn bảo vệ mắt và các nút bấm màu vàng ánh kim phong cách Locket hiện đại.',
        },
        {
          'icon': '⚡',
          'title': 'Đăng bài & Gửi tin nhắn siêu tốc',
          'description': 'Tốc độ tải ảnh Locket, gửi lời nhắn và thả biểu cảm cảm xúc được nâng cấp nhanh tức thì, không bị trễ hay gián đoạn.',
        },
        {
          'icon': '💛',
          'title': 'Kết nối bạn bè & Người yêu mượt mà',
          'description': 'Dễ dàng kết nối bạn bè, chụp ảnh khoảnh khắc đôi và cập nhật chuỗi lửa ngày liên tục với độ ổn định cao nhất.',
        },
        {
          'icon': '📱',
          'title': 'Giao diện thông báo mới vừa vặn màn hình',
          'description': 'Bảng thông tin phiên bản mới được thiết kế rộng rãi, bo góc đẹp mắt và tự động căn chỉnh không bị che bởi phím điều hướng hệ thống.',
        },
      ],
    },
    {
      'version': '1.1.0+4',
      'date': '02/08/2026',
      'title': 'Nâng Cấp Trải Nghiệm Siêu Tốc & Giao Diện Mới 🚀',
      'subtitle': 'Cải tiến vượt trội hệ thống truyền tin, nâng cấp độ mượt và tối ưu hiển thị giao diện.',
      'badge': 'TÍNH NĂNG MỚI',
      'features': [
        {
          'icon': '⚡',
          'title': 'Hệ thống truyền tải tin nhắn & ảnh siêu tốc',
          'description': 'Nâng cấp toàn diện cơ sở kết nối giúp tin nhắn và hình ảnh được gửi nhận tức thì, tiết kiệm băng thông tối đa.',
        },
        {
          'icon': '🌙',
          'title': 'Bảo vệ mắt tối đa với Chế độ tối toàn diện',
          'description': 'Cố định giao diện tối cao cấp trên mọi thiết bị, không lo bị chói mắt kể cả khi máy đang để chế độ sáng.',
        },
        {
          'icon': '👥',
          'title': 'Hiển thị bài viết bạn bè mượt mà',
          'description': 'Khắc phục hoàn toàn lỗi ẩn bài viết bạn bè trên bảng tin, giúp bạn cập nhật khoảnh khắc của mọi người nhanh nhất.',
        },
        {
          'icon': '👤',
          'title': 'Cải tiến ảnh đại diện lịch sử chuỗi',
          'description': 'Thay thế hình đại diện mặc định thân thiện, trực quan hơn trong danh sách mốc lịch sử chuỗi ngày.',
        },
      ],
    },
    {
      'version': '1.0.2+3',
      'date': '02/08/2026',
      'title': 'Bản sửa lỗi & Tối ưu hóa Toàn diện 🌟',
      'subtitle': 'Khắc phục các lỗi crash quảng cáo, cải thiện đồng bộ thời gian thực và trải nghiệm điều hướng.',
      'badge': 'BẢN SỬA LỖI',
      'features': [
        {
          'icon': '🚪',
          'title': 'Sửa lỗi điều hướng Đăng xuất',
          'description': 'Đảm bảo điều hướng sạch sẽ về màn login sau khi logout không bị gián đoạn do unmount context.',
        },
        {
          'icon': '🛡️',
          'title': 'Ngăn chặn đè thanh hệ thống',
          'description': 'Thêm SafeArea và useSafeArea vào modal nhập tên tháng giúp tránh bị che khuất bởi thanh điều hướng ảo ở đáy màn hình.',
        },
        {
          'icon': '👥',
          'title': 'Đồng bộ Bạn bè & Bạn thân Real-time',
          'description': 'Đồng bộ trực tiếp danh sách bạn bè và trạng thái bạn thân theo thời gian thực thay vì lưu cục bộ.',
        },
        {
          'icon': '🖼️',
          'title': 'Bảo toàn Avatar Google & TXANetworkImage',
          'description': 'Giữ nguyên avatar Google khi đăng nhập lại mà không bị reset, đồng thời tăng tính ổn định tải ảnh qua TXANetworkImage.',
        },
        {
          'icon': '📢',
          'title': 'Sửa lỗi Crash Native Ad & Dimming',
          'description': 'Tích hợp Template Medium của Google Mobile Ads sửa lỗi crash NativeAdFactory, đồng thời làm mờ & khóa các nút tương tác khi xem quảng cáo.',
        },
        {
          'icon': '🔍',
          'title': 'Ẩn Zoom 0.5x & Tối ưu chữ',
          'description': 'Ẩn tùy chọn 0.5x trên máy không có camera góc rộng và cố định cỡ chữ trên zoom pill tránh tràn khung hình.',
        },
      ],
    },
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
