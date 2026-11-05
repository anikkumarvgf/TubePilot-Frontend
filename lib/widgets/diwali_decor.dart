import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Shared Diwali palette + decor used by dashboard (and later other screens).
class DiwaliColors {
  // Background: flat cream (festival image is drawn on top of it).
  static const creamTop = Color(0xFFFFF8E7);
  static const creamBottom = Color(0xFFFFF8E7);

  // Cards: clean white.
  static const cardTop = Color(0xFFFFFFFF);
  static const cardBottom = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFEBD9AE);

  // Primary text / icon colour.
  static const purpleDark = Color(0xFF4A235A);
  static const purple = Color(0xFF7A2C8C);
  static const purpleDeep = Color(0xFF4A235A);
  static const mauve = Color(0xFF9B6F94);
  static const textDim = Color(0xFF7D6B78);

  // Dark text used on the login screen bottom lines (very readable).
  static const inkBlack = Color(0xFF1B0F20);

  // Light beige used behind every icon.
  static const iconCircle = Color(0xFFF5EAD3);

  static const goldLight = Color(0xFFF6D98A);
  static const gold = Color(0xFFD9A441);
  static const goldDeep = Color(0xFFB57F25);

  static const petal = Color(0xFFA83A9A);

  static const TextStyle script = TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: ['Georgia', 'Times New Roman'],
    fontStyle: FontStyle.italic,
  );
}

// ---------------------------------------------------------------------------
// Full-screen background. Wrap a transparent Scaffold with this.
//
// DEFAULT (festivalImage: false): our own painted cream (#FFF8E7) with very
// faint gold rings — NO image file is used, so assets/diwali_bg.png is not
// loaded here at all.
// festivalImage: true brings the old diwali_bg.png artwork back.
//
// [decor] is kept only so old call sites still compile; it does nothing now.
// ---------------------------------------------------------------------------
class DiwaliBackground extends StatelessWidget {
  final Widget child;
  final bool decor;
  final bool festivalImage;
  const DiwaliBackground(
      {super.key,
      required this.child,
      this.decor = true,
      this.festivalImage = false});

  @override
  Widget build(BuildContext context) {
    final asset = festivalImage
        ? context.watch<ThemeProvider>().festivalBackgroundAsset
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: DiwaliColors.creamTop),
        if (!festivalImage)
          const Positioned.fill(
              child: CustomPaint(painter: _CreamRingsPainter())),
        if (asset != null) ...[
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _BgHalf(asset: asset, top: true)),
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BgHalf(asset: asset, top: false)),
        ],
        child,
      ],
    );
  }
}

