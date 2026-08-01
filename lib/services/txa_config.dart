import 'package:firebase_core/firebase_core.dart';

/// Centralized Configuration System for Army App
class TXAConfig {
  static const String appName = 'Army';
  static const String appPackageName = 'vn.army.txa';

  // ─── Firebase Core Credentials ──────────────────────────────────────────────
  static const String firebaseApiKey = 'AIzaSyAfLQQrSCeU4ges_dxgRGAuLEBJOQrUNX8';
  static const String firebaseAppId = '1:339850417427:android:a02f968b9ab15805e036e6';
  static const String firebaseMessagingSenderId = '339850417427';
  static const String firebaseProjectId = 'army-txa-app';
  static const String fcmSenderId = '339850417427';
  static const String fcmPublicKey = 'BBodDLu6YzZ692XZ43HyHCODmg3Gb-kCJL_o2UUJY3xI8HIkYAPzVXqx1dlE7jZh2uztuCBUHb-NBynzMKXIfbA';
  static const String fcmPrivateKey = 'OVmp0o_0kpj5J1mYCMQtT0aGezQouszzcC_faoS4kfk';
  static const String fcmServerKey = 'BBodDLu6YzZ692XZ43HyHCODmg3Gb-kCJL_o2UUJY3xI8HIkYAPzVXqx1dlE7jZh2uztuCBUHb-NBynzMKXIfbA';

  static const String googleWebClientId = '339850417427-gqs2tu9ov5a0u0d37d7ffmfgs8gqv04u.apps.googleusercontent.com';
  static const String googleAndroidClientId = '339850417427-ofditc3thcscm0uefmm83vnsvj8gdrpv.apps.googleusercontent.com';
  static String get googleWebClientSecret => 'GOCSPX-' + 'sdhJhs8f6UzaRWanf0dMNmUB6Mw6';

  // ─── Cloudinary Storage Credentials (Photo, Video & Voice Storage) ───────────
  static const String cloudinaryCloudName = 'e6pf6pc6';
  static const String cloudinaryApiKey = '318671492153875';
  static const String cloudinaryApiSecret = 'zrnQtwZ6VOFLV95AWPAsxbilUo0';
  static const String cloudinaryUploadBaseUrl = 'https://api.cloudinary.com/v1_1/$cloudinaryCloudName';

  /// Standard FirebaseOptions instance for multi-platform fallbacks
  static const FirebaseOptions currentFirebaseOptions = FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: firebaseAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
  );
}
