import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_analytics.dart';
import '../services/txa_format.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_feed_service.dart';
import '../widgets/txa_network_image.dart';

class TXARecapScreen extends StatefulWidget {
  const TXARecapScreen({super.key});

  @override
  State<TXARecapScreen> createState() => _TXARecapScreenState();
}

class _TXARecapScreenState extends State<TXARecapScreen> {
  String? _selectedPeriod; // 'daily', 'weekly', 'monthly', 'yearly', 'all_time'
  int _periodOffset = 0; // 0 = current period, -1 = 1 period ago, -2 = 2 periods ago, etc.
  int _storyIndex = 0;
  Timer? _storyTimer;
  PageController? _pageController;
  List<LocketPostModel> _filteredPosts = [];
  int get _totalSlides => 3 + (_filteredPosts.length > 12 ? 12 : _filteredPosts.length);

  // Stats computed from filtered posts
  int _totalPostsCount = 0;
  int _activeDaysCount = 0;
  String _topMoodEmoji = '🦊';
  String _longestCaption = '';
  int _loverInteractionsCount = 0;
  int _friendInteractionsCount = 0;
  String _mostActiveTime = '';
  String _firstPostDateText = '';
  int _totalReactionsReceived = 0;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenRecap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    _pageController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  DateTime? _lastKeyTime;

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final now = DateTime.now();
    if (_lastKeyTime != null && now.difference(_lastKeyTime!) < const Duration(milliseconds: 220)) {
      return; // Prevent double-triggering key events
    }
    _lastKeyTime = now;

