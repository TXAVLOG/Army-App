import 'package:flutter/material.dart';
import '../services/txa_supabase_service.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_analytics.dart';
import '../services/txa_auth_service.dart';
import '../widgets/txa_toast.dart';
import '../widgets/txa_network_image.dart';

class TXALoveSetupScreen extends StatefulWidget {
  final String? preselectedUsername;
  const TXALoveSetupScreen({super.key, this.preselectedUsername});

  @override
  State<TXALoveSetupScreen> createState() => _TXALoveSetupScreenState();
}

class _TXALoveSetupScreenState extends State<TXALoveSetupScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedFriendUsername;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenLoveSetup);
    _selectedFriendUsername = widget.preselectedUsername;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF43F5E), // Rose pink
              onPrimary: Colors.white,
              surface: Color(0xFF18181C),
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFF43F5E)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _sendInvitation() async {
    final txaLang = TXALanguage.instance;
    if (_selectedFriendUsername == null) {
      TXAToast.show(
        context,
        txaLang.getText('select_friend_to_couple'),
        icon: Icons.favorite_border_rounded,
        backgroundColor: TXATheme.statusRed,
      );
      return;
    }

    setState(() => _isSending = true);

    final result = await TXAAuthService.instance.sendLoveInvitation(
      _selectedFriendUsername!,
      _selectedDate.toIso8601String(),
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (result['success'] == true) {
        TXAToast.show(
          context,
          txaLang.getText('love_invite_sent_success'),
          icon: Icons.favorite_rounded,
          backgroundColor: const Color(0xFFF43F5E),
        );
        Navigator.pop(context);
      } else {
        final errorMsg = result['message'] as String? ?? 'Error';
        final displayMsg = errorMsg.contains('pending') || errorMsg.contains('chờ')
            ? txaLang.getText('love_invite_pending_error')
            : errorMsg;
        TXAToast.show(
          context,
          displayMsg,
          icon: Icons.error_outline_rounded,
          backgroundColor: TXATheme.statusRed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaAuth = TXAAuthService.instance;
    final friends = txaAuth.friendsList;
    final preselectedFriend = widget.preselectedUsername != null
        ? friends.firstWhere(
            (f) => f['username'] == widget.preselectedUsername,
            orElse: () => <String, dynamic>{},
          )
        : null;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: txaAuth.listenSentLoveRequests(),
      builder: (context, sentSnapshot) {
        final sentInvites = sentSnapshot.data ?? [];
        final mySentInvite = sentInvites.firstWhere(
          (inv) => inv['receiver'] == _selectedFriendUsername,
          orElse: () => <String, dynamic>{},
        );
        final hasSentInvite = mySentInvite.isNotEmpty;

        if (hasSentInvite) {
          return Scaffold(
            backgroundColor: TXATheme.background,
            appBar: AppBar(
              title: Text(
                txaLang.getText('love_menu_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withAlpha(30),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF43F5E), width: 2),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFF43F5E),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      txaLang.getText('waiting_response'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      txaLang.getText('love_setup_waiting_desc').replaceFirst('%user%', _selectedFriendUsername ?? ''),
                      style: const TextStyle(
                        color: TXATheme.textMuted,
                        fontSize: 15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final inviteId = mySentInvite['id'] as String;
                          await TXASupabaseService.instance.client.from('txa_love_invitations').delete().eq('id', inviteId);
                          if (context.mounted) {
                            TXAToast.show(
                              context,
                              txaLang.getText('revoke_invite_success'),
                              icon: Icons.delete_outline_rounded,
                            );
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(20),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                        label: Text(txaLang.getText('revoke_invite_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: TXATheme.background,
          appBar: AppBar(
            title: Text(
              txaLang.getText('love_menu_title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heart and Mascot illustration
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF43F5E).withAlpha(30),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF43F5E), width: 2),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFF43F5E),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          txaLang.getText('love_menu_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Anniversary date selector
                  Text(
                    txaLang.getText('set_love_date'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: TXATheme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF43F5E).withAlpha(120), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Color(0xFFF43F5E)),
                              const SizedBox(width: 12),
                              Text(
                                '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Friend selector / Locked preselected friend
                  if (widget.preselectedUsername != null && preselectedFriend != null && preselectedFriend.isNotEmpty) ...[
                    Text(
                      txaLang.getText('lover'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF43F5E),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Color(preselectedFriend['bgColor'] as int? ?? 0xFF607D8B),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: (preselectedFriend['avatar'] as String? ?? '👤').startsWith('http')
                                  ? TXANetworkImage(url: preselectedFriend['avatar'] as String, fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        preselectedFriend['avatar'] as String? ?? '👤',
                                        style: const TextStyle(fontSize: 26),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preselectedFriend['name'] as String? ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  preselectedFriend['username'] as String? ?? '',
                                  style: const TextStyle(
                                    color: TXATheme.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFF43F5E),
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ] else ...[
                    Text(
                      txaLang.getText('friends_title'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: friends.isEmpty
                          ? Center(
                              child: Text(
                                txaLang.getText('no_posts_yet'),
                                style: const TextStyle(color: TXATheme.textMuted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: friends.length,
                              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                              itemBuilder: (ctx, index) {
                                final friend = friends[index];
                                final username = friend['username'] as String;
                                final isSelected = _selectedFriendUsername == username;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedFriendUsername = username;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFF43F5E).withAlpha(30) : TXATheme.cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFF43F5E) : TXATheme.cardBorder,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Friend Avatar
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Color(friend['bgColor'] as int? ?? 0xFF607D8B),
                                            shape: BoxShape.circle,
                                          ),
                                          child: ClipOval(
                                            child: (friend['avatar'] as String? ?? '👤').startsWith('http')
                                                ? TXANetworkImage(url: friend['avatar'] as String, fit: BoxFit.cover)
                                                : Center(
                                                    child: Text(
                                                      friend['avatar'] as String? ?? '👤',
                                                      style: const TextStyle(fontSize: 22),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                friend['name'] as String? ?? '',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                friend['username'] as String? ?? '',
                                                style: const TextStyle(
                                                  color: TXATheme.textMuted,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.favorite_rounded,
                                            color: Color(0xFFF43F5E),
                                            size: 24,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendInvitation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF43F5E),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFF43F5E).withAlpha(100),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFFF43F5E).withAlpha(120),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              txaLang.getText('send_love_invite_btn'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
