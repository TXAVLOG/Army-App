import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_google_play_services.dart';
import '../widgets/txa_toast.dart';
import 'txa_register_screen.dart';
import 'locket_main_screen.dart';

class TXALoginScreen extends StatefulWidget {
  const TXALoginScreen({super.key});

  @override
  State<TXALoginScreen> createState() => _TXALoginScreenState();
}

class _TXALoginScreenState extends State<TXALoginScreen> {
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _identityFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  String? _identityError;
  String? _passwordError;

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _identityController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);

    _identityFocusNode.addListener(() {
      if (_identityFocusNode.hasFocus && _identityError != null) {
        setState(() => _identityError = null);
      }
    });

    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus && _passwordError != null) {
        setState(() => _passwordError = null);
      }
    });
  }

  void _onFieldChanged() {
    if (_identityError != null && _identityController.text.isNotEmpty) {
      setState(() => _identityError = null);
    }
    if (_passwordError != null && _passwordController.text.isNotEmpty) {
      setState(() => _passwordError = null);
    }
    setState(() {});
  }

  bool get _isLoginButtonEnabled {
    return _identityController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty &&
        !_isLoading;
  }

  bool _isGoogleLoading = false;

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final identity = _identityController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _identityError = null;
      _passwordError = null;
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    final res = await TXAAuthService.instance.login(
      identity: identity,
      password: password,
    );

    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (mounted) {
        TXAToast.show(
          context,
          TXALanguage.instance.getText('login_success').replaceAll('%user%', res['user'].username),
          icon: Icons.check_circle_rounded,
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LocketMainScreen()),
          (route) => false,
        );
      }
    } else {
      final errorField = res['errorField'] as String?;
      final message = res['message'] as String? ?? TXALanguage.instance.getText('login_failed');

      setState(() {
        if (errorField == 'identity') {
          _identityError = message;
        } else if (errorField == 'password') {
          _passwordError = message;
        } else {
          _identityError = message;
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

  Future<void> _handleGoogleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _isGoogleLoading = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    final res = await TXAAuthService.instance.loginWithGoogle();
    if (!mounted) return;

    setState(() => _isGoogleLoading = false);

    if (res['success'] == true) {
      final user = res['user'];
      TXAToast.show(
        context,
        TXALanguage.instance.getText('google_login_success').replaceAll('%user%', user.username),
        icon: Icons.g_mobiledata_rounded,
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LocketMainScreen()),
        (route) => false,
      );
    } else {
      TXAToast.show(
        context,
        res['message'] ?? TXALanguage.instance.getText('google_login_failed'),
        backgroundColor: TXATheme.statusRed,
      );
    }
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    _identityFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final txaGms = TXAGooglePlayServices.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([txaLang, txaGms]),
      builder: (context, _) {
        final isGmsAvailable = txaGms.isAvailable;
        return Scaffold(
          backgroundColor: TXATheme.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // App Logo & Header Title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: TXATheme.cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: TXATheme.primaryYellow, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: TXATheme.primaryYellow.withAlpha(140),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/armi_mascot.png',
                              width: 74,
                              height: 74,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          txaLang.getText('login_title'),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          txaLang.getText('login_subtitle'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: TXATheme.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Email or Username Input Field
                  Text(
                    txaLang.getText('email_or_username'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _identityController,
                    focusNode: _identityFocusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: txaLang.getText('email_or_username'),
                      hintStyle: const TextStyle(color: TXATheme.textMuted),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: TXATheme.textMuted),
                      filled: true,
                      fillColor: TXATheme.cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: _identityError != null ? TXATheme.statusRed : TXATheme.cardBorder,
                          width: _identityError != null ? 2.0 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: _identityError != null ? TXATheme.statusRed : TXATheme.primaryYellow,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                  if (_identityError != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.error_rounded, color: TXATheme.statusRed, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _identityError!,
                          style: const TextStyle(color: TXATheme.statusRed, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Password Input Field
                  Text(
                    txaLang.getText('password'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: txaLang.getText('password'),
                      hintStyle: const TextStyle(color: TXATheme.textMuted),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: TXATheme.textMuted),
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
                        borderSide: BorderSide(
                          color: _passwordError != null ? TXATheme.statusRed : TXATheme.cardBorder,
                          width: _passwordError != null ? 2.0 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: _passwordError != null ? TXATheme.statusRed : TXATheme.primaryYellow,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                  if (_passwordError != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.error_rounded, color: TXATheme.statusRed, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _passwordError!,
                          style: const TextStyle(color: TXATheme.statusRed, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Login Button (Only lights up when fields are filled)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoginButtonEnabled ? _handleLogin : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoginButtonEnabled
                            ? TXATheme.primaryYellow
                            : Colors.white.withAlpha(25),
                        foregroundColor: _isLoginButtonEnabled ? Colors.black : Colors.white38,
                        elevation: _isLoginButtonEnabled ? 4 : 0,
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
                              txaLang.getText('login_btn'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Google Sign-In Button with transparent Google logo PNG asset (Disabled if GMS missing)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: (isGmsAvailable && !_isGoogleLoading) ? _handleGoogleLogin : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isGmsAvailable ? TXATheme.cardBorder : Colors.white10,
                          width: 1.5,
                        ),
                        backgroundColor: isGmsAvailable ? TXATheme.cardBg : Colors.white.withAlpha(10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: isGmsAvailable ? 1.0 : 0.4,
                                  child: Image.asset(
                                    'assets/google_logo.png',
                                    width: 22,
                                    height: 22,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  txaLang.getText('google_login_btn'),
                                  style: TextStyle(
                                    color: isGmsAvailable ? Colors.white : Colors.white38,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (!isGmsAvailable) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: TXATheme.statusRed, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          txaLang.getText('gms_disabled_tooltip'),
                          style: const TextStyle(color: TXATheme.statusRed, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Register Link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          txaLang.getText('no_account'),
                          style: const TextStyle(color: TXATheme.textMuted, fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TXARegisterScreen()),
                            );
                          },
                          child: Text(
                            txaLang.getText('create_new_account'),
                            style: const TextStyle(
                              color: TXATheme.primaryYellow,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
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