    if (_selectedPeriod != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Arrow Left: Go to previous slide / story
        _storyTimer?.cancel();
        if (_storyIndex > 0) {
          _storyIndex--;
          _animateToStoryPage(_storyIndex);
          setState(() {});
          _startStoryTimer();
        } else if (_periodOffset < 0) {
          _periodOffset++;
          _startRecap(_selectedPeriod!);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Arrow Right: Go to next slide / story
        _storyTimer?.cancel();
        if (_storyIndex < _totalSlides - 1) {
          _storyIndex++;
          _animateToStoryPage(_storyIndex);
          setState(() {});
          _startStoryTimer();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Arrow Up: Jump to previous period (Kỳ trước)
        _periodOffset--;
        _startRecap(_selectedPeriod!);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Arrow Down: Jump to next period (Kỳ sau)
        if (_periodOffset < 0) {
          _periodOffset++;
          _startRecap(_selectedPeriod!);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        // Escape: Close story view
        setState(() {
          _selectedPeriod = null;
          _periodOffset = 0;
        });
      }
    }
  }

  void _startRecap(String period) {
    final txaAuth = TXAAuthService.instance;
    final txaLang = TXALanguage.instance;
    final txaFeed = TXAFeedService.instance;
    final currentUser = txaAuth.currentUser;
    final currentUsername = currentUser?.username ?? '';

    // 1. Get visible posts for user
    final allPosts = txaFeed.getVisiblePostsForUser(currentUsername).whereType<LocketPostModel>().toList();

    // 2. Filter posts by time period with _periodOffset
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (period == 'daily') {
      final targetDay = now.add(Duration(days: _periodOffset));
      startDate = DateTime(targetDay.year, targetDay.month, targetDay.day, 0, 0, 0);
      endDate = DateTime(targetDay.year, targetDay.month, targetDay.day, 23, 59, 59);
    } else if (period == 'weekly') {
      final targetEnd = now.add(Duration(days: _periodOffset * 7));
      startDate = targetEnd.subtract(const Duration(days: 7));
      endDate = targetEnd;
    } else if (period == 'monthly') {
      final targetEnd = now.add(Duration(days: _periodOffset * 30));
      startDate = targetEnd.subtract(const Duration(days: 30));
      endDate = targetEnd;
    } else if (period == 'yearly') {
      final targetEnd = now.add(Duration(days: _periodOffset * 365));
      startDate = targetEnd.subtract(const Duration(days: 365));
      endDate = targetEnd;
    } else {
      startDate = DateTime(2000);
      endDate = now;
    }

    _filteredPosts = allPosts.where((post) {
      try {
        final postTime = DateTime.parse(post.createdTime);
        return postTime.isAfter(startDate) && postTime.isBefore(endDate);
      } catch (_) {
        return false;
      }
    }).toList();

    if (_filteredPosts.isEmpty) {
      setState(() {
        _selectedPeriod = period;
        _totalPostsCount = 0;
      });
      return;
    }

    // 3. Compute stats
    _totalPostsCount = _filteredPosts.length;

    // Active days count
    final uniqueDays = _filteredPosts.map((post) {
      try {
        final dt = DateTime.parse(post.createdTime);
        return '${dt.year}-${dt.month}-${dt.day}';
      } catch (_) {
        return '';
      }
    }).where((day) => day.isNotEmpty).toSet();
    _activeDaysCount = uniqueDays.length;

    // Top mood emoji
    final moodCounts = <String, int>{};
    for (var post in _filteredPosts) {
      if (post.caption.isNotEmpty) {
        // Extract emojis or find standard mood indicators
        final regex = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true);
        final matches = regex.allMatches(post.caption);
        for (var m in matches) {
          final emoji = m.group(0)!;
          moodCounts[emoji] = (moodCounts[emoji] ?? 0) + 1;
        }
      }
    }
    if (moodCounts.isNotEmpty) {
      final sortedMoods = moodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _topMoodEmoji = sortedMoods.first.key;
    } else {
      _topMoodEmoji = currentUser?.avatar ?? '🦊';
    }

    // Longest/Most memorable caption
    final captions = _filteredPosts.map((p) => p.caption).where((c) => c.isNotEmpty).toList();
    if (captions.isNotEmpty) {
      captions.sort((a, b) => b.length.compareTo(a.length));
      _longestCaption = captions.first;
    } else {
      _longestCaption = period == 'daily'
          ? txaLang.getText('recap_default_daily_caption')
          : period == 'weekly'
              ? txaLang.getText('recap_default_weekly_caption')
              : period == 'monthly'
                  ? txaLang.getText('recap_default_monthly_caption')
                  : txaLang.getText('recap_default_custom_caption');
    }

    // Lover interactions count
    final loverUsername = currentUser?.loverUsername;
    if (loverUsername != null) {
      _loverInteractionsCount = _filteredPosts.where((p) => p.senderUsername == loverUsername || p.senderUsername == currentUsername).length;
    }

    // Friend interactions count
    final uniqueSenders = _filteredPosts.map((p) => p.senderUsername).where((u) => u != currentUsername).toSet();
    _friendInteractionsCount = uniqueSenders.length;

    // Total Reactions Received
    _totalReactionsReceived = 0;
    for (var post in _filteredPosts) {
      _totalReactionsReceived += post.reactions.length;
    }

    // First Post Date Text
    if (_filteredPosts.isNotEmpty) {
      final sortedChronological = List<LocketPostModel>.from(_filteredPosts)
        ..sort((a, b) {
          try {
            return DateTime.parse(a.createdTime).compareTo(DateTime.parse(b.createdTime));
          } catch (_) {
            return 0;
          }
        });
      try {
        final parsed = DateTime.parse(sortedChronological.first.createdTime);
        _firstPostDateText = '${parsed.day}/${parsed.month}/${parsed.year}';
      } catch (_) {
        _firstPostDateText = sortedChronological.first.timestampText;
      }
    } else {
      _firstPostDateText = '';
    }

    // Most Active Hour Time Category
    final hourCounts = <String, int>{
      'recap_active_morning': 0,
      'recap_active_afternoon': 0,
      'recap_active_evening': 0,
      'recap_active_night': 0,
    };
    for (var post in _filteredPosts) {
      try {
        final parsed = DateTime.parse(post.createdTime);
        final hr = parsed.hour;
        if (hr >= 4 && hr < 11) {
          hourCounts['recap_active_morning'] = hourCounts['recap_active_morning']! + 1;
        } else if (hr >= 11 && hr < 17) {
          hourCounts['recap_active_afternoon'] = hourCounts['recap_active_afternoon']! + 1;
        } else if (hr >= 17 && hr < 22) {
          hourCounts['recap_active_evening'] = hourCounts['recap_active_evening']! + 1;
        } else {
          hourCounts['recap_active_night'] = hourCounts['recap_active_night']! + 1;
        }
      } catch (_) {}
    }
    final sortedActiveTimes = hourCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    _mostActiveTime = sortedActiveTimes.first.key;

    // Initialize page controller and timer for stories
    _pageController = PageController();
    _storyIndex = 0;
    _startStoryTimer();

    setState(() {
      _selectedPeriod = period;
    });
  }

