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

// Palette: warm white canvas, plum purple, gold.
class _C {
  static const purpleDark = Color(0xFF4B1A5E);
  static const purple = Color(0xFF7A2C8C);
  static const purpleDeep = Color(0xFF5A1F6E);
  static const mauve = Color(0xFF9B6F94);

  static const goldLight = Color(0xFFF6D98A);
  static const gold = Color(0xFFD9A441);
  static const goldDeep = Color(0xFFB57F25);
}

const TextStyle _script = TextStyle(
  fontFamily: 'serif',
  fontFamilyFallback: ['Georgia', 'Times New Roman'],
  fontStyle: FontStyle.italic,
);

/// The shareable achievement card. Wrap in RepaintBoundary to export as PNG.
///
/// The card has a fixed layout (no scrolling) and automatically scales down
/// to fit whatever space the parent gives it.
///
/// [channelAvatarUrl] is optional. If it is null or fails to load, the
/// TubePilot play-logo badge is shown instead.
/// [channelHandle] is the user's real YouTube handle (e.g. `@mychannel`).
/// [greeting] / [tagline] are the festival texts at the bottom
/// (change them for every new occasion).
class MilestoneCard extends StatelessWidget {
  final String type; // 'subscribers' | 'views'
  final int value;
  final String channelTitle;
  final String? channelHandle;
  final String? videoTitle;
  final String? channelAvatarUrl;
  final bool showVerifiedBadge;
  final String greeting;
  final String tagline;

  const MilestoneCard({
    super.key,
    required this.type,
    required this.value,
    required this.channelTitle,
    this.channelHandle,
    this.videoTitle,
    this.channelAvatarUrl,
    this.showVerifiedBadge = true,
    this.greeting = 'Happy Diwali',
    this.tagline = 'STAY CREATIVE  \u2022  STAY BLESSED',
  });

  static const double _w = 340;
  static const double _h = 664;

  String get _handleText {
    final h = (channelHandle ?? '').trim();
    if (h.isEmpty) return 'YouTube Channel';
    return h.startsWith('@') ? h : '@$h';
  }

