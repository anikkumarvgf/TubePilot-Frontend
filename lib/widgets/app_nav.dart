import 'dart:async';
import 'package:flutter/material.dart';

/// Global state of the bottom navigation bar (one bar for the WHOLE app).
///
/// main.dart draws the bar once, below the Navigator, so it shows on every
/// screen (My Videos, Wallet, ...) — not only inside the dashboard.
///
///  * The bar is visible only while the Dashboard is alive (= user is logged
///    in), so Splash / Login / Onboarding never show it.
///  * Tapping a tab selects it and returns to the Dashboard.
///  * It hides itself while the keyboard is open.
///  * A screen that must be full-screen (camera, player) can be wrapped in
///    [HideAppNav] to hide the bar while it is open.
class AppNav extends ChangeNotifier {
  AppNav._();
  static final AppNav instance = AppNav._();

  int _tab = 0;
  bool _dashboardMounted = false;
  int _hideCount = 0;

  /// Route of the Dashboard — set by DashboardScreen, used to pop back to it.
  ModalRoute<dynamic>? dashboardRoute;

  int get tab => _tab;
  bool get visible => _dashboardMounted && _hideCount == 0;

  void setTab(int i) {
    if (_tab == i) return;
    _tab = i;
    _notify();
  }

  void setDashboardMounted(bool v) {
    if (_dashboardMounted == v) return;
    _dashboardMounted = v;
    _notify();
  }

  void pushHide() {
    _hideCount++;
    _notify();
  }

  void popHide() {
    if (_hideCount > 0) _hideCount--;
    _notify();
  }

  // Notify after the current frame work, so listeners never rebuild while the
  // widget tree is locked (e.g. when a screen is being disposed).
  void _notify() => scheduleMicrotask(notifyListeners);
}

/// Wrap a screen with this to hide the global bottom bar while it is open.
class HideAppNav extends StatefulWidget {
  final Widget child;
  const HideAppNav({super.key, required this.child});
  @override
  State<HideAppNav> createState() => _HideAppNavState();
}

class _HideAppNavState extends State<HideAppNav> {
  @override
  void initState() {
    super.initState();
    AppNav.instance.pushHide();
  }

  @override
  void dispose() {
    AppNav.instance.popHide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
