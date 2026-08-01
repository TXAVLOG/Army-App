import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_version.dart';
import 'txa_toast.dart';

class TXAUpdateModal extends StatelessWidget {
  final String newVersion;
  final String updateNotes;
  final bool isForceUpdate;

  const TXAUpdateModal({
    super.key,
    required this.newVersion,
    required this.updateNotes,
    this.isForceUpdate = false,
  });

  static void show(
    BuildContext context, {
    String newVersion = '1.2.0',
    String updateNotes = 'Cập nhật thêm tính năng Love Feed, Sticker tâm trạng và tối ưu hóa tốc độ chụp ảnh.',
    bool isForceUpdate = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (ctx) => TXAUpdateModal(
        newVersion: newVersion,
        updateNotes: updateNotes,
        isForceUpdate: isForceUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: TXATheme.cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: TXATheme.primaryYellow.withAlpha(100), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(180),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Update Icon Badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: TXATheme.primaryYellow.withAlpha(40),
                shape: BoxShape.circle,
                border: Border.all(color: TXATheme.primaryYellow, width: 2),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: TXATheme.primaryYellow,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Có phiên bản mới!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Version Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Phiên bản hiện tại: ${TXAVersion.currentVersion}  ➔  Mới: $newVersion',
                style: const TextStyle(
                  color: TXATheme.primaryYellow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Description / Notes
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF121218),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TXATheme.cardBorder),
              ),
              child: Text(
                updateNotes,
                style: const TextStyle(
                  color: TXATheme.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                if (!isForceUpdate) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TXATheme.textPrimary,
                        side: BorderSide(color: TXATheme.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Để sau', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      TXAToast.show(
                        context,
                        '📲 Đang bắt đầu cập nhật In-App Update...',
                        icon: Icons.system_update_alt_rounded,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TXATheme.primaryYellow,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cập nhật ngay',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
