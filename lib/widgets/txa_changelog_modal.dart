import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_version.dart';

class TXAChangelogModal extends StatelessWidget {
  const TXAChangelogModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // Thêm useSafeArea để đảm bảo modal không bị thanh hệ thống che khuất
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TXAChangelogModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final latestChangelog = TXAVersion.changelogData.first;
    final features = latestChangelog['features'] as List<dynamic>;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14), // Pitch Black Locket background
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: Colors.white.withAlpha(25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(200),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Drag Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // 2. Header Row: Badge, Version Tag & Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Badge "TÍNH NĂNG MỚI" / "CẬP NHẬT"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE082), Color(0xFFFFC72C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC72C).withAlpha(90),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        latestChangelog['badge'] ?? 'TÍNH NĂNG MỚI',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Version Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(30)),
                  ),
                  child: Text(
                    latestChangelog['version'] ?? TXAVersion.fullVersionString,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const Spacer(),

                // Close Glass Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Title & Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latestChangelog['title'] ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  latestChangelog['subtitle'] ?? '',
                  style: TextStyle(
                    color: TXATheme.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 4. Feature Cards Scroll List
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: features.map((feat) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181820),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: TXATheme.primaryYellow.withAlpha(30),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: TXATheme.primaryYellow.withAlpha(80),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              feat['icon'] ?? '✨',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feat['title'] ?? '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                feat['description'] ?? '',
                                style: TextStyle(
                                  color: TXATheme.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 5. Bottom Action Button with Dynamic System Inset Protection
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: bottomPadding > 0 ? bottomPadding + 12 : 20,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TXATheme.primaryYellow,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shadowColor: TXATheme.primaryYellow.withAlpha(100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      txaLang.getText('continue'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}