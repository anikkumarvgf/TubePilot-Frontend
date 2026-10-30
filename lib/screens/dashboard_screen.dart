import 'dart:math' show max;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../providers/language_provider.dart';
import '../widgets/common.dart';
import '../widgets/brand_icons.dart';
// Festival background + clean white cards (shared decor)
import '../widgets/diwali_decor.dart';
// Diwali welcome popup + shared popup shell
import '../widgets/diwali_popups.dart';
// Milestone achievement popup (subscribers / views card)
import '../widgets/milestone_popup.dart';
import 'upload_screen.dart';
import 'upcoming_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';
// Premium tile opens the Buy Diamonds screen
import 'diamond_store_screen.dart';
import 'notifications_screen.dart';
import 'rate_us_screen.dart';
import 'ai_ideas_screen.dart';
import 'ai_title_description_screen.dart';
import 'channel_audit_screen.dart';
// Quick Actions has a "Live Stream" button.
import 'live_stream_screen.dart';

const String kIdeasPopupLastShownKey = 'ideas_popup_last_shown_ms';

/// Horizontal padding for the whole screen.
const double _kScreenPadding = 16;

/// Gap between card rows.
const double _kRowGap = 14;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _DashboardHome(),
      const UploadScreen(embedded: true),
      const UpcomingScreen(embedded: true),
      const AnalyticsScreen(embedded: true),
      const ProfileScreen(embedded: true),
    ];

    // ⚠️ FIX (bottom overlap): the background now lives here, behind the
    // Scaffold, and extendBody is FALSE. The body therefore ends exactly where
    // the floating bottom bar begins, so content can never slide underneath it.
    return DiwaliBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: false,
        body: IndexedStack(index: _tabIndex, children: screens),
        bottomNavigationBar: AppBottomNav(currentIndex: _tabIndex, onTap: (i) => setState(() => _tabIndex = i)),
      ),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  const _DashboardHome();
  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

// WidgetsBindingObserver added so we notice when the user returns from the
// YouTube connect screen (browser) and can show the first milestone card /
// idea popup for the freshly connected channel.
class _DashboardHomeState extends State<_DashboardHome> with WidgetsBindingObserver {
  Map<String, dynamic>? data;
  List<dynamic> notifications = [];
  int unreadCount = 0;

  Map<String, dynamic>? youtubeChannel;
  Map<String, dynamic>? facebookStatus;

  List<Map<String, dynamic>> upcomingEvents = [];
  List<Map<String, dynamic>> recentVideos = [];

  bool loading = true;
  bool _resumeBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load().then((_) async {
      if (!mounted) return;

      // Diwali welcome popup — only the first time. If shown, skip the rest this time.
      final shownWelcome = await maybeShowDiwaliWelcome(context);
      if (!mounted || shownWelcome) return;

      // Milestone popup has priority. If a milestone card was shown, skip
      // Rate Us and the AI Idea popup this time — no dialog on top of another.
      final shownMilestone = await MilestonePopup.checkAndShow(context);
      if (!mounted || shownMilestone) return;

      // Wait for Rate Us to close first, so the Idea popup never opens on top of it.
      await maybeShowRateUsPopup(context);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) await _maybeShowIdeaPopup();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }

  // Back from the YouTube connect screen: reload, and if the channel was JUST
  // connected, wait for the backend to create the first milestone and show it.
  Future<void> _onResume() async {
    if (_resumeBusy) return;
    _resumeBusy = true;
    try {
      final wasConnected = youtubeChannel != null;
      await _load(showLoader: false);
      if (!mounted) return;
      if (!wasConnected && youtubeChannel != null) {
        var shown = false;
        for (final waitSec in const [3, 4, 5]) {
          await Future.delayed(Duration(seconds: waitSec));
          if (!mounted) return;
          shown = await MilestonePopup.checkAndShow(context);
          if (shown) break;
        }
        // No milestone card -> now (and only now) suggest ideas for this channel.
        if (!shown && mounted) await _maybeShowIdeaPopup();
      }
    } finally {
      _resumeBusy = false;
    }
  }

