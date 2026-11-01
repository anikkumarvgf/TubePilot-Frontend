import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'services/auth_provider.dart';
import 'services/api_service.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/meta_page_picker_screen.dart';
import 'screens/my_videos_screen.dart';
import 'widgets/common.dart';
import 'widgets/app_brand_background.dart';
import 'widgets/app_nav.dart';
import 'widgets/diwali_decor.dart' show DiwaliBottomNav;

final navigatorKey = GlobalKey<NavigatorState>();

// ⚠️ TODO: replace with your real OneSignal App ID
const String oneSignalAppId = '205c5c05-ad00-4e06-a8f4-d7ff9245ccfd';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ NEW: edge-to-edge + transparent system bars. Phone chahe gesture navigation pe ho
  // ya 3-button navigation pe, app ek hi tarah se behave karti hai; neeche ki jagah
  // MaterialApp.builder (niche) sambhalta hai.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));

  // Keep only the FAST local read (SharedPreferences) before runApp().
  // Slow Firebase/OneSignal init runs after runApp() so it never blocks
  // the first Flutter frame.
  final languageProvider = LanguageProvider();
  await languageProvider.loadSaved();

  runApp(TubePilotApp(languageProvider: languageProvider));

  _initBackgroundServices();
}

Future<void> _initBackgroundServices() async {
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw Exception('Firebase.initializeApp() timed out after 8s'),
    );
  } catch (e) {
    debugPrint('⚠️ Firebase init failed/skipped, continuing without push notifications: $e');
  }

  try {
    OneSignal.initialize(oneSignalAppId);
    OneSignal.Notifications.requestPermission(true);
  } catch (e) {
    debugPrint('⚠️ OneSignal init failed/skipped, continuing without diamond-alert push: $e');
  }
}

/// ⚠️ NEW — GLOBAL FESTIVAL BACKGROUND (one place for all ~40 screens).
///
/// Wraps every page route in AppBrandBackground, then hands over to the
/// normal platform transition. Why here and not in MaterialApp.builder:
/// a single background behind the Navigator would show the OLD screen
/// through the NEW (transparent) one during page transitions. Drawing the
/// background inside each route keeps every page opaque while animating.
///
/// Per-screen opt-out: a screen that wraps itself in
/// AppBrandBackground(excludeFromFestival: true) (like Splash) or sets an
/// explicit Scaffold(backgroundColor: ...) keeps its own look.
class _FestivalPageTransitionsBuilder extends PageTransitionsBuilder {
  final PageTransitionsBuilder inner;
  const _FestivalPageTransitionsBuilder(this.inner);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return inner.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      AppBrandBackground(watermarkWhenNormal: false, child: child),
    );
  }
}

const PageTransitionsTheme _festivalTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _FestivalPageTransitionsBuilder(ZoomPageTransitionsBuilder()),
    TargetPlatform.iOS: _FestivalPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
  },
);

class TubePilotApp extends StatefulWidget {
  final LanguageProvider languageProvider;
  const TubePilotApp({super.key, required this.languageProvider});
  @override
  State<TubePilotApp> createState() => _TubePilotAppState();
}

class _TubePilotAppState extends State<TubePilotApp> {
  StreamSubscription<Uri>? _linkSub;

  final AuthProvider _authProvider = AuthProvider();
  bool _pushInitDone = false;

  Uri? _lastHandledUri;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initOneSignalPlayerIdSync();

