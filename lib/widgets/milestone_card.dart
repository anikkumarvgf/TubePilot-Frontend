import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

String formatMilestone(num n) {
  String trim(double v) => v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  if (n >= 1000000) return '${trim(n / 1000000)}M';
  if (n >= 1000) return '${trim(n / 1000)}K';
  return n.toString();
}

/// Full count for the card hero: 1,000 / 12,500 / 999,999 / 1.2M
String formatCount(num n) {
  if (n >= 1000000) return formatMilestone(n);
  return n.toInt().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
}

// Palette: cream canvas, plum purple, gold.
class _C {
  static const creamTop = Color(0xFFFEF8EC);
  static const creamBottom = Color(0xFFFBEBD0);
  static const cardBg = Color(0xFFFFF8EA);
  static const cardBorder = Color(0xFFE9C987);

  static const purpleDark = Color(0xFF4B1A5E);
  static const purple = Color(0xFF7A2C8C);
  static const purpleDeep = Color(0xFF5A1F6E);
  static const mauve = Color(0xFF9B6F94);

  static const goldLight = Color(0xFFF6D98A);
  static const gold = Color(0xFFD9A441);
  static const goldDeep = Color(0xFFB57F25);

  static const petal = Color(0xFFA83A9A);
}

const TextStyle _script = TextStyle(
  fontFamily: 'serif',
  fontFamilyFallback: ['Georgia', 'Times New Roman'],
  fontStyle: FontStyle.italic,
);

/// The shareable achievement card. Wrap in RepaintBoundary to export as PNG.
///
/// [channelAvatarUrl] is optional. If it is null or fails to load, the
/// TubePilot play-logo badge is shown instead.
/// [channelHandle] is the user's real YouTube handle (e.g. `@mychannel`).
class MilestoneCard extends StatelessWidget {
  final String type; // 'subscribers' | 'views'
  final int value;
  final String channelTitle;
  final String? channelHandle;
  final String? videoTitle;
  final String? channelAvatarUrl;
  final bool showVerifiedBadge;

  const MilestoneCard({
    super.key,
    required this.type,
    required this.value,
    required this.channelTitle,
    this.channelHandle,
    this.videoTitle,
    this.channelAvatarUrl,
    this.showVerifiedBadge = true,
  });

  String get _handleText {
    final h = (channelHandle ?? '').trim();
    if (h.isEmpty) return 'YouTube Channel';
    return h.startsWith('@') ? h : '@$h';
  }

  @override
  Widget build(BuildContext context) {
    final v = formatCount(value);
    final isSubs = type == 'subscribers';

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 340,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),
            const Positioned.fill(child: CustomPaint(painter: _PetalsPainter())),

