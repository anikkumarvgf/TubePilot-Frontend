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
import 'widgets/app_decor.dart' show AppBottomNav, UiColors;

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

/// Wraps every page route in AppBrandBackground, then hands over to the normal
/// platform transition. Drawing the background inside each route keeps every page
/// opaque while animating (the old screen never shows through the new one).
class _PageBackgroundTransitionsBuilder extends PageTransitionsBuilder {
  final PageTransitionsBuilder inner;
  const _PageBackgroundTransitionsBuilder(this.inner);

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

const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _PageBackgroundTransitionsBuilder(ZoomPageTransitionsBuilder()),
    TargetPlatform.iOS: _PageBackgroundTransitionsBuilder(CupertinoPageTransitionsBuilder()),
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
              navigatorObservers: [PopupNavObserver()],
              title: 'TubePilot',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light.copyWith(pageTransitionsTheme: _pageTransitions),
              darkTheme: AppTheme.dark.copyWith(pageTransitionsTheme: _pageTransitions),
              themeMode: themeProvider.themeMode,
              // ONE bottom nav bar for the whole app, drawn here below the Navigator so it
              // shows on every screen after login. It is visible only while the Dashboard is
              // alive and hidden while the keyboard is open.
              // Android system bar: transparent. Screens WITHOUT the nav bar (Splash, Login,
              // Sign Up ...) keep the full height and paint behind it, so there is no
              // cream strip any more. Only when the nav bar is shown do screens give up the
              // bottom inset (the bar itself already sits above the system buttons).
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                final keyboardOpen = mq.viewInsets.bottom > 0;
                // Text size: never BIGGER than the design (a phone with a large system font
                // used to push texts out of cards / popups). Smaller is still respected.
                return MediaQuery(
                  data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.0)),
                  child: Builder(
                    builder: (context) => ColoredBox(
                      color: UiColors.bg,
                      child: AnimatedBuilder(
                        animation: AppNav.instance,
                        builder: (context, _) {
                          // Bar is hidden while the keyboard OR any popup / bottom sheet is open.
                          final showNav = AppNav.instance.visible && !keyboardOpen;
                          return Column(
                            children: [
                              Expanded(
                                child: MediaQuery.removePadding(
                                  context: context,
                                  removeBottom: showNav,
                                  child: child ?? const SizedBox.shrink(),
                                ),
                              ),
                              if (showNav)
                                AppBottomNav(
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