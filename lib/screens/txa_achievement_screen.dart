import 'package:flutter/material.dart';
import '../models/txa_achievement.dart';
import '../services/txa_achievement_service.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../widgets/txa_achievement_badge_widget.dart';
import '../widgets/txa_achievement_detail_dialog.dart';

class TXAAchievementScreen extends StatefulWidget {
  const TXAAchievementScreen({super.key});

  @override
  State<TXAAchievementScreen> createState() => _TXAAchievementScreenState();
}

class _TXAAchievementScreenState extends State<TXAAchievementScreen> {
  TXAAchievementCategory _selectedCategory = TXAAchievementCategory.all;

  @override
  void initState() {
    super.initState();
    TXAAchievementService.instance.init();
  }

  List<TXAAchievement> _getFilteredAchievements() {
    final list = TXAAchievementService.instance.achievements;
    if (_selectedCategory == TXAAchievementCategory.all) return list;
    return list.where((ach) => ach.category == _selectedCategory).toList();
  }

  String _getCategoryName(TXAAchievementCategory category) {
    switch (category) {
      case TXAAchievementCategory.all:
        return TXALanguage.instance.getText('cat_all');
      case TXAAchievementCategory.posts:
        return TXALanguage.instance.getText('cat_posts');
      case TXAAchievementCategory.friends:
        return TXALanguage.instance.getText('cat_friends');
      case TXAAchievementCategory.streak:
        return TXALanguage.instance.getText('cat_streak');
      case TXAAchievementCategory.love:
        return TXALanguage.instance.getText('cat_love');
      case TXAAchievementCategory.stamps:
        return TXALanguage.instance.getText('cat_stamps');
      case TXAAchievementCategory.spotify:
        return TXALanguage.instance.getText('cat_spotify');
      case TXAAchievementCategory.ultimate:
        return TXALanguage.instance.getText('cat_ultimate');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TXALanguage.instance,
        TXAAchievementService.instance,
      ]),
      builder: (context, _) {
        final service = TXAAchievementService.instance;
        final unlockedTiers = service.getTotalUnlockedTiers();
        final possibleTiers = service.getTotalPossibleTiers();
        final filteredList = _getFilteredAchievements();

        return Scaffold(
          backgroundColor: const Color(0xFF0C0C10),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0C0C10),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              TXALanguage.instance.getText('achievements_title'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Header Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A1A4E), Color(0xFF140D2A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                          border: Border.all(
                            color: TXATheme.primaryYellow,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '🏆',
                          style: TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TXALanguage.instance.getText('achievements_subtitle'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  TXALanguage.instance
                                      .getText('achievements_header_count')
                                      .replaceAll('%unlocked%', unlockedTiers.toString())
                                      .replaceAll('%total%', possibleTiers.toString()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${service.getOverallCompletionPercentage()}%',
                                  style: const TextStyle(
                                    color: TXATheme.primaryYellow,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: possibleTiers > 0
                                    ? (unlockedTiers / possibleTiers)
                                        .clamp(0.0, 1.0)
                                    : 0.0,
                                backgroundColor: Colors.black45,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  TXATheme.primaryYellow,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Category Chip Scroll Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: TXAAchievementCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(_getCategoryName(cat)),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        selectedColor: TXATheme.primaryYellow,
                        backgroundColor: const Color(0xFF1E1E28),
                        side: BorderSide(
                          color: isSelected
                              ? TXATheme.primaryYellow
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Badge Grid
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Text(
                          TXALanguage.instance.getText('no_posts_yet'),
                          style: const TextStyle(color: Colors.white38),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 190,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final ach = filteredList[index];
                          final currentValue = service.getStat(ach.id);

                          return TXAAchievementBadgeWidget(
                            achievement: ach,
                            currentValue: currentValue,
                            onTap: () {
                              TXAAchievementDetailDialog.show(
                                context,
                                achievement: ach,
                                currentValue: currentValue,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