            // Hanging diyas + fireworks (top)
            const Positioned(top: 4, left: 6, child: _HangingDiyas()),
            Positioned(top: 4, right: 6, child: Transform.flip(flipX: true, child: const _HangingDiyas())),
            const Positioned(top: 12, left: 50, child: _Fireworks()),
            const Positioned(top: 12, right: 50, child: _Fireworks()),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- Brand header ----
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _C.purple, width: 4),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: _C.purple, size: 28),
                  ),
                  const SizedBox(height: 6),
                  const Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Tube', style: TextStyle(color: Color(0xFF1A1A1A))),
                      TextSpan(text: 'Pilot', style: TextStyle(color: _C.purple)),
                    ]),
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.1),
                  ),
                  const Text(
                    'Your YouTube Growth Partner',
                    style: TextStyle(color: _C.mauve, fontSize: 10.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),

                  // ---- Main frame ----
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                    decoration: BoxDecoration(
                      color: _C.cardBg.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _C.cardBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: _C.goldDeep.withValues(alpha: 0.14),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Congratulations
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _Laurel(width: 22, height: 30),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Congratulations!',
                                  style: _script.copyWith(
                                    color: _C.purpleDark,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _Laurel(width: 22, height: 30, mirrored: true),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'You\u2019ve reached a new milestone!',
                          style: TextStyle(color: _C.purpleDark, fontSize: 13.5, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),

                        // Channel row: avatar + name + handle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [_C.goldLight, _C.gold, _C.goldDeep, _C.goldLight, _C.gold, _C.goldLight],
                                ),
                              ),
                              child: _Avatar(url: channelAvatarUrl, name: channelTitle, size: 54),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          channelTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _C.purpleDark,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      if (showVerifiedBadge) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.purple),
                                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const _YtLogo(),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _handleText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: _C.mauve, fontSize: 12.5, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Hero badge: crown + plum plaque + laurels + ribbon
                        SizedBox(
                          width: 284,
                          height: 166,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              const Positioned(left: 0, top: 26, child: _Laurel(width: 46, height: 112, big: true)),
                              const Positioned(right: 0, top: 26, child: _Laurel(width: 46, height: 112, big: true, mirrored: true)),
                              Positioned(
                                top: 18,
                                child: Container(
                                  width: 226,
                                  height: 118,
                                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                    border: Border.all(color: _C.gold, width: 2.5),
                                    gradient: const RadialGradient(
                                      center: Alignment(-0.2, -0.4),
                                      radius: 1.0,
                                      colors: [Color(0xFF7B2E8E), Color(0xFF4A1860)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: _C.gold.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 1),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isSubs ? 'SUBSCRIBERS' : 'VIEWS',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Expanded(
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: ShaderMask(
                                              blendMode: BlendMode.srcIn,
                                              shaderCallback: (r) => const LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [Color(0xFFFFF3C4), _C.goldLight, _C.gold, _C.goldDeep],
                                                stops: [0.0, 0.35, 0.7, 1.0],
                                              ).createShader(r),
                                              child: Text(
                                                v,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 54,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -1,
                                                  height: 1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Positioned(top: 0, child: _Crown()),
                              Positioned(
                                top: 126,
                                child: Container(
                                  width: 224,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    gradient: const LinearGradient(
                                      colors: [_C.goldLight, Color(0xFFFBE9B5), _C.goldLight],
                                    ),
                                    border: Border.all(color: _C.goldDeep.withValues(alpha: 0.6), width: 1),
                                    boxShadow: [
                                      BoxShadow(color: _C.goldDeep.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3)),
                                    ],
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Dreams \u00B7 Content \u00B7 Growth',
                                      style: TextStyle(color: _C.purpleDark, fontSize: 12.5, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Thank-you text
                        const Text(
                          'Your support fuels our journey!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _C.purpleDark, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Thank you for being a part of the TubePilot family.\nKeep creating, keep growing!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _C.purpleDark, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w400),
                        ),
                        if (!isSubs && (videoTitle ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            videoTitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _C.mauve.withValues(alpha: 0.9), fontSize: 11.5),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Divider with lotus
                        Row(
                          children: [
                            Expanded(child: Container(height: 1, color: _C.purple.withValues(alpha: 0.45))),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.local_florist_rounded, color: _C.gold, size: 20),
                            ),
                            Expanded(child: Container(height: 1, color: _C.purple.withValues(alpha: 0.45))),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Feature row
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Feature(icon: Icons.lightbulb_outline_rounded, label: 'AI Ideas'),
                            _Feature(icon: Icons.calendar_month_outlined, label: 'Smart\nScheduler'),
                            _Feature(icon: Icons.bar_chart_rounded, label: 'Analytics'),
                            _Feature(icon: Icons.cloud_upload_outlined, label: 'Easy\nUpload'),
                            _Feature(icon: Icons.auto_awesome_outlined, label: 'More\nViews'),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Brand pill
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(colors: [_C.purpleDark, _C.purpleDeep, _C.purple]),
                            boxShadow: [
                              BoxShadow(color: _C.purpleDark.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: Colors.white, width: 1.8),
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'TubePilot',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                Container(
                                  width: 1,
                                  height: 18,
                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                  color: _C.goldLight.withValues(alpha: 0.7),
                                ),
                                Text(
                                  'Together We Grow',
                                  style: _script.copyWith(color: _C.goldLight, fontSize: 13.5),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.eco_rounded, color: _C.goldLight, size: 13),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Greeting
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 14, height: 1, color: _C.gold),
                            const SizedBox(width: 8),
                            Text(
                              'Happy Diwali',
                              style: _script.copyWith(color: _C.goldDeep, fontSize: 25, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Container(width: 14, height: 1, color: _C.gold),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'STAY CREATIVE  \u2022  STAY BLESSED',
                            style: TextStyle(color: _C.purpleDark, fontSize: 8.5, letterSpacing: 1.3, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom diyas + marigolds
            const Positioned(bottom: 0, left: 2, child: _CornerDecor()),
            Positioned(bottom: 0, right: 2, child: Transform.flip(flipX: true, child: const _CornerDecor())),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------
class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.6),
              border: Border.all(color: _C.gold.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, size: 17, color: _C.purpleDeep),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.purpleDark, fontSize: 9.5, height: 1.15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _YtLogo extends StatelessWidget {
  const _YtLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 14,
      decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(4)),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 11),
    );
  }
}

class _Crown extends StatelessWidget {
  const _Crown();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 40, height: 24, child: CustomPaint(painter: _CrownPainter()));
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.3)
      ..lineTo(w * 0.25, h * 0.62)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.75, h * 0.62)
      ..lineTo(w, h * 0.3)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_C.goldLight, _C.goldDeep],
        ).createShader(Offset.zero & size),
    );
    final dot = Paint()..color = _C.goldLight;
    canvas.drawCircle(Offset(0, h * 0.3), 2.2, dot);
    canvas.drawCircle(Offset(w * 0.5, 0), 2.4, dot);
    canvas.drawCircle(Offset(w, h * 0.3), 2.2, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Diya drawing (shared)
// ---------------------------------------------------------------------------
void _drawDiya(Canvas canvas, Offset c, double w) {
  // glow
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

  // bowl
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
        colors: [_C.purple, _C.purpleDark],
      ).createShader(Rect.fromLTWH(c.dx - w / 2, c.dy, w, w * 0.32)),
  );
  canvas.drawPath(
    bowl,
    Paint()
      ..style = PaintingStyle.stroke
      ..color = _C.gold
      ..strokeWidth = 1,
  );
  // little gold ornament on the bowl
  canvas.drawCircle(Offset(c.dx, c.dy + w * 0.14), w * 0.05, Paint()..color = _C.goldLight);

  // rim
  final rim = Rect.fromCenter(center: c, width: w, height: w * 0.2);
  canvas.drawOval(rim, Paint()..color = _C.goldLight);
  canvas.drawOval(rim.deflate(w * 0.04), Paint()..color = _C.goldDeep.withValues(alpha: 0.75));

  // flame
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

// ---------------------------------------------------------------------------
// Hanging diyas (top corners)
// ---------------------------------------------------------------------------
class _HangingDiyas extends StatelessWidget {
  const _HangingDiyas();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 64, height: 128, child: CustomPaint(painter: _HangingPainter()));
  }
}

