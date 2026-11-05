import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared page background: off-white base (+ optional faint play-icon watermark).
/// Used by Onboarding, Profile Setup and (through main.dart) every page route.
///
/// Per-screen control:
///  * [backgroundAsset]      - use this image instead (screen-specific design).
///  * [customBackground]     - use this widget as the background.
///  * [foreground]           - decorations drawn above [child] (never block taps).
///  * [watermarkWhenNormal]  - false for screens that have their own opaque Scaffold.
///  * [excludeFromFestival]  - kept ONLY so old call sites still compile. Does nothing
///                             (there is no festival / Diwali system any more).
///  * [bottomReserve]        - kept for old call sites. Does nothing.
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

  Widget _imageBackground(String asset) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (c, e, s) => _watermarkPattern(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? background;
    if (customBackground != null) {
      background = customBackground;
    } else if (backgroundAsset != null) {
      background = _imageBackground(backgroundAsset!);
    }

    final usesImageBackground = background != null;
    final baseTheme = Theme.of(context);

    return Container(
      color: usesImageBackground ? const Color(0xFFFDFCFE) : const Color(0xFFFAF7FC),
      child: Stack(
        children: [
          Positioned.fill(
            child: background ?? (watermarkWhenNormal ? _watermarkPattern() : const SizedBox.shrink()),
          ),
          Theme(
            data: usesImageBackground ? AppTheme.withTransparentSurfaces(baseTheme) : baseTheme,
            child: child,
          ),
          if (foreground != null) Positioned.fill(child: IgnorePointer(child: foreground!)),
        ],
      ),
    );
  }
}
