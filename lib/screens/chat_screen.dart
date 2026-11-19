import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../widgets/app_decor.dart';
import '../widgets/subscription_offer.dart';
import 'live_stream_screen.dart';

// ---------------------------------------------------------------------------
// AI CHAT (left page of the dashboard: swipe RIGHT on the dashboard to open it,
// swipe LEFT in the chat to come back). The AI only UNDERSTANDS the user
// (backend /assistant/*); every number shown here comes from the real
// endpoints (/analytics/audit, /analytics/competitors, /videos/upload ...).
// ---------------------------------------------------------------------------

enum _Stage { idle, askHint, askThumb, askTime, confirm, busy }

class _Act {
  final String label;
  final VoidCallback onTap;
  const _Act(this.label, this.onTap);
}

class _Msg {
  final bool user;
  final String? text;
  final Widget? card;
  final List<_Act> actions;
  bool typing;
  _Msg({this.user = false, this.text, this.card, this.actions = const [], this.typing = false});
}

class _Vid {
  final String path;
  String hint = '';
  String title = '';
  String description = '';
  String tags = '';
  _Vid(this.path);
  String get name => path.split(Platform.pathSeparator).last;
  String get sizeText {
    try {
      final b = File(path).lengthSync();
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }
}

class ChatScreen extends StatefulWidget {
  /// called when the user wants to go back to the dashboard (swipe / button)
  final VoidCallback? onBack;
  const ChatScreen({super.key, this.onBack});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final List<_Msg> _msgs = [];

  _Stage _stage = _Stage.idle;
  final List<_Vid> _videos = [];
  int _hintIdx = 0;
  String? _thumbPath;
  String? _scheduleIso; // null = now / auto
  bool _autoSlot = false;
  bool _awaitingHandle = false;
  bool _auto = true; // upload without asking for approval (switch in the header)