class _HangingPainter extends CustomPainter {
  const _HangingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final string = Paint()
      ..color = _C.gold.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    // strings
    canvas.drawLine(const Offset(42, 0), const Offset(42, 60), string);
    canvas.drawLine(const Offset(16, 0), const Offset(16, 100), string);
    // gold stars on strings
    final star = Paint()..color = _C.gold;
    for (final p in const [Offset(42, 18), Offset(42, 34), Offset(16, 28), Offset(16, 50)]) {
      canvas.drawCircle(p, 2.6, star);
    }
    _drawDiya(canvas, const Offset(42, 62), 34);
    _drawDiya(canvas, const Offset(16, 102), 30);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Fireworks
// ---------------------------------------------------------------------------
class _Fireworks extends StatelessWidget {
  const _Fireworks();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 72, height: 72, child: CustomPaint(painter: _FireworkPainter()));
  }
}

class _FireworkPainter extends CustomPainter {
  const _FireworkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 16; i++) {
      final a = i * 2 * math.pi / 16;
      final r1 = size.width * 0.1;
      final r2 = size.width * (i.isEven ? 0.44 : 0.32);
      final color = i % 3 == 0 ? _C.petal.withValues(alpha: 0.65) : _C.gold.withValues(alpha: 0.85);
      final p1 = c + Offset(math.cos(a), math.sin(a)) * r1;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * r2;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = color
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r2 + 3), 1.3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Bottom corner decoration: marigolds + diya
// ---------------------------------------------------------------------------
class _CornerDecor extends StatelessWidget {
  const _CornerDecor();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 84, height: 80, child: CustomPaint(painter: _CornerDecorPainter()));
  }
}

class _CornerDecorPainter extends CustomPainter {
  const _CornerDecorPainter();

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

// ---------------------------------------------------------------------------
// Cream canvas with purple swooshes in all four corners
// ---------------------------------------------------------------------------
class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter();

  void _corner(Canvas canvas, double w, double h, {required bool flipX, required bool flipY}) {
    canvas.save();
    canvas.translate(flipX ? w : 0, flipY ? h : 0);
    canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);

