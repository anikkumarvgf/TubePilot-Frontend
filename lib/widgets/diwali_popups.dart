import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import 'brand_icons.dart';
import 'diwali_decor.dart';

/// Diwali style popups (cream + gold + plum), shared by the whole app.
///
///  * [DiwaliPopupShell]            -> card jisme koi bhi popup ka content daalo
///  * [showDiwaliWelcome]           -> "Welcome to TubePilot / Happy Diwali" popup
///  * [maybeShowDiwaliWelcome]      -> sirf ek baar dikhata hai (SharedPreferences)
///  * [showDiwaliConnectYoutube]    -> chhota "Connect Your YouTube Channel" popup
///  * [showDiwaliSheet]             -> ⚠️ NEW: Diwali bottom sheet (help / options menus)
///      + [DiwaliSheetTitle], [DiwaliSheetTile], [DiwaliSheetDivider]
///
/// Rate Us / baaki popups ko bhi isi shell mein daal sakte ho.

const String kDiwaliWelcomeShownKey = 'diwali_welcome_shown_v1';

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------
class DiwaliPopupShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onClose;
  final bool hangingDiyas;
  final bool cornerFlowers;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const DiwaliPopupShell({
    super.key,
    required this.child,
    this.onClose,
    this.hangingDiyas = true,
    this.cornerFlowers = false,
    this.padding = const EdgeInsets.fromLTRB(30, 26, 30, 20),
    this.maxWidth = 380,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [DiwaliColors.creamTop, DiwaliColors.creamBottom],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: DiwaliColors.gold.withValues(alpha: 0.8), width: 1.4),
            boxShadow: [
              BoxShadow(color: DiwaliColors.goldDeep.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                if (hangingDiyas) ...[
                  const Positioned(top: 0, left: 0, child: IgnorePointer(child: DiwaliHangingDiyas(scale: 0.5))),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IgnorePointer(child: Transform.flip(flipX: true, child: const DiwaliHangingDiyas(scale: 0.5))),
                  ),
                ],
                if (cornerFlowers) ...[
                  const Positioned(bottom: 0, left: 0, child: IgnorePointer(child: DiwaliCornerDecor(scale: 0.7))),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IgnorePointer(child: Transform.flip(flipX: true, child: const DiwaliCornerDecor(scale: 0.7))),
                  ),
                ],
                SingleChildScrollView(padding: padding, child: child),
                if (onClose != null)
                  Positioned(
                    top: 10,
                    right: hangingDiyas ? 38 : 10,
                    child: GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          border: Border.all(color: DiwaliColors.cardBorder),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: DiwaliColors.purpleDark),
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
// ⚠️ NEW — Diwali bottom sheet
//
// Why: showModalBottomSheet routes are NOT PageRoutes, so the global Diwali
// page background never reaches them -> sheets were plain white. Use this
// instead of showModalBottomSheet:
//
//   final k = await showDiwaliSheet<String>(
//     context: context,
//     builder: (sheetContext) => Column(
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const DiwaliSheetTitle(text: 'What do you need help with?'),
//         DiwaliSheetTile(icon: Icons.payments_rounded, title: 'Payment',
//             onTap: () => Navigator.pop(sheetContext, 'payment')),
//       ],
//     ),
//   );
//
// The sheet shows the same festival artwork as the pages (hanging diyas at the
// top corners), and keeps its content ABOVE the Android system navigation area
// (3-button bar and gesture bar) and above the keyboard.
// ---------------------------------------------------------------------------
Future<T?> showDiwaliSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Keeps the sheet clear of the status bar / notch (top, left, right).
    // The bottom is handled inside _DiwaliSheetFrame with SafeArea.
    useSafeArea: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black54,
    builder: (sheetContext) => _DiwaliSheetFrame(child: builder(sheetContext)),
  );
}

class _DiwaliSheetFrame extends StatelessWidget {
  final Widget child;
  const _DiwaliSheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final asset = context.watch<ThemeProvider>().festivalBackgroundAsset;
    final width = MediaQuery.sizeOf(context).width;
    // Top half of the 9:16 festival artwork (1152 x 2048).
    final artHeight = width * (2048 / 1152) / 2;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    const radius = Radius.circular(28);