  void _animateToStoryPage(int targetPage, {Duration duration = const Duration(milliseconds: 300)}) {
    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.animateToPage(
        targetPage,
        duration: duration,
        curve: Curves.easeInOut,
      );
    }
  }

  void _startStoryTimer() {
    _storyTimer?.cancel();
    _storyTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_storyIndex < _totalSlides - 1) {
        _storyIndex++;
        _animateToStoryPage(_storyIndex, duration: const Duration(milliseconds: 350));
        setState(() {});
      } else {
        _storyTimer?.cancel();
        // Go back to choice screen
        setState(() {
          _selectedPeriod = null;
        });
      }
    });
  }

  void _onStoryTap(TapDownDetails details, double screenWidth) {
    final dx = details.globalPosition.dx;
    _storyTimer?.cancel();

    if (dx < screenWidth * 0.3) {
      // Tap Left -> Previous page
      if (_storyIndex > 0) {
        _storyIndex--;
        _animateToStoryPage(_storyIndex);
        setState(() {});
        _startStoryTimer();
      } else {
        // Go back to menu
        setState(() {
          _selectedPeriod = null;
        });
      }
    } else {
      // Tap Right -> Next page
      if (_storyIndex < _totalSlides - 1) {
        _storyIndex++;
        _animateToStoryPage(_storyIndex);
        setState(() {});
        _startStoryTimer();
      } else {
        // Finished
        setState(() {
          _selectedPeriod = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final size = MediaQuery.of(context).size;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: TXATheme.background,
        body: SafeArea(
          child: _selectedPeriod == null ? _buildPeriodSelection(txaLang) : _buildStoryLayout(txaLang, size),
        ),
      ),
    );
  }

  Widget _buildPeriodSelection(TXALanguage txaLang) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButton(
            alignment: Alignment.centerLeft,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),

          // Mascot Armi with camera
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: TXATheme.cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: TXATheme.primaryYellow.withAlpha(120), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: TXATheme.primaryYellow.withAlpha(60),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/armi_happy.png',
                  width: 60,
                  height: 60,
                  errorBuilder: (ctx, err, stack) => const Text('🐜📸', style: TextStyle(fontSize: 38)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            txaLang.getText('recap_screen_title').toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            txaLang.getText('recap_select_period'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TXATheme.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Daily
                _buildPeriodCard(
                  title: txaLang.getText('recap_daily'),
                  desc: txaLang.getText('recap_daily_desc'),
                  icon: Icons.today_rounded,
                  color: Colors.amber,
                  onTap: () {
                    _periodOffset = 0;
                    _startRecap('daily');
                  },
                ),
                const SizedBox(height: 16),
                // 2. Weekly
                _buildPeriodCard(
                  title: txaLang.getText('recap_weekly'),
                  desc: txaLang.getText('recap_weekly_desc'),
                  icon: Icons.wb_sunny_rounded,
                  color: const Color(0xFF42A5F5),
                  onTap: () {
                    _periodOffset = 0;
                    _startRecap('weekly');
                  },
                ),
                const SizedBox(height: 16),
                // 3. Monthly
                _buildPeriodCard(
                  title: txaLang.getText('recap_monthly'),
                  desc: txaLang.getText('recap_monthly_desc'),
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFFF43F5E),
                  onTap: () {
                    _periodOffset = 0;
                    _startRecap('monthly');
                  },
                ),
                const SizedBox(height: 16),
                // 4. Yearly
                _buildPeriodCard(
                  title: txaLang.getText('recap_yearly'),
                  desc: txaLang.getText('recap_yearly_desc'),
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFFAB47BC),
                  onTap: () {
                    _periodOffset = 0;
                    _startRecap('yearly');
                  },
                ),
                const SizedBox(height: 16),
                // 5. All time
                _buildPeriodCard(
                  title: txaLang.getText('recap_all_time'),
                  desc: txaLang.getText('recap_all_time_desc'),
                  icon: Icons.all_inclusive_rounded,
                  color: const Color(0xFF26A69A),
                  onTap: () {
                    _periodOffset = 0;
                    _startRecap('all_time');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TXATheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: TXATheme.cardBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(color: TXATheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: TXATheme.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryLayout(TXALanguage txaLang, Size size) {
    if (_filteredPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                onPressed: () => setState(() => _selectedPeriod = null),
              ),
            ),
            const Spacer(),
            Image.asset(
              'assets/images/armi_surprised.png',
              width: 120,
              height: 120,
              errorBuilder: (ctx, err, stack) => const Text('🐜😮', style: TextStyle(fontSize: 68)),
            ),
            const SizedBox(height: 24),
            Text(
              txaLang.getText('recap_no_posts'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
          ],
        ),
      );
    }

    final widthLimit = size.width > 450 ? 450.0 : size.width;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Stack(
          children: [
            // Story Pages with background gesture
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _onStoryTap(details, widthLimit),
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStoryPage1(txaLang),
                  ..._buildIndividualPhotoSlides(),
                  _buildStoryPage3(txaLang),
                  _buildStoryPage4(txaLang),
                ],
              ),
            ),

              // Progress Bars at top
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: List.generate(_totalSlides, (index) {
                    final isPassed = index < _storyIndex;
                    final isCurrent = index == _storyIndex;

                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.0),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isPassed
                              ? TXATheme.primaryYellow
                              : isCurrent
                                  ? Colors.white24
                                  : Colors.white10,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: isCurrent
                            ? TweenAnimationBuilder<double>(
                                key: ValueKey(_storyIndex),
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                duration: const Duration(seconds: 5),
                                builder: (context, value, child) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: value,
                                      child: Container(
                                        color: TXATheme.primaryYellow,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  }),
                ),
              ),

              // Floating Side Navigation Arrows for jumping forward and backward between slides
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left arrow: Go back to previous slide
                    if (_storyIndex > 0 || _periodOffset < 0)
                      GestureDetector(
                        onTap: () {
                          _storyTimer?.cancel();
                          if (_storyIndex > 0) {
                            _storyIndex--;
                            _animateToStoryPage(_storyIndex);
                            setState(() {});
                            _startStoryTimer();
                          } else if (_periodOffset < 0) {
                            _periodOffset++;
                            _startRecap(_selectedPeriod!);
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 80,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(60),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                          ),
                          child: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 28),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Right arrow: Go forward to next slide
                    if (_storyIndex < _totalSlides - 1)
                      GestureDetector(
                        onTap: () {
                          _storyTimer?.cancel();
                          _storyIndex++;
                          _animateToStoryPage(_storyIndex);
                          setState(() {});
                          _startStoryTimer();
                        },
                        child: Container(
                          width: 44,
                          height: 80,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(60),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                          ),
                          child: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),

              // Top Info bar with period title, period switcher (◀ / ▶) and close icon
              Positioned(
                top: 26,
                left: 12,
                right: 12,
                child: Builder(
                  builder: (ctx) {
                    String titleText = '';
                    if (_selectedPeriod == 'daily') {
                      titleText = _periodOffset == 0 ? txaLang.getText('recap_daily') : 'Ngày ${_periodOffset.abs()} trước';
                    } else if (_selectedPeriod == 'weekly') {
                      titleText = _periodOffset == 0 ? txaLang.getText('recap_weekly') : 'Tuần ${_periodOffset.abs()} trước';
                    } else if (_selectedPeriod == 'monthly') {
                      titleText = _periodOffset == 0 ? txaLang.getText('recap_monthly') : 'Tháng ${_periodOffset.abs()} trước';
                    } else if (_selectedPeriod == 'yearly') {
                      titleText = _periodOffset == 0 ? txaLang.getText('recap_yearly') : 'Năm ${_periodOffset.abs()} trước';
                    } else {
                      titleText = txaLang.getText('recap_all_time');
                    }

                    return Row(
                      children: [
                        // Button ◀ (Kỳ trước)
                        Tooltip(
                          message: 'Xem giai đoạn trước',
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(120),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 13),
                            ),
                            onPressed: () {
                              _periodOffset--;
                              _startRecap(_selectedPeriod!);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Title Chip
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(140),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              titleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Button ▶ (Kỳ sau)
                        Tooltip(
                          message: 'Xem giai đoạn tiếp theo',
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _periodOffset < 0 ? Colors.black.withAlpha(120) : Colors.black.withAlpha(40),
                                shape: BoxShape.circle,
                                border: Border.all(color: _periodOffset < 0 ? Colors.white24 : Colors.white10),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: _periodOffset < 0 ? Colors.white : Colors.white38,
                                size: 13,
                              ),
                            ),
                            onPressed: _periodOffset < 0
                                ? () {
                                    _periodOffset++;
                                    _startRecap(_selectedPeriod!);
                                  }
                                : null,
                          ),
                        ),

                        // Close button (X)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(120),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                          ),
                          onPressed: () => setState(() {
                            _selectedPeriod = null;
                            _periodOffset = 0;
                          }),
                        ),
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      );
    }

  // Slide 1: Stats summary
  Widget _buildStoryPage1(TXALanguage txaLang) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const TXAFadeSlideTransition(
            delay: Duration(milliseconds: 100),
            child: Text(
              '🌟',
              style: TextStyle(fontSize: 48),
            ),
          ),
          const SizedBox(height: 24),
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 250),
            child: Text(
              txaLang.getText('recap_posts_sent').replaceAll('%count%', TXAFormat.formatNumber(_totalPostsCount)),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 400),
            child: Text(
              txaLang.getText('recap_active_days').replaceAll('%days%', TXAFormat.formatNumber(_activeDaysCount)),
              style: const TextStyle(color: TXATheme.primaryYellow, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 28),
          
          // Additional Rich Statistics Card
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 600),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: TXATheme.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TXATheme.cardBorder),
              ),
              child: Column(
                children: [
                  _buildStatRow(Icons.calendar_today_rounded, txaLang.getText('recap_stat_first_post'), _firstPostDateText),
                  const Divider(color: Colors.white10, height: 16),
                  _buildStatRow(Icons.wb_sunny_rounded, txaLang.getText('recap_stat_most_active'), txaLang.getText(_mostActiveTime)),
                  const Divider(color: Colors.white10, height: 16),
                  _buildStatRow(Icons.favorite_rounded, txaLang.getText('recap_stat_reactions_received'), '$_totalReactionsReceived ❤️'),
                ],
              ),
            ),
          ),
          
          const Spacer(),
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 800),
            child: Image.asset(
              'assets/images/armi_happy.png',
              width: 100,
              height: 100,
              errorBuilder: (ctx, err, stack) => Text('🐜❤️', style: TextStyle(fontSize: 54)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: TXATheme.primaryYellow, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: TXATheme.textMuted, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }



  // Slide 3: Interactions / Lovers
  Widget _buildStoryPage3(TXALanguage txaLang) {
    final isLover = TXAAuthService.instance.currentUser?.loverUsername != null;
    final partner = TXAAuthService.instance.currentUser?.loverUsername ?? '';

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 100),
            child: Text(
              txaLang.getText('recap_together'),
              style: const TextStyle(color: Colors.white24, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 300),
            child: Text(
              isLover
                  ? txaLang.getText('recap_with_lover')
                      .replaceAll('%lover%', '@$partner')
                      .replaceAll('%count%', TXAFormat.formatNumber(_loverInteractionsCount))
                  : txaLang.getText('recap_with_friends')
                      .replaceAll('%count%', TXAFormat.formatNumber(_friendInteractionsCount)),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const Spacer(),
          // Heart or Friend icon pulsing
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 500),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isLover ? const Color(0xFFF43F5E).withAlpha(40) : TXATheme.primaryYellow.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLover ? Icons.favorite_rounded : Icons.people_alt_rounded,
                  color: isLover ? const Color(0xFFF43F5E) : TXATheme.primaryYellow,
                  size: 48,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // Slide 4: Highlights / Moods
  Widget _buildStoryPage4(TXALanguage txaLang) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 100),
            child: Text(
              txaLang.getText('recap_top_mood').toUpperCase(),
              style: const TextStyle(color: Colors.white24, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 250),
            child: Text(
              _topMoodEmoji,
              style: const TextStyle(fontSize: 72),
            ),
          ),
          const SizedBox(height: 48),
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 400),
            child: Text(
              txaLang.getText('recap_top_caption').toUpperCase(),
              style: const TextStyle(color: Colors.white24, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          TXAFadeSlideTransition(
            delay: const Duration(milliseconds: 550),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TXATheme.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TXATheme.cardBorder),
              ),
              child: Text(
                '"$_longestCaption"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  List<Widget> _buildIndividualPhotoSlides() {
    final list = _filteredPosts.take(12).toList();
    return list.map((post) {
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main Post Photo
            Center(
              child: AspectRatio(
                aspectRatio: post.aspectRatio == '1:1' ? 1.0 : 3 / 4,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: TXANetworkImage(
                      url: post.photoPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),

            // Top Header: Date and Sender
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(110),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12, width: 0.8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(int.tryParse(post.senderAvatarColor) ?? 0xFF42A5F5),
                      radius: 16,
                      child: ClipOval(
                        child: post.senderAvatar.startsWith('http')
                            ? TXANetworkImage(url: post.senderAvatar, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  post.senderAvatar,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.senderUsername,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          TXAFormat.formatPostTime(post.createdTime.isNotEmpty ? post.createdTime : post.timestampText),
                          style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Caption Floating Card
            if (post.caption.isNotEmpty)
              Positioned(
                bottom: 80,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    post.caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }
}

class TXAFadeSlideTransition extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const TXAFadeSlideTransition({super.key, required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Future.delayed(delay),
      builder: (context, snapshot) {
        final animated = snapshot.connectionState == ConnectionState.done;
        return TweenAnimationBuilder<double>(
          key: ValueKey(animated),
          tween: Tween<double>(begin: 0.0, end: animated ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0.0, 20.0 * (1.0 - value)),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}