/// Very faint gold rings on the cream (same as the original painted design).
class _CreamRingsPainter extends CustomPainter {
  const _CreamRingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = DiwaliColors.gold.withValues(alpha: 0.10);
    for (final c in [
      Offset(size.width * 0.05, size.height * 0.42),
      Offset(size.width * 0.98, size.height * 0.66)
    ]) {
      for (var r = 24.0; r <= 84; r += 20) {
        canvas.drawCircle(c, r, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One half (top or bottom) of the background artwork, fitted to the width.
class _BgHalf extends StatelessWidget {
  final String asset;
  final bool top;
  const _BgHalf({required this.asset, required this.top});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        // Fade the edge that faces the middle of the screen (hides the seam).
        shaderCallback: (rect) => LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: const [0.0, 0.8, 1.0],
        ).createShader(rect),
        child: ClipRect(
          child: Align(
            alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
            heightFactor: 0.5,
            child: Image.asset(
              asset,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clean white card used across the app: radius 20, soft shadow, padding 16.
// [sprig] / [star] are optional extras and are OFF by default (no clutter).
// ---------------------------------------------------------------------------
class DiwaliCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool sprig;
  final bool star;
  final double sprigSize;

  const DiwaliCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 20,
    this.sprig = false,
    this.star = false,
    this.sprigSize = 30,
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
          border: Border.all(
              color: DiwaliColors.cardBorder.withValues(alpha: 0.55), width: 1),
          boxShadow: [
            BoxShadow(
                color: DiwaliColors.purpleDark.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (sprig)
              Positioned(
                right: 6,
                bottom: 4,
                child: IgnorePointer(
                    child:
                        DiwaliSprig(width: sprigSize * 0.8, height: sprigSize)),
              ),
            if (star)
              const Positioned(
                top: 6,
                right: 9,
                child: Text('\u2726',
                    style: TextStyle(color: DiwaliColors.gold, fontSize: 9)),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom navigation bar — built from the reference artwork.
//
// assets/nav_bg.png (1152 x 186, transparent top) holds the cream bar, the
// plum swooshes with the gold line, the diyas and the marigolds. It is scaled
// to the SCREEN WIDTH, so the proportions are identical on every phone. Only
// the 5 icons + labels + the active underline are real widgets drawn on top
// (so taps, active state and languages keep working).
//
// Android 3-button / gesture bar: wrapped in SafeArea, so the bar always sits
// ABOVE the system buttons. Use it as Scaffold.bottomNavigationBar with
// extendBody: false.
// ---------------------------------------------------------------------------
class DiwaliBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;

  const DiwaliBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.labels = const ['Home', 'Upload', 'Videos', 'Analytics', 'Profile'],
  });

  static const _outlined = <IconData>[
    Icons.home_outlined,
    Icons.cloud_upload_outlined,
    Icons.video_library_outlined,
    Icons.insights_rounded,
    Icons.person_outline_rounded,
  ];
  static const _filled = <IconData>[
    Icons.home_rounded,
    Icons.cloud_upload_rounded,
    Icons.video_library_rounded,
    Icons.insights_rounded,
    Icons.person_rounded,
  ];

  // Artwork size and the x-centre of each tab inside it (artwork pixels).
  static const double _artW = 1152;
  static const double _artH = 186;
  static const _centers = <double>[210, 383, 575, 758, 940];
  // Slight zoom (taller bar, bigger icons + labels) so it is easy to read/tap.
  static const double _zoom = 1.22;

  @override
  Widget build(BuildContext context) {
    // Material ancestor: the bar is drawn in main.dart, outside any Scaffold, so
    // without this its Text widgets fall back to the debug style (yellow underline).
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final s = w / _artW; // artwork px -> dp
            final h = _artH * s * _zoom;
            final tabW = 150 * s;
            final top = 36 * s * _zoom;

            return SizedBox(
              width: w,
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/nav_bg.png',
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: DiwaliColors.creamTop),
                    ),
                  ),
                  for (var i = 0; i < 5; i++)
                    Positioned(
                      left: _centers[i] * s - tabW / 2,
                      top: top,
                      width: tabW,
                      height: h - top,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(
                              i == currentIndex ? _filled[i] : _outlined[i],
                              size: 100 * s,
                              color: DiwaliColors.purpleDeep,
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                i < labels.length ? labels[i] : '',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: (42 * s).clamp(11.5, 14.5),
                                  height: 1.1,
                                  fontWeight: i == currentIndex
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: DiwaliColors.purpleDeep,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: i == currentIndex ? 56 * s : 0,
                              height: (9 * s).clamp(3.0, 4.5),
                              decoration: BoxDecoration(
                                color: DiwaliColors.purpleDeep,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small public pieces (still available for the popups / other screens)
// ---------------------------------------------------------------------------
class DiwaliDiya extends StatelessWidget {
  final double width;
  const DiwaliDiya({super.key, this.width = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: width,
        height: width,
        child: CustomPaint(painter: _DiyaPainter()));
  }
}

class DiwaliSprig extends StatelessWidget {
  final double width;
  final double height;
  final bool mirrored;
  const DiwaliSprig(
      {super.key, this.width = 24, this.height = 30, this.mirrored = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _SprigPainter(mirrored: mirrored)));
  }
}

class DiwaliHangingDiyas extends StatelessWidget {
  final double scale;
  const DiwaliHangingDiyas({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64 * scale,
      height: 128 * scale,
      child: FittedBox(
        fit: BoxFit.fill,
        child: const SizedBox(
            width: 64,
            height: 128,
            child: CustomPaint(painter: _HangingPainter())),
      ),
    );
  }
}

class DiwaliCornerDecor extends StatelessWidget {
  final double scale;
  const DiwaliCornerDecor({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84 * scale,
      height: 80 * scale,
      child: FittedBox(
        fit: BoxFit.fill,
        child: const SizedBox(
            width: 84,
            height: 80,
            child: CustomPaint(painter: _CornerPainter())),
      ),
    );
  }
}

/// Marigold flowers + petals shown beside the "Happy Diwali" badge.
class DiwaliSideFlowers extends StatelessWidget {
  const DiwaliSideFlowers({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
        width: 46,
        height: 80,
        child: CustomPaint(painter: _SideFlowersPainter()));
  }
}

class _SideFlowersPainter extends CustomPainter {
  const _SideFlowersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _drawFlower(canvas, const Offset(38, 20), 13, const Color(0xFFF28C1B));
    _drawFlower(canvas, const Offset(30, 46), 9, const Color(0xFFFFB81F));
    _drawFlower(canvas, const Offset(42, 66), 10, const Color(0xFFE8731A));
    final p = Paint()..color = DiwaliColors.petal.withValues(alpha: 0.75);
    for (final s in const [
      [20.0, 34.0, 0.6],
      [26.0, 70.0, -0.5],
    ]) {
      canvas.save();
      canvas.translate(s[0], s[1]);
      canvas.rotate(s[2]);
      canvas.drawPath(
        Path()
          ..quadraticBezierTo(6, -4, 12, 0)
          ..quadraticBezierTo(6, 4, 0, 0),
        p,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Drawing helpers
// ---------------------------------------------------------------------------
void _drawDiya(Canvas canvas, Offset c, double w) {
  final glowCenter = Offset(c.dx, c.dy - w * 0.45);
  final glowRect = Rect.fromCircle(center: glowCenter, radius: w * 0.6);
  canvas.drawCircle(
    glowCenter,
    w * 0.6,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x66FFD27A), Color(0x00FFD27A)],
      ).createShader(glowRect),
  );

  final bowl = Path()
    ..moveTo(c.dx - w / 2, c.dy)
    ..cubicTo(c.dx - w * 0.46, c.dy + w * 0.42, c.dx + w * 0.46,
        c.dy + w * 0.42, c.dx + w / 2, c.dy)
    ..close();
  canvas.drawPath(
    bowl,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [DiwaliColors.purple, DiwaliColors.purpleDark],
      ).createShader(Rect.fromLTWH(c.dx - w / 2, c.dy, w, w * 0.32)),
  );
  canvas.drawPath(
    bowl,
    Paint()
      ..style = PaintingStyle.stroke
      ..color = DiwaliColors.gold
      ..strokeWidth = 1,
  );
  canvas.drawCircle(Offset(c.dx, c.dy + w * 0.14), w * 0.05,
      Paint()..color = DiwaliColors.goldLight);

  final rim = Rect.fromCenter(center: c, width: w, height: w * 0.2);
  canvas.drawOval(rim, Paint()..color = DiwaliColors.goldLight);
  canvas.drawOval(rim.deflate(w * 0.04),
      Paint()..color = DiwaliColors.goldDeep.withValues(alpha: 0.75));

  final flame = Path()
    ..moveTo(c.dx, c.dy - w * 0.8)
    ..quadraticBezierTo(c.dx + w * 0.22, c.dy - w * 0.35, c.dx, c.dy - w * 0.06)
    ..quadraticBezierTo(c.dx - w * 0.22, c.dy - w * 0.35, c.dx, c.dy - w * 0.8);
  canvas.drawPath(
    flame,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF6C2), Color(0xFFFFB030)],
      ).createShader(
          Rect.fromLTWH(c.dx - w * 0.2, c.dy - w * 0.8, w * 0.4, w * 0.75)),
  );
}

void _drawFlower(Canvas canvas, Offset c, double r, Color color) {
  final petal = Paint()..color = color;
  for (var i = 0; i < 8; i++) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(i * math.pi / 4);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, -r * 0.55), width: r * 0.7, height: r * 0.95),
        petal);
    canvas.restore();
  }
  canvas.drawCircle(c, r * 0.32, Paint()..color = const Color(0xFFD9741A));
}

class _DiyaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawDiya(
        canvas, Offset(size.width / 2, size.height * 0.62), size.width * 0.9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HangingPainter extends CustomPainter {
  const _HangingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final string = Paint()
      ..color = DiwaliColors.gold.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(42, 0), const Offset(42, 60), string);
    canvas.drawLine(const Offset(16, 0), const Offset(16, 100), string);
    final star = Paint()..color = DiwaliColors.gold;
    for (final p in const [
      Offset(42, 18),
      Offset(42, 34),
      Offset(16, 28),
      Offset(16, 50)
    ]) {
      canvas.drawCircle(p, 2.6, star);
    }
    _drawDiya(canvas, const Offset(42, 62), 34);
    _drawDiya(canvas, const Offset(16, 102), 30);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _drawFlower(canvas, const Offset(10, 66), 13, const Color(0xFFF28C1B));
    _drawFlower(canvas, const Offset(22, 44), 10, const Color(0xFFFFB81F));
    _drawFlower(canvas, const Offset(8, 38), 8, const Color(0xFFE8731A));
    _drawFlower(canvas, const Offset(76, 68), 10, const Color(0xFFFFB81F));
    _drawFlower(canvas, const Offset(70, 48), 7, const Color(0xFFF28C1B));
    _drawDiya(canvas, const Offset(44, 58), 52);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SprigPainter extends CustomPainter {
  final bool mirrored;
  _SprigPainter({required this.mirrored});

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final w = size.width;
    final h = size.height;
    final p0 = Offset(w * 0.2, h);
    final p1 = Offset(w * 0.15, h * 0.4);
    final p2 = Offset(w * 0.8, 0);

    Offset at(double t) {
      final mt = 1 - t;
      return Offset(
        mt * mt * p0.dx + 2 * mt * t * p1.dx + t * t * p2.dx,
        mt * mt * p0.dy + 2 * mt * t * p1.dy + t * t * p2.dy,
      );
    }

    double angleAt(double t) {
      final mt = 1 - t;
      final dx = 2 * mt * (p1.dx - p0.dx) + 2 * t * (p2.dx - p1.dx);
      final dy = 2 * mt * (p1.dy - p0.dy) + 2 * t * (p2.dy - p1.dy);
      return math.atan2(dy, dx);
    }

    canvas.drawPath(
      Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy),
      Paint()
        ..color = DiwaliColors.goldDeep.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final leafLen = h * 0.36;
    final leafWid = h * 0.07;
    const count = 5;
    for (var i = 0; i < count; i++) {
      final t = 0.12 + 0.8 * i / (count - 1);
      final pos = at(t);
      final a = angleAt(t);
      final scale = 1.0 - 0.4 * (i / count);
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(a + side * 0.8);
        final path = Path()
          ..quadraticBezierTo(
              leafLen * scale * 0.5, -leafWid * scale, leafLen * scale, 0)
          ..quadraticBezierTo(leafLen * scale * 0.5, leafWid * scale, 0, 0);
        canvas.drawPath(
          path,
          Paint()
            ..shader = const LinearGradient(
              colors: [DiwaliColors.goldLight, DiwaliColors.goldDeep],
            ).createShader(Rect.fromLTWH(0, -leafWid, leafLen, leafWid * 2)),
        );
        canvas.restore();
      }
    }
    canvas.drawCircle(
        Offset(w * 0.12, h * 0.94), 1.8, Paint()..color = DiwaliColors.petal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// AUTH / SPLASH ART — everything below is drawn in CODE (no image files).
//
//   DiwaliAuthBackground  -> full-screen Diwali background (garlands, plum
//                            corners, fireworks, petals, big diya at the bottom)
//   DiwaliAuthButton      -> plum pill button with a diya icon + arrow
//   DiwaliTitleOrnament   -> small diya with leaves (above a title)
//   DiwaliLotusDivider    -> line - lotus - line
//   DiwaliSplashView      -> the complete splash screen (visuals only)
// =============================================================================

enum DiwaliArt { auth, splash }

class DiwaliAuthBackground extends StatelessWidget {
  final Widget child;
  final DiwaliArt art;
  const DiwaliAuthBackground(
      {super.key, required this.child, this.art = DiwaliArt.auth});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final s = (width / 390).clamp(0.8, 1.15).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFBF2), Color(0xFFFFF4DF)],
            ),
          ),
        ),
        IgnorePointer(
            child: CustomPaint(
                painter: _AuthBgPainter(splash: art == DiwaliArt.splash))),
        Positioned(
            top: 0,
            left: 0,
            child: IgnorePointer(child: DiwaliGarlands(scale: s))),
        Positioned(
          top: 0,
          right: 0,
          child: IgnorePointer(
              child:
                  Transform.flip(flipX: true, child: DiwaliGarlands(scale: s))),
        ),
        // UPDATED: the bottom diya / rangoli art is REMOVED on the auth screen
        // (it sat behind the "Already have an account?" and Terms lines).
        // The plum corner swooshes at the bottom are still drawn by _AuthBgPainter.
        child,
      ],
    );
  }
}