    return Container(
      decoration: BoxDecoration(
        color: DiwaliColors.creamTop,
        borderRadius: const BorderRadius.vertical(top: radius),
        border: Border(
          top: BorderSide(color: DiwaliColors.gold.withValues(alpha: 0.8), width: 1.4),
          left: BorderSide(color: DiwaliColors.gold.withValues(alpha: 0.4), width: 1),
          right: BorderSide(color: DiwaliColors.gold.withValues(alpha: 0.4), width: 1),
        ),
        boxShadow: [
          BoxShadow(color: DiwaliColors.goldDeep.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, -6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(27)),
        child: Stack(
          children: [
            if (asset != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: artHeight,
                child: IgnorePointer(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    // Fade the artwork out downwards so list text stays readable.
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(rect),
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 0.5,
                        child: Image.asset(
                          asset,
                          width: width,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // ⚠️ SafeArea (bottom) = system 3-button bar / gesture bar. The cream
            // background above still runs behind it, so there is no gap.
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(0, 10, 0, 12 + keyboard),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: DiwaliColors.gold.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet heading. Side padding (36) keeps it clear of the hanging diyas.
class DiwaliSheetTitle extends StatelessWidget {
  final String text;
  final Widget? leading;
  const DiwaliSheetTitle({super.key, required this.text, this.leading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 4, 36, 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of a Diwali sheet: icon in a beige circle, title, optional subtitle,
/// chevron. [danger] makes it red (e.g. Disconnect).
class DiwaliSheetTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool danger;
  final VoidCallback? onTap;

  const DiwaliSheetTile({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    final color = danger ? red : DiwaliColors.purpleDark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: DiwaliColors.iconCircle),
              child: leading ?? Icon(icon ?? Icons.circle_outlined, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: DiwaliColors.textDim, size: 22),
          ],
        ),
      ),
    );
  }
}

class DiwaliSheetDivider extends StatelessWidget {
  const DiwaliSheetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 36),
      color: DiwaliColors.cardBorder.withValues(alpha: 0.55),
    );
  }
}

// Plum gradient pill button with gold border.
class DiwaliButton extends StatelessWidget {
  final String label;
  final IconData? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool loading;
  const DiwaliButton({super.key, required this.label, required this.onTap, this.trailing, this.leading, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [DiwaliColors.purple, DiwaliColors.purpleDark]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: DiwaliColors.goldLight, width: 1.4),
          boxShadow: [BoxShadow(color: DiwaliColors.purpleDark.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), Icon(trailing, color: Colors.white, size: 20)],
          ],
        ),
      ),
    );
  }
}

class _GoldCircle extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  const _GoldCircle({required this.icon, required this.size, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: [Color(0xFFFFF1E0), Color(0xFFF6DDC0)],
        ),
        border: Border.all(color: DiwaliColors.gold.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, color: DiwaliColors.purpleDeep, size: iconSize),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome popup
// ---------------------------------------------------------------------------
Future<void> showDiwaliWelcome(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (_) => const _DiwaliWelcomeDialog(),
  );
}

/// Sirf pehli baar dikhata hai. true = dikhaya gaya.
Future<bool> maybeShowDiwaliWelcome(BuildContext context) async {
  bool already = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    already = prefs.getBool(kDiwaliWelcomeShownKey) ?? false;
    if (already) return false;
    await prefs.setBool(kDiwaliWelcomeShownKey, true);
  } catch (_) {
    return false;
  }
  if (!context.mounted) return false;
  await showDiwaliWelcome(context);
  return true;
}

class _DiwaliWelcomeDialog extends StatelessWidget {
  const _DiwaliWelcomeDialog();

