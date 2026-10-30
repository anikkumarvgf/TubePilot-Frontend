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
// Full-screen festival background.
//
// FIX: the artwork (9:16) used to be drawn with BoxFit.cover, which crops the
// sides on taller phones and cut the hanging diyas. Now it is scaled to the
// screen WIDTH (nothing is cropped sideways, no stretching): the top half is
// pinned to the top and the bottom half to the bottom, the middle fades into
// plain cream. Wrap a transparent Scaffold with this.
//
// [decor] is kept only so old call sites still compile; it does nothing now.
// ---------------------------------------------------------------------------
class DiwaliBackground extends StatelessWidget {
  final Widget child;
  final bool decor;
  const DiwaliBackground({super.key, required this.child, this.decor = true});

  @override
  Widget build(BuildContext context) {
    final asset = context.watch<ThemeProvider>().festivalBackgroundAsset;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: DiwaliColors.creamTop),
        if (asset != null) ...[
          Positioned(top: 0, left: 0, right: 0, child: _BgHalf(asset: asset, top: true)),
          Positioned(bottom: 0, left: 0, right: 0, child: _BgHalf(asset: asset, top: false)),
        ],
        child,
      ],
    );
  }
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
          border: Border.all(color: DiwaliColors.cardBorder.withValues(alpha: 0.55), width: 1),
          boxShadow: [
            BoxShadow(color: DiwaliColors.purpleDark.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (sprig)
              Positioned(
                right: 6,
                bottom: 4,
                child: IgnorePointer(child: DiwaliSprig(width: sprigSize * 0.8, height: sprigSize)),
              ),
            if (star)
              const Positioned(
                top: 6,
                right: 9,
                child: Text('\u2726', style: TextStyle(color: DiwaliColors.gold, fontSize: 9)),
              ),
            Padding(padding: padding, child: child),
          ],
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
    return SizedBox(width: width, height: width, child: CustomPaint(painter: _DiyaPainter()));
  }
}

class DiwaliSprig extends StatelessWidget {
  final double width;
  final double height;
  final bool mirrored;
  const DiwaliSprig({super.key, this.width = 24, this.height = 30, this.mirrored = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height, child: CustomPaint(painter: _SprigPainter(mirrored: mirrored)));
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
        child: const SizedBox(width: 64, height: 128, child: CustomPaint(painter: _HangingPainter())),
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
        child: const SizedBox(width: 84, height: 80, child: CustomPaint(painter: _CornerPainter())),
      ),
    );
  }
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
    ..cubicTo(c.dx - w * 0.46, c.dy + w * 0.42, c.dx + w * 0.46, c.dy + w * 0.42, c.dx + w / 2, c.dy)
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
  canvas.drawCircle(Offset(c.dx, c.dy + w * 0.14), w * 0.05, Paint()..color = DiwaliColors.goldLight);

  final rim = Rect.fromCenter(center: c, width: w, height: w * 0.2);
  canvas.drawOval(rim, Paint()..color = DiwaliColors.goldLight);
  canvas.drawOval(rim.deflate(w * 0.04), Paint()..color = DiwaliColors.goldDeep.withValues(alpha: 0.75));

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
      ).createShader(Rect.fromLTWH(c.dx - w * 0.2, c.dy - w * 0.8, w * 0.4, w * 0.75)),
  );
}

void _drawFlower(Canvas canvas, Offset c, double r, Color color) {
  final petal = Paint()..color = color;
  for (var i = 0; i < 8; i++) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(i * math.pi / 4);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.55), width: r * 0.7, height: r * 0.95), petal);
    canvas.restore();
  }
  canvas.drawCircle(c, r * 0.32, Paint()..color = const Color(0xFFD9741A));
}

class _DiyaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawDiya(canvas, Offset(size.width / 2, size.height * 0.62), size.width * 0.9);
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
    for (final p in const [Offset(42, 18), Offset(42, 34), Offset(16, 28), Offset(16, 50)]) {
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
          ..quadraticBezierTo(leafLen * scale * 0.5, -leafWid * scale, leafLen * scale, 0)
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
    canvas.drawCircle(Offset(w * 0.12, h * 0.94), 1.8, Paint()..color = DiwaliColors.petal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}