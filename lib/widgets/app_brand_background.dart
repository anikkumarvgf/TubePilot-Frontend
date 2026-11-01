import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

/// The shared "off-white base + faint play-icon watermark" background
/// (same look as Splash) — factored out so Onboarding, Login/Signup, and
/// Profile Setup can all share exactly one implementation instead of
/// copy-pasted per screen. Splash screen itself is untouched and keeps
/// its own inline version.
///
/// Festival support: when ThemeProvider's festival mode is on, eligible
/// screens show the festival image instead of the watermark background.
/// Per-screen control:
///  * [excludeFromFestival]  — always keep the normal background.
///  * [backgroundAsset]      — use this image instead (screen-specific design).
///  * [customBackground]     — use this widget as the background.
///  * [foreground]           — decorations drawn above [child] (never block taps).
///  * [watermarkWhenNormal]  — set false for screens that have their own opaque
///                             Scaffold: in normal mode nothing extra is drawn
///                             behind them; in festival mode the image shows.
///  * [bottomReserve]        — height (px) at the bottom that the screen covers
///                             with its own UI (floating nav pill, button bar).
///                             The bottom artwork (diya, flowers) is lifted above
///                             this area so it is never hidden behind it.
class AppBrandBackground extends StatelessWidget {
  final Widget child;
  final bool excludeFromFestival;
  final String? backgroundAsset;
  final Widget? customBackground;
  final Widget? foreground;
  final bool watermarkWhenNormal;
  final double bottomReserve;

  const AppBrandBackground({
    super.key,
    required this.child,
    this.excludeFromFestival = false,
    this.backgroundAsset,
    this.customBackground,
    this.foreground,
    this.watermarkWhenNormal = true,
    this.bottomReserve = 0,
  });

  /// Festival artwork is 1152 x 2048 (9:16).
  static const double _artRatio = 2048 / 1152;

  Widget _watermarkPattern() {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.07,
        child: GridView.builder(
          padding: const EdgeInsets.symmetric(vertical: 40),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 30,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: 32,
          itemBuilder: (context, index) => Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.purple,
            size: 42,
          ),
        ),
      ),
    );
  }

  /// Why not plain BoxFit.cover: phones are taller than 9:16 (e.g. 9:20), so
  /// cover fills the height and crops the sides — the hanging diyas get cut
  /// at the screen edge. Instead the image is shown at FULL WIDTH. On tall
  /// screens the top half is pinned to the top and the bottom half to the
  /// bottom; the gap in the middle is filled by a soft, stretched copy of the
  /// same image (see softBase below) and the halves fade into it, so no seam
  /// or colour band is visible.
  Widget _imageBackground(BuildContext context, String asset) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = size.width;
    final imgH = w * _artRatio;
    final cacheW = (w * dpr).round();

    Widget fallback(BuildContext c, Object e, StackTrace? s) => _watermarkPattern();

    // FIX (middle band / "cut" on tall phones):
    //  * Before: the gap between the two halves showed a flat colour
    //    (festivalIvory) that does NOT match the PNG's own cream, so a
    //    visible band appeared in the middle of every screen.
    //  * Now: (1) a tiny copy of the SAME image is stretched over the whole
    //    screen as a base layer - decoded at ~48px wide so the upscale is
    //    naturally soft/blurred (cheap, no blur filter), so the gap gets the
    //    image's own colours; (2) the inner edge of each half fades out
    //    (ShaderMask) so the halves melt into that base - no hard seam.
    Widget softBase() => Positioned.fill(
          child: Image.asset(
            asset,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            cacheWidth: 48,
            errorBuilder: (c, e, s) => const SizedBox.shrink(),
          ),
        );

    Widget half({required bool top}) => Positioned(
          left: 0,
          right: 0,
          top: top ? 0 : null,
          bottom: top ? null : bottomReserve,
          height: imgH / 2,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            // Fade only the edge that faces the middle of the screen.
            shaderCallback: (rect) => LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: const [0.0, 0.84, 1.0],
            ).createShader(rect),
            child: ClipRect(
              child: Align(
                alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
                heightFactor: 0.5,
                child: Image.asset(
                  asset,
                  width: w,
                  fit: BoxFit.fitWidth,
                  gaplessPlayback: true,
                  cacheWidth: cacheW,
                  errorBuilder: fallback,
                ),
              ),
            ),
          ),
        );

    final tallScreen = size.height > imgH * 1.02;

    return ExcludeSemantics(
      child: IgnorePointer(
        child: tallScreen
            ? Stack(children: [softBase(), half(top: true), half(top: false)])
            // Short / wide screens: cover is fine, nothing important is cut.
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                cacheWidth: cacheW,
                errorBuilder: fallback,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the festival asset actually changes.
    final festivalAsset = context.select<ThemeProvider, String?>(
      (p) => p.festivalBackgroundAsset,
    );

    Widget? background;
    if (customBackground != null) {
      background = customBackground;
    } else if (backgroundAsset != null) {
      background = _imageBackground(context, backgroundAsset!);
    } else if (!excludeFromFestival && festivalAsset != null) {
      background = _imageBackground(context, festivalAsset);
    }

    final usesImageBackground = background != null;
    final baseTheme = Theme.of(context);

    return Container(
      color: usesImageBackground
          ? AppColors.festivalIvory
          : const Color(0xFFFAF7FC),
      child: Stack(
        children: [
          Positioned.fill(
            child: background ??
                (watermarkWhenNormal ? _watermarkPattern() : const SizedBox.shrink()),
          ),
          // Theme wrapper is always present so toggling festival mode does
          // not change the widget structure (screen state is preserved).
          Theme(
            data: usesImageBackground
                ? AppTheme.withTransparentSurfaces(baseTheme)
                : baseTheme,
            child: child,
          ),
          if (foreground != null)
            Positioned.fill(child: IgnorePointer(child: foreground!)),
        ],
      ),
    );
  }
}