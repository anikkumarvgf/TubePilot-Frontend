import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_decor.dart';

/// First-time hint: shows a hand sliding to the right + "Swipe right for AI Chat".
/// Shown once (SharedPreferences), dismissed by a tap or by a swipe.
class ChatSwipeTrail {
  static const _key = 'chat_trail_seen_v1';

  static Future<bool> shouldShow() async {
    try {
      final p = await SharedPreferences.getInstance();
      return !(p.getBool(_key) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, true);
    } catch (_) {}
  }
}

class ChatTrailOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const ChatTrailOverlay({super.key, required this.onDismiss});
  @override
  State<ChatTrailOverlay> createState() => _ChatTrailOverlayState();
}

class _ChatTrailOverlayState extends State<ChatTrailOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      onHorizontalDragEnd: (_) => widget.onDismiss(),
      child: Container(
        color: const Color(0xB31B0F20),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 90,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final t = Curves.easeInOut.transform(_c.value);
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                      ),
                      Positioned(
                        left: 10 + t * 130,
                        child: Opacity(
                          opacity: 1 - (t > 0.85 ? (t - 0.85) / 0.15 : 0),
                          child: const Icon(Icons.swipe_right_alt_rounded, color: Colors.white, size: 64),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Naya: AI Chat ✨',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UiColors.purple)),
                  SizedBox(height: 6),
                  Text(
                    'Dashboard par RIGHT slide karo, chat khul jayegi.\nVideo daalo, SEO karao, competitor dekho, sab chat se.\nWapas aane ke liye LEFT slide.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4, color: UiColors.inkBlack),
                  ),
                  SizedBox(height: 8),
                  Text('Band karne ke liye tap karo', style: TextStyle(fontSize: 12, color: UiColors.textDim)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caption shown while the mock swipe demo plays (chat slides to the dashboard and back).
class ChatDemoCaption extends StatelessWidget {
  const ChatDemoCaption({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: UiColors.purple,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 5))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.swipe_rounded, color: Colors.white, size: 26),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Aise slide karke dashboard aur chat badlo',
                style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}