  Future<void> _loadAuto() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (mounted) setState(() => _auto = p.getBool('chat_auto_mode_v1') ?? true);
    } catch (_) {}
  }

  Future<void> _setAuto(bool v) async {
    setState(() => _auto = v);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('chat_auto_mode_v1', v);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadAuto();
    _ai('Namaste! Main TubePilot AI hoon. 🎬\nVideo daalo (＋ dabao) aur main title, description, tags aur schedule sab set kar dunga. '
        'Channel SEO, competitor analysis aur live stream bhi bol ke karwa sakte ho.',
        actions: [
          _Act('Video daalo', _pickVideo),
          _Act('Channel SEO karo', () => _quick('mera channel SEO karke do')),
          _Act('Competitor analysis', () => _quick('competitor analysis karna hai')),
          _Act('Live stream', () => _quick('live stream karna hai')),
        ]);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ helpers
  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  _Msg _ai(String text, {List<_Act> actions = const [], Widget? card}) {
    final m = _Msg(text: text, actions: actions, card: card);
    if (!mounted) return m;
    setState(() => _msgs.add(m));
    _scrollEnd();
    return m;
  }

  void _addCard(Widget card) {
    if (!mounted) return;
    setState(() => _msgs.add(_Msg(card: card)));
    _scrollEnd();
  }

  _Msg _typing() {
    final m = _Msg(typing: true);
    if (mounted) setState(() => _msgs.add(m));
    _scrollEnd();
    return m;
  }

  void _removeMsg(_Msg m) {
    if (mounted) setState(() => _msgs.remove(m));
  }

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  String _fmt(num? n) {
    if (n == null) return '—';
    final v = n.toDouble();
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  void _quick(String text) {
    _ctrl.text = text;
    _send();
  }

  // ------------------------------------------------------------ attach video
  Future<void> _pickVideo() async {
    if (_stage == _Stage.busy) return;
    try {
      final v = await _picker.pickVideo(source: ImageSource.gallery);
      if (v == null) return;
      final fresh = _videos.isEmpty || _stage == _Stage.idle;
      if (_stage == _Stage.idle) {
        _videos.clear();
        _thumbPath = null;
        _scheduleIso = null;
        _autoSlot = false;
      }
      if (_videos.length >= 30) {
        _ai('Ek baar me max 30 videos.');
        return;
      }
      _videos.add(_Vid(v.path));
      final list = List<_Vid>.from(_videos);
      setState(() {
        // replace the previous "videos" bubble so it shows one growing list
        _msgs.removeWhere((m) => m.card is _VideosBubble);
        _msgs.add(_Msg(user: true, card: _VideosBubble(list)));
      });
      _scrollEnd();
      if (fresh && _stage == _Stage.idle) {
        _stage = _Stage.askHint;
        _hintIdx = 0;
        _askHint();
      } else if (_stage == _Stage.askHint) {
        // one more video added while answering hints: nothing else to do
      }
    } catch (e) {
      _ai('Video nahi chun paya: ${_err(e)}');
    }
  }

  void _askHint() {
    if (_videos.length == 1) {
      _ai('1 video mili. Ye video kis bare me hai? Thoda sa bata do (ya "auto" bolo, main video dekh ke khud likh dunga).',
          actions: [
            _Act('＋ Aur video', _pickVideo),
            _Act('Auto', () => _quick('auto')),
          ]);
    } else {
      final i = _hintIdx + 1;
      _ai('${_videos.length} videos mili. Video $i kis bare me hai? ("auto" = khud dekh lunga, "sab auto" = baaki sab auto)',
          actions: [
            _Act('＋ Aur video', _pickVideo),
            _Act('Auto', () => _quick('auto')),
            _Act('Sab auto', () => _quick('sab auto')),
          ]);
    }
  }

  // ------------------------------------------------------------ main send
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _stage == _Stage.busy) return;
    _ctrl.clear();
    setState(() => _msgs.add(_Msg(user: true, text: text)));
    _scrollEnd();

    // user was asked for a competitor link
    if (_awaitingHandle) {
      final ref = _parseChannelRef(text);
      if (ref != null) {
        _awaitingHandle = false;
        await _runCompetitor(ref);
        return;
      }
    }

    // while describing a video we do not need the AI to understand it: treat as hint
    final lower = text.toLowerCase();
    if (_stage == _Stage.askHint) {
      final isAuto = RegExp(r'^(auto|skip|tum dekh lo|khud dekh lo|pata nahi|nahi pata)\b').hasMatch(lower) ||
          lower.contains('sab auto');
      await _takeHint(isAuto ? '' : text, allRest: lower.contains('sab') && isAuto);
      return;
    }

    final typing = _typing();
    Map<String, dynamic> u;
    try {
      u = await ApiService.instance.rawPost('/assistant/understand', {
        'message': text,
        'stage': _stage == _Stage.askThumb
            ? 'ask_thumb'
            : _stage == _Stage.askTime
                ? 'ask_time'
                : _stage == _Stage.askHint
                    ? 'ask_hint'
                    : 'idle',
        'videoCount': _videos.length,
      });
    } catch (e) {
      _removeMsg(typing);
      _ai('Abhi AI se baat nahi ho pa rahi: ${_err(e)}');
      return;
    }
    _removeMsg(typing);

    final intent = (u['intent'] ?? 'chat').toString();
    final reply = (u['reply'] ?? '').toString();

    switch (intent) {
      case 'time':
        if (_stage == _Stage.askTime) {
          _setTime(iso: u['scheduleIso']?.toString(), now: u['now'] == true, auto: u['bulkAuto'] == true);
          return;
        }
        break;
      case 'thumbnail':
        if (_stage == _Stage.askThumb) {
          _thumbPath = null;
          _askTime();
          return;
        }
        break;
      case 'upload':
        if (_videos.isEmpty) {
          _ai(reply.isNotEmpty ? reply : 'Pehle video chuno 👇', actions: [_Act('Video daalo', _pickVideo)]);
        } else {
          _ai('Video already chat me hai. Upar ke sawal ka jawab do.');
        }
        return;
      case 'seo':
        await _runSeo();
        return;
      case 'competitor':
        final ref = _parseChannelRef((u['handle'] ?? '').toString()) ?? _parseChannelRef(text);
        if (ref == null) {
          _awaitingHandle = true;
          _ai(reply.isNotEmpty ? reply : 'Competitor ka @handle ya channel link bhejo.');
        } else {
          await _runCompetitor(ref);
        }
        return;
      case 'live':
        _ai(reply.isNotEmpty ? reply : 'Live stream ke liye Live screen kholta hoon.', actions: [
          _Act('Live screen kholo', () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveStreamScreen()));
          }),
        ]);
        return;
    }
    _ai(reply.isNotEmpty ? reply : 'Samajh nahi aaya. Video daalo, "channel SEO karo" ya "competitor analysis" bolo.');
  }

  // ------------------------------------------------------------ upload flow
  Future<void> _takeHint(String hint, {bool allRest = false}) async {
    if (_hintIdx >= _videos.length) return;
    if (allRest) {
      for (var i = _hintIdx; i < _videos.length; i++) {
        _videos[i].hint = '';
      }
      _hintIdx = _videos.length;
    } else {
      _videos[_hintIdx].hint = hint;
      _hintIdx++;
    }
    if (_hintIdx < _videos.length) {
      _ai('Video ${_hintIdx + 1} kis bare me hai?', actions: [
        _Act('Auto', () => _quick('auto')),
        _Act('Sab auto', () => _quick('sab auto')),
      ]);
      return;
    }
    await _generateMeta();
  }

  Future<void> _generateMeta() async {
    final typing = _typing();
    try {
      final idx = <int>[];
      final hints = <String>[];
      for (var i = 0; i < _videos.length; i++) {
        if (_videos[i].hint.trim().isNotEmpty) {
          idx.add(i);
          hints.add(_videos[i].hint.trim());
        }
      }
      if (hints.isNotEmpty) {
        final res = await ApiService.instance.rawPost('/assistant/meta', {'hints': hints});
        final items = (res['items'] as List?) ?? [];
        for (var k = 0; k < idx.length && k < items.length; k++) {
          final it = items[k] as Map;
          final v = _videos[idx[k]];
          v.title = (it['title'] ?? '').toString();
          v.description = (it['description'] ?? '').toString();
          final tags = it['tags'];
          v.tags = tags is List ? tags.join(',') : (tags ?? '').toString();
        }
      }
    } catch (e) {
      _removeMsg(typing);
      _ai('Title banane me dikkat aayi: ${_err(e)}\nDobara try karne ke liye video ka topic phir se likho.');
      return;
    }
    _removeMsg(typing);

    _addCard(_SetupCard(_videos.map((v) => v.title).toList()));
    if (_videos.length == 1) {
      _stage = _Stage.askThumb;
      _ai('Thumbnail kaunsa lagana hai? Gallery se chuno, ya skip karo (YouTube video se khud bana dega).', actions: [
        _Act('Thumbnail chuno', _pickThumb),
        _Act('Skip', () => _quick('skip')),
      ]);
    } else {
      _askTime();
    }
  }

  Future<void> _pickThumb() async {
    try {
      final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (img == null) return;
      _thumbPath = img.path;
      setState(() => _msgs.add(_Msg(user: true, text: '🖼️ Thumbnail chuna')));
      _askTime();
    } catch (e) {
      _ai('Thumbnail nahi chun paya: ${_err(e)}');
    }
  }

  void _askTime() {
    _stage = _Stage.askTime;
    _ai(
        _videos.length == 1
            ? 'Kitne baje schedule karun? Jaise "kal shaam 6 baje" likho, ya neeche se chuno.'
            : 'Kis time se schedule karun? Videos alag-alag din me khud baant dunga. Jaise "kal shaam 6 baje" likho, ya "Auto slot" dabao.',
        actions: [
          if (_videos.length == 1) _Act('Abhi upload', () => _quick('abhi')),
          _Act('Auto slot', () => _quick('auto slot best time')),
        ]);
  }

  void _setTime({String? iso, bool now = false, bool auto = false}) {
    _scheduleIso = iso;
    _autoSlot = auto || _videos.length > 1;
    if (iso == null && !now && !auto) {
      _ai('Time samajh nahi aaya, dobara likho.');
      return;
    }
    _stage = _Stage.confirm;
    String when;
    if (iso != null) {
      final d = DateTime.parse(iso).toLocal();
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      when = '${d.day}/${d.month}/${d.year} ${h}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
    } else {
      when = auto || _videos.length > 1 ? 'Auto slot (best time)' : 'Abhi';
    }
    if (_auto) {
      _ai('Auto mode ON: ${_videos.length} video • $when • YouTube. Upload shuru kar raha hoon...');
      _upload();
      return;
    }
    _ai('Ready! ${_videos.length} video • $when • YouTube.', actions: [
      _Act('✅ Upload karo', _upload),
      _Act('Cancel', _cancelFlow),
    ]);
  }

  void _cancelFlow() {
    setState(() {
      _videos.clear();
      _stage = _Stage.idle;
      _thumbPath = null;
      _scheduleIso = null;
    });
    _ai('Theek hai, cancel kar diya.');
  }

  Future<void> _upload() async {
    if (_stage != _Stage.confirm || _videos.isEmpty) return;
    setState(() => _stage = _Stage.busy);
    final typing = _typing();
    try {
      // free uploads (3) / diamonds: the server enforces it, we check first for a clear message
      try {
        final dash = await ApiService.instance.dashboard();
        final free = (dash['data']?['remainingFreeUploads'] ?? 0) as num;
        final dia = (dash['data']?['diamondBalance'] ?? 0) as num;
        final cap = free.toInt() + (dia.toInt() ~/ 10);
        if (cap <= 0) {
          _removeMsg(typing);
          await _upgrade();
          return;
        }
        if (_videos.length > cap) {
          final cut = _videos.length - cap;
          _videos.removeRange(cap, _videos.length);
          _ai('Aapke paas sirf $cap upload bache hain, isliye pehli $cap video upload kar raha hoon. Baaki $cut ke liye upgrade karna hoga.');
        }
      } catch (_) {/* server check below still applies */}

      if (_videos.length == 1) {
        final v = _videos.first;
        final res = await ApiService.instance.uploadVideo(
          videoPath: v.path,
          thumbnailPath: _thumbPath,
          platforms: ['youtube'],
          postType: null,
          youtube: {
            'title': v.title,
            'description': v.description,
            'tags': v.tags,
            'category': '22',
            'playlist': '',
            'audience': 'not_for_kids',
            'privacyStatus': 'public',
            if (_scheduleIso != null) 'scheduledAt': _scheduleIso,
          },
          facebook: null,
          instagram: null,
          autoSlot: _autoSlot,
        );
        _removeMsg(typing);
        final at = DateTime.tryParse((res['autoSlotAt'] ?? '').toString())?.toLocal();
        _ai(at != null
            ? '✅ Video schedule ho gayi: ${at.day}/${at.month} ${at.hour}:${at.minute.toString().padLeft(2, '0')}'
            : '✅ Video queue me lag gayi.');
      } else {
        String? preferred;
        if (_scheduleIso != null) {
          final d = DateTime.parse(_scheduleIso!).toLocal();
          preferred = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
        }
        final res = await ApiService.instance.bulkUploadVideos(
          videoPaths: _videos.map((v) => v.path).toList(),
          platforms: ['youtube'],
          postType: null,
          items: _videos
              .map((v) => {
                    'title': v.title,
                    'description': v.description,
                    'tags': v.tags,
                    'category': '22',
                    'playlist': '',
                    'audience': 'not_for_kids',
                    'privacyStatus': 'public',
                  })
              .toList(),
          preferredTime: preferred,
          autoSlot: true,
        );
        _removeMsg(typing);
        final results = (res['results'] as List?) ?? [];
        final ok = results.where((r) => r is Map && r['success'] == true).length;
        _ai(ok == _videos.length
            ? '✅ $ok videos schedule ho gayi.'
            : '$ok/${_videos.length} videos schedule hui. Baaki fail hui, Upcoming me check karo.');
      }
      _videos.clear();
      _thumbPath = null;
      _scheduleIso = null;
      setState(() => _stage = _Stage.idle);
      if (mounted) await showSubscriptionOfferIfNeeded(context);
    } catch (e) {
      _removeMsg(typing);
      if (e is ApiException && (e.code == 'INSUFFICIENT_DIAMONDS' || e.code == 'PAYMENT_REQUIRED')) {
        await _upgrade();
        return;
      }
      setState(() => _stage = _Stage.confirm);
      _ai('Upload nahi hua: ${_err(e)}', actions: [_Act('Dobara try', _upload), _Act('Cancel', _cancelFlow)]);
    }
  }

  /// Free uploads are over -> keep the videos, ask to upgrade.
  Future<void> _upgrade() async {
    if (mounted) setState(() => _stage = _Stage.confirm);
    _ai('Aapke 3 free uploads khatam ho gaye. 🎬 Upgrade karke (₹10 me 30 uploads + 99 diamonds) chat se upload jaari rakho.',
        actions: [
          _Act('Upgrade karo', () async {
            await showSubscriptionOfferIfNeeded(context, force: true);
            if (mounted) _ai('Payment ke baad "Dobara try" dabao.', actions: [_Act('Dobara try', _upload), _Act('Cancel', _cancelFlow)]);
          }),
          _Act('Cancel', _cancelFlow),
        ]);
  }

  // ------------------------------------------------------------ channel SEO
  Future<void> _runSeo() async {
    final typing = _typing();
    try {
      final res = await ApiService.instance.rawGet('/analytics/audit');
      _removeMsg(typing);
      final a = Map<String, dynamic>.from((res['audit'] as Map?) ?? {});
      final recs = ((a['recommendations'] as List?) ?? []).map((r) => (r as Map)['message'].toString()).toList();
      final report = res['report'];
      String? score;
      if (report is Map) {
        for (final k in ['healthScore', 'score', 'health']) {
          final v = report[k];
          if (v is num) {
            score = v.round().toString();
            break;
          }
        }
      }
      _addCard(_InfoCard(
        title: 'Channel SEO report',
        rows: [
          if (score != null) ['Health score', '$score/100'],
          ['Subscribers', _fmt(a['subscriberCount'] as num?)],
          ['Total views', _fmt(a['totalViews'] as num?)],
          ['Total videos', _fmt(a['totalVideos'] as num?)],
          ['Engagement', a['engagementPct'] == null ? '—' : '${a['engagementPct']}%'],
          ['Last 7 din uploads', '${a['recentUploadsLast7Days'] ?? 0}'],
        ],
        bullets: recs,
        bulletsTitle: 'Kya sudharna hai',
      ));
      _ai('Ye aapke channel ka real data hai. Chaho to kisi sudhaar par kaam shuru karein?');
    } catch (e) {
      _removeMsg(typing);
      _ai('SEO report nahi bani: ${_err(e)}');
    }
  }

  // ------------------------------------------------------------ competitor
  Map<String, String>? _parseChannelRef(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final id = RegExp(r'UC[\w-]{22}').firstMatch(t);
    if (id != null) return {'channelId': id.group(0)!};
    final h = RegExp(r'@([\w.\-]{2,})').firstMatch(t);
    if (h != null) return {'handle': '@${h.group(1)}'};
    return null;
  }

  Future<void> _runCompetitor(Map<String, String> ref) async {
    final typing = _typing();
    try {
      Map<String, dynamic>? comp;
      try {
        final r = await ApiService.instance.rawPost('/analytics/competitors', Map<String, dynamic>.from(ref));
        comp = Map<String, dynamic>.from(r['competitor'] as Map);
      } catch (e) {
        if (_err(e).toLowerCase().contains('already')) {
          final list = await ApiService.instance.rawGet('/analytics/competitors');
          for (final c in (list['competitors'] as List? ?? [])) {
            final m = Map<String, dynamic>.from(c as Map);
            final rid = (m['lastStats']?['resolvedChannelId'] ?? '').toString();
            if ((ref['channelId'] != null && (m['channelId'] == ref['channelId'] || rid == ref['channelId'])) ||
                (ref['handle'] != null && m['handle'] == ref['handle'])) {
              comp = m;
              break;
            }
          }
        }
        if (comp == null) rethrow;
      }

      final id = (comp['_id'] ?? '').toString();
      Map<String, dynamic> d = {};
      try {
        d = await ApiService.instance.rawGet('/analytics/competitors/$id');
      } catch (_) {}
      _removeMsg(typing);

      final ch = Map<String, dynamic>.from((d['channel'] as Map?) ?? (comp['lastStats'] as Map?) ?? {});
      final stats = Map<String, dynamic>.from((comp['lastStats'] as Map?) ?? {});
      final err = (ch['error'] ?? stats['error'])?.toString();
      if (err != null && err.isNotEmpty && stats['subscriberCount'] == null && ch['subscriberCount'] == null) {
        _ai('Is channel ka data abhi nahi mila: $err');
        return;
      }
      final subs = (ch['subscriberCount'] ?? stats['subscriberCount']) as num?;
      final views = (ch['viewCount'] ?? stats['viewCount']) as num?;
      final vids = (ch['videoCount'] ?? stats['videoCount']) as num?;
      final top = ((d['mostViewed'] as List?) ?? []).take(3).map((v) {
        final m = v as Map;
        return '${m['title']}  •  ${_fmt(m['views'] as num?)} views';
      }).toList();
      final recent = ((d['recent'] as List?) ?? []).take(3).map((v) => (v as Map)['title'].toString()).toList();

      _addCard(_InfoCard(
        title: (comp['label'] ?? comp['handle'] ?? 'Competitor').toString(),
        thumb: (ch['thumbnail'] ?? stats['thumbnail'] ?? '').toString(),
        rows: [
          ['Subscribers', _fmt(subs)],
          ['Total views', _fmt(views)],
          ['Videos', _fmt(vids)],
        ],
        bulletsTitle: top.isEmpty ? null : 'Sabse zyada views (last 30 din)',
        bullets: top,
        bullets2Title: recent.isEmpty ? null : 'Haal ke videos',
        bullets2: recent,
      ));
      if (top.isEmpty && recent.isEmpty) {
        _ai('Is channel ke videos ka data abhi load ho raha hai. Thodi der baad dobara pucho.');
      } else {
        _ai('Ye channel ab aapke competitors me add hai. Aur kuch analyse karna hai?');
      }
    } catch (e) {
      _removeMsg(typing);
      _ai(_err(e));
    }
  }

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: UiColors.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: UiColors.purple, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('TubePilot AI',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UiColors.purple)),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Auto upload', style: TextStyle(fontSize: 10.5, color: UiColors.textDim, fontWeight: FontWeight.w700)),
                      SizedBox(
                        height: 26,
                        child: Transform.scale(
                          scale: 0.8,
                          child: Switch(value: _auto, activeColor: UiColors.purple, onChanged: _setAuto),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.dashboard_outlined, size: 18, color: UiColors.purple),
                    label: const Text('Dashboard', style: TextStyle(color: UiColors.purple, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                itemCount: _msgs.length,
                itemBuilder: (_, i) => _bubble(_msgs[i], isLast: i == _msgs.length - 1),
              ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Msg m, {required bool isLast}) {
    if (m.typing) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: SizedBox(width: 38, height: 18, child: LinearProgressIndicator(color: UiColors.purple, backgroundColor: UiColors.iconCircle)),
        ),
      );
    }
    final isUser = m.user;
    final bubbleCard = m.card != null;
    final content = m.card ??
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFFEFE6F3) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isUser ? null : Border.all(color: UiColors.cardBorder),
          ),
          child: Text(m.text ?? '', style: const TextStyle(fontSize: 14.5, height: 1.35, color: UiColors.inkBlack)),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (bubbleCard && !isUser) content else Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: isUser
                ? [Flexible(child: content), const SizedBox(width: 8), _userAvatar()]
                : [_aiAvatar(), const SizedBox(width: 8), Flexible(child: content)],
          ),
          if (isLast && m.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: m.actions
                    .map((a) => ActionChip(
                          label: Text(a.label, style: const TextStyle(color: UiColors.purple, fontWeight: FontWeight.w700)),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: UiColors.purple),
                          onPressed: _stage == _Stage.busy ? null : a.onTap,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _aiAvatar() => Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(color: UiColors.purple, shape: BoxShape.circle),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
      );

  // The user's real profile photo (from the account); first letter of the name when there is none.
  Widget _userAvatar() {
    final user = context.read<AuthProvider>().user ?? {};
    final avatar = (user['avatar'] ?? user['photo'] ?? user['picture'] ?? '').toString();
    final name = (user['username'] ?? user['name'] ?? '').toString().trim();
    final letter = name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase();
    final isUrl = avatar.startsWith('http');
    return CircleAvatar(
      radius: 14,
      backgroundColor: UiColors.purple,
      backgroundImage: isUrl ? NetworkImage(avatar) : null,
      child: isUrl ? null : Text(letter, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  Widget _inputBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: UiColors.cardBorder),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _stage == _Stage.busy ? null : _pickVideo,
            icon: const Icon(Icons.add, color: UiColors.purple),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'Yahan likho...', border: InputBorder.none),
            ),
          ),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: UiColors.purple, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- cards
