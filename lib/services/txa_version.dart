import 'package:flutter/material.dart';

class TXAVersion extends ChangeNotifier {
  static final TXAVersion instance = TXAVersion._internal();
  TXAVersion._internal();

  static const String appName = 'Army';
  static const String currentVersion = '1.7.0';
  static const int buildNumber = 12;
  static const String releaseDate = '22/08/2026';
  static const String fullVersionString = 'Bản 1.7.0+12';

  static const List<Map<String, dynamic>> changelogData = [
    {
      'version': '1.7.0+12',
      'date': '22/08/2026',
      'title': 'Bộ Sưu Tập 25 Icon App 3D Độc Quyền & Trải Nghiệm Mượt Mà 📱✨',
      'subtitle': 'Biến hóa màn hình chính cực chất với 25 mẫu Icon 3D dập nổi sang trọng, mở khóa trải nghiệm 30 ngày thả ga và tối ưu hóa độ mượt toàn diện.',
      'badge': 'BẢN CẬP NHẬT LỚN',
      'features': [
        {
          'icon': '📱',
          'title': 'Kho Biểu Tượng 3D Sống Động (25 Phong Cách)',
          'description': 'Tự do biến hóa icon ứng dụng ngoài màn hình chính điện thoại với 25 mẫu thiết kế 3D sắc nét, từ phong cách Cổ Điển, Trắng Tinh Khôi đến các mẫu VIP Hoàng Gia lấp lánh.',
        },
        {
          'icon': '🎬',
          'title': 'Xem Video Ngắn Dùng Thả Ga 30 Ngày',
          'description': 'Trải nghiệm trọn bộ các mẫu biểu tượng VIP cao cấp trong suốt 1 tháng chỉ với 1 lượt xem video ngắn, theo dõi số ngày còn lại trực quan và tiện lợi.',
        },
        {
          'icon': '👑',
          'title': 'Đặc Quyền Mở Khóa Trọn Bộ Hội Viên Gold Pass',
          'description': 'Hội viên Gold Pass thoải mái chuyển đổi và sử dụng vĩnh viễn trọn bộ 25 mẫu biểu tượng 3D độc quyền không giới hạn.',
        },
        {
          'icon': '⚡',
          'title': 'Đổi Biểu Tượng Tức Thì & Tự Động Hóa',
          'description': 'Tốc độ chuyển đổi biểu tượng siêu mượt mà, tự động ghi nhớ mẫu icon bạn yêu thích và vận hành ổn định trên mọi dòng máy.',
        },
        {
          'icon': '🌐',
          'title': 'Giao Diện Đa Ngôn Ngữ Tinh Tế',
          'description': 'Mọi thông tin hướng dẫn, nhãn biểu tượng và thông báo đều được chăm chút tỉ mỉ, hiển thị rõ ràng và đẹp mắt theo ngôn ngữ Tiếng Việt & Tiếng Anh.',
        },
      ],
    },
    {
      'version': '1.6.0+11',
      'date': '22/08/2026',
      'title': 'Cài Đặt Máy Ảnh Chuyên Nghiệp: Hẹn Giờ Chụp & Đèn Flash ⏱️📸',
      'subtitle': 'Thỏa sức selfie từ xa và bắt trọn khoảnh khắc nhóm với Hẹn Giờ Chụp thông minh, tùy chỉnh Đèn Flash đa chế độ và trải nghiệm mượt mà.',
      'badge': 'TÍNH NĂNG MỚI',
      'features': [
        {
          'icon': '⏱️',
          'title': 'Hẹn giờ chụp ảnh đa mốc (3s, 5s, 7s, 10s)',
          'description': 'Đếm ngược trực quan với số to nổi bật trên camera, rung phản hồi xúc giác qua từng giây và dễ dàng hủy đếm ngược bất kỳ lúc nào.',
        },
        {
          'icon': '⚡',
          'title': 'Tùy chỉnh Đèn Flash đa chế độ',
          'description': 'Linh hoạt chuyển đổi giữa Tắt, Bật sáng liên tục (Torch) và Tự động (Auto) giúp bắt trọn mọi góc chụp trong điều kiện thiếu sáng.',
        },
        {
          'icon': '🎛️',
          'title': 'Bảng Cài Đặt Camera Hiện Đại & Tinh Tế',
          'description': 'Thiết kế Bottom Sheet sang trọng, tự động lưu cấu hình yêu thích vào bộ nhớ máy và khôi phục khi mở lại app.',
        },
        {
          'icon': '🛡️',
          'title': 'Hủy hẹn giờ thông minh & An toàn',
          'description': 'Tự động hủy đếm ngược khi đổi camera, mở thư viện ảnh hoặc ẩn app ra ngoài màn hình chính, chống lỗi camera tuyệt đối.',
        },
        {
          'icon': '🚀',
          'title': 'Tối ưu hiệu năng & Phản hồi tức thì',
          'description': 'Tốc độ chụp ảnh nhanh chóng, xử lý mượt mà và tối ưu hóa thời lượng pin cho thiết bị.',
        },
      ],
    },
    {
      'version': '1.5.0+10',
      'date': '16/08/2026',
      'title': 'Bộ Sưu Tập Icon 3D & Nâng Cấp Trải Nghiệm Mượt Mà 📱✨',
      'subtitle': 'Biến hóa phong cách với 25 Icon 3D cực chất, ưu đãi gói năm Gold Pass siêu tiết kiệm và tinh chỉnh giao diện hiển thị hoàn hảo.',
      'badge': 'BẢN CẬP NHẬT LỚN',
      'features': [
        {
          'icon': '📱',
          'title': 'Bộ sưu tập 25 Icon 3D cực chất',
          'description': 'Thoải mái đổi icon ứng dụng theo cá tính riêng với 25 mẫu icon 3D sống động từ phong cách Cổ Điển, Neon rực rỡ đến các mẫu VIP độc quyền.',
        },
        {
          'icon': '🌟',
          'title': 'Ưu đãi gói năm Gold Pass siêu tiết kiệm 45%',
          'description': 'Hiển thị giá gốc và mức ưu đãi rõ ràng khi nâng cấp gói năm, giúp bạn dễ dàng chọn gói cước tiết kiệm và tiện lợi nhất.',
        },
        {
          'icon': '🔔',
          'title': 'Giao diện thông báo thoáng mắt & Dễ nhìn',
          'description': 'Căn chỉnh các thông báo trạng thái luôn hiển thị vừa vặn, không bị che khuất bởi các phím điều hướng của điện thoại.',
        },
        {
          'icon': '🏆',
          'title': 'Mở khóa huy hiệu Sưu Tầm Icon',
          'description': 'Khám phá và sở hữu các mẫu icon độc đáo để nâng cấp danh hiệu và nhận huy hiệu thành tựu cực ngầu.',
        },
        {
          'icon': '⚡',
          'title': 'Trải nghiệm mượt mà & Nâng tầm cảm ứng',
          'description': 'Thao tác xem trước, đổi icon và chọn gói cước phản hồi tức thì, kèm hiệu ứng rung phản hồi chân thực.',
        },
      ],
    },
    {
      'version': '1.4.1+9',
      'date': '16/08/2026',
      'title': 'Trải Nghiệm Siêu Mượt & Giao Diện Hoàn Hảo ⚡✨',
      'subtitle': 'Tối ưu tốc độ phản hồi tức thì, lưu đĩa đệm xem lại bài đăng mượt mà, nâng cao bố cục phím bấm và tinh chỉnh giao diện thoáng mắt.',
      'badge': 'BẢN CẬP NHẬT',
      'features': [
        {
          'icon': '🚀',
          'title': 'Mở ứng dụng siêu tốc & mượt mà',
          'description': 'Tối ưu hóa quy trình khởi chạy giúp ứng dụng phản hồi nhanh chóng, mở màn hình chính tức thì.',
        },
        {
          'icon': '⚡',
          'title': 'Xem bài đăng mượt mà & Tiết kiệm data',
          'description': 'Tích hợp bộ nhớ đệm thông minh, hiển thị tức thì 0ms các bài đăng đã lưu giúp lướt mượt mà và không tốn dung lượng mạng.',
        },
        {
          'icon': '🎨',
          'title': 'Tối ưu không gian hiển thị bài viết',
          'description': 'Tinh chỉnh khoảng cách và nhịp cuộn trang hợp lý, mang lại trải nghiệm xem ảnh khoảnh khắc tự nhiên, thoải mái.',
        },
        {
          'icon': '🔔',
          'title': 'Thông báo trạng thái hệ thống linh hoạt',
          'description': 'Cập nhật giao diện thông báo thân thiện với ngôn ngữ chuẩn xác, giúp bạn dễ dàng theo dõi trạng thái ứng dụng.',
        },
        {
          'icon': '📱',
          'title': 'Bố cục phím bấm chuẩn xác & Nút nâng cao',
          'description': 'Tối ưu khoảng cách phím điều hướng ở góc dưới màn hình, thao tác bấm nhạy và không lo bị đè chữ hay lệch vị trí.',
        },
      ],
    },
    {
      'version': '1.4.0+8',
      'date': '09/08/2026',
      'title': 'Giao Diện Sáng Rực Rỡ & Trải Nghiệm Mượt Mà ☀️✨',
      'subtitle': 'Tự động tối ưu màu sắc sắc nét khi dùng Chế độ Sáng (Light Mode), hiển thị đa ngôn ngữ chuẩn xác và nâng cao độ mượt toàn diện.',
      'badge': 'BẢN CẬP NHẬT',
      'features': [
        {
          'icon': '🎨',
          'title': 'Giao diện Chế độ Sáng (Light Mode) sắc nét',
          'description': 'Màu chữ và khung thông tin tự động chuyển đổi tương phản cao trên nền sáng, xem thông tin dễ dàng và êm mắt.',
        },
        {
          'icon': '🌐',
          'title': 'Trải nghiệm Đa ngôn ngữ chuẩn xác',
          'description': 'Tất cả nút bấm, hộp thoại thông báo và thông tin hiển thị tự động tinh chỉnh mượt mà theo Tiếng Việt và Tiếng Anh.',
        },
        {
          'icon': '⚡',
          'title': 'Tối ưu độ mượt & Phản hồi nhanh',
          'description': 'Tối ưu hóa toàn bộ hệ thống giúp ứng dụng phản hồi mượt mà, thao tác chuyển màn hình tức thì và tiết kiệm pin.',
        },
        {
          'icon': '📲',
          'title': 'Bảng thông báo bản mới trực quan',
          'description': 'Hộp thoại thông báo phiên bản mới tự động trình bày các tính năng mới rõ ràng, hiện đại và dễ xem.',
        },
      ],
    },
    {
      'version': '1.3.1+7',
      'date': '06/08/2026',
      'title': 'Sửa Lỗi Quảng Cáo Feed & Nâng Cấp Khôi Phục Giao Dịch 🚀',
      'subtitle': 'Xử lý dứt điểm lỗi đơ thanh tiến độ quảng cáo, tích hợp hiệu ứng quay dò tìm & thông báo lỗi mạng khi khôi phục mua hàng.',
      'badge': 'BẢN CẬP NHẬT',
      'features': [
        {
          'icon': '📢',
          'title': 'Sửa lỗi tải quảng cáo tài trợ',
          'description': 'Khắc phục lỗi đứng thanh phần trăm khi tải quảng cáo, tự động thông báo và hỗ trợ thử lại hoặc nâng cấp Gold Pass.',
        },
        {
          'icon': '💳',
          'title': 'Khôi phục gói hội viên mượt mà',
          'description': 'Hiển thị vòng xoay trạng thái tìm kiếm trực tiếp cạnh chữ Khôi Phục Giao Dịch, đồng bộ kết quả thực từ cửa hàng.',
        },
        {
          'icon': '📡',
          'title': 'Thông báo kết nối mạng',
          'description': 'Tự động phát hiện và báo lỗi thân thiện khi thiết bị ngắt kết nối Internet trong lúc khôi phục mua hàng.',
        },
        {
          'icon': '🌐',
          'title': 'Hỗ trợ đa ngôn ngữ hoàn hảo',
          'description': 'Tối ưu hóa toàn bộ giao diện thông báo và cài đặt theo ngôn ngữ Tiếng Việt & Tiếng Anh.',
        },
      ],
    },
    {
      'version': '1.3.0+6',
      'date': '06/08/2026',
      'title': 'Tối Ưu Bảng Tin Locket & Nhắn Tin Siêu Mượt 🚀',
      'subtitle': 'Cải tiến độ mượt khi lướt feed, đồng bộ tin nhắn chuẩn xác và hiển thị ảnh đại diện sắc nét.',
      'badge': 'BẢN CẬP NHẬT',
      'features': [
        {
          'icon': '💬',
          'title': 'Trò chuyện & Nhắn tin chuẩn xác',
          'description': 'Nội dung tin nhắn hiển thị đầy đủ, đồng bộ ngay lập tức giữa danh sách và khung chat chi tiết.',
        },

        {
          'icon': '⚡',
          'title': 'Lướt bảng tin siêu mượt',
          'description': 'Tối ưu tốc độ cuộn bảng tin Locket, thao tác vuốt mượt mà và tiết kiệm pin tối đa.',
        },
        {
          'icon': '👤',
          'title': 'Ảnh đại diện Google sắc nét',
          'description': 'Tự động cập nhật ảnh đại diện mới nhất từ tài khoản Google và bạn bè.',
        },
        {
          'icon': '🔍',
          'title': 'Bộ lọc bài viết thông minh',
          'description': 'Dễ dàng lọc xem khoảnh khắc của Tôi, Bạn thân hoặc từng người bạn cụ thể.',
        },
      ],
    },
    {
      'version': '1.2.0+5',
      'date': '05/08/2026',
      'title': 'Nâng Cấp Giao Diện Locket Mới & Trải Nghiệm Siêu Mượt ✨',
      'subtitle': 'Trải nghiệm chụp ảnh Locket đỉnh cao với tông màu tối sang trọng, gửi tin nhắn siêu tốc và giao diện mượt mà.',
      'badge': 'TÍNH NĂNG MỚI',
      'features': [
        {
          'icon': '📸',
          'title': 'Giao diện Locket Pitch Black Sang Trọng',
          'description': 'Khung camera bo góc mềm mại, tông nền đen tối mịn bảo vệ mắt và các nút bấm màu vàng ánh kim phong cách Locket hiện đại.',
        },
        {
          'icon': '⚡',
          'title': 'Đăng bài & Gửi tin nhắn siêu tốc',
          'description': 'Tốc độ tải ảnh Locket, gửi lời nhắn và thả biểu cảm cảm xúc được nâng cấp nhanh tức thì.',
        },
        {
          'icon': '💛',
          'title': 'Kết nối bạn bè & Người yêu mượt mà',
          'description': 'Dễ dàng kết nối bạn bè, chụp ảnh khoảnh khắc đôi và cập nhật chuỗi lửa ngày liên tục.',
        },
        {
          'icon': '📱',
          'title': 'Giao diện thông báo mới vừa vặn',
          'description': 'Bảng thông tin phiên bản mới được thiết kế rộng rãi, bo góc đẹp mắt và tự động căn chỉnh vừa vặn màn hình.',
        },
      ],
    },
    {
      'version': '1.1.0+4',
      'date': '02/08/2026',
      'title': 'Nâng Cấp Trải Nghiệm Siêu Tốc & Giao Diện Mới 🚀',
      'subtitle': 'Cải tiến vượt trội tốc độ chia sẻ khoảnh khắc, nâng cấp độ mượt và tối ưu hiển thị giao diện.',
      'badge': 'TÍNH NĂNG MỚI',
      'features': [
        {
          'icon': '⚡',
          'title': 'Truyền tải tin nhắn & ảnh siêu tốc',
          'description': 'Nâng cấp toàn diện tốc độ kết nối giúp tin nhắn và hình ảnh được gửi nhận tức thì.',
        },
        {
          'icon': '🌙',
          'title': 'Bảo vệ mắt với Chế độ tối toàn diện',
          'description': 'Giao diện tối cao cấp giúp bảo vệ mắt, không lo bị chói kể cả khi sử dụng ban đêm.',
        },
        {
          'icon': '👥',
          'title': 'Hiển thị bài viết bạn bè mượt mà',
          'description': 'Cập nhật khoảnh khắc mới nhất của bạn bè nhanh chóng và đầy đủ.',
        },
        {
          'icon': '👤',
          'title': 'Cải tiến hình đại diện lịch sử',
          'description': 'Hình đại diện trong danh sách chuỗi ngày hiển thị trực quan và đẹp mắt hơn.',
        },
      ],
    },
    {
      'version': '1.0.2+3',
      'date': '02/08/2026',
      'title': 'Bản Sửa Lỗi & Tối Ưu Hóa Giao Diện 🌟',
      'subtitle': 'Khắc phục các sự cố hiển thị, cải thiện độ ổn định và mang lại trải nghiệm xem ảnh tuyệt vời.',
      'badge': 'BẢN SỬA LỖI',
      'features': [
        {
          'icon': '🚪',
          'title': 'Đăng xuất & Chuyển tài khoản mượt mà',
          'description': 'Đảm bảo quá trình đăng xuất và chuyển đổi tài khoản diễn ra an toàn, không bị gián đoạn.',
        },
        {
          'icon': '🛡️',
          'title': 'Tối ưu hiển thị vừa vặn màn hình',
          'description': 'Tự động căn chỉnh giao diện không bị che khuất bởi các thanh điều hướng trên nhiều dòng máy.',
        },
        {
          'icon': '👥',
          'title': 'Cập nhật bạn bè & Bạn thân thời gian thực',
          'description': 'Danh sách bạn bè và trạng thái bạn thân tự động cập nhật tức thì.',
        },
        {
          'icon': '🖼️',
          'title': 'Bảo toàn Ảnh đại diện',
          'description': 'Giữ nguyên ảnh đại diện của bạn khi đăng nhập lại mà không bị mất hoặc reset.',
        },
        {
          'icon': '📢',
          'title': 'Quảng cáo vận hành mượt mà',
          'description': 'Tối ưu hóa giao diện hiển thị quảng cáo giúp trải nghiệm xem bảng tin luôn ổn định.',
        },
        {
          'icon': '🔍',
          'title': 'Tùy chỉnh ống kính camera',
          'description': 'Tự động căn chỉnh các mức thu phóng camera phù hợp với ống kính thiết bị của bạn.',
        },
      ],
    },
    {
      'version': '1.0.1+2',
      'date': '01/08/2026',
      'title': 'Cải Tiến Trang Cá Nhân & Đăng Xuất 🛠️',
      'subtitle': 'Tối ưu hóa tốc độ tải thông tin cá nhân và trải nghiệm cập nhật tài khoản.',
      'badge': 'BẢN CẬP NHẬT',
      'features': [
        {
          'icon': '🚪',
          'title': 'Đăng xuất an toàn',
          'description': 'Làm sạch thông tin cá nhân khi bấm đăng xuất, đảm bảo an toàn dữ liệu tài khoản.',
        },
        {
          'icon': '⏳',
          'title': 'Tải trang cá nhân siêu tốc',
          'description': 'Tải nhanh thông tin bạn bè và chuỗi ngày thắp lửa để mở giao diện tức thì.',
        },
        {
          'icon': '👤',
          'title': 'Đồng bộ thông tin cá nhân',
          'description': 'Cập nhật và lưu trữ thông tin cá nhân an toàn trên hệ thống đám mây.',
        },
      ],
    },
    {
      'version': '1.0.0+1',
      'date': '26/07/2026',
      'title': 'Khởi Chạy Chính Thức Army Locket UI 🚀',
      'subtitle': 'Phiên bản đầu tiên mang tới trải nghiệm Locket Dark mượt mà, camera chuyên nghiệp và chia sẻ ảnh bạn bè.',
      'badge': 'TÍNH NĂNG MỚI',
      'features': [
        {
          'icon': '📸',
          'title': 'Camera Locket & Thu phóng mượt mà',
          'description': 'Tùy chỉnh tỷ lệ 1:1, 4:3, thu phóng camera sau, bật tắt đèn pin và lật camera mượt mà.',
        },
        {
          'icon': '✂️',
          'title': 'Cắt ảnh Locket tương tác',
          'description': 'Bộ công cụ cắt ảnh từ thư viện với cử chỉ kéo thả, cuộn chuột, zoom và xem trước khung bo tròn 24px.',
        },
        {
          'icon': '😊',
          'title': 'Sticker Tâm trạng & Dòng trạng thái',
          'description': 'Đính kèm sticker biểu cảm emoji hệ thống và dòng trạng thái tự động nổi trên bàn phím.',
        },
        {
          'icon': '🌐',
          'title': 'Hỗ trợ Đa ngôn ngữ',
          'description': 'Hỗ trợ thay đổi ngôn ngữ Tiếng Việt & Tiếng Anh tức thì trong phần Cài đặt.',
        },
        {
          'icon': '🔔',
          'title': 'Nhắc nhở & Thông báo tức thì',
          'description': 'Nhận thông báo ngay khi bạn bè thả cảm xúc, nhắn tin, trả lời khoảnh khắc.',
        },
        {
          'icon': '🏆',
          'title': 'Bộ Danh Hiệu & Thành Tựu Army',
          'description': 'Hệ thống huy hiệu tiến cấp phong phú, theo dõi tiến độ và chinh phục các cột mốc ý nghĩa.',
        },
      ],
    },
  ];

  bool checkHasUpdate(String serverVersion) {
    return serverVersion != currentVersion;
  }
}