    final s = w * 0.2;
    final swoosh = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.3, 0)
      ..quadraticBezierTo(w * 0.07, w * 0.03, 0, s)
      ..close();
    canvas.drawPath(
      swoosh,
      Paint()..shader = const LinearGradient(colors: [_C.purpleDark, _C.purple]).createShader(Rect.fromLTWH(0, 0, w * 0.3, s)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.34, 0)
        ..quadraticBezierTo(w * 0.1, w * 0.045, 0, s + 8),
      Paint()
        ..color = _C.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_C.creamTop, _C.creamBottom],
        ).createShader(rect),
    );

    // faint decorative leaves
    final faint = Paint()..color = _C.gold.withValues(alpha: 0.12);
    _leaf(canvas, Offset(w * 0.04, h * 0.5), 54, 16, -0.6, faint);
    _leaf(canvas, Offset(w * 0.9, h * 0.62), 50, 15, -2.4, faint);
    _leaf(canvas, Offset(w * 0.06, h * 0.7), 40, 12, -1.0, faint);

    _corner(canvas, w, h, flipX: false, flipY: false);
    _corner(canvas, w, h, flipX: true, flipY: false);
    _corner(canvas, w, h, flipX: false, flipY: true);
    _corner(canvas, w, h, flipX: true, flipY: true);
  }

  void _leaf(Canvas canvas, Offset at, double len, double wid, double angle, Paint paint) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final p = Path()
      ..quadraticBezierTo(len * 0.5, -wid, len, 0)
      ..quadraticBezierTo(len * 0.5, wid, 0, 0);
    canvas.drawPath(p, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Scattered purple petals (kept to the margins / top so text is never covered)
// ---------------------------------------------------------------------------
class _PetalsPainter extends CustomPainter {
  const _PetalsPainter();

  static const _spots = <List<double>>[
    // x fraction, y fraction, angle, length
    [0.20, 0.050, 0.9, 12],
    [0.80, 0.045, -0.7, 12],
    [0.04, 0.26, 0.5, 13],
    [0.965, 0.30, -0.6, 12],
    [0.035, 0.46, -0.3, 11],
    [0.97, 0.50, 0.8, 13],
    [0.03, 0.66, 0.7, 12],
    [0.965, 0.74, -0.5, 11],
    [0.04, 0.84, -0.8, 12],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _C.petal.withValues(alpha: 0.7);
    for (final s in _spots) {
      canvas.save();
      canvas.translate(size.width * s[0], size.height * s[1]);
      canvas.rotate(s[2]);
      final len = s[3];
      final wid = len * 0.38;
      final p = Path()
        ..quadraticBezierTo(len * 0.5, -wid, len, 0)
        ..quadraticBezierTo(len * 0.5, wid, 0, 0);
      canvas.drawPath(p, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Laurel branch (alternating gold / purple leaves along a curved stem)
// ---------------------------------------------------------------------------
class _Laurel extends StatelessWidget {
  final double width;
  final double height;
  final bool mirrored;
  final bool big;
  const _Laurel({required this.width, required this.height, this.mirrored = false, this.big = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _LaurelPainter(mirrored: mirrored, leaves: big ? 7 : 5)),
    );
  }
}

class _LaurelPainter extends CustomPainter {
  final bool mirrored;
  final int leaves;
  _LaurelPainter({required this.mirrored, required this.leaves});

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final w = size.width;
    final h = size.height;

    // stem: bottom (slightly right) curving up to top (left)
    final p0 = Offset(w * 0.78, h);
    final p1 = Offset(w * 1.05, h * 0.45);
    final p2 = Offset(w * 0.30, 0);

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
        ..color = _C.purple.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    final leafLen = h * 0.2;
    final leafWid = h * 0.055;
    for (var i = 0; i < leaves; i++) {
      final t = 0.1 + 0.8 * i / (leaves - 1);
      final pos = at(t);
      final a = angleAt(t);
      final scale = 1.0 - 0.35 * (i / leaves); // smaller towards the tip
      for (final side in [-1.0, 1.0]) {
        final isGold = (i + (side > 0 ? 1 : 0)) % 2 == 0;
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(a + side * 0.75);
        final path = Path()
          ..quadraticBezierTo(leafLen * scale * 0.5, -leafWid * scale, leafLen * scale, 0)
          ..quadraticBezierTo(leafLen * scale * 0.5, leafWid * scale, 0, 0);
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              colors: isGold ? [_C.goldLight, _C.goldDeep] : [_C.purple, _C.purpleDark],
            ).createShader(Rect.fromLTWH(0, -leafWid, leafLen, leafWid * 2)),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Channel avatar. Falls back to the TubePilot play-logo when there is no photo.
// ---------------------------------------------------------------------------
class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const _Avatar({required this.url, required this.name, required this.size});

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.purple, _C.purpleDark],
        ),
      ),
      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * 0.62),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = (url ?? '').isNotEmpty;
    final img = hasUrl
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _fallback(),
              errorWidget: (_, __, ___) => _fallback(),
            ),
          )
        : _fallback();
    // thin gold rim
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.gold),
      child: img,
    );
  }
}