import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_feed_service.dart';
import '../services/txa_streak_service.dart';
import '../services/txa_language.dart';
import '../services/txa_format.dart';
import '../widgets/txa_toast.dart';

class TXAAdminPanelScreen extends StatefulWidget {
  const TXAAdminPanelScreen({super.key});

  @override
  State<TXAAdminPanelScreen> createState() => _TXAAdminPanelScreenState();
}

class _TXAAdminPanelScreenState extends State<TXAAdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserModel> _users = [];
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await TXAAuthService.instance.getAllUsersFromFirestore();
    final reports = await TXAFeedService.instance.getReportsFromFirestore();
    setState(() {
      _users = users;
      _reports = reports;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteUser(UserModel user) async {
    final txaLang = TXALanguage.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TXATheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(txaLang.getText('admin_delete_user_title'), style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold)),
        content: Text(txaLang.getText('admin_delete_user_confirm').replaceAll('%user%', user.username)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(txaLang.getText('cancel'), style: const TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: TXATheme.statusRed, foregroundColor: Colors.white),
            child: Text(txaLang.getText('admin_delete_btn')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TXAAuthService.instance.deleteUserFromFirestore(user.id);
      if (mounted) {
        TXAToast.show(context, txaLang.getText('admin_deleted_user_success').replaceAll('%user%', user.username));
        _loadData();
      }
    }
  }

  Future<void> _handleResolveReport(Map<String, dynamic> report) async {
    final txaLang = TXALanguage.instance;
    final reporter = report['reporter'] ?? '@user';
    await TXAFeedService.instance.resolveReport(
      reportId: report['id'],
      reporterUsername: reporter,
    );

    if (mounted) {
      TXAToast.show(context, txaLang.getText('admin_resolve_report_success').replaceAll('%reporter%', reporter));
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    return Scaffold(
      backgroundColor: TXATheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          txaLang.getText('admin_panel_title'),
          style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TXATheme.primaryYellow,
          labelColor: TXATheme.primaryYellow,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.bar_chart_rounded), text: txaLang.getText('admin_stats_tab')),
            Tab(icon: const Icon(Icons.people_rounded), text: 'Users (${TXAFormat.formatNumber(_users.length)})'),
            const Tab(icon: Icon(Icons.photo_library_rounded), text: 'Posts'),
            const Tab(icon: Icon(Icons.flag_rounded), text: 'Reports'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TXATheme.primaryYellow))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAnalyticsTab(),
                _buildUsersTab(),
                _buildPostsTab(),
                _buildReportsTab(),
              ],
            ),
    );
  }

  Widget _buildUsersTab() {
    final txaLang = TXALanguage.instance;
    if (_users.isEmpty) {
      return Center(child: Text(txaLang.getText('admin_no_users'), style: const TextStyle(color: TXATheme.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (context, index) => Divider(color: TXATheme.cardBorder, height: 16),
      itemBuilder: (ctx, idx) {
        final user = _users[idx];
        final isMe = user.username == TXAAuthService.instance.currentUser?.username;
        final isFriend = TXAAuthService.instance.friendsList.any((f) => f['username'] == user.username);

        final roleLocalized = user.role == 'admin'
            ? (txaLang.currentLanguage == 'vi' ? 'Quản trị viên' : 'Admin')
            : (txaLang.currentLanguage == 'vi' ? 'Người dùng' : 'User');

        final dt = DateTime.tryParse(user.createdTime);
        final dateLocalized = dt != null
            ? '${TXAFormat.formatNumber(dt.day)}/${TXAFormat.formatNumber(dt.month)}/${dt.year}'
            : user.createdTime.split("T").first;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Color(int.tryParse(user.avatarBgColor) ?? 0xFFF57C00),
            child: Text(user.avatar, style: const TextStyle(fontSize: 20)),
          ),
          title: Text(
            user.username,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            txaLang.getText('admin_role_created').replaceAll('%role%', roleLocalized).replaceAll('%date%', dateLocalized),
            style: const TextStyle(color: TXATheme.textMuted, fontSize: 12),
          ),
          trailing: isMe
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: Text(txaLang.getText('admin_you'), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isFriend ? Icons.person_remove_rounded : Icons.person_add_alt_1_rounded,
                        color: isFriend ? TXATheme.statusRed : TXATheme.primaryYellow,
                      ),
                      tooltip: isFriend ? txaLang.getText('admin_unfriend_tooltip') : txaLang.getText('admin_friend_tooltip'),
                      onPressed: () async {
                        if (isFriend) {
                          await TXAAuthService.instance.deleteFriendInstantly(user.username);
                          if (mounted) {
                            TXAToast.show(context, txaLang.getText('admin_unfriend_success').replaceAll('%user%', user.username));
                          }
                        } else {
                          await TXAAuthService.instance.addFriendInstantly(user);
                          if (mounted) {
                            TXAToast.show(context, txaLang.getText('admin_friend_success').replaceAll('%user%', user.username));
                          }
                        }
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: TXATheme.statusRed),
                      tooltip: txaLang.getText('admin_delete_user_title'),
                      onPressed: () => _handleDeleteUser(user),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildPostsTab() {
    final txaLang = TXALanguage.instance;
    final posts = TXAFeedService.instance.posts;
    if (posts.isEmpty) {
      return Center(child: Text(txaLang.getText('admin_no_posts'), style: const TextStyle(color: TXATheme.textMuted)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: (() {
          final w = MediaQuery.of(context).size.width;
          if (w >= 1200) return 6;
          if (w >= 900) return 5;
          if (w >= 600) return 4;
          return 2;
        })(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: posts.length,
      itemBuilder: (ctx, idx) {
        final post = posts[idx];
        return Container(
          decoration: BoxDecoration(
            color: TXATheme.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TXATheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: post.photoPath.startsWith('assets/')
                      ? Image.asset(post.photoPath, fit: BoxFit.cover)
                      : Image.network(post.photoPath, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                          return Container(color: Colors.white12, child: const Icon(Icons.broken_image, color: Colors.white30));
                        }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.senderUsername,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.caption.isNotEmpty ? post.caption : txaLang.getText('admin_no_caption'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: TXATheme.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(post.timestampText, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: TXATheme.cardBg,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                title: Text(txaLang.getText('admin_delete_post_title'), style: const TextStyle(color: TXATheme.statusRed, fontWeight: FontWeight.bold)),
                                content: Text(txaLang.getText('admin_delete_post_confirm')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(txaLang.getText('cancel'), style: const TextStyle(color: Colors.white70))),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: TXATheme.statusRed, foregroundColor: Colors.white),
                                    child: Text(txaLang.getText('admin_delete_btn')),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await TXAFeedService.instance.deletePost(post.id);
                               if (mounted) {
                                 TXAToast.show(context, txaLang.getText('admin_deleted_post_success'));
                               }
                              _loadData();
                            }
                          },
                          child: const Icon(Icons.delete_outline_rounded, color: TXATheme.statusRed, size: 18),
                        )
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsTab() {
    final txaLang = TXALanguage.instance;
    if (_reports.isEmpty) {
      return Center(child: Text(txaLang.getText('admin_no_reports'), style: const TextStyle(color: TXATheme.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      separatorBuilder: (context, index) => Divider(color: TXATheme.cardBorder, height: 16),
      itemBuilder: (ctx, idx) {
        final r = _reports[idx];
        final isResolved = r['status'] == 'resolved';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TXATheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TXATheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    txaLang.getText('admin_report_by').replaceAll('%reporter%', r['reporter'] ?? '@user'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isResolved ? TXATheme.statusGreen.withAlpha(40) : TXATheme.statusRed.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isResolved ? txaLang.getText('admin_report_resolved') : txaLang.getText('admin_report_pending'),
                      style: TextStyle(
                        color: isResolved ? TXATheme.statusGreen : TXATheme.statusRed,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 6),
              Text(
                txaLang.getText('admin_report_target').replaceAll('%target%', r['postSender'] ?? '@user'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (r['caption'] != null && r['caption'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  txaLang.getText('admin_report_content').replaceAll('%content%', r['caption'].toString()),
                  style: const TextStyle(color: TXATheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isResolved) ...[
                    OutlinedButton(
                      onPressed: () => _handleResolveReport(r),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TXATheme.primaryYellow,
                        side: const BorderSide(color: TXATheme.primaryYellow),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: Text(txaLang.getText('admin_resolve_fcm_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    Text(txaLang.getText('admin_reporter_notified'), style: const TextStyle(color: Colors.white30, fontSize: 11)),
                  ]
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    final txaLang = TXALanguage.instance;
    final allPosts = TXAFeedService.instance.posts;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Thống kê bài đăng
    final totalPosts = allPosts.length;
    final postsToday = allPosts.where((p) => p.createdTime.startsWith(todayStr)).length;

    // 2. Thống kê người dùng
    final totalUsers = _users.length;
    final usersToday = _users.where((u) => u.createdTime.startsWith(todayStr)).length;

    // 3. Thống kê cặp đôi tình yêu
    final couplesCount = _users.where((u) => u.loverUsername != null && u.loverUsername!.isNotEmpty).length ~/ 2;

    // 4. Tổng lượt tương tác
    int totalReactions = 0;
    for (var p in allPosts) {
      totalReactions += p.reactions.length;
    }

    // 5. BXH Top người có chuỗi lửa cao nhất
    final usersWithStreak = List<UserModel>.from(_users)
      ..sort((a, b) => TXAStreakService.instance.getStreak(b.username).compareTo(TXAStreakService.instance.getStreak(a.username)));
    final topStreakUsers = usersWithStreak.take(10).toList();

    // 6. BXH Top người đăng bài nhiều nhất
    final postCounts = <String, int>{};
    final todayPostCounts = <String, int>{};
    for (var p in allPosts) {
      postCounts[p.senderUsername] = (postCounts[p.senderUsername] ?? 0) + 1;
      if (p.createdTime.startsWith(todayStr)) {
        todayPostCounts[p.senderUsername] = (todayPostCounts[p.senderUsername] ?? 0) + 1;
      }
    }
    final sortedPosters = postCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topPosters = sortedPosters.take(10).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // --- HEADER SYSTEM STATS OVERVIEW ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              txaLang.getText('admin_stats_overview'),
              style: const TextStyle(color: TXATheme.primaryYellow, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white60, size: 18),
              onPressed: _loadData,
              tooltip: txaLang.getText('admin_refresh_tooltip'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          childAspectRatio: 1.35,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Stat 1: Tổng Bài Đăng (Army)
            _buildStatCard(
              title: txaLang.getText('admin_total_army'),
              value: TXAFormat.formatNumber(totalPosts),
              subBadge: postsToday > 0 ? txaLang.getText('admin_today_posts').replaceAll('%count%', '$postsToday') : '0',
              subBadgeColor: postsToday > 0 ? const Color(0xFF42A5F5) : Colors.white38,
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF42A5F5),
            ),

            // Stat 2: Tổng Người Dùng
            _buildStatCard(
              title: txaLang.getText('admin_total_users'),
              value: TXAFormat.formatNumber(totalUsers),
              subBadge: usersToday > 0 ? txaLang.getText('admin_today_users').replaceAll('%count%', '$usersToday') : '0',
              subBadgeColor: usersToday > 0 ? Colors.amber : Colors.white38,
              icon: Icons.people_alt_rounded,
              color: Colors.amber,
            ),

            // Stat 3: Cặp Đôi Tình Yêu
            _buildStatCard(
              title: txaLang.getText('admin_total_couples'),
              value: TXAFormat.formatNumber(couplesCount),
              subBadge: txaLang.getText('admin_couples_sub'),
              subBadgeColor: const Color(0xFFF43F5E),
              icon: Icons.favorite_rounded,
              color: const Color(0xFFF43F5E),
            ),

            // Stat 4: Lượt Tương Tác
            _buildStatCard(
              title: txaLang.getText('admin_total_interactions'),
              value: TXAFormat.formatNumber(totalReactions),
              subBadge: txaLang.getText('admin_interactions_sub'),
              subBadgeColor: const Color(0xFFAB47BC),
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFFAB47BC),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // --- LEADERBOARD 1: TOP CHUỖI NGỌN LỬA CAO NHẤT ---
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              txaLang.getText('admin_top_streak_title'),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: TXATheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TXATheme.cardBorder),
          ),
          child: topStreakUsers.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('...', style: TextStyle(color: Colors.white38))))
              : Column(
                  children: topStreakUsers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final user = entry.value;
                    final rankStr = idx == 0 ? '🥇 #1' : idx == 1 ? '🥈 #2' : idx == 2 ? '🥉 #3' : '#${idx + 1}';
                    final rankColor = idx == 0 ? Colors.amber : idx == 1 ? const Color(0xFFCFD8DC) : idx == 2 ? const Color(0xFFFFB74D) : Colors.white38;

                    return Column(
                      children: [
                        ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 36,
                                child: Text(
                                  rankStr,
                                  style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                              ),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(int.tryParse(user.avatarBgColor) ?? 0xFF42A5F5),
                                child: Text(user.avatar, style: const TextStyle(fontSize: 16)),
                              ),
                            ],
                          ),
                          title: Text(
                            user.username,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            user.role == 'admin' ? '⭐ Admin' : 'User',
                            style: const TextStyle(color: TXATheme.textMuted, fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withAlpha(60)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${TXAStreakService.instance.getStreak(user.username)} ${txaLang.getText('admin_days_unit')}',
                                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (idx < topStreakUsers.length - 1)
                          Divider(color: TXATheme.cardBorder, height: 1),
                      ],
                    );
                  }).toList(),
                ),
        ),

        const SizedBox(height: 24),

        // --- LEADERBOARD 2: TOP NGƯỜI ĐĂNG BÀI NHIỀU NHẤT ---
        Row(
          children: [
            const Icon(Icons.photo_library_rounded, color: Color(0xFF42A5F5), size: 20),
            const SizedBox(width: 8),
            Text(
              txaLang.getText('admin_top_posters_title'),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: TXATheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TXATheme.cardBorder),
          ),
          child: topPosters.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('...', style: TextStyle(color: Colors.white38))))
              : Column(
                  children: topPosters.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final posterName = entry.value.key;
                    final count = entry.value.value;
                    final countToday = todayPostCounts[posterName] ?? 0;
                    final rankStr = idx == 0 ? '🥇 #1' : idx == 1 ? '🥈 #2' : idx == 2 ? '🥉 #3' : '#${idx + 1}';
                    final rankColor = idx == 0 ? Colors.amber : idx == 1 ? const Color(0xFFCFD8DC) : idx == 2 ? const Color(0xFFFFB74D) : Colors.white38;

                    return Column(
                      children: [
                        ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 36,
                                child: Text(
                                  rankStr,
                                  style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                              ),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF42A5F5),
                                child: Text(
                                  posterName.isNotEmpty ? posterName[0].toUpperCase() : '👤',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            posterName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            countToday > 0 ? '+$countToday ✨' : '',
                            style: TextStyle(color: countToday > 0 ? const Color(0xFF42A5F5) : TXATheme.textMuted, fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF42A5F5).withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF42A5F5).withAlpha(60)),
                            ),
                            child: Text(
                              '$count ${txaLang.getText('admin_posts_unit')}',
                              style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        if (idx < topPosters.length - 1)
                          Divider(color: TXATheme.cardBorder, height: 1),
                      ],
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subBadge,
    required Color subBadgeColor,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TXATheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TXATheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(color: TXATheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            subBadge,
            style: TextStyle(color: subBadgeColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
