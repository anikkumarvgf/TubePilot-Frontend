import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/diwali_decor.dart';
import '../widgets/diwali_popups.dart';
import '../providers/language_provider.dart';
import 'username_setup_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = false; // default: Sign Up screen shows first for new users
  bool loading = false;
  bool googleLoading = false;
  bool obscurePassword = true;
  String? slowServerHint;
  Timer? _slowHintTimer;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _startSlowHintTimer() {
    _slowHintTimer?.cancel();
    _slowHintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => slowServerHint = context.tr('waking_up_server_hint'));
      }
    });
  }

  void _clearSlowHint() {
    _slowHintTimer?.cancel();
    if (mounted) setState(() => slowServerHint = null);
  }

  @override
  void dispose() {
    _slowHintTimer?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _goNext(Map<String, dynamic>? user) {
    final username = user?['username'];
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => (username == null || username == '') ? const UsernameSetupScreen() : const DashboardScreen(),
    ));
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    _startSlowHintTimer();
    final auth = context.read<AuthProvider>();
    try {
      if (isLogin) {
        await auth.emailLogin(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      } else {
        await auth.emailSignup(name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
        await markDiwaliWelcomePending(); // new account -> welcome popup once
      }
      if (!mounted) return;
      PushService.initAfterLogin();
      _goNext(auth.user);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      _clearSlowHint();
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => googleLoading = true);
    _startSlowHintTimer();
    final auth = context.read<AuthProvider>();
    try {
      await auth.googleLogin();
      // Google: welcome only if the account was created just now (new user).
      final created = DateTime.tryParse('${auth.user?['createdAt'] ?? ''}');
      if (created != null && DateTime.now().difference(created).inMinutes.abs() < 10) {
        await markDiwaliWelcomePending();
      }
      if (!mounted) return;
      PushService.initAfterLogin();
      _goNext(auth.user);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      _clearSlowHint();
      if (mounted) setState(() => googleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showToast(context, context.tr('valid_email_first_error'), isError: true);
      return;
    }
    try {
      await ApiService.instance.forgotPassword(email);
      if (mounted) showToast(context, context.tr('reset_link_sent'), isSuccess: true);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: DiwaliColors.purple, size: 22),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: DiwaliColors.gold.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DiwaliColors.purple, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Whole page is drawn in code (DiwaliAuthBackground) - no PNG background.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DiwaliAuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: Image.asset(
                        'assets/splash.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.play_arrow_rounded, color: AppColors.purple, size: 40),
                      ),
                    ),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                        children: [
                          TextSpan(text: 'Tube', style: TextStyle(color: Color(0xFF1B0F20))),
                          TextSpan(text: 'Pilot', style: TextStyle(color: DiwaliColors.purple)),
                        ],
                      ),
                    ),
                    Text(context.tr('splash_tagline'), style: const TextStyle(color: DiwaliColors.textDim, fontSize: 13)),
                    const SizedBox(height: 14),
                    const DiwaliTitleOrnament(),
                    Text(isLogin ? context.tr('welcome_back') : context.tr('create_account'),
                        style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(isLogin ? context.tr('sign_in_to_continue') : context.tr('start_scheduling_seconds'),
                        textAlign: TextAlign.center, style: const TextStyle(color: DiwaliColors.textDim)),
                    const SizedBox(height: 8),
                    const DiwaliLotusDivider(width: 190),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: googleLoading ? null : _submitGoogle,
                        icon: googleLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Image.network(
                                'https://developers.google.com/identity/images/g-logo.png',
                                width: 20, height: 20,
                                errorBuilder: (_, __, ___) => const Text('G',
                                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFFDB4437))),
                              ),
                        label: Text(isLogin ? context.tr('continue_with_google') : context.tr('signup_with_google'),
                            style: const TextStyle(color: DiwaliColors.purpleDark, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          side: BorderSide(color: DiwaliColors.gold.withValues(alpha: 0.7)),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(children: [
                        Expanded(child: Divider(color: DiwaliColors.gold.withValues(alpha: 0.5))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(context.tr('or_continue_with_email'), style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12.5)),
                        ),
                        Expanded(child: Divider(color: DiwaliColors.gold.withValues(alpha: 0.5))),
                      ]),
                    ),

                    if (!isLogin) ...[
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _dec(context.tr('your_full_name_hint'), Icons.person_outline),
                        validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('enter_your_name_error') : null,
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _dec('you@example.com', Icons.mail_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return context.tr('enter_your_email_error');
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) return context.tr('enter_valid_email_error');
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: _dec(
                        context.tr('password_label'),
                        Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20, color: DiwaliColors.textDim),
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? context.tr('password_min_length_error') : null,
                    ),

                    if (isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text(context.tr('forgot_password'), style: const TextStyle(color: AppColors.purple, fontSize: 13)),
                        ),
                      ),

                    const SizedBox(height: 14),
                    DiwaliAuthButton(
                      label: isLogin ? context.tr('login_btn') : context.tr('signup_btn'),
                      loading: loading,
                      onPressed: _submitEmailAuth,
                    ),
                    if (slowServerHint != null) ...[
                      const SizedBox(height: 10),
                      Text(slowServerHint!, style: const TextStyle(color: AppColors.purpleLight, fontSize: 12), textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 14),

                    // UPDATED: both bottom lines are now DARK BLACK and sit on a
                    // soft cream strip, so the diya art behind can never make
                    // them hard to read.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: DiwaliColors.creamTop.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  isLogin ? context.tr('no_account_prompt') : context.tr('have_account_prompt'),
                                  style: const TextStyle(color: DiwaliColors.inkBlack, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => isLogin = !isLogin),
                                child: Text(
                                  isLogin ? context.tr('signup_btn') : context.tr('login_btn'),
                                  style: const TextStyle(color: DiwaliColors.purple, fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('terms_privacy_notice'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: DiwaliColors.inkBlack, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    // room so the bottom diya art never covers the last text
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}