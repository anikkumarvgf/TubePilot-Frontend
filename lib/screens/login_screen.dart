import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';
import '../widgets/common.dart';
import '../widgets/app_decor.dart';
import '../widgets/app_popups.dart';
import '../providers/language_provider.dart';
import 'username_setup_screen.dart';
import 'dashboard_screen.dart';

/// Login + Sign Up (one screen, two modes) - layout follows the UI design:
/// plum header with teal leaves + "Hello!", light rounded sheet with pill fields.
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
  bool obscureConfirm = true;
  bool detailsCorrect = false;
  String? slowServerHint;
  Timer? _slowHintTimer;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const _hintColor = Color(0xFF6E6070);

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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      isLogin = !isLogin;
      detailsCorrect = false;
      _confirmCtrl.clear();
      _formKey.currentState?.reset();
    });
  }

  void _goNext(Map<String, dynamic>? user) {
    final username = user?['username'];
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => (username == null || username == '') ? const UsernameSetupScreen() : const DashboardScreen(),
    ));
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isLogin && !detailsCorrect) {
      showToast(context, 'Please tick "All details correct"', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    _startSlowHintTimer();
    final auth = context.read<AuthProvider>();
    try {
      final email = _emailCtrl.text.trim();
      if (isLogin) {
        await auth.emailLogin(email: email, password: _passwordCtrl.text);
      } else {
        // The design has no name field: use the part before "@" (the username is
        // chosen on the next screen anyway).
        await auth.emailSignup(name: email.split('@').first, email: email, password: _passwordCtrl.text);
        // New account -> Rs1 payment -> connect channel -> welcome (shown on the dashboard).
        await markOnboardingPending(auth.user);
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
      // Google: the new-user flow starts only if the account was created just now.
      final created = DateTime.tryParse('${auth.user?['createdAt'] ?? ''}');
      if (created != null && DateTime.now().difference(created).inMinutes.abs() < 10) {
        await markOnboardingPending(auth.user);
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
        hintStyle: const TextStyle(color: _hintColor, fontSize: 14.5, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: _hintColor, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: UiColors.plum, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
        errorStyle: const TextStyle(fontSize: 11.5),
      );

  Widget _eye(bool obscured, VoidCallback onTap) => IconButton(
        icon: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: _hintColor),
        onPressed: onTap,
      );

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: googleLoading ? null : _submitGoogle,
        icon: googleLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Image.network(
                'https://developers.google.com/identity/images/g-logo.png',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) =>
                    const Text('G', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFFDB4437))),
              ),
        label: const Text('Continue with Google', style: TextStyle(color: UiColors.plum, fontWeight: FontWeight.w700, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: Colors.white,
          shape: const StadiumBorder(),
          side: const BorderSide(color: UiColors.plum, width: 1.1),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hello!', style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w400, height: 1.05)),
        if (!isLogin)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Welcome To Tube Pilot',
              style: TextStyle(color: Color(0xFFD9F3EC), fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _sheet() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLogin) ...[
              GestureDetector(
                onTap: _switchMode,
                behavior: HitTestBehavior.opaque,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, color: UiColors.plum, size: 18),
                    SizedBox(width: 8),
                    Text('Back To Sign Up', style: TextStyle(color: UiColors.plum, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(isLogin ? 'Login' : 'Sign Up',
                style: const TextStyle(color: UiColors.plum, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: _dec('Email', Icons.mail_outline_rounded),
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
              decoration: _dec('Password', Icons.lock_rounded,
                  suffix: _eye(obscurePassword, () => setState(() => obscurePassword = !obscurePassword))),
              validator: (v) => (v == null || v.length < 6) ? context.tr('password_min_length_error') : null,
            ),

            if (!isLogin) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: obscureConfirm,
                decoration: _dec('Confirm Password', Icons.lock_rounded,
                    suffix: _eye(obscureConfirm, () => setState(() => obscureConfirm = !obscureConfirm))),
                validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => detailsCorrect = !detailsCorrect),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: detailsCorrect,
                        onChanged: (v) => setState(() => detailsCorrect = v ?? false),
                        activeColor: UiColors.plum,
                        side: const BorderSide(color: UiColors.plum, width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('All details correct', style: TextStyle(color: _hintColor, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],

            if (isLogin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 34)),
                  child: const Text('Forgot Password', style: TextStyle(color: UiColors.plum, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),

            SizedBox(height: isLogin ? 8 : 18),
            AppAuthButton(
              label: isLogin ? 'Login' : 'Sign Up',
              loading: loading,
              onPressed: _submitEmailAuth,
            ),
            if (slowServerHint != null) ...[
              const SizedBox(height: 10),
              Center(child: Text(slowServerHint!, style: const TextStyle(color: UiColors.textDim, fontSize: 12), textAlign: TextAlign.center)),
            ],
            const SizedBox(height: 14),
            const Center(child: Text('Or login with', style: TextStyle(color: _hintColor, fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            _googleButton(),
            const SizedBox(height: 16),

            Center(
              child: GestureDetector(
                onTap: _switchMode,
                behavior: HitTestBehavior.opaque,
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(color: _hintColor, fontSize: 12.5, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(text: isLogin ? "Don't have an account? " : 'Already have an account? '),
                      TextSpan(
                        text: isLogin ? 'Sign Up' : 'Login',
                        style: const TextStyle(color: UiColors.plum, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isLogin) ...[
              const SizedBox(height: 18),
              const Center(child: Text('Powered By Tube Pilot', style: TextStyle(color: _hintColor, fontSize: 11.5, fontWeight: FontWeight.w700))),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: UiColors.plum,
        body: AuthHeaderBackground(
          headerHeight: keyboardOpen ? 135 : 230,
          showPlant: !isLogin && !keyboardOpen,
          header: _header(),
          sheet: _sheet(),
        ),
      ),
    );
  }
}
