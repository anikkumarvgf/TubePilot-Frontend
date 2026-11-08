import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'app_decor.dart';

/// Video of the Rs1 offer screen (assets/videos/offer.mp4).
///
/// FAST LOAD: [warmUp] is called when the dashboard opens, so the video is already
/// initialised by the time the Rs1 screen appears. Until it is ready (or if the file is
/// missing) a soft 16:9 placeholder is shown, so the screen never waits or breaks.
class OfferVideo {
  OfferVideo._();

  static const String asset = 'assets/videos/offer.mp4';

  static VideoPlayerController? _ctrl;
  static Future<void>? _init;
  static bool _failed = false;

  /// Starts loading in the background. Safe to call many times.
  static void warmUp() {
    if (_ctrl != null || _failed) return;
    final c = VideoPlayerController.asset(asset, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _ctrl = c;
    _init = c.initialize().then((_) {
      c.setLooping(true);
      c.setVolume(0); // autoplay is always muted (like a story ad)
    }).catchError((Object e) {
      debugPrint('[OfferVideo] could not load $asset: $e');
      _failed = true;
      c.dispose();
      _ctrl = null;
    });
  }

  /// Frees the player (called when the Rs1 screen closes). Next [warmUp] loads it again.
  static void release() {
    final c = _ctrl;
    _ctrl = null;
    _init = null;
    c?.pause();
    c?.dispose();
  }
}

/// 16:9 rounded video box shown at the top of the Rs1 screen.
class OfferVideoBox extends StatefulWidget {
  const OfferVideoBox({super.key});
  @override
  State<OfferVideoBox> createState() => _OfferVideoBoxState();
}

class _OfferVideoBoxState extends State<OfferVideoBox> {
  bool _ready = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    OfferVideo.warmUp();
    final f = OfferVideo._init;
    f?.then((_) {
      final c = OfferVideo._ctrl;
      if (!mounted || c == null || !c.value.isInitialized) return;
      c.play();
      setState(() => _ready = true);
    });
  }

  void _toggleMute() {
    final c = OfferVideo._ctrl;
    if (c == null) return;
    setState(() => _muted = !_muted);
    c.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = OfferVideo._ctrl;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: UiColors.cardBorder.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // placeholder (also the poster while the video loads)
              Container(
                color: const Color(0xFFF4EEF6),
                alignment: Alignment.center,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Icon(Icons.play_arrow_rounded, color: UiColors.purpleDark, size: 30),
                ),
              ),
              if (_ready && c != null)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              if (_ready)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                      child: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 17),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
