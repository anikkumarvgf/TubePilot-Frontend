import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import 'app_decor.dart';
import 'app_nav.dart';
import 'common.dart';
import 'milestone_card.dart';

class MilestonePopup {
  static bool _busy = false;

  /// Call from the home page (DashboardScreen.initState, after first frame).
  /// Shows the pending milestone card, if any. Safe to call many times.
  /// Returns true if a milestone card was actually shown.
  static Future<bool> checkAndShow(BuildContext context) async {
    if (_busy) return false;
    _busy = true;
    try {
      final res = await ApiService.instance.getPendingMilestone();
      final m = res['milestone'];
      if (m == null || !context.mounted) return false;

      // The backend keeps a card "active" for 15 days. Here it is limited to ONCE PER DAY
      // (local date). The day is saved BEFORE showing, so a closed app does not repeat it today.
      final id = '${m['id']}';
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final prefs = await SharedPreferences.getInstance();
      final key = 'milestone_last_shown_day_$id';
      if (prefs.getString(key) == today) return false;
      await prefs.setString(key, today);
      if (!context.mounted) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        // Dark overlay instead of grey, so the home page does not show through.
        barrierColor: Colors.black.withValues(alpha: 0.88),
        useSafeArea: false, // the dialog handles the safe area itself (full screen)
        builder: (_) => _MilestoneDialog(data: Map<String, dynamic>.from(m)),
      );
      return true;
    } catch (_) {
      // Popup is a bonus feature - never break the home page because of it.
      return false;
    } finally {
      _busy = false;
    }
  }
}

class _MilestoneDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  const _MilestoneDialog({required this.data});
  @override
  State<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<_MilestoneDialog> {
  final _cardKey = GlobalKey();
  bool _working = false;

  String? _avatarUrl;
  String? _handle; // real YouTube @handle

  @override
  void initState() {
    super.initState();
    // Mark as seen the moment it is shown, so the same milestone never pops up twice.
    ApiService.instance.markMilestoneSeen('${widget.data['id']}').catchError((_) => <String, dynamic>{});
    _avatarUrl = _pickAvatar(widget.data);
    _handle = _pickHandle(widget.data);
    // Milestone data has no photo / handle -> take them from the connected YouTube channel.
    if (_avatarUrl == null || _handle == null) _loadFromChannel();
  }

  static const _handleKeys = ['channelHandle', 'handle', 'customUrl'];

  /// Real @handle if the API sent one (also one level deep, e.g. res['channel']).
  String? _pickHandle(Map? m) {
    if (m == null) return null;
    for (final k in _handleKeys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final nested = m['channel'];
    if (nested is Map) return _pickHandle(nested);
    return null;
  }

  static const _avatarKeys = [
    'channelThumbnail',
    'channelAvatar',
    'channelImage',
    'channelPhoto',
    'thumbnail',
    'thumbnailUrl',
    'avatar',
    'image',
    'picture',
    'profileImage',
  ];

  /// Looks for a photo URL in a map (also one level deep, e.g. res['channel']).
  /// If your API uses a different key name, add it to _avatarKeys.
  String? _pickAvatar(Map? m) {
    if (m == null) return null;
    for (final k in _avatarKeys) {
      final v = m[k];
      if (v is String && v.startsWith('http')) return v;
      // thumbnails sometimes come as {url: ...}
      if (v is Map && v['url'] is String && (v['url'] as String).startsWith('http')) {
        return v['url'] as String;
      }
    }
    final nested = m['channel'];
    if (nested is Map) return _pickAvatar(nested);
    return null;
  }

  Future<void> _loadFromChannel() async {
    try {
      final res = await ApiService.instance.getYoutubeChannel();
      final url = _avatarUrl == null ? _pickAvatar(res) : null;
      final h = _handle == null ? _pickHandle(res) : null;
      if (mounted && (url != null || h != null)) {
        setState(() {
          if (url != null) _avatarUrl = url;
          if (h != null) _handle = h;
        });
      }
    } catch (_) {
      // Optional; the card falls back to the logo badge / "YouTube Channel".
    }
  }

  /// The card on screen is scaled to fit the phone, so the capture pixel ratio is
  /// chosen to always give a sharp ~1080px wide image, whatever the screen size.
  Future<Uint8List> _capturePng() async {
    final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final w = boundary.size.width;
    final pixelRatio = w > 0 ? (1080 / w).clamp(1.0, 8.0) : 3.0;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _download() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final png = await _capturePng();
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(png, album: 'TubePilot', name: 'tubepilot_milestone_${widget.data['value']}');
      if (mounted) showToast(context, 'Saved to your gallery', isSuccess: true);
    } catch (e) {
      if (mounted) showToast(context, 'Could not save image', isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _share() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final png = await _capturePng();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tubepilot_milestone_${widget.data['value']}.png');
      await file.writeAsBytes(png);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Milestone unlocked with TubePilot \u{1F680}',
        ),
      );
    } catch (e) {
      if (mounted) showToast(context, 'Could not share image', isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  ButtonStyle get _btnStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: UiColors.plum,
        disabledBackgroundColor: Colors.white70,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    // FULL SCREEN, no Dialog padding: close button on top, card in the middle, buttons below.
    // The card is as big as the free space allows (never scrolls, never overlaps) and the
    // card itself is the white container - there is no empty white area under it.
    // HideAppNav: the app's bottom bar is hidden while this card is open (it used to stay visible).
    return HideAppNav(
      child: SizedBox.expand(
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    padding: const EdgeInsets.all(12),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      const sideMargin = 14.0;
                      final scale = math.min(
                        (box.maxWidth - sideMargin * 2) / MilestoneCard.cardW,
                        (box.maxHeight - 8) / MilestoneCard.cardH,
                      );
                      final cardW = MilestoneCard.cardW * scale;
                      final cardH = MilestoneCard.cardH * scale;
                      // Only this part is exported as the PNG (no buttons in the image).
                      return Center(
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: SizedBox(
                            width: cardW,
                            height: cardH,
                            child: MilestoneCard(
                              type: '${d['type']}',
                              value: (d['value'] as num).toInt(),
                              channelTitle: '${d['channelTitle'] ?? ''}',
                              channelHandle: _handle, // real handle, null -> card shows "YouTube Channel"
                              videoTitle: d['videoTitle'] as String?,
                              channelAvatarUrl: _avatarUrl,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _working ? null : _download,
                          icon: const Icon(Icons.download_rounded, size: 22),
                          label: const Text('Download'),
                          style: _btnStyle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _working ? null : _share,
                          icon: const Icon(Icons.share_rounded, size: 20),
                          label: const Text('Share'),
                          style: _btnStyle,
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
}