    _authProvider.addListener(_maybeInitPush);
    _maybeInitPush(); // covers "already logged in, app just reopened"
  }

  void _maybeInitPush() {
    final isLoggedIn = _authProvider.user != null;
    if (!isLoggedIn) {
      _pushInitDone = false;
      return;
    }
    if (_pushInitDone) return;
    _pushInitDone = true;
    PushService.initAfterLogin();
  }

  void _initOneSignalPlayerIdSync() {
    try {
      final existingId = OneSignal.User.pushSubscription.id;
      if (existingId != null) {
        ApiService.instance.registerOneSignalPlayerId(existingId).catchError((_) {});
      }
      OneSignal.User.pushSubscription.addObserver((state) {
        final playerId = OneSignal.User.pushSubscription.id;
        if (playerId != null) {
          ApiService.instance.registerOneSignalPlayerId(playerId).catchError((_) {});
        }
      });
    } catch (e) {
      debugPrint('⚠️ OneSignal player id sync failed to start: $e');
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      final appLinks = AppLinks();

      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }

      _linkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
    } catch (e) {
      debugPrint('⚠️ Deep link listener failed to start: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'tubepilot') return;

    // ------ OAuth success callback ------ //
    // tubepilot://oauth-success?...
    if (uri.host == 'oauth-success') {
      _handleOAuthSuccess(uri);
      return;
    }

    // ------ "My Videos" share deep link ------ //
    // https://<backend>/v/<videoId> -> tubepilot://video/<videoId>
    if (uri.host == 'video') {
      _handleVideoDeepLink(uri);
      return;
    }
  }

  void _handleOAuthSuccess(Uri uri) {
    if (_lastHandledUri == uri) return;
    _lastHandledUri = uri;

    final hasYoutubeParam = uri.queryParameters.containsKey('youtube_connected');
    final hasDriveParam = uri.queryParameters.containsKey('drive_connected');
    final hasMetaParam = uri.queryParameters.containsKey('meta_connected');
    final ctx = navigatorKey.currentContext;

    bool metaSuccess = false;
    bool metaMultiplePages = false;

    if (hasYoutubeParam) {
      final connected = uri.queryParameters['youtube_connected'] == '1';
      if (ctx != null) {
        showToast(ctx, connected ? 'YouTube channel connected!' : 'Failed to connect YouTube channel', isSuccess: connected, isError: !connected);
      }
    } else if (hasDriveParam) {
      final connected = uri.queryParameters['drive_connected'] == '1';
      if (ctx != null) {
        showToast(ctx, connected ? 'Google Drive connected!' : 'Failed to connect Google Drive', isSuccess: connected, isError: !connected);
      }
    } else if (hasMetaParam) {
      metaSuccess = uri.queryParameters['meta_connected'] == '1';
      metaMultiplePages = uri.queryParameters['multiple_pages'] == '1';
      if (ctx != null && !metaMultiplePages) {
        showToast(ctx, metaSuccess ? 'Facebook / Instagram connected!' : 'Failed to connect Facebook / Instagram', isSuccess: metaSuccess, isError: !metaSuccess);
      }
    }

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );

    if (hasMetaParam && metaSuccess && metaMultiplePages) {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const MetaPagePickerScreen()));
    }
  }

  // Handles tubepilot://video/<videoId>. Opens "My Videos" and lets that
  // screen highlight the matching card via `highlightVideoId`.
  void _handleVideoDeepLink(Uri uri) {
    if (_lastHandledUri == uri) return;
    _lastHandledUri = uri;

    final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    if (videoId == null || videoId.isEmpty) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => MyVideosScreen(highlightVideoId: videoId)),
    );
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _authProvider.removeListener(_maybeInitPush);
    widget.languageProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<LanguageProvider>.value(value: widget.languageProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return LanguageScope(
            languageProvider: widget.languageProvider,
            child: MaterialApp(
              navigatorKey: navigatorKey,
              title: 'TubePilot',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light.copyWith(pageTransitionsTheme: _festivalTransitions),
              darkTheme: AppTheme.dark.copyWith(pageTransitionsTheme: _festivalTransitions),
              themeMode: themeProvider.themeMode,
              // ⚠️ NEW — SYSTEM NAV BAR (buttons + gestures) ka ek hi hal, sab screens ke liye.
              // Android ka neeche wala system area (3-button bar ~48dp, gesture mode mein
              // bahut chhota/0) app ke content ko dabaye nahi — saari screens uske UPAR
              // banti hain, aur woh patti cream rehti hai. Keyboard khulne par `padding`
              // apne aap 0 ho jaata hai, isliye keyboard ke upar extra gap nahi banta.
              // ⚠️ NEW — ONE bottom nav bar for the whole app. It is drawn here, below the
              // Navigator, so it shows on every screen (My Videos, Wallet, ...) after login and
              // never overlaps content: each screen simply gets the space above the bar.
              // Hidden while the keyboard is open, and on Splash/Login (Dashboard not alive).
              builder: (context, child) {
                final bottom = MediaQuery.paddingOf(context).bottom;
                final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
                return ColoredBox(
                  color: AppColors.festivalIvory,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottom),
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: AnimatedBuilder(
                        animation: AppNav.instance,
                        builder: (context, _) {
                          final showNav = AppNav.instance.visible && !keyboardOpen;
                          return Column(
                            children: [
                              Expanded(child: child ?? const SizedBox.shrink()),
                              if (showNav)
                                DiwaliBottomNav(
                                  currentIndex: AppNav.instance.tab,
                                  onTap: (i) {
                                    AppNav.instance.setTab(i);
                                    // Back to the Dashboard (closes any pushed screens / dialogs).
                                    final r = AppNav.instance.dashboardRoute;
                                    if (r != null && r.isActive) {
                                      navigatorKey.currentState?.popUntil((x) => x == r);
                                    }
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              home: const SplashScreen(),
            ),
          );
        },
      ),
    );
  }
}