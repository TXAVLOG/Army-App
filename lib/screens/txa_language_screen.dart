import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import 'txa_format_screen.dart';

class TXALanguageScreen extends StatefulWidget {
  const TXALanguageScreen({super.key});

  @override
  State<TXALanguageScreen> createState() => _TXALanguageScreenState();
}

class _TXALanguageScreenState extends State<TXALanguageScreen> {
  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;

    return AnimatedBuilder(
      animation: txaLang,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: TXATheme.background,
          appBar: AppBar(
            title: Text(txaLang.getText('language_select_title')),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: TXALanguage.supportedLanguages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final code = TXALanguage.supportedLanguages.keys.elementAt(index);
                        final isSelected = txaLang.currentLanguage == code;
                        final title = code == 'vi' ? 'Tiếng Việt' : 'English';

                        return GestureDetector(
                          onTap: () {
                            txaLang.setLanguage(code);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            decoration: BoxDecoration(
                              color: TXATheme.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? TXATheme.primaryYellow : TXATheme.cardBorder,
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Text(
                                   title,
                                   style: TextStyle(
                                     fontSize: 16,
                                     fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                     color: isSelected ? TXATheme.primaryYellow : TXATheme.textPrimary,
                                   ),
                                 ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: TXATheme.primaryYellow,
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TXAFormatScreen()),
                        );
                      },
                      child: Text(txaLang.getText('continue')),
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