  Future<void> _maybeShowIdeaPopup() async {
    // No channel connected -> no ideas. (Also do NOT start the 24h timer.)
    if (youtubeChannel == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt(kIdeasPopupLastShownKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastShown != null && now - lastShown < const Duration(hours: 24).inMilliseconds) {
      return;
    }
    if (!mounted) return;

    // Niche comes from the connected channel (its category, else its name).
    final category = (youtubeChannel?['category'] ?? '').toString().trim();
    final title = (youtubeChannel?['channelTitle'] ?? '').toString().trim();
    final niche = category.isNotEmpty ? category : title;

    await showIdeaPopup(context, channelNiche: niche.isNotEmpty ? niche : null);
    await prefs.setInt(kIdeasPopupLastShownKey, now);
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) setState(() => loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.dashboard(),
        ApiService.instance.getNotifications(),
        ApiService.instance.getYoutubeChannel().catchError((_) => <String, dynamic>{}),
        ApiService.instance.getMetaStatus().catchError((_) => <String, dynamic>{}),
        ApiService.instance.listVideos(status: 'queued').catchError((_) => <String, dynamic>{}),
        ApiService.instance.listVideos(status: 'uploaded').catchError((_) => <String, dynamic>{}),
      ]);

      final dash = results[0]['data'];
      final notifRes = results[1];
      final ytRes = results[2];
      final metaRes = results[3];
      final queuedRes = results[4];
      final uploadedRes = results[5];

      final events = _extractPlatformEvents(queuedRes, const {'pending', 'queued'});
      events.sort((a, b) {
        final aTime = a['scheduledAt'] as String?;
        final bTime = b['scheduledAt'] as String?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        return aTime.compareTo(bTime);
      });