  @override
  Widget build(BuildContext context) {
    final v = formatCount(value);
    final isSubs = type == 'subscribers';

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: _w,
        height: _h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF3)],
              ),
            ),
            child: Stack(
              children: [
                // ---- Brand header ----
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: _C.purple, width: 3.5),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: _C.purple, size: 24),
                      ),
                      const SizedBox(height: 3),
                      const Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Tube', style: TextStyle(color: Color(0xFF1A1A1A))),
                          TextSpan(text: 'Pilot', style: TextStyle(color: _C.purple)),
                        ]),
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1),
                      ),
                      const Text(
                        'Your YouTube Growth Partner',
                        style: TextStyle(color: _C.mauve, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                // ---- Ornate frame + content ----
                Positioned(
                  top: 98,
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: CustomPaint(painter: _FramePainter())),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Congratulations
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.eco_rounded, color: _C.gold, size: 20),
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
                                    Transform.flip(
                                      flipX: true,
                                      child: const Icon(Icons.eco_rounded, color: _C.gold, size: 20),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'You\u2019ve reached a new milestone!',
                                  style: TextStyle(color: _C.purpleDark, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),

                            // Channel row (real avatar / name / handle)
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
                                  child: _Avatar(url: channelAvatarUrl, name: channelTitle, size: 46),
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
                                                fontSize: 18,
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

                            // Hero badge: crown + round plaque + laurel wreath + ribbon
                            SizedBox(
                              width: 260,
                              height: 176,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Positioned.fill(child: CustomPaint(painter: _WreathPainter())),
                                  Positioned(
                                    left: 66,
                                    top: 28,
                                    child: Container(
                                      width: 128,
                                      height: 128,
                                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 36),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: _C.gold, width: 3),
                                        gradient: const RadialGradient(
                                          center: Alignment(-0.2, -0.4),
                                          radius: 1.0,
                                          colors: [Color(0xFF7B2E8E), Color(0xFF4A1860)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(color: _C.gold.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 1),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(width: 6, height: 1, color: _C.goldLight),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isSubs ? 'SUBSCRIBERS' : 'VIEWS',
                                                  style: const TextStyle(
                                                    color: _C.goldLight,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 2.2,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Container(width: 6, height: 1, color: _C.goldLight),
                                              ],
                                            ),
                                          ),
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
                                                      fontSize: 46,
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
                                  const Positioned(top: 4, left: 110, child: _Crown()),
                                  const Positioned(top: 118, left: 28, child: _Ribbon()),
                                ],
                              ),
                            ),

                            // Thank-you text
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Your support fuels our journey!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _C.purpleDark, fontSize: 14.5, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Thank you for being a part of the TubePilot family.\nKeep creating, keep growing!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _C.purpleDark, fontSize: 11, height: 1.35, fontWeight: FontWeight.w400),
                                ),
                                if (!isSubs && (videoTitle ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    videoTitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: _C.mauve.withValues(alpha: 0.9), fontSize: 11),
                                  ),
                                ],
                              ],
                            ),

                            // Divider with lotus
                            Row(
                              children: [
                                const SizedBox(width: 24),
                                Expanded(child: Container(height: 1, color: _C.purple.withValues(alpha: 0.45))),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.local_florist_rounded, color: _C.purple, size: 20),
                                ),
                                Expanded(child: Container(height: 1, color: _C.purple.withValues(alpha: 0.45))),
                                const SizedBox(width: 24),
                              ],
                            ),

                            // Feature row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const _Feature(icon: Icons.lightbulb_outline_rounded, label: 'AI Ideas'),
                                _vDivider(),
                                const _Feature(icon: Icons.calendar_month_outlined, label: 'Smart\nScheduler'),
                                _vDivider(),
                                const _Feature(icon: Icons.bar_chart_rounded, label: 'Analytics'),
                                _vDivider(),
                                const _Feature(icon: Icons.cloud_upload_outlined, label: 'Easy\nUpload'),
                                _vDivider(),
                                const _Feature(icon: Icons.auto_awesome_outlined, label: 'More\nViews'),
                              ],
                            ),

                            // Brand pill
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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

                            // Greeting
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.eco_rounded, color: _C.gold, size: 14),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          greeting,
                                          style: _script.copyWith(color: _C.goldDeep, fontSize: 25, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Transform.flip(
                                      flipX: true,
                                      child: const Icon(Icons.eco_rounded, color: _C.gold, size: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(width: 22, height: 1, color: _C.gold.withValues(alpha: 0.7)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          tagline,
                                          style: const TextStyle(
                                            color: _C.purpleDark,
                                            fontSize: 8.5,
                                            letterSpacing: 1.3,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(width: 22, height: 1, color: _C.gold.withValues(alpha: 0.7)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _vDivider() => Container(
        width: 1,
        height: 44,
        color: _C.gold.withValues(alpha: 0.35),
      );
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
              color: Colors.white.withValues(alpha: 0.7),
              border: Border.all(color: _C.gold.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, size: 17, color: _C.purpleDeep),
          ),
          const SizedBox(height: 4),
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

// ---------------------------------------------------------------------------
// Crown
// ---------------------------------------------------------------------------
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
// Gold ribbon across the badge: "Dreams · Content · Growth"
// ---------------------------------------------------------------------------
class _Ribbon extends StatelessWidget {
  const _Ribbon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 204,
      height: 34,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _RibbonPainter())),
          const Positioned(
            left: 26,
            right: 26,
            top: 0,
            height: 28,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Dreams \u00B7 Content \u00B7 Growth',
                  style: TextStyle(color: _C.purpleDark, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final tail = Paint()..color = const Color(0xFFC8923A);

    // swallow-tail ends (behind the band)
    final left = Path()
      ..moveTo(0, 6)
      ..lineTo(20, 6)
      ..lineTo(20, 33)
      ..lineTo(0, 33)
      ..lineTo(8, 19.5)
      ..close();
    final right = Path()
      ..moveTo(w, 6)
      ..lineTo(w - 20, 6)
      ..lineTo(w - 20, 33)
      ..lineTo(w, 33)
      ..lineTo(w - 8, 19.5)
      ..close();
    canvas.drawPath(left, tail);
    canvas.drawPath(right, tail);

    // main band
    final band = RRect.fromRectAndRadius(Rect.fromLTRB(14, 0, w - 14, 28), const Radius.circular(3));
    canvas.drawShadow(Path()..addRRect(band), _C.goldDeep, 3, false);
    canvas.drawRRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          colors: [_C.goldLight, Color(0xFFFBE9B5), _C.goldLight],
        ).createShader(band.outerRect),
    );
    canvas.drawRRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _C.goldDeep.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Golden laurel wreath around the round badge
// ---------------------------------------------------------------------------
class _WreathPainter extends CustomPainter {
  const _WreathPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, 92);

    void side(bool mirror) {
      canvas.save();
      if (mirror) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      const n = 9;
      for (var i = 0; i < n; i++) {
        final t = i / (n - 1);
        final theta = (100 + 135 * t) * math.pi / 180;
        final pos = c + Offset(math.cos(theta), math.sin(theta)) * 78;
        final tangent = theta + math.pi / 2;
        final len = 18.0 - 5 * t;
        const wid = 5.5;
        for (final s in [-1.0, 1.0]) {
          final isLight = (i + (s > 0 ? 1 : 0)).isEven;
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(tangent + s * 0.65);
          final path = Path()
            ..quadraticBezierTo(len * 0.5, -wid, len, 0)
            ..quadraticBezierTo(len * 0.5, wid, 0, 0);
          canvas.drawPath(
            path,
            Paint()
              ..shader = LinearGradient(
                colors: isLight ? [_C.goldLight, _C.gold] : [_C.gold, _C.goldDeep],
              ).createShader(Rect.fromLTWH(0, -wid, len, wid * 2)),
          );
          canvas.restore();
        }
      }
      canvas.restore();
    }

    side(false);
    side(true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Ornate cream frame (arched top/bottom, scooped corners, double gold outline)
// ---------------------------------------------------------------------------
class _FramePainter extends CustomPainter {
  const _FramePainter();

  Path _framePath(Size s, double inset, double bow, double c) {
    final l = inset;
    final r = s.width - inset;
    final t = inset + bow;
    final b = s.height - inset - bow;
    final cx = s.width / 2;
    return Path()
      ..moveTo(l + c, t)
      ..quadraticBezierTo(cx, t - 2 * bow, r - c, t)
      ..arcTo(Rect.fromCircle(center: Offset(r, t), radius: c), math.pi, -math.pi / 2, false)
      ..lineTo(r, b - c)
      ..arcTo(Rect.fromCircle(center: Offset(r, b), radius: c), -math.pi / 2, -math.pi / 2, false)
      ..quadraticBezierTo(cx, b + 2 * bow, l + c, b)
      ..arcTo(Rect.fromCircle(center: Offset(l, b), radius: c), 0, -math.pi / 2, false)
      ..lineTo(l, t + c)
      ..arcTo(Rect.fromCircle(center: Offset(l, t), radius: c), math.pi / 2, -math.pi / 2, false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _framePath(size, 2, 9, 20);
    final inner = _framePath(size, 9, 7, 14);

    canvas.drawShadow(outer, _C.goldDeep.withValues(alpha: 0.45), 6, false);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFCF4), Color(0xFFFAF3E3)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _C.gold.withValues(alpha: 0.85),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _C.goldLight.withValues(alpha: 0.9),
    );
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