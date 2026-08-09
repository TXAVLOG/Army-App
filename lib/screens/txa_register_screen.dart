import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_analytics.dart';
import '../widgets/txa_toast.dart';
import 'locket_main_screen.dart';

class TXARegisterScreen extends StatefulWidget {
  const TXARegisterScreen({super.key});

  @override
  State<TXARegisterScreen> createState() => _TXARegisterScreenState();
}

class _TXARegisterScreenState extends State<TXARegisterScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _displayNameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _dobFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _isUsernameManuallyEdited = false;

  int _selectedAvatarIndex = 0;

  String? _emailError;
  String? _usernameError;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  final List<String> _allowedDomains = [
    '@gmail.com',
    '@icloud.com',
    '@outlook.com',
    '@hotmail.com',
    '@live.com',
    '@msn.com'
  ];

  @override
  void initState() {
    super.initState();
    TXAAnalytics.logScreenView(screenName: TXAAnalytics.screenRegister);
    _displayNameController.addListener(_onDisplayNameChanged);
    _emailController.addListener(_onFieldChanged);
    _usernameController.addListener(_onFieldChanged);
    _dobController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);

    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus && _emailError != null) {
        setState(() => _emailError = null);
      }
    });

    _usernameFocusNode.addListener(() {
      if (_usernameFocusNode.hasFocus) {
        _isUsernameManuallyEdited = true;
      }
      if (_usernameFocusNode.hasFocus && _usernameError != null) {
        setState(() => _usernameError = null);
      }
    });
  }

  void _onDisplayNameChanged() {
    _onFieldChanged();
    final displayNameText = _displayNameController.text.trim();
    if (!_isUsernameManuallyEdited) {
      if (displayNameText.isEmpty) {
        _usernameController.text = '';
      } else {
        String raw = displayNameText.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        if (raw.isEmpty) raw = 'usr';
        final prefix = raw.length >= 3 ? raw.substring(0, 3) : raw.padRight(3, 'x');
        
        final rand = Random();
        const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
        final suffix = List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join('');
        
        _usernameController.text = '$prefix$suffix';
      }
    }
  }

  void _onFieldChanged() {
    setState(() {
      if (_emailError != null && _emailController.text.isNotEmpty) {
        _emailError = null;
      }
      if (_usernameError != null && _usernameController.text.isNotEmpty) {
        _usernameError = null;
      }
    });
  }

  bool _isValidEmailDomain(String email) {
    final clean = email.trim().toLowerCase();
    return _allowedDomains.any((domain) => clean.endsWith(domain));
  }

  bool get _isRegisterButtonEnabled {
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final dob = _dobController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    final isDisplayNameValid = displayName.isNotEmpty;
    final isEmailValid = email.isNotEmpty && _isValidEmailDomain(email);
    final isUsernameValid = username.isNotEmpty && username.length >= 3;
    final isDobValid = dob.isNotEmpty;
    final isPasswordValid = password.length >= 6;
    final isConfirmValid = confirm.isNotEmpty && confirm == password;

    return isDisplayNameValid &&
        isEmailValid &&
        isUsernameValid &&
        isDobValid &&
        isPasswordValid &&
        isConfirmValid &&
        !_isLoading;
  }

  Future<void> _selectDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: TXATheme.primaryYellow,
              surface: TXATheme.cardBg,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      setState(() => _dobController.text = formatted);
    }
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    final txaLang = TXALanguage.instance;
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    final dob = _dobController.text.trim().isEmpty ? '19/10/2000' : _dobController.text.trim();

    if (!_isValidEmailDomain(email)) {
      setState(() => _emailError = txaLang.getText('email_invalid_domain'));
      return;
    }

    if (password != confirm) {
      TXAToast.show(
        context,
        txaLang.getText('confirm_password_mismatch'),
        icon: Icons.error_outline_rounded,
        backgroundColor: TXATheme.statusRed,
      );
      return;
    }

    setState(() {
      _emailError = null;
      _usernameError = null;
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    final selectedAvatar = TXAAuthService.presetAvatars[_selectedAvatarIndex];

    final res = await TXAAuthService.instance.register(
      email: email,
      username: username,
      password: password,
      dob: dob,
      avatar: selectedAvatar['emoji']!,
      avatarBgColor: selectedAvatar['color']!,
      displayName: _displayNameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (mounted) {
        TXAToast.show(
          context,
          txaLang.getText('register_success').replaceAll('%user%', res['user'].username),
          icon: Icons.check_circle_rounded,
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LocketMainScreen()),
          (route) => false,
        );
      }
    } else {
      final errorField = res['errorField'] as String?;
      final message = res['message'] as String? ?? txaLang.getText('register_failed');

      setState(() {
        if (errorField == 'email') {
          _emailError = message;
        } else if (errorField == 'username') {
          _usernameError = message;
        }
      });

      if (mounted) {
        TXAToast.show(
          context,
          message,
          icon: Icons.error_outline_rounded,
          backgroundColor: TXATheme.statusRed,
        );
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _displayNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _usernameFocusNode.dispose();
    _dobFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final emailText = _emailController.text.trim();
    final passwordText = _passwordController.text.trim();
    final confirmText = _confirmPasswordController.text.trim();

    final isEmailDomainInvalid = emailText.isNotEmpty && !_isValidEmailDomain(emailText);
    final isPasswordMismatch = confirmText.isNotEmpty && confirmText != passwordText;

    return AnimatedBuilder(
      animation: txaLang,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: TXATheme.background,
          appBar: AppBar(
            title: Text(txaLang.getText('register_title')),
            backgroundColor: TXATheme.background,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Selection Grid (10 Preset Avatars)
                  Text(
                    txaLang.getText('select_avatar_title'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: TXAAuthService.presetAvatars.length,
                  itemBuilder: (context, index) {
                    final item = TXAAuthService.presetAvatars[index];
                    final isSelected = _selectedAvatarIndex == index;
                    final colorVal = int.parse(item['color']!);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatarIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(colorVal).withAlpha(180),
                          border: Border.all(
                            color: isSelected ? TXATheme.primaryYellow : Colors.transparent,
                            width: isSelected ? 3.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: TXATheme.primaryYellow.withAlpha(120),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            item['emoji']!,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Display Name Field
              Text(
                txaLang.getText('display_name_label'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _displayNameController,
                focusNode: _displayNameFocusNode,
                style: TextStyle(color: Colors.white, fontSize: 15),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: txaLang.getText('display_name_hint'),
                  hintStyle: TextStyle(color: TXATheme.textMuted),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: TXATheme.textMuted),
                  filled: true,
                  fillColor: TXATheme.cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: TXATheme.cardBorder,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: TXATheme.primaryYellow,
                      width: 2.0,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Email Field (Validates Gmail, iCloud, Microsoft)
              Text(
                txaLang.getText('email_address_label'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: txaLang.getText('email_domain_hint'),
                  hintStyle: TextStyle(color: TXATheme.textMuted),
                  prefixIcon: Icon(Icons.email_outlined, color: TXATheme.textMuted),
                  filled: true,
                  fillColor: TXATheme.cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: (_emailError != null || isEmailDomainInvalid) ? TXATheme.statusRed : TXATheme.cardBorder,
                      width: (_emailError != null || isEmailDomainInvalid) ? 2.0 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: (_emailError != null || isEmailDomainInvalid) ? TXATheme.statusRed : TXATheme.primaryYellow,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              if (isEmailDomainInvalid) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: TXATheme.statusRed, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        txaLang.getText('email_invalid_domain'),
                        style: const TextStyle(color: TXATheme.statusRed, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ] else if (_emailError != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.error_rounded, color: TXATheme.statusRed, size: 14),
                    const SizedBox(width: 4),
                    Text(_emailError!, style: const TextStyle(color: TXATheme.statusRed, fontSize: 12)),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Username Field + Helper Notice
              Text(
                txaLang.getText('username_label'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                style: TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: txaLang.getText('username_hint'),
                  hintStyle: TextStyle(color: TXATheme.textMuted),
                  prefixIcon: Icon(Icons.alternate_email_rounded, color: TXATheme.textMuted),
                  filled: true,
                  fillColor: TXATheme.cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: _usernameError != null ? TXATheme.statusRed : TXATheme.cardBorder,
                      width: _usernameError != null ? 2.0 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: _usernameError != null ? TXATheme.statusRed : TXATheme.primaryYellow,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: TXATheme.actionBlue, size: 13),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      txaLang.getText('username_desc'),
                      style: TextStyle(color: TXATheme.actionBlue.withAlpha(200), fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              if (_usernameError != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.error_rounded, color: TXATheme.statusRed, size: 14),
                    const SizedBox(width: 4),
                    Text(_usernameError!, style: const TextStyle(color: TXATheme.statusRed, fontSize: 12)),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Date of Birth Field
              Text(
                txaLang.getText('dob_title'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _selectDOB,
                child: AbsorbPointer(
                  child: TextField(
                    controller: _dobController,
                    focusNode: _dobFocusNode,
                    style: TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: txaLang.getText('dob_hint'),
                      hintStyle: TextStyle(color: TXATheme.textMuted),
                      prefixIcon: Icon(Icons.cake_outlined, color: TXATheme.textMuted),
                      filled: true,
                      fillColor: TXATheme.cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: TXATheme.cardBorder),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Password Field
              Text(
                txaLang.getText('password'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: !_isPasswordVisible,
                style: TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: txaLang.getText('password_min_hint'),
                  hintStyle: TextStyle(color: TXATheme.textMuted),
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: TXATheme.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: TXATheme.textMuted,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  filled: true,
                  fillColor: TXATheme.cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: TXATheme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: TXATheme.primaryYellow, width: 2.0),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Confirm Password Field
              Text(
                txaLang.getText('confirm_password'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocusNode,
                obscureText: !_isConfirmPasswordVisible,
                style: TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: txaLang.getText('confirm_password_hint'),
                  hintStyle: TextStyle(color: TXATheme.textMuted),
                  prefixIcon: Icon(Icons.lock_reset_rounded, color: TXATheme.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: TXATheme.textMuted,
                    ),
                    onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ),
                  filled: true,
                  fillColor: TXATheme.cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: isPasswordMismatch ? TXATheme.statusRed : TXATheme.cardBorder,
                      width: isPasswordMismatch ? 2.0 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: isPasswordMismatch ? TXATheme.statusRed : TXATheme.primaryYellow,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              if (isPasswordMismatch) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.error_rounded, color: TXATheme.statusRed, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      txaLang.getText('confirm_password_mismatch'),
                      style: const TextStyle(color: TXATheme.statusRed, fontSize: 12),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Register Button (Lights up when all valid)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isRegisterButtonEnabled ? _handleRegister : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRegisterButtonEnabled
                        ? TXATheme.primaryYellow
                        : Colors.white.withAlpha(25),
                    foregroundColor: _isRegisterButtonEnabled ? Colors.black : Colors.white38,
                    elevation: _isRegisterButtonEnabled ? 4 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                        )
                      : Text(
                          txaLang.getText('register_btn'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  },
);
  }
}