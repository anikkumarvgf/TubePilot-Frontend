import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/storage_service.dart';
import '../services/push_service.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import '../widgets/app_decor.dart';
import '../widgets/app_brand_background.dart';

/// Splash: ONLY the "Tube Pilot" text, which pops in (scale-up with a small bounce + fade).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Splash stays at least this long (text pops in ~0.9s, then rests a moment).
  static const _minSplashDuration = Duration(milliseconds: 2400);
  late final AnimationController _pop;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _pop, curve: Curves.elasticOut));
    _fade = CurvedAnimation(parent: _pop, curve: const Interval(0, 0.35, curve: Curves.easeOut));
    _pop.forward();
    // Google Play policy: no upfront photo / video permission requests here (image_picker uses the
    // Android Photo Picker when the user taps "select a video").
    _decideNextScreen();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Future<void> _decideNextScreen() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([
      auth.loadSession(),
      Future.delayed(_minSplashDuration),
    ]);
    if (!mounted) return;
    Widget next;
    if (auth.isLoggedIn) {
      next = const DashboardScreen();
      PushService.initAfterLogin();
    } else {
      final onboarded = await StorageService.isOnboarded();
      next = onboarded ? const LoginScreen() : const OnboardingScreen();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FC),
      body: AppBrandBackground(
        child: SizedBox.expand(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: -1.2),
                        children: [
                          TextSpan(text: 'Tube ', style: TextStyle(color: Color(0xFF0A0A0A))),
                          TextSpan(text: 'Pilot', style: TextStyle(color: UiColors.plum)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
