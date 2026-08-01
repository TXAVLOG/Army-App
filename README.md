# Army 🐜 — Locket Dark Social & Instant Widget Moments

<p align="center">
  <img src="assets/icons/app_icon.png" width="120" alt="Army Logo" style="border-radius: 24px; box-shadow: 0 10px 25px rgba(0,0,0,0.5);" />
</p>

<p align="center">
  <b>Army</b> là ứng dụng mạng xã hội chia sẻ khoảnh khắc tức thì (Instant Widget Sharing) mang phong cách <b>Locket Dark Glassmorphic</b> hiện đại. Cho phép chụp ảnh, quay video ngắn 5 giây đính kèm âm nhạc Spotify và gửi trực tiếp tới màn hình chính (Home Widget) của bạn bè.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter&logoColor=white" alt="Flutter Version" />
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20iOS-brightgreen" alt="Supported Platforms" />
  <img src="https://img.shields.io/badge/Language-Vi%20%7C%20En-FFC72C" alt="Multi Language" />
  <img src="https://img.shields.io/badge/Backend-Firebase%20Cloud-FFCA28?logo=firebase&logoColor=white" alt="Firebase Backend" />
</p>

---

## 🚀 Tính Năng Nổi Bật (Key Features)

- 📸 **Camera Locket & 5s Video**: Chụp ảnh, quay video ngắn 5s với cụm Zoom 1.0x $\rightarrow$ 3.0x, bật/tắt Flash và lật camera mượt mà.
- 🎵 **Spotify Music Integration**: Tìm kiếm và đính kèm đoạn nhạc Spotify 30s truyền cảm hứng vào từng khoảnh khắc.
- 📮 **Tem Thư Bưu Chính Vintage (Postmark Stamp)**: Độc quyền tính năng tạo tem thư cổ điển đóng dấu thời gian & địa điểm cá nhân.
- 💖 **Chế Độ Tình Nhân (Love Mode)**: Không gian đôi tình nhân đếm số ngày yêu, gửi khoảnh khắc riêng và giữ chuỗi Streak 🔥.
- 🏆 **Hệ Thống Thành Tựu Tiến Cấp (TXAAchievement)**:
  - 12+ chuỗi thành tựu tiến cấp mở khóa huy hiệu (Đồng 🥉, Bạc 🥈, Vàng 🥇, Kim Cương 💎, Vương Miện 👑).
  - Phân cấp độ Dễ 🟢, Trung Bình 🟡, Khó 🔴 và Đỉnh Cao 🌟.
  - Bộ đếm % hoàn thành & **Tỉ lệ người chơi toàn cầu mở khóa (`Global Unlock Rate %`)**.
- 🌟 **Army Gold Pass (VIP Pass)**: Mở khóa trọn bộ **25+ Mẫu Icon 3D** tùy chỉnh giao diện ứng dụng.
- 🛡️ **Hệ Thống Bắt Lỗi Crash Tự Động (`TXACrashScreen`)**: Tự động bắt mọi ngoại lệ hệ thống, bảo vệ dữ liệu và đồng bộ log lỗi trực tiếp lên Cloud Firestore.
- 🌐 **Đa Ngôn Ngữ (Multi-Language)**: Chuyển đổi linh hoạt Tiếng Việt 🇻🇳 và Tiếng Anh 🇺🇸 toàn bộ ứng dụng.

---

## 🛠️ Yêu Cầu Môi Trường (Prerequisites)

- **Flutter SDK**: `>= 3.12.0`
- **Dart SDK**: `>= 3.0.0`
- **Android SDK**: `minSdk 28` (Android 9.0+) / `targetSdk 36`
- **Windows**: Windows 10 / 11 (Desktop Support)

---

## 💻 Hướng Dẫn Chạy & Build App (Getting Started)

### 1. Cài đặt Dependencies & Chạy ứng dụng

```bash
# Clone dự án về máy
git clone https://github.com/<your-username>/army.git
cd army

# Tải các gói phụ thuộc
flutter pub get

# Chạy ứng dụng trên thiết bị (Android / Windows)
flutter run
```

### 2. Build Bản Phát Hành Production (Release Builds)

Sử dụng kịch bản tự động `build_rs.bat` để biên dịch bản Release chuẩn bị xuất bản:

```powershell
# Build file Release APK
.\build_rs.bat apk

# Build file Android App Bundle (AAB) cho Google Play Console
.\build_rs.bat aab

# Build trọn bộ tất cả Artifacts
.\build_rs.bat all
```

> **Artifacts đầu ra**: Tất cả các file `.apk`, `.aab` phát hành đều được tập trung tự động tại thư mục `production/`.

---

## 📂 Cấu Trúc Dự Án (Project Breakdown)

```text
Army/
├── android/                 # Cấu hình Native Android (MainActivity.kt, AndroidManifest.xml)
├── assets/                  # Hình ảnh, icon 3D & tài nguyên tĩnh
├── docs/                    # Trang Privacy Policy & Terms cho GitHub Pages (docs/index.html)
├── lib/
│   ├── models/              # Lớp dữ liệu (TXAAchievement, LocketPostModel...)
│   ├── screens/             # Các màn hình chính (Locket Feed, Achievements, Profile, Crash Screen...)
│   ├── services/            # Dịch vụ cốt lõi (Auth, Firestore, Language, Achievements, Logger...)
│   ├── theme/               # TXATheme - Glassmorphic Theme System
│   ├── widgets/             # Các UI Components tái sử dụng (Badge, Dialog, Toast...)
│   └── main.dart            # Entrypoint với Top-Level Error Boundary
├── build_release.ps1        # PowerShell Script build Release tự động
├── build_rs.bat             # Batch Script gọi build_release.ps1
└── pubspec.yaml             # Cấu hình gói và dependencies
```

---

## 🔒 Chính Sách Quyền Riêng Tư (Privacy Policy)

Trang chính sách bảo mật của Army được lưu sẵn tại `docs/index.html` sẵn sàng để lưu trữ trên **GitHub Pages**:

- **Đường dẫn local**: [docs/index.html](docs/index.html)
- **Kích hoạt GitHub Pages**: Sau khi tạo Repo, vào `Settings -> Pages -> Branch -> Source: /docs` để công khai đường dẫn Privacy Policy cho Google Play Console.

---

## 📜 Giấy Phép (License)

Được phát triển bởi **TXA Team**. Bảo lưu mọi quyền đối với thương hiệu Army 🐜.
