import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/app_brand_background.dart';
import 'login_screen.dart';

/// First launch: ONE simple Welcome screen (light page with the play-icon pattern, plum wave at the
/// bottom, "Welcome / Your YouTube Growth Partner", round arrow button). The arrow opens the
/// Sign Up page directly.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  static const _plum = Color(0xFF4E0E52);
  late final AnimationController _in;
  bool _going = false;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_going) return;
    _going = true;
    await StorageService.setOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())); // Sign Up shows first
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _in, curve: Curves.easeOut);
    final slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _in, curve: Curves.easeOutCubic));
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FC),
      body: AppBrandBackground(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final waveTop = h * 0.50;
            return Stack(
              children: [
                // plum wave
                Positioned.fill(
                  top: waveTop,
                  child: CustomPaint(painter: _WavePainter(_plum)),
                ),
                // texts
                Positioned(
                  left: 32,
                  right: 24,
                  top: waveTop + 70,
                  child: FadeTransition(
                    opacity: fade,
                    child: SlideTransition(
                      position: slide,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome',
                              style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                          SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              children: [
                                TextSpan(text: 'Your ', style: TextStyle(color: Colors.white)),
                                TextSpan(text: 'YouTube Growth Partner', style: TextStyle(color: Color(0xFFE2B8EA))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // arrow button
                Positioned(
                  right: 28,
                  bottom: 28 + MediaQuery.of(context).padding.bottom,
                  child: FadeTransition(
                    opacity: fade,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _finish,
                        child: const SizedBox(
                          width: 64,
                          height: 64,
                          child: Icon(Icons.arrow_forward_rounded, color: _plum, size: 30),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  _WavePainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, s.height * 0.10)
      ..cubicTo(s.width * 0.22, -s.height * 0.02, s.width * 0.45, s.height * 0.02, s.width * 0.62, s.height * 0.12)
      ..cubicTo(s.width * 0.78, s.height * 0.22, s.width * 0.92, s.height * 0.17, s.width, s.height * 0.12)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.color != color;
}
