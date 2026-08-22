import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/txa_language.dart';
import '../services/txa_rating_service.dart';

class TXARatingModal extends StatefulWidget {
  const TXARatingModal({super.key});

  static void show(BuildContext context) {
    TXARatingService.instance.incrementPromptCount();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TXARatingModal(),
    );
  }

  @override
  State<TXARatingModal> createState() => _TXARatingModalState();
}

class _TXARatingModalState extends State<TXARatingModal> {
  int _selectedStars = 5;
  final TextEditingController _feedbackCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  String _getDynamicMessage(TXALanguage lang) {
    if (_selectedStars == 5) {
      return lang.getText('rating_stars_5');
    } else if (_selectedStars == 4) {
      return lang.getText('rating_stars_4');
    } else {
      return lang.getText('rating_stars_low');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = TXALanguage.instance;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mascot Header
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF9100)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/armi_happy.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text('🐜', style: TextStyle(fontSize: 42)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            lang.getText('rating_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            lang.getText('rating_subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Interactive 5 Star Bar
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF22222E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  final isFilled = starNum <= _selectedStars;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedStars = starNum;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFilled ? const Color(0xFFFFD700) : Colors.white24,
                        size: 38,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dynamic Star Status Message
          Text(
            _getDynamicMessage(lang),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _selectedStars >= 4 ? const Color(0xFFFFD700) : const Color(0xFF29B6F6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),

          // Flow A: 4-5 Stars -> Big Store Button
          if (_selectedStars >= 4) ...[
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await TXARatingService.instance.openStoreListing();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(lang.getText('rating_thank_you_toast')),
                        backgroundColor: const Color(0xFF00E676),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.star_rounded, color: Colors.black),
                label: Text(
                  lang.getText('rating_rate_now_btn'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Flow B: 1-3 Stars -> Internal Feedback Form
            TextField(
              controller: _feedbackCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: lang.getText('rating_feedback_hint'),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF22222E),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF29B6F6)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSending
                  ? null
                  : () async {
                      if (_feedbackCtrl.text.trim().isEmpty) return;
                      setState(() => _isSending = true);
                      await TXARatingService.instance.sendInternalFeedback(
                        stars: _selectedStars,
                        feedback: _feedbackCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang.getText('rating_feedback_sent_toast')),
                            backgroundColor: const Color(0xFF29B6F6),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF29B6F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                lang.getText('rating_send_feedback_btn'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Bottom Action Links (Remind later / No thanks)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () async {
                  await TXARatingService.instance.recordRemindLater();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  lang.getText('rating_remind_later_btn'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              const Text('•', style: TextStyle(color: Colors.white24)),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () async {
                  await TXARatingService.instance.recordNoThanks();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  lang.getText('rating_no_thanks_btn'),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
