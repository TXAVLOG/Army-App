import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_format.dart';
import 'txa_login_screen.dart';

class TXAFormatScreen extends StatefulWidget {
  const TXAFormatScreen({super.key});

  @override
  State<TXAFormatScreen> createState() => _TXAFormatScreenState();
}

class _TXAFormatScreenState extends State<TXAFormatScreen> {
  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaFormat = TXAFormat.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([txaLang, txaFormat]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: TXATheme.background,
          appBar: AppBar(
            title: Text(txaLang.getText('format_select_title')),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: TXATheme.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: TXATheme.cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            txaLang.getText('show_timestamp'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Switch(
                          value: txaFormat.showTimestamp,
                          activeTrackColor: TXATheme.primaryYellow,
                          onChanged: (val) => txaFormat.setShowTimestamp(val),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('txa_initial_setup_completed', true);

                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const TXALoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      child: Text(txaLang.getText('save')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