/// Three hanging gold strands (beads, lotus buds, lit diyas) for the top-left
/// corner. Mirror it with Transform.flip for the right corner.
class DiwaliGarlands extends StatelessWidget {
  final double scale;
  const DiwaliGarlands({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120 * scale,
      height: 320 * scale,
      child: FittedBox(
        fit: BoxFit.fill,
        child: const SizedBox(
            width: 120,
            height: 320,
            child: CustomPaint(painter: _GarlandsPainter())),
      ),
    );
  }
}

/// Large diya on a rangoli with marigolds on both sides.
class DiwaliBigDiya extends StatelessWidget {
  final double width;
  const DiwaliBigDiya({super.key, this.width = 220});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: width,
        height: width * 0.58,
        child: const CustomPaint(painter: _BigDiyaPainter()));
  }
}

/// Small white diya icon (used inside buttons).
class DiwaliDiyaIcon extends StatelessWidget {
  final double size;
  final Color color;
  const DiwaliDiyaIcon({super.key, this.size = 22, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _DiyaIconPainter(color)));
  }
}

/// Plum pill button: [diya icon]  Label  [arrow] — with gold leaf sprigs on both
/// outer sides. Pass loading: true to show a spinner instead.
class DiwaliAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const DiwaliAuthButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const DiwaliSprig(width: 22, height: 28),
        const SizedBox(width: 4),
        Expanded(
          child: GestureDetector(
            onTap: loading ? null : onPressed,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [DiwaliColors.purple, DiwaliColors.purpleDark]),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: DiwaliColors.goldLight, width: 1.6),
                boxShadow: [
                  BoxShadow(
                      color: DiwaliColors.purpleDark.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 5))
                ],
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DiwaliDiyaIcon(size: 24),
                        const SizedBox(width: 12),
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 22),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        const DiwaliSprig(width: 22, height: 28, mirrored: true),
      ],
    );
  }
}

