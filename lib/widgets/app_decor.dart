import 'package:flutter/material.dart';

/// Shared TubePilot palette + small UI pieces (card, background, buttons,
/// bottom bar). Clean white / purple look - no festival artwork anywhere.
class UiColors {
  // Page + cards
  static const bg = Color(0xFFFDFCFE);
  static const cardTop = Color(0xFFFFFFFF);
  static const cardBottom = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE6DDE8);
  static const iconCircle = Color(0xFFF3ECF4);

  // Brand purples (dashboard / popups)
  static const purpleDark = Color(0xFF4A1A52); // dark plum
  static const purple = Color(0xFF7A2C8C);
  static const purpleDeep = Color(0xFF4A1A52);
  static const mauve = Color(0xFF8E7BA6);
  static const textDim = Color(0xFF6E6A78);
  static const inkBlack = Color(0xFF1B0F20);

  // Login / Sign-up artwork (plum header + teal leaves)
  static const plum = Color(0xFF52235E);
  static const authSheet = Color(0xFFF5EEF6);
  static const leaf = Color(0xFF52B3A0);
  static const leafDark = Color(0xFF4A9F8E);
  static const leafVein = Color(0xFF1F7A78);

  // Gold ring around the profile avatar
  static const goldLight = Color(0xFFF6D98A);
  static const gold = Color(0xFFD9A441);
  static const goldDeep = Color(0xFFB57F25);
}

// ---------------------------------------------------------------------------
// Plain page background. Wrap a transparent Scaffold with this.
// ---------------------------------------------------------------------------
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: UiColors.bg),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// White rounded card used across the app (radius 20, thin border, soft shadow).
// ---------------------------------------------------------------------------
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: UiColors.cardBorder, width: 1),
          boxShadow: [
            BoxShadow(color: UiColors.purpleDark.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating bottom bar (cream pill, purple border) - drawn fully in code,
// no image asset needed. Sits above the Android system bar (SafeArea).
// ---------------------------------------------------------------------------
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.labels = const ['Home', 'Upload', 'Upcoming', 'Analytics', 'Profile'],
  });

  static const _outlined = <IconData>[
    Icons.home_outlined,
    Icons.cloud_upload_outlined,
    Icons.calendar_month_outlined,
    Icons.bar_chart_rounded,
    Icons.person_outline_rounded,
  ];
  static const _filled = <IconData>[
    Icons.home_rounded,
    Icons.cloud_upload_rounded,
    Icons.calendar_month_rounded,
    Icons.bar_chart_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    // Material ancestor: the bar is drawn in main.dart outside any Scaffold, so
    // without it the Text widgets would fall back to the debug style.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F5),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: UiColors.purpleDark, width: 2),
              boxShadow: [
                BoxShadow(color: UiColors.purpleDark.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == currentIndex ? _filled[i] : _outlined[i],
                            size: 25,
                            color: UiColors.purpleDark,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              i < labels.length ? labels[i] : '',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.1,
                                fontWeight: i == currentIndex ? FontWeight.w800 : FontWeight.w600,
                                color: UiColors.purpleDark,
                              ),
                            ),
                          ),
                        ],
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

// ---------------------------------------------------------------------------
// Login / Sign-up layout (UI design): the page behind is off-white (the screen puts the
// faint play-icon pattern behind this widget), a big plum header text on top, and a
// lavender sheet with rounded top corners from [headerHeight] down to the bottom.
// [headerHeight] includes the status bar.
// ---------------------------------------------------------------------------
class AuthHeaderBackground extends StatelessWidget {
  final Widget header;
  final Widget sheet;
  final double headerHeight;

  const AuthHeaderBackground({
    super.key,
    required this.header,
    required this.sheet,
    this.headerHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: headerHeight,
          width: double.infinity,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(padding: const EdgeInsets.fromLTRB(30, 0, 24, 26), child: header),
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: UiColors.authSheet,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              child: sheet,
            ),
          ),
        ),
      ],
    );
  }
}

// Plum pill button used on Login / Sign Up.
class AppAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const AppAuthButton({super.key, required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: UiColors.plum,
          borderRadius: BorderRadius.circular(26),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
