import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/storage_service.dart';
import '../services/push_service.dart';
import '../providers/language_provider.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import '../widgets/app_decor.dart';
import '../widgets/app_brand_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Splash visible for 7 seconds (same as before)
  static const _minSplashDuration = Duration(seconds: 7);
  late final AnimationController _logoController; // scale/fade-in for the logo
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final AnimationController _barController; // loading bar fills over the splash time

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack);
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoController.forward();
    _barController = AnimationController(vsync: this, duration: _minSplashDuration)..forward();
    // ⚠️ REMOVED (Google Play policy fix): upfront Permission.photos /
    // Permission.videos requests were removed from here. Google Play's
    // Photo and Video Permissions policy flags apps that request
    // READ_MEDIA_IMAGES / READ_MEDIA_VIDEO for infrequent, user-initiated
    // access like ours — the correct approach is to let image_picker use
    // the Android Photo Picker (API 33+) reactively, exactly when the user
    // taps "select a video" / "select a thumbnail" on the Upload screen.
    // The Photo Picker needs NO permission grant at all, so there is
    // nothing to request here anymore. See AndroidManifest.xml, where
    // READ_MEDIA_IMAGES / READ_MEDIA_VIDEO are now explicitly removed via
    // tools:node="remove" to stop them being merged in from this package's
    // (and permission_handler's) own manifests.
    _decideNextScreen();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _barController.dispose();
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  // The real logo lives at assets/splash.png (single source of truth).
  Widget _realLogo({required double size}) {
    return Image.asset(
      'assets/splash.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.play_circle_outline_rounded, color: UiColors.plum, size: size * 0.8),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Off-white page with the faint play-icon pattern (same as the Setup screen),
    // logo, "Tube Pilot" (Tube black / Pilot plum), tagline, progress bar, Powered by.
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FC),
      body: AppBrandBackground(
        child: SafeArea(
          child: SizedBox.expand(
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, -0.22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(opacity: _logoFade, child: _realLogo(size: 96)),
                      ),
                      const SizedBox(height: 34),
                      FadeTransition(
                        opacity: _logoFade,
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
                      const SizedBox(height: 4),
                      FadeTransition(
                        opacity: _logoFade,
                        child: Text(
                          context.tr('splash_tagline'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Color(0xFF77747C)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Loading bar + text.
                Positioned(
                  left: 40,
                  right: 40,
                  bottom: 76,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _barController,
                          builder: (context, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: 0.06 + 0.94 * Curves.easeInOut.transform(_barController.value),
                              minHeight: 14,
                              color: UiColors.plum,
                              backgroundColor: const Color(0xFFDCC8E0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Loading ......',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: UiColors.plum),
                        ),
                      ],
                    ),
                  ),
                ),
                // "Powered by TubePilot" at the very bottom.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Center(
                      child: Text(
                        context.tr('splash_powered_by'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0A0A0A)),
                      ),
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