class _VideosBubble extends StatelessWidget {
  final List<_Vid> videos;
  const _VideosBubble(this.videos);
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFEFE6F3), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${videos.length} video${videos.length > 1 ? 's' : ''} daale gaye',
              style: const TextStyle(fontSize: 12, color: UiColors.textDim)),
          const SizedBox(height: 8),
          ...videos.map((v) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: UiColors.iconCircle, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.play_arrow, color: UiColors.purple),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(v.sizeText, style: const TextStyle(fontSize: 11, color: UiColors.textDim)),
                    ]),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  final List<String> titles;
  const _SetupCard(this.titles);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: UiColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF2E9E6B)),
          const SizedBox(width: 8),
          Text('Setup ready • ${titles.length} video${titles.length > 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < titles.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: UiColors.cardBorder), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VIDEO ${(i + 1).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: UiColors.purple)),
              const SizedBox(height: 3),
              Text(titles[i].isEmpty ? 'Title video dekh kar khud banega' : titles[i],
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(titles[i].isEmpty ? 'Upload ke baad AI video se likhega' : 'Description + Tags + Hashtags ready',
                  style: const TextStyle(fontSize: 11.5, color: UiColors.textDim)),
            ]),
          ),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String? thumb;
  final List<List<String>> rows;
  final String? bulletsTitle;
  final List<String> bullets;
  final String? bullets2Title;
  final List<String> bullets2;
  const _InfoCard({
    required this.title,
    this.thumb,
    this.rows = const [],
    this.bulletsTitle,
    this.bullets = const [],
    this.bullets2Title,
    this.bullets2 = const [],
  });

  Widget _list(String? t, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (t != null) Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: UiColors.purple)),
        const SizedBox(height: 4),
        for (final b in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•  '),
              Expanded(child: Text(b, style: const TextStyle(fontSize: 13, height: 1.3))),
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: UiColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (thumb != null && thumb!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: CircleAvatar(radius: 20, backgroundImage: NetworkImage(thumb!)),
            ),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        ]),
        const SizedBox(height: 10),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(child: Text(r[0], style: const TextStyle(color: UiColors.textDim, fontSize: 13))),
              Text(r[1], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ),
        _list(bulletsTitle, bullets),
        _list(bullets2Title, bullets2),
      ]),
    );
  }
}