/// Small lit diya with a leaf sprig on each side (sits above a title).
class DiwaliTitleOrnament extends StatelessWidget {
  const DiwaliTitleOrnament({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: const [
        DiwaliSprig(width: 22, height: 24, mirrored: true),
        SizedBox(width: 4),
        DiwaliDiya(width: 34),
        SizedBox(width: 4),
        DiwaliSprig(width: 22, height: 24),
      ],
    );
  }
}

/// ——— ❀ ——— divider.
class DiwaliLotusDivider extends StatelessWidget {
  final double width;
  const DiwaliLotusDivider({super.key, this.width = 230});

  @override
  Widget build(BuildContext context) {
    final line = Container(
        height: 1, color: DiwaliColors.purple.withValues(alpha: 0.55));
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(child: line),
          const SizedBox(width: 8),
          const SizedBox(
              width: 26,
              height: 20,
              child: CustomPaint(painter: _LotusPainter())),
          const SizedBox(width: 8),
          Expanded(child: line),
        ],
      ),
    );
  }
}

/// Complete splash screen visuals. In SplashScreen keep your existing
/// timer / navigation and just `return const DiwaliSplashView();` from build().
///
/// UPDATED layout (fixes the spinner touching the rangoli):
///   * logo + greeting moved up a little
///   * big diya / rangoli made a bit smaller and lifted
///   * loader sits clearly BELOW the rangoli with a visible gap
class DiwaliSplashView extends StatelessWidget {
  const DiwaliSplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DiwaliAuthBackground(
        art: DiwaliArt.splash,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final logo = (h * 0.14).clamp(80.0, 140.0).toDouble();
          final diyaW = (w * 0.66).clamp(200.0, 320.0).toDouble();

          return Stack(
            children: [
              // ---- logo + name + tagline ----
              Positioned(
                top: h * 0.15,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/splash.png',
                      width: logo,
                      height: logo,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.play_circle_outline_rounded,
                          size: logo * 0.8,
                          color: DiwaliColors.purple),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2),
                        children: [
                          TextSpan(
                              text: 'Tube',
                              style: TextStyle(color: Color(0xFF14091A))),
                          TextSpan(
                              text: 'Pilot',
                              style: TextStyle(color: DiwaliColors.purple)),
                        ],
                      ),
                    ),
                    const Text('Your YouTube Growth Partner',
                        style: TextStyle(
                            color: DiwaliColors.textDim, fontSize: 15)),
                  ],
                ),
              ),
              // ---- greeting ----
              Positioned(
                top: h * 0.425,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'H A P P Y',
                      style: TextStyle(
                          color: DiwaliColors.purpleDark,
                          fontSize: 14,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w500),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const DiwaliSprig(
                            width: 26, height: 32, mirrored: true),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(colors: [
                            DiwaliColors.purpleDark,
                            DiwaliColors.purple
                          ]).createShader(r),
                          child: Text(
                            'Diwali',
                            style: DiwaliColors.script.copyWith(
                                color: Colors.white,
                                fontSize: 58,
                                fontWeight: FontWeight.w600,
                                height: 1.05),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const DiwaliSprig(width: 26, height: 32),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'May your content shine brighter\nand your dreams grow bigger.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: DiwaliColors.purpleDark,
                          fontSize: 15.5,
                          height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    const DiwaliLotusDivider(width: 200),
                  ],
                ),
              ),
              // ---- side diyas + big diya + rangoli + flowers ----
              Positioned(
                  left: 14,
                  bottom: h * 0.19,
                  child: IgnorePointer(child: DiwaliDiya(width: 40))),
              Positioned(
                  right: 14,
                  bottom: h * 0.19,
                  child: IgnorePointer(child: DiwaliDiya(width: 40))),
              Positioned(
                left: 0,
                right: 0,
                bottom: h * 0.15,
                child: IgnorePointer(
                    child: Center(child: DiwaliBigDiya(width: diyaW))),
              ),
              // ---- loader: clearly BELOW the rangoli (visible gap) ----
              Positioned(
                left: 0,
                right: 0,
                bottom: h * 0.075,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: DiwaliColors.purple),
                    ),
                    SizedBox(height: 8),
                    Text('Loading Your Creative Journey…',
                        style: TextStyle(
                            color: DiwaliColors.purpleDark, fontSize: 13.5)),
                  ],
                ),
              ),
              // ---- "Powered by TubePilot" at the very bottom ----
              Positioned(
                left: 0,
                right: 0,
                bottom: h * 0.02,
                child: const Center(
                  child: Text(
                    'Powered by TubePilot',
                    style: TextStyle(
                      color: DiwaliColors.purpleDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters for the auth / splash art
// ---------------------------------------------------------------------------
void _drawLotusBud(Canvas canvas, Offset c, double r) {
  final paint = Paint()..color = DiwaliColors.gold;
  for (final a in const [-0.85, 0.0, 0.85]) {
    canvas.save();
    canvas.translate(c.dx, c.dy + r * 0.4);
    canvas.rotate(a);
    canvas.drawPath(
      Path()
        ..moveTo(0, -r * 1.3)
        ..quadraticBezierTo(r * 0.55, -r * 0.4, 0, r * 0.2)
        ..quadraticBezierTo(-r * 0.55, -r * 0.4, 0, -r * 1.3),
      paint,
    );
    canvas.restore();
  }
}

void _drawFirework(Canvas canvas, Offset c, double r) {
  final line = Paint()
    ..color = DiwaliColors.purple.withValues(alpha: 0.35)
    ..strokeWidth = 1;
  final dot = Paint()..color = DiwaliColors.gold.withValues(alpha: 0.7);
  for (var i = 0; i < 28; i++) {
    final a = i * 2 * math.pi / 28;
    final dir = Offset(math.cos(a), math.sin(a));
    final len = i.isEven ? r : r * 0.75;
    canvas.drawLine(c + dir * (r * 0.22), c + dir * len, line);
    canvas.drawCircle(c + dir * (len + 2), 1.3, dot);
  }
}

class _AuthBgPainter extends CustomPainter {
  final bool splash;
  const _AuthBgPainter({this.splash = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // faint mandala behind the logo
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = DiwaliColors.gold.withValues(alpha: 0.10);
    final mc = Offset(w * 0.5, h * 0.20);
    for (var r = 40.0; r <= 150; r += 22) {
      canvas.drawCircle(mc, r, ring);
    }
    for (var i = 0; i < 12; i++) {
      canvas.save();
      canvas.translate(mc.dx, mc.dy);
      canvas.rotate(i * math.pi / 6);
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -112), width: 34, height: 66),
          ring);
      canvas.restore();
    }

    if (!splash) {
      _drawFirework(canvas, Offset(w * 0.22, h * 0.16), 34);
      _drawFirework(canvas, Offset(w * 0.82, h * 0.30), 38);
    }

    // plum corner swooshes (top + bottom), mirrored for the right side
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(w, 0);
        canvas.scale(-1, 1);
      }
      final top = splash
          ? Path()
          : (Path()
            ..moveTo(0, 0)
            ..lineTo(w * 0.36, 0)
            ..quadraticBezierTo(w * 0.12, h * 0.025, 0, h * 0.085)
            ..close());
      if (!splash) {
        canvas.drawPath(
          top,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [DiwaliColors.purple, DiwaliColors.purpleDark],
            ).createShader(Rect.fromLTWH(0, 0, w * 0.36, h * 0.09)),
        );
      }
      if (!splash) {
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.36, 0)
            ..quadraticBezierTo(w * 0.13, h * 0.03, 0, h * 0.095),
          Paint()
            ..color = DiwaliColors.gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      final bottom = Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.955)
        ..quadraticBezierTo(w * 0.10, h * 0.978, w * 0.28, h)
        ..close();
      canvas.drawPath(
        bottom,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [DiwaliColors.purple, DiwaliColors.purpleDark],
          ).createShader(Rect.fromLTWH(0, h * 0.95, w * 0.3, h * 0.05)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(0, h * 0.948)
          ..quadraticBezierTo(w * 0.11, h * 0.975, w * 0.30, h),
        Paint()
          ..color = DiwaliColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.restore();
    }

    // scattered petals
    final petal = Paint()..color = DiwaliColors.petal.withValues(alpha: 0.7);
    const spots = <List<double>>[
      [0.52, 0.30, 0.9, 11],
      [0.90, 0.40, -0.7, 12],
      [0.06, 0.37, 0.5, 11],
      [0.94, 0.58, -0.6, 11],
      [0.04, 0.60, -0.3, 10],
      [0.80, 0.78, 0.7, 11],
      [0.62, 0.93, -0.5, 10],
      [0.40, 0.95, 0.8, 10],
    ];
    for (final sp in spots) {
      canvas.save();
      canvas.translate(w * sp[0], h * sp[1]);
      canvas.rotate(sp[2]);
      final len = sp[3];
      canvas.drawPath(
        Path()
          ..quadraticBezierTo(len * 0.5, -len * 0.38, len, 0)
          ..quadraticBezierTo(len * 0.5, len * 0.38, 0, 0),
        petal,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GarlandsPainter extends CustomPainter {
  const _GarlandsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final string = Paint()
      ..color = DiwaliColors.gold.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    final bead = Paint()..color = DiwaliColors.gold;

    void strand(double x, double endY, double diyaY, double diyaW) {
      canvas.drawLine(Offset(x, 0), Offset(x, endY), string);
      for (var y = 12.0; y < endY - 6; y += 13) {
        canvas.drawCircle(Offset(x, y), 1.7, bead);
      }
      for (var y = 34.0; y < endY - 12; y += 40) {
        _drawLotusBud(canvas, Offset(x, y), 6.5);
      }
      _drawDiya(canvas, Offset(x, diyaY), diyaW);
      _drawLotusBud(canvas, Offset(x, endY), 8.5);
    }

    strand(16, 290, 236, 34);
    strand(58, 196, 146, 32);
    strand(100, 118, 84, 30);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BigDiyaPainter extends CustomPainter {
  const _BigDiyaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // rangoli (flat mandala under the diya)
    final c = Offset(w * 0.5, h * 0.80);
    final r = w * 0.46;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, 0.26);
    final goldRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = DiwaliColors.gold.withValues(alpha: 0.85);
    canvas.drawCircle(Offset.zero, r,
        Paint()..color = const Color(0xFFF6EAF8).withValues(alpha: 0.9));
    canvas.drawCircle(Offset.zero, r, goldRing);
    const n = 16;
    for (var i = 0; i < n; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / n);
      final petal = Path()
        ..moveTo(0, r * 0.28)
        ..quadraticBezierTo(r * 0.17, r * 0.62, 0, r * 0.95)
        ..quadraticBezierTo(-r * 0.17, r * 0.62, 0, r * 0.28);
      canvas.drawPath(
        petal,
        Paint()
          ..color =
              (i.isEven ? const Color(0xFFB45BC4) : const Color(0xFFE58AC0))
                  .withValues(alpha: 0.88),
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, r * 0.27,
        Paint()..color = DiwaliColors.goldLight.withValues(alpha: 0.95));
    canvas.drawCircle(Offset.zero, r * 0.27, goldRing);
    canvas.restore();

    // marigolds on both sides
    _drawFlower(
        canvas, Offset(w * 0.07, h * 0.80), w * 0.075, const Color(0xFFF28C1B));
    _drawFlower(
        canvas, Offset(w * 0.16, h * 0.64), w * 0.058, const Color(0xFFFFB81F));
    _drawFlower(
        canvas, Offset(w * 0.93, h * 0.80), w * 0.075, const Color(0xFFF28C1B));
    _drawFlower(
        canvas, Offset(w * 0.84, h * 0.64), w * 0.058, const Color(0xFFFFB81F));

    // the diya
    _drawDiya(canvas, Offset(w * 0.5, h * 0.52), w * 0.56);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiyaIconPainter extends CustomPainter {
  final Color color;
  const _DiyaIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.06, h * 0.60)
        ..cubicTo(w * 0.10, h * 1.00, w * 0.90, h * 1.00, w * 0.94, h * 0.60)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.0)
        ..quadraticBezierTo(w * 0.78, h * 0.26, w * 0.5, h * 0.52)
        ..quadraticBezierTo(w * 0.22, h * 0.26, w * 0.5, h * 0.0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiyaIconPainter old) => old.color != color;
}

class _LotusPainter extends CustomPainter {
  const _LotusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.95);
    final h = size.height * 0.95;
    for (final a in const [-1.05, 1.05, -0.5, 0.5, 0.0]) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(a);
      canvas.drawPath(
        Path()
          ..quadraticBezierTo(h * 0.34, -h * 0.45, 0, -h)
          ..quadraticBezierTo(-h * 0.34, -h * 0.45, 0, 0),
        Paint()..color = DiwaliColors.purple,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