      final recent = _extractPlatformEvents(uploadedRes, const {'uploaded'});
      recent.sort((a, b) {
        final aTime = (a['publishedAt'] ?? a['scheduledAt']) as String?;
        final bTime = (b['publishedAt'] ?? b['scheduledAt']) as String?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() {
        data = dash;
        notifications = (notifRes['notifications'] as List?) ?? [];
        unreadCount = notifRes['unreadCount'] ?? 0;
        youtubeChannel = ytRes['success'] == true ? ytRes['channel'] : null;
        facebookStatus = metaRes['facebook'];
        upcomingEvents = events.take(5).toList();
        recentVideos = recent.take(4).toList();
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (showLoader && mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _extractPlatformEvents(Map<String, dynamic> res, Set<String> statuses) {
    final out = <Map<String, dynamic>>[];
    final videos = (res['videos'] as List?) ?? [];
    for (final v in videos) {
      final platforms = (v['platforms'] as List?) ?? [];
      for (final p in platforms) {
        if (!statuses.contains(p['status'])) continue;
        out.add({
          'videoId': v['_id'],
          'platform': p['platform'],
          'title': p['platform'] == 'youtube'
              ? (p['title'] ?? 'Untitled')
              : ((p['caption'] ?? '').toString().isNotEmpty ? p['caption'] : 'Untitled'),
          'scheduledAt': p['scheduledAt'],
          'publishedAt': p['publishedAt'],
          'thumbnailUrl': p['thumbnailUrl'] ?? '',
          'status': p['status'],
        });
      }
    }
    return out;
  }

  void _goToProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _load(showLoader: false));
  }

  void _openPreview(Map<String, dynamic> event) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpcomingScreen())).then((_) => _load(showLoader: false));
  }

  String? _userEmail(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? {};
    final email = user['email'];
    return (email is String && email.isNotEmpty) ? email : null;
  }

  String _userInitial(BuildContext context) {
    final email = _userEmail(context);
    return (email != null) ? email.trim()[0].toUpperCase() : '?';
  }

  String _userFirstName(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? {};
    final name = user['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim().split(' ').first;
    final email = _userEmail(context);
    if (email != null && email.contains('@')) return email.split('@').first;
    return context.tr('there_fallback');
  }

  int get _diamondCostPerUpload {
    final cost = data?['diamondCostPerUpload'] ?? data?['uploadCostDiamonds'];
    if (cost is num && cost > 0) return cost.toInt();
    return 10;
  }

  // "remaining / total" card. Remaining comes from the backend. Total: backend
  // total key, else remaining+used, else 20 (default free uploads).
  ({int remaining, int total}) _freeUploads() {
    int? n(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    final remaining = n(data?['remainingFreeUploads']) ?? 0;
    final explicit = n(data?['totalFreeUploads'] ?? data?['freeUploadsLimit'] ?? data?['monthlyFreeUploads']);
    final used = n(data?['usedFreeUploads'] ?? data?['freeUploadsUsed']);
    final total = (explicit != null && explicit > 0) ? explicit : (used != null ? remaining + used : 20);
    return (remaining: remaining, total: max(total, remaining));
  }

  ({String label, Color color}) _platformMeta(BuildContext context, String? platform) {
    switch (platform) {
      case 'youtube':
        return (label: context.tr('platform_youtube_label'), color: AppColors.red);
      case 'facebook':
        return (label: context.tr('platform_facebook_label'), color: AppColors.diamond);
      default:
        return (label: platform ?? '', color: AppColors.purple);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diamondBalance = (data?['diamondBalance'] ?? 0) as num;
    final worthUploads = diamondBalance ~/ _diamondCostPerUpload;
    final free = _freeUploads();

    // The festival background is provided by DashboardScreen, so this
    // Scaffold is simply transparent.
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight: 66,
        // Side spacing keeps title / buttons clear of the hanging diyas in the artwork.
        titleSpacing: 36,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/splash.png', width: 40, height: 40),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 23, height: 1.05, letterSpacing: -0.5),
                      children: [
                        TextSpan(text: 'Tube', style: TextStyle(color: DiwaliColors.purpleDark)),
                        TextSpan(text: 'Pilot', style: TextStyle(color: DiwaliColors.purple)),
                      ],
                    ),
                  ),
                  const Text(
                    'Your YouTube Growth Partner',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: DiwaliColors.purpleDark, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: DiwaliColors.purpleDark, size: 26),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _load(showLoader: false)),
              ),
              if (unreadCount > 0)
                Positioned(right: 10, top: 10, child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 38, left: 2),
            child: Tooltip(
              message: context.tr('profile_tooltip'),
              child: GestureDetector(
                onTap: _goToProfile,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [DiwaliColors.purple, DiwaliColors.purpleDark],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: DiwaliColors.goldLight, width: 1.5),
                  ),
                  child: Text(
                    _userInitial(context),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: () => _load(showLoader: false),
              child: ListView(
                // Bottom padding is small now: the body already ends above the
                // floating nav bar (extendBody: false), so nothing is hidden.
                padding: const EdgeInsets.fromLTRB(_kScreenPadding, 8, _kScreenPadding, 24),
                children: [
                  // ---- Greeting (large + bold) and subtext (small + grey) ----
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${context.tr('hello_greeting')} ${_userFirstName(context)}! 👋',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: DiwaliColors.purpleDark,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('welcome_back_subtitle'),
                    style: const TextStyle(color: DiwaliColors.textDim, fontSize: 13.5, height: 1.25),
                  ),
                  const SizedBox(height: 18),

                  // ---- Stat cards (2 x 2). Rows size themselves to their content,
                  // so there is no fixed aspect ratio that can overflow. ----
                  _cardRow([
                    _MetricCard(
                      icon: Icons.cloud_upload_rounded,
                      label: context.tr('stat_free_uploads_left'),
                      value: '${data?['remainingFreeUploads'] ?? 0}',
                      subtitle: context.tr('resets_30_days'),
                    ),
                    _MetricCard(
                      icon: Icons.diamond_outlined,
                      label: context.tr('stat_diamond_balance'),
                      value: '$diamondBalance',
                      subtitle: worthUploads > 0 ? context.tr('diamonds_worth_uploads').replaceAll('%d', '$worthUploads') : null,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())).then((_) => _load(showLoader: false)),
                    ),
                  ]),
                  const SizedBox(height: _kRowGap),
                  _cardRow([
                    _MetricCard(
                      icon: Icons.play_circle_fill_rounded,
                      label: context.tr('stat_videos_published'),
                      value: '${data?['totalUploadedVideos'] ?? 0}',
                      subtitle: context.tr('total_videos'),
                    ),
                    _MetricCard(
                      icon: Icons.event_available_rounded,
                      label: context.tr('scheduled_videos'),
                      value: '${upcomingEvents.length}',
                      subtitle: context.tr('this_month'),
                    ),
                  ]),
                  const SizedBox(height: _kRowGap),

                  // ---- AI Ideas + Free uploads strip ----
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: DiwaliCard(
                            padding: const EdgeInsets.all(12),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiIdeasScreen())),
                            child: Row(
                              children: [
                                const _IconCircle(icon: Icons.bolt_rounded, size: 42, iconSize: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('qa_ai_ideas'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 16, fontWeight: FontWeight.w800),
                                      ),
                                      const Text(
                                        'Get video ideas tailored to your niche',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: DiwaliColors.textDim, fontSize: 10.5, height: 1.2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: DiwaliColors.purpleDeep),
                                  child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 8,
                          child: DiwaliCard(
                            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadScreen())).then((_) => _load(showLoader: false)),
                            child: Row(
                              children: [
                                const _IconCircle(icon: Icons.diamond_rounded, size: 34, iconSize: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('stat_free_uploads_left'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 10.5, height: 1.15, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${free.remaining} / ${free.total}',
                                          style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 18, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: free.total > 0 ? (free.remaining / free.total).clamp(0.0, 1.0) : 0,
                                          minHeight: 4,
                                          backgroundColor: DiwaliColors.iconCircle,
                                          valueColor: const AlwaysStoppedAnimation(DiwaliColors.gold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: DiwaliColors.purpleDark, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Quick Actions ----
                  Text(
                    context.tr('quick_actions'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: DiwaliColors.purpleDark, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _quickAction(
                            icon: Icons.cloud_upload_outlined,
                            label: context.tr('qa_upload_video'),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadScreen())).then((_) => _load(showLoader: false)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // "Live Stream" (Analytics opens from the bottom bar tab).
                        Expanded(
                          child: _quickAction(
                            icon: Icons.podcasts_rounded,
                            label: context.tr('qa_live_stream'),
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const LiveStreamScreen()))
                                .then((_) => _load(showLoader: false)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _quickAction(
                            icon: Icons.auto_awesome_rounded,
                            label: context.tr('qa_ai_ideas'),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiIdeasScreen())),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _quickAction(
                            icon: Icons.edit_note_rounded,
                            label: context.tr('qa_description_ideas'),
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const AiTitleDescriptionScreen(startInDescriptionMode: true))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Premium tile -> Buy Diamonds screen.
                        Expanded(
                          child: _quickAction(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Premium',
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const DiamondStoreScreen()))
                                .then((_) => _load(showLoader: false)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _kRowGap),

                  // ---- Channel Audit + Competitor Radar ----
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _featureCard(
                            icon: Icons.workspace_premium_rounded,
                            title: context.tr('qa_channel_audit'),
                            subtitle: 'Get detailed insights & improve your channel',
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChannelAuditScreen())),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Competitor Radar — route not known yet, so "coming soon" toast.
                        // Put your screen's route here when it exists.
                        Expanded(
                          child: _featureCard(
                            icon: Icons.emoji_events_rounded,
                            title: 'Competitor Radar',
                            subtitle: 'See what your competitors do',
                            onTap: () => showToast(context, 'Competitor Radar coming soon', isSuccess: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _kRowGap),

                  // ---- Upcoming Schedule ----
                  DiwaliCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _IconCircle(icon: Icons.calendar_month_rounded, size: 34, iconSize: 19),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr('upcoming_schedule'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DiwaliColors.purpleDark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpcomingScreen())),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(context.tr('see_all'), style: const TextStyle(color: DiwaliColors.purple, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.arrow_forward_rounded, color: DiwaliColors.purple, size: 15),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (upcomingEvents.isEmpty)
                          _emptyStrip(
                            icon: Icons.event_note_rounded,
                            text: context.tr('no_upcoming_publishes'),
                          )
                        else
                          ...upcomingEvents.map((e) => _mediaRow(
                                context,
                                thumbnailUrl: e['thumbnailUrl'],
                                title: e['title'] ?? '',
                                platform: e['platform'],
                                badgeLabel: e['status'] == 'pending' ? context.tr('status_scheduled') : context.tr('status_queued'),
                                dateLabel: e['scheduledAt'] != null ? formatDateTime(e['scheduledAt']) : context.tr('publishing_now'),
                                onTap: () => _openPreview(e),
                              )),
                      ],
                    ),
                  ),
                  const SizedBox(height: _kRowGap),

                  // ---- Recent Activity ----
                  DiwaliCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _IconCircle(icon: Icons.bolt_rounded, size: 34, iconSize: 19),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr('recent_activity_home'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DiwaliColors.purpleDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (recentVideos.isEmpty)
                          _emptyStrip(
                            icon: Icons.history_rounded,
                            text: context.tr('no_recent_activity'),
                          )
                        else
                          ...recentVideos.map((e) => _mediaRow(
                                context,
                                thumbnailUrl: e['thumbnailUrl'],
                                title: e['title'] ?? '',
                                platform: e['platform'],
                                badgeLabel: context.tr('status_published'),
                                dateLabel: formatDate(e['publishedAt'] ?? e['scheduledAt']),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Two equal-width cards in a row, both as tall as the taller one.
  Widget _cardRow(List<Widget> children) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(const SizedBox(width: 12));
      items.add(Expanded(child: children[i]));
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }

  Widget _quickAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return DiwaliCard(
      // Five tiles share one row, so side padding is kept small here.
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconCircle(icon: icon, size: 42, iconSize: 23),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: DiwaliColors.purpleDark, height: 1.15),
          ),
        ],
      ),
    );
  }

  Widget _featureCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return DiwaliCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          _IconCircle(icon: icon, size: 40, iconSize: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DiwaliColors.textDim, fontSize: 10, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyStrip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DiwaliColors.creamTop,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DiwaliColors.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _IconCircle(icon: icon, size: 36, iconSize: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaRow(
    BuildContext context, {
    required String? thumbnailUrl,
    required String title,
    required String? platform,
    required String badgeLabel,
    required String dateLabel,
    VoidCallback? onTap,
  }) {
    final meta = _platformMeta(context, platform);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: DiwaliColors.creamTop,
          border: Border.all(color: DiwaliColors.cardBorder.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                  ? Image.network(
                      thumbnailUrl,
                      width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbnailFallback(meta.color),
                    )
                  : _thumbnailFallback(meta.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: DiwaliColors.purpleDark)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _platformBadgeIcon(platform),
                      const SizedBox(width: 5),
                      Text(meta.label, style: const TextStyle(color: DiwaliColors.textDim, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(dateLabel, style: const TextStyle(color: DiwaliColors.textDim, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppBadge(label: badgeLabel, color: meta.color),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailFallback(Color color) {
    return Container(
      width: 56, height: 56,
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.14),
      child: Icon(Icons.movie_outlined, color: color, size: 22),
    );
  }

  Widget _platformBadgeIcon(String? platform) {
    switch (platform) {
      case 'youtube':
        return const YoutubeIcon(size: 13);
      case 'facebook':
        return const FacebookIcon(size: 13);
      default:
        return const Icon(Icons.movie_outlined, size: 13);
    }
  }
}

// Every icon in the dashboard: rounded icon inside a light beige circle.
class _IconCircle extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  const _IconCircle({required this.icon, required this.size, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: DiwaliColors.iconCircle),
      child: Icon(icon, color: DiwaliColors.purpleDeep, size: iconSize),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;
  const _MetricCard({required this.icon, required this.label, required this.value, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return DiwaliCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconCircle(icon: icon, size: 36, iconSize: 19),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 12.5, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: DiwaliColors.purpleDark, height: 1.2)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(color: DiwaliColors.textDim, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// =============================================================================
// AI Idea popup
// =============================================================================

Future<void> showIdeaPopup(BuildContext context, {String? channelNiche}) async {
  // No niche = no connected channel -> never show generic 'Tech' ideas,
  // no matter which screen calls this.
  if (channelNiche == null || channelNiche.trim().isEmpty) return;

  List<Map<String, dynamic>> ideas = [];
  try {
    final res = await ApiService.instance.aiIdeas(
      niche: channelNiche,
      platform: 'youtube',
      count: 3,
    );
    ideas = (res['ideas'] as List? ?? []).cast<Map<String, dynamic>>();
  } catch (_) {
    // Silent failure — soft nudge popup, not a core flow.
  }
  if (ideas.isEmpty || !context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _IdeaPopupDialog(ideas: ideas.take(3).toList()),
  );
}

class _FlyingEmoji {
  final Key id;
  final String emoji;
  _FlyingEmoji(this.id, this.emoji);
}

class _IdeaPopupDialog extends StatefulWidget {
  final List<Map<String, dynamic>> ideas;
  const _IdeaPopupDialog({required this.ideas});
  @override
  State<_IdeaPopupDialog> createState() => _IdeaPopupDialogState();
}

class _IdeaPopupDialogState extends State<_IdeaPopupDialog> {
  late final PageController _pageController;
  int _index = 0;
  static const _reactions = ['🔥', '😍', '🤔', '👎'];

  final List<_FlyingEmoji> _flyingEmojis = [];
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_index < widget.ideas.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onReactionTap(String emoji) async {
    final flyId = UniqueKey();
    setState(() {
      _flyingEmojis.add(_FlyingEmoji(flyId, emoji));
      _dismissing = true;
    });

    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() => _dismissing = false);
    _goNext();

    await Future.delayed(const Duration(milliseconds: 620));
    if (mounted) setState(() => _flyingEmojis.removeWhere((f) => f.id == flyId));
  }

  Future<void> _copyIdea(Map<String, dynamic> idea) async {
    final title = (idea['title'] ?? '').toString();
    final desc = (idea['description'] ?? idea['hook'] ?? '').toString();
    final text = desc.isNotEmpty ? '$title\n\n$desc' : title;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showToast(context, context.tr('idea_popup_copied_toast'), isSuccess: true);
  }

  Widget _peekCard({required double angle, required double top, required double opacity, required double scale}) {
    return Positioned(
      top: top,
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 190,
              height: 300,
              decoration: BoxDecoration(
                color: DiwaliColors.cardTop,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: DiwaliColors.cardBorder.withValues(alpha: 0.8)),
                boxShadow: [BoxShadow(color: DiwaliColors.goldDeep.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 3))],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ideaCard(Map<String, dynamic> idea, int idx) {
    return Container(
      width: 200,
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DiwaliColors.cardTop, DiwaliColors.cardBottom],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DiwaliColors.cardBorder),
        boxShadow: [BoxShadow(color: DiwaliColors.goldDeep.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: DiwaliColors.gold.withValues(alpha: 0.22), shape: BoxShape.circle),
                  child: const Icon(Icons.lightbulb_rounded, color: DiwaliColors.purpleDeep, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('idea_popup_card_label').replaceAll('%d', '${idx + 1}'),
                    style: const TextStyle(color: DiwaliColors.textDim, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(idea['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DiwaliColors.purpleDark)),
            const SizedBox(height: 10),
            Text(idea['description'] ?? idea['hook'] ?? '', style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12.5, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlyingEmoji(_FlyingEmoji f) {
    return Positioned.fill(
      key: f.id,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOut,
          builder: (context, t, child) {
            return Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -90 * t),
                child: Align(
                  alignment: const Alignment(0, 0.72),
                  child: Transform.scale(
                    scale: 1 + (0.4 * (1 - t)),
                    child: Text(f.emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: DiwaliPopupShell(
        onClose: () => Navigator.of(context).pop(),
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title (centered so it clears the hanging diyas and the close button)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: DiwaliColors.purpleDeep, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.tr('idea_popup_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DiwaliColors.purpleDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text('${_index + 1}/${widget.ideas.length}', style: const TextStyle(color: DiwaliColors.textDim, fontSize: 11.5)),
                const SizedBox(height: 10),

                SizedBox(
                  height: 320,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      if (_index < widget.ideas.length - 2)
                        _peekCard(angle: -0.15, top: 12, opacity: 0.45, scale: 0.92),
                      if (_index < widget.ideas.length - 1)
                        _peekCard(angle: 0.11, top: 6, opacity: 0.7, scale: 0.96),
                      AnimatedOpacity(
                        opacity: _dismissing ? 0 : 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: AnimatedScale(
                          scale: _dismissing ? 0.88 : 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: widget.ideas.length,
                            onPageChanged: (i) => setState(() => _index = i),
                            itemBuilder: (_, i) => Center(child: _ideaCard(widget.ideas[i], i)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('idea_popup_swipe_hint'),
                  style: const TextStyle(color: DiwaliColors.textDim, fontSize: 10.5, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _reactions
                      .map((e) => GestureDetector(
                            onTap: () => _onReactionTap(e),
                            child: Text(e, style: const TextStyle(fontSize: 26)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),

                DiwaliButton(
                  label: context.tr('idea_popup_copy_btn'),
                  leading: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                  onTap: () => _copyIdea(widget.ideas[_index]),
                ),
                const SizedBox(height: 2),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: DiwaliColors.purpleDark),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.tr('skip'), style: const TextStyle(color: DiwaliColors.purpleDark, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            ..._flyingEmojis.map(_buildFlyingEmoji),
          ],
        ),
      ),
    );
  }
}