  @override
  Widget build(BuildContext context) {
    const features = <(IconData, String)>[
      (Icons.video_call_rounded, 'Upload\nVideos'),
      (Icons.calendar_month_rounded, 'Smart\nScheduler'),
      (Icons.auto_awesome_rounded, 'AI\nIdeas'),
      (Icons.bar_chart_rounded, 'Analytics'),
      (Icons.diamond_outlined, 'Grow\nFaster'),
    ];

    return DiwaliPopupShell(
      onClose: () => Navigator.of(context).pop(),
      cornerFlowers: true,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 58),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/splash.png', width: 34, height: 34),
              const SizedBox(width: 6),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
                  children: [
                    TextSpan(text: 'Tube', style: TextStyle(color: DiwaliColors.purpleDark)),
                    TextSpan(text: 'Pilot', style: TextStyle(color: DiwaliColors.purple)),
                  ],
                ),
              ),
            ],
          ),
          const Text(
            'Your YouTube Growth Partner',
            style: TextStyle(color: DiwaliColors.purpleDark, fontSize: 10.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text('Welcome to', style: DiwaliColors.script.copyWith(color: DiwaliColors.purple, fontSize: 24, fontWeight: FontWeight.w600, height: 1.0)),
          const Text(
            'TubePilot',
            style: TextStyle(color: DiwaliColors.purpleDark, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.1),
          ),
          const SizedBox(height: 4),
          const Text(
            "Let's make your YouTube journey bigger!",
            textAlign: TextAlign.center,
            style: TextStyle(color: DiwaliColors.purpleDark, fontSize: 12.5),
          ),
          const SizedBox(height: 8),

          // Happy Diwali
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Happy', style: DiwaliColors.script.copyWith(color: DiwaliColors.purple, fontSize: 22, fontWeight: FontWeight.w600, height: 1.0)),
              const SizedBox(width: 6),
              const DiwaliDiya(width: 30),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Diwali', style: DiwaliColors.script.copyWith(color: DiwaliColors.purpleDark, fontSize: 56, fontWeight: FontWeight.w800, height: 1.0)),
          ),
          const SizedBox(height: 4),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'New Beginnings  •  Bigger Dreams  •  More Views',
              style: TextStyle(color: DiwaliColors.purpleDark, fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Congratulations on joining TubePilot!',
            textAlign: TextAlign.center,
            style: TextStyle(color: DiwaliColors.purpleDark, fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          const Text(
            'May this Diwali bring creativity, success and endless opportunities to your YouTube journey.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DiwaliColors.purpleDark, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 12),

          // Features strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DiwaliColors.cardBorder.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                for (final f in features)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GoldCircle(icon: f.$1, size: 36, iconSize: 19),
                        const SizedBox(height: 4),
                        Text(
                          f.$2,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 9.5, height: 1.15),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DiwaliButton(label: "Let's Go", trailing: Icons.arrow_forward_rounded, onTap: () => Navigator.of(context).pop()),
          const SizedBox(height: 8),
          Text('Together We Grow', style: DiwaliColors.script.copyWith(color: DiwaliColors.purple, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connect YouTube popup (short)
// ---------------------------------------------------------------------------
/// true = user ne "Connect" dabaya. Connect ka asli kaam (OAuth URL kholna)
/// jahan se call karte ho wahin karo: `if (await showDiwaliConnectYoutube(context)) { ... }`
Future<bool> showDiwaliConnectYoutube(
  BuildContext context, {
  String title = 'Connect Your YouTube Channel',
  String subtitle = 'Get your uploaded videos and optimize them with AI.',
  String buttonLabel = 'Connect YouTube Channel',
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => DiwaliConnectYoutubeDialog(title: title, subtitle: subtitle, buttonLabel: buttonLabel),
  );
  return r == true;
}

class DiwaliConnectYoutubeDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  const DiwaliConnectYoutubeDialog({
    super.key,
    this.title = 'Connect Your YouTube Channel',
    this.subtitle = 'Get your uploaded videos and optimize them with AI.',
    this.buttonLabel = 'Connect YouTube Channel',
  });

  Widget _row(IconData icon, String t, String s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _GoldCircle(icon: icon, size: 34, iconSize: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 12.5, fontWeight: FontWeight.w800)),
                Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DiwaliColors.textDim, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DiwaliPopupShell(
      onClose: () => Navigator.of(context).pop(false),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 84,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 104,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: DiwaliColors.cardBorder),
                    boxShadow: [BoxShadow(color: DiwaliColors.goldDeep.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const YoutubeIcon(size: 46),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [DiwaliColors.purple, DiwaliColors.purpleDark]),
                      border: Border.all(color: DiwaliColors.goldLight, width: 1.2),
                    ),
                    child: const Icon(Icons.link_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12.5, height: 1.3),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DiwaliColors.cardBorder.withValues(alpha: 0.6)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _row(Icons.video_library_rounded, 'Access your uploaded videos', 'Pick videos right from your channel'),
                _row(Icons.auto_awesome_rounded, 'AI-powered SEO analysis', 'Instant scores and suggestions'),
                _row(Icons.trending_up_rounded, 'Boost your reach', 'Better metadata = more views'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DiwaliButton(
            label: buttonLabel,
            trailing: Icons.chevron_right_rounded,
            leading: const YoutubeIcon(size: 20),
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, size: 13, color: DiwaliColors.textDim),
              SizedBox(width: 5),
              Text('Secure & Read Only Access', style: TextStyle(color: DiwaliColors.textDim, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}