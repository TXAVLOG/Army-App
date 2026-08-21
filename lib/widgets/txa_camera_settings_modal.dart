import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import 'txa_toast.dart';

class TXACameraSettingsModal extends StatefulWidget {
  final int initialFlashMode;
  final int initialTimerSeconds;
  final bool isRearCamera;
  final ValueChanged<int> onFlashChanged;
  final ValueChanged<int> onTimerChanged;

  const TXACameraSettingsModal({
    super.key,
    required this.initialFlashMode,
    required this.initialTimerSeconds,
    required this.isRearCamera,
    required this.onFlashChanged,
    required this.onTimerChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required int initialFlashMode,
    required int initialTimerSeconds,
    required bool isRearCamera,
    required ValueChanged<int> onFlashChanged,
    required ValueChanged<int> onTimerChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TXACameraSettingsModal(
        initialFlashMode: initialFlashMode,
        initialTimerSeconds: initialTimerSeconds,
        isRearCamera: isRearCamera,
        onFlashChanged: onFlashChanged,
        onTimerChanged: onTimerChanged,
      ),
    );
  }

  @override
  State<TXACameraSettingsModal> createState() => _TXACameraSettingsModalState();
}

class _TXACameraSettingsModalState extends State<TXACameraSettingsModal> {
  late int _currentFlashMode;
  late int _currentTimerSeconds;

  @override
  void initState() {
    super.initState();
    _currentFlashMode = widget.initialFlashMode;
    _currentTimerSeconds = widget.initialTimerSeconds;
  }

  void _selectFlashMode(int mode) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentFlashMode = mode;
    });
    widget.onFlashChanged(mode);

    final txaLang = TXALanguage.instance;
    final toasts = [
      txaLang.getText('flash_off_toast'),
      txaLang.getText('flash_on_toast'),
      txaLang.getText('flash_auto_toast'),
    ];
    final icons = [
      Icons.flash_off_rounded,
      Icons.flash_on_rounded,
      Icons.flash_auto_rounded,
    ];
    if (mode >= 0 && mode < toasts.length) {
      TXAToast.show(context, toasts[mode], icon: icons[mode]);
    }
  }

  void _selectTimerSeconds(int seconds) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentTimerSeconds = seconds;
    });
    widget.onTimerChanged(seconds);

    final txaLang = TXALanguage.instance;
    if (seconds == 0) {
      TXAToast.show(context, txaLang.getText('timer_off_toast'), icon: Icons.timer_off_outlined);
    } else {
      TXAToast.show(
        context,
        txaLang.getText('timer_set_toast').replaceAll('%sec%', '$seconds'),
        icon: Icons.timer_outlined,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Danh sách các tùy chọn Flash
    final flashOptions = [
      {
        'mode': 0,
        'title': txaLang.getText('flash_off'),
        'icon': Icons.flash_off_rounded,
      },
      {
        'mode': 1,
        'title': txaLang.getText('flash_on'),
        'icon': Icons.flash_on_rounded,
      },
      {
        'mode': 2,
        'title': txaLang.getText('flash_auto'),
        'icon': Icons.flash_auto_rounded,
      },
    ];

    // Danh sách các tùy chọn Hẹn giờ
    final timerOptions = [
      {
        'seconds': 0,
        'title': txaLang.getText('timer_off'),
        'badge': 'OFF',
        'icon': Icons.timer_off_outlined,
      },
      {
        'seconds': 3,
        'title': txaLang.getText('timer_3s'),
        'badge': '3s',
        'icon': Icons.timer_outlined,
      },
      {
        'seconds': 5,
        'title': txaLang.getText('timer_5s'),
        'badge': '5s',
        'icon': Icons.timer_outlined,
      },
      {
        'seconds': 7,
        'title': txaLang.getText('timer_7s'),
        'badge': '7s',
        'icon': Icons.timer_outlined,
      },
      {
        'seconds': 10,
        'title': txaLang.getText('timer_10s'),
        'badge': '10s',
        'icon': Icons.timer_outlined,
      },
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: Colors.white.withAlpha(25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(220),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 14),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // 2. Header: Title, Subtitle & Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TXATheme.primaryYellow.withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: TXATheme.primaryYellow.withAlpha(100),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: TXATheme.primaryYellow,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          txaLang.getText('camera_settings_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          txaLang.getText('camera_settings_subtitle'),
                          style: TextStyle(
                            color: Colors.white.withAlpha(140),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),

            // 3. Body: 2 Columns (Flash & Timer)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── CỘT 1: ĐÈN FLASH ───
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withAlpha(15),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Column Header
                            Row(
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: TXATheme.primaryYellow,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    txaLang.getText('flash_title').toUpperCase(),
                                    style: const TextStyle(
                                      color: TXATheme.primaryYellow,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Flash Items
                            ...flashOptions.map((opt) {
                              final mode = opt['mode'] as int;
                              final isSelected = _currentFlashMode == mode;
                              final title = opt['title'] as String;
                              final icon = opt['icon'] as IconData;

                              return _buildOptionTile(
                                title: title,
                                icon: icon,
                                isSelected: isSelected,
                                onTap: () => _selectFlashMode(mode),
                              );
                            }),

                            if (!widget.isRearCamera) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.orange.withAlpha(60),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.orangeAccent,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        txaLang.getText('flash_rear_only_hint'),
                                        style: TextStyle(
                                          color: Colors.orange.shade200,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ─── CỘT 2: HẸN GIỜ CHỤP ───
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withAlpha(15),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Column Header
                            Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: Color(0xFF4FC3F7),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    txaLang.getText('timer_title').toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF4FC3F7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Timer Items
                            ...timerOptions.map((opt) {
                              final seconds = opt['seconds'] as int;
                              final isSelected = _currentTimerSeconds == seconds;
                              final title = opt['title'] as String;
                              final badge = opt['badge'] as String?;
                              final icon = opt['icon'] as IconData;

                              return _buildOptionTile(
                                title: title,
                                badge: badge,
                                icon: icon,
                                isSelected: isSelected,
                                activeColor: const Color(0xFF4FC3F7),
                                onTap: () => _selectTimerSeconds(seconds),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 4. Footer Note & Done Button
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding > 0 ? bottomPadding : 16),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TXATheme.primaryYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded, size: 20, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      txaLang.getText('save'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
    Color activeColor = TXATheme.primaryYellow,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: activeColor.withAlpha(30),
          highlightColor: activeColor.withAlpha(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withAlpha(30) : Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? activeColor : Colors.white.withAlpha(15),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withAlpha(60),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : Colors.white.withAlpha(15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 14,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                ),
                const SizedBox(width: 8),

                // Label Text
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),

                // Badge / Checkmark
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: activeColor,
                    size: 16,
                  )
                else if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
