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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Splash visible for 7 seconds (same as before)
  static const _minSplashDuration = Duration(seconds: 7);
  late final AnimationController _logoController; // scale/fade-in for the logo
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale =
        CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack);
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoController.forward();
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
      if (!mounted) return;
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
      // Fallback only fires if the asset is missing from the project/pubspec.
      errorBuilder: (_, __, ___) => Icon(Icons.play_circle_outline_rounded,
          color: UiColors.purpleDark, size: size * 0.8),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Clean white splash: logo, TubePilot wordmark, tagline, spinner + loading text.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox.expand(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                          opacity: _logoFade, child: _realLogo(size: 110)),
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: _logoFade,
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2),
                          children: [
                            TextSpan(
                                text: 'Tube',
                                style: TextStyle(color: UiColors.inkBlack)),
                            TextSpan(
                                text: 'Pilot',
                                style: TextStyle(color: UiColors.purple)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeTransition(
                      opacity: _logoFade,
                      child: Text(
                        context.tr('splash_tagline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: UiColors.textDim),
                      ),
                    ),
                  ],
                ),
              ),
              // Spinner + loading text (lower part of the screen).
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.sizeOf(context).height * 0.17,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: UiColors.purple,
                            backgroundColor: Color(0xFFE9DDF3)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading Your Creative Journey...',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: UiColors.purpleDark),
                      ),
                    ],
                  ),
                ),
              ),
              // "Powered by TubePilot" centered at the very bottom.
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Center(
                    child: Text(
                      context.tr('splash_powered_by'),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: UiColors.inkBlack),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
