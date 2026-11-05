import 'package:flutter/material.dart';

/// Shared TubePilot palette + small UI pieces (card, background, buttons,
/// bottom bar). Clean white / purple look - no festival artwork anywhere.
class UiColors {
  // Page + cards
  static const bg = Color(0xFFFDFCFE);
  static const cardTop = Color(0xFFFFFFFF);
  static const cardBottom = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE4DFEC);
  static const iconCircle = Color(0xFFF1ECF8);

  // Brand purples (dashboard / popups)
  static const purpleDark = Color(0xFF3F1A7A);
  static const purple = Color(0xFF6B2C9C);
  static const purpleDeep = Color(0xFF3F1A7A);
  static const mauve = Color(0xFF8E7BA6);
  static const textDim = Color(0xFF6E6A78);
  static const inkBlack = Color(0xFF1B0F20);

  // Login / Sign-up artwork (plum header + teal leaves)
  static const plum = Color(0xFF52235E);
  static const authSheet = Color(0xFFF6EFF6);
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
// Login / Sign-up artwork from the UI design: plum header with teal leaves,
// and a light rounded sheet that overlaps it.
// ---------------------------------------------------------------------------
class AuthHeaderBackground extends StatelessWidget {
  final Widget header;
  final Widget sheet;
  final double headerHeight;
  final bool showPlant;

  const AuthHeaderBackground({
    super.key,
    required this.header,
    required this.sheet,
    this.headerHeight = 250,
    this.showPlant = true,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: UiColors.plum,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight + 40,
            child: CustomPaint(painter: _LeavesPainter(showPlant: showPlant, topInset: topInset)),
          ),
          Positioned.fill(
            child: Column(
            children: [
              SizedBox(
                height: headerHeight + topInset,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(padding: const EdgeInsets.fromLTRB(30, 0, 24, 34), child: header),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _LeavesPainter extends CustomPainter {
  final bool showPlant;
  final double topInset;
  const _LeavesPainter({required this.showPlant, required this.topInset});

  @override
  void paint(Canvas canvas, Size size) {
    final leaf = Paint()..color = UiColors.leaf;
    final vein = Paint()
      ..color = UiColors.leafVein
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Big leaf, top-left corner.
    final big = Path()
      ..moveTo(-10, -6)
      ..cubicTo(40, -10, 100, 30, 112, 100)
      ..cubicTo(150, 105, 140, 150, 98, 148)
      ..cubicTo(40, 150, -10, 110, -10, 60)
      ..close();
    canvas.drawPath(big, leaf);
    final v = Path()
      ..moveTo(12, 0)
      ..quadraticBezierTo(50, 30, 52, 82);
    canvas.drawPath(v, vein);

    if (showPlant) {
      // Tall plant on the right.
      final w = size.width;
      final l1 = Path()
        ..moveTo(w - 70, 200)
        ..cubicTo(w - 112, 140, w - 108, 100, w - 92, 80)
        ..cubicTo(w - 70, 110, w - 56, 160, w - 54, 200)
        ..close();
      canvas.drawPath(l1, Paint()..color = UiColors.leaf);
      final l2 = Path()
        ..moveTo(w - 62, 200)
        ..cubicTo(w - 60, 130, w - 44, 80, w - 30, 40)
        ..cubicTo(w - 14, 90, w - 20, 160, w - 40, 200)
        ..close();
      canvas.drawPath(l2, Paint()..color = UiColors.leafDark);
    }
  }

  @override
  bool shouldRepaint(covariant _LeavesPainter old) => old.showPlant != showPlant || old.topInset != topInset;
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
