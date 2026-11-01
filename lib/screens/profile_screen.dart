import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/brand_icons.dart';
import '../widgets/app_brand_background.dart';
// ⚠️ NEW: Diwali cards + Diwali bottom sheets
import '../widgets/diwali_decor.dart';
import '../widgets/diwali_popups.dart';
import 'wallet_screen.dart';
import 'diamond_store_screen.dart';
import 'gift_code_screen.dart';
import 'notifications_screen.dart';
import 'admin_screen.dart';
import 'refer_earn_screen.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'rate_us_screen.dart';
import 'settings_screen.dart';
import 'ai_ideas_screen.dart';
import 'ai_title_description_screen.dart';
import 'seo_optimizer_screen.dart';
import 'competitor_radar_screen.dart';
import 'smart_scheduler_screen.dart';
import 'visual_analyzer_screen.dart';
import 'channel_audit_screen.dart';
import 'my_videos_screen.dart';
import 'live_stream_screen.dart'; // Live Streaming feature

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// WidgetsBindingObserver added — this tab lives in an IndexedStack, so
// initState runs only once. We refresh when the app comes back from the browser
// (YouTube / Facebook connect) so the connected channel shows up immediately.
class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  static const _supportCategoryKeys = [
    'support_cat_payment',
    'support_cat_upload_failed',
    'support_cat_youtube_connection',
    'support_cat_account_login',
    'support_cat_app_bug',
    'support_cat_other',
  ];
  Map<String, dynamic>? _metaStatus;
  bool _loadingMeta = true;
  Map<String, dynamic>? _liveChannel;
  bool _loadingChannel = false;
  bool _liveChannelFetchFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshChannel());
    _loadMetaStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the browser (YouTube/Facebook connect) -> refresh everything.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshChannel();
      _loadMetaStatus();
    }
  }

  Future<void> _refreshChannel() async {
    if (!mounted) return;
    await context.read<AuthProvider>().refreshUser();
    if (!mounted) return;
    await _loadLiveChannel();
  }

  Future<void> _loadMetaStatus() async {
    try {
      final res = await ApiService.instance.getMetaStatus();
      if (mounted) setState(() => _metaStatus = res);
    } catch (_) {
      if (mounted) setState(() => _metaStatus = null);
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  // No longer quits early when the cached user has no channel yet
  // (that was the bug: right after connecting, the cached user was still empty).
  // A 404 simply means "not connected" -> show the Connect YouTube card.
  Future<void> _loadLiveChannel() async {
    if (!mounted) return;
    setState(() {
      _loadingChannel = true;
      _liveChannelFetchFailed = false;
    });
    try {
      final res = await ApiService.instance.getYoutubeChannel();
      if (mounted) setState(() => _liveChannel = res['channel']);
      debugPrint('✅ [Profile] Live YouTube channel fetched: subscriberCount=${res['channel']?['subscriberCount']}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 404) {
        setState(() => _liveChannel = null);
      } else {
        debugPrint('❌ [Profile] Live YouTube channel fetch FAILED: $e');
        setState(() => _liveChannelFetchFailed = true);
      }
    } catch (e) {
      debugPrint('❌ [Profile] Live YouTube channel fetch FAILED: $e');
      if (mounted) setState(() => _liveChannelFetchFailed = true);
    } finally {
      if (mounted) setState(() => _loadingChannel = false);
    }
  }

  // Icon shown in the beige circle of each help category.
  Widget _supportLeading(String key) {
    const c = DiwaliColors.purpleDeep;
    switch (key) {
      case 'support_cat_payment':
        return const Icon(Icons.diamond_outlined, color: c, size: 20);
      case 'support_cat_upload_failed':
        return const Icon(Icons.cloud_off_rounded, color: c, size: 20);
      case 'support_cat_youtube_connection':
        return const YoutubeIcon(size: 20);
      case 'support_cat_facebook_connection':
        return const FacebookIcon(size: 20);
      case 'support_cat_account_login':
        return const Icon(Icons.lock_person_rounded, color: c, size: 20);
      case 'support_cat_app_bug':
        return const Icon(Icons.bug_report_rounded, color: c, size: 20);
      default:
        return const Icon(Icons.help_outline_rounded, color: c, size: 20);
    }
  }

  // ⚠️ CHANGED: showModalBottomSheet -> showDiwaliSheet. The old sheet was plain
  // white (bottom sheets are not part of the global Diwali page background) and
  // could slide under the Android 3-button / gesture bar. The Diwali sheet shows
  // the festival artwork and keeps its content above the system bar.
  Future<void> _openSupport() async {
    final categoryKey = await showDiwaliSheet<String>(
      context: context,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DiwaliSheetTitle(text: context.tr('support_sheet_title')),
            const SizedBox(height: 4),
            for (var i = 0; i < _supportCategoryKeys.length; i++) ...[
              if (i > 0) const DiwaliSheetDivider(),
              DiwaliSheetTile(
                leading: _supportLeading(_supportCategoryKeys[i]),
                title: context.tr(_supportCategoryKeys[i]),
                onTap: () => Navigator.pop(sheetContext, _supportCategoryKeys[i]),
              ),
            ],
          ],
        );
      },
    );
    if (categoryKey == null || !mounted) return;
    await _sendSupportEmail(categoryKey);
  }

  Future<void> _sendSupportEmail(String categoryKey) async {
    final category = context.tr(categoryKey);
    final user = context.read<AuthProvider>().user ?? {};
    final uri = Uri(
      scheme: 'mailto',
      path: 'anikkesharwani37@gmail.com',
      query: 'subject=${Uri.encodeComponent('TubePilot Support: $category')}'
          '&body=${Uri.encodeComponent('User ID: ${user['userId'] ?? '-'}\nEmail: ${user['email'] ?? '-'}\nCategory: $category\n\nDescribe your issue below:\n')}',
    );
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        showToast(context, '${context.tr('no_email_app_found')} anikkesharwani37@gmail.com', isError: true);
      }
    } catch (_) {
      if (mounted) showToast(context, '${context.tr('no_email_app_found')} anikkesharwani37@gmail.com', isError: true);
    }
  }

  Future<void> _launchOAuth(String url) async {
    await custom_tabs.launchUrl(
      Uri.parse(url),
      customTabsOptions: custom_tabs.CustomTabsOptions(
        shareState: custom_tabs.CustomTabsShareState.off,
        urlBarHidingEnabled: true,
        showTitle: true,
      ),
      safariVCOptions: const custom_tabs.SafariViewControllerOptions(
        barCollapsingEnabled: true,
        dismissButtonStyle: custom_tabs.SafariViewControllerDismissButtonStyle.close,
      ),
    );
  }

  Future<void> _connectYoutube() async {
    try {
      final res = await ApiService.instance.getYoutubeOAuthUrl();
      if (res['url'] != null) await _launchOAuth(res['url']);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  // ⚠️ CHANGED: also a Diwali sheet now (same fix as _openSupport).
  Future<void> _openYoutubeOptions(Map<String, dynamic> channel) async {
    final thumb = (channel['thumbnail'] ?? '').toString();
    final action = await showDiwaliSheet<String>(
      context: context,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 4, 36, 12),
              child: Row(children: [
                thumb.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          thumb,
                          width: 40, height: 40, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const YoutubeIcon(size: 22),
                        ),
                      )
                    : const YoutubeIcon(size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel['channelTitle'] ?? context.tr('up_youtube_label'),
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: DiwaliColors.purpleDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${channel['subscriberCount'] ?? 0} ${context.tr('subscribers_label')}',
                        style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            const DiwaliSheetDivider(),
            DiwaliSheetTile(
              icon: Icons.edit_note_rounded,
              // TODO: move these two strings into app_strings.dart for multi-language.
              title: 'Open YouTube Studio',
              subtitle: 'Change channel name, handle & logo',
              trailing: const Icon(Icons.open_in_new_rounded, color: DiwaliColors.textDim, size: 18),
              onTap: () => Navigator.pop(sheetContext, 'studio'),
            ),
            const DiwaliSheetDivider(),
            DiwaliSheetTile(
              icon: Icons.link_off_rounded,
              danger: true,
              title: context.tr('disconnect_action'),
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.pop(sheetContext, 'disconnect'),
            ),
          ],
        );
      },
    );
    if (action == 'disconnect') await _disconnectYoutube();
    if (action == 'studio') await _openYoutubeStudio(channel);
  }

  // Opens this channel's customization page in YouTube Studio (name, handle, logo
  // can only be changed there). External app/browser is used so the user's
  // existing Google login is picked up.
  Future<void> _openYoutubeStudio(Map<String, dynamic> channel) async {
    final id = (channel['channelId'] ?? '').toString();
    final url = id.isNotEmpty
        ? 'https://studio.youtube.com/channel/$id/editing/profile'
        : 'https://studio.youtube.com';
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) showToast(context, 'Could not open YouTube Studio', isError: true);
    } catch (_) {
      if (mounted) showToast(context, 'Could not open YouTube Studio', isError: true);
    }
  }

  Future<void> _disconnectYoutube() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('disconnect_youtube_title')),
        content: Text(context.tr('disconnect_youtube_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('disconnect_action'), style: const TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.instance.disconnectYoutube();
      if (mounted) {
        showToast(context, context.tr('youtube_disconnected_toast'), isSuccess: true);
        setState(() => _liveChannel = null);
        context.read<AuthProvider>().refreshUser();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _connectMeta() async {
    try {
      final res = await ApiService.instance.getMetaOAuthUrl();
      if (res['url'] != null) await _launchOAuth(res['url']);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _disconnectFacebook() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('disconnect_facebook_title')),
        content: Text(context.tr('disconnect_facebook_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('disconnect_action'), style: const TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.instance.disconnectFacebook();
      if (mounted) {
        showToast(context, context.tr('facebook_disconnected_toast'), isSuccess: true);
        _loadMetaStatus();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Widget _connectTile({
    required Widget icon,
    required String label,
    required String status,
    required bool connected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (connected ? AppColors.green : context.surfaces.textDim).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: icon,
              ),
              const SizedBox(height: 8),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: connected ? AppColors.green : context.surfaces.textDim, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instagramTile(Map<String, dynamic>? instagram, bool facebookIsConnected) {
    final connected = instagram != null;
    final username = instagram?['igUsername'] as String?;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            connected
                ? CircleAvatar(
                    radius: 20,
                    backgroundColor: (AppColors.green).withValues(alpha: 0.14),
                    backgroundImage: (instagram['igProfilePicture'] ?? '').toString().isNotEmpty
                        ? NetworkImage(instagram['igProfilePicture'])
                        : null,
                    child: (instagram['igProfilePicture'] ?? '').toString().isEmpty
                        ? const InstagramIcon(size: 20)
                        : null,
                  )
                : Container(
                    width: 40, height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: context.surfaces.textDim.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                    child: const InstagramIcon(size: 20),
                  ),
            const SizedBox(height: 8),
            Text(
              connected ? '@${username ?? ''}' : context.tr('instagram_label'),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            if (connected)
              AppBadge(label: context.tr('connected_label'), color: AppColors.green)
            else
              Text(
                facebookIsConnected ? context.tr('no_ig_on_page') : context.tr('auto_linked_facebook'),
                maxLines: 2, textAlign: TextAlign.center,
                style: TextStyle(color: context.surfaces.textDim, fontSize: 10, fontWeight: FontWeight.w600, height: 1.2),
              ),
          ],
        ),
      ),
    );
  }

  // Card look shared by the YouTube card (white, radius 20, soft shadow).
  BoxDecoration _cardDecoration({Gradient? gradient}) {
    return BoxDecoration(
      color: Colors.white,
      gradient: gradient,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: DiwaliColors.cardBorder.withValues(alpha: 0.55)),
      boxShadow: [
        BoxShadow(color: DiwaliColors.purpleDark.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 5)),
      ],
    );
  }

  Widget _youtubeSubscriberCard(Map<String, dynamic>? cachedChannel) {
    final channel = _liveChannel ?? cachedChannel;
    if (channel == null) {
      return GestureDetector(
        onTap: _connectYoutube,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: DiwaliColors.iconCircle, shape: BoxShape.circle),
                child: const YoutubeIcon(size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('connect_youtube_title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: DiwaliColors.purpleDark)),
                    const SizedBox(height: 2),
                    Text(context.tr('connect_youtube_subtitle'), style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: DiwaliColors.textDim),
            ],
          ),
        ),
      );
    }
    final subs = channel['subscriberCount']?.toString() ?? '0';
    final title = channel['channelTitle'] ?? context.tr('up_youtube_label');
    final thumbnail = (channel['thumbnail'] ?? '').toString();
    return GestureDetector(
      onTap: () => _openYoutubeOptions(channel),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(
          gradient: LinearGradient(colors: [AppColors.red.withValues(alpha: 0.08), Colors.white]),
        ),
        child: Row(
          children: [
            thumbnail.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      thumbnail,
                      width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.14), shape: BoxShape.circle),
                        child: const YoutubeIcon(size: 24),
                      ),
                    ),
                  )
                : Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: const YoutubeIcon(size: 24),
                  ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: DiwaliColors.purpleDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatSubscriberCount(subs),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.red),
                      ),
                      const SizedBox(width: 6),
                      Text(context.tr('subscribers_label'), style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                      if (_loadingChannel) ...[
                        const SizedBox(width: 8),
                        const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.6, color: DiwaliColors.textDim)),
                      ],
                      if (_liveChannelFetchFailed && !_loadingChannel) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _loadLiveChannel,
                          child: const Icon(Icons.refresh_rounded, size: 14, color: DiwaliColors.textDim),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_horiz_rounded, color: DiwaliColors.textDim),
          ],
        ),
      ),
    );
  }

  String _formatSubscriberCount(String raw) {
    final n = int.tryParse(raw);
    if (n == null) return raw;
    if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user ?? {};
    final channel = user['youtubeChannel'];

    final scaffold = Scaffold(
      appBar: AppBar(
        // Side spacing keeps the title clear of the hanging diyas in the artwork.
        titleSpacing: widget.embedded ? 36 : null,
        title: Text(
          context.tr('profile_settings_title'),
          style: const TextStyle(color: DiwaliColors.purpleDark, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        // Bottom padding is small: when embedded, the body already ends above
        // the floating nav bar, so nothing is hidden behind it.
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _youtubeSubscriberCard(channel),
          const SizedBox(height: 16),
          // ---------------- Creator OS (VidIQ-style tools) ----------------
          Text(context.tr('creator_os_section'), style: const TextStyle(color: DiwaliColors.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _menuCard([
            // Live Streaming feature, top of Creator OS list.
            _menuRow(Icons.podcasts_rounded, context.tr('menu_live_stream'), AppColors.red,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveStreamScreen()))),
            _divider(),
            _menuRow(Icons.auto_awesome_rounded, context.tr('menu_ai_ideas'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiIdeasScreen()))),
            _divider(),
            _menuRow(Icons.title_rounded, context.tr('menu_ai_title_desc'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiTitleDescriptionScreen()))),
            _divider(),
            // Uses translation key (multi-language support) — NOT hardcoded.
            _menuRow(Icons.query_stats_rounded, context.tr('menu_seo_optimizer'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeoOptimizerScreen()))),
            _divider(),
            _menuRow(Icons.radar_rounded, context.tr('menu_competitor_radar'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompetitorRadarScreen()))),
            _divider(),
            _menuRow(Icons.calendar_month_rounded, context.tr('menu_smart_scheduler'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SmartSchedulerScreen()))),
            _divider(),
            _menuRow(Icons.image_search_rounded, context.tr('menu_visual_analyzer'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VisualAnalyzerScreen()))),
            _divider(),
            _menuRow(Icons.fact_check_rounded, context.tr('menu_channel_audit'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChannelAuditScreen()))),
            _divider(),
            _menuRow(Icons.video_collection_rounded, context.tr('menu_my_videos'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyVideosScreen()))),
          ]),
          const SizedBox(height: 20),
          // Subscription & Wallet comes FIRST, Buy Diamonds second.
          _menuCard([
            // "Buy Diamonds" is now "Subscription" (plans / diamond packs).
            _menuRow(Icons.workspace_premium_rounded, 'Subscription', AppColors.diamond,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiamondStoreScreen()))),
            _divider(),
            // Wallet + transactions + purchases + refund logs, all in one page.
            _menuRow(Icons.account_balance_wallet_rounded, context.tr('subscription_wallet'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen()))),
            _divider(),
            _menuRow(Icons.card_giftcard_rounded, context.tr('menu_gift_code'), AppColors.diamond,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GiftCodeScreen()))),
            _divider(),
            _menuRow(Icons.card_giftcard_rounded, context.tr('refer_earn'), AppColors.green,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReferEarnScreen()))),
            _divider(),
            _menuRow(Icons.notifications_rounded, context.tr('notifications'), AppColors.purpleLight,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            _divider(),
            _menuRow(Icons.help_rounded, context.tr('help_support'), AppColors.purple, _openSupport),
            if (auth.isAdmin) ...[
              _divider(),
              _menuRow(Icons.admin_panel_settings_rounded, context.tr('admin_panel'), AppColors.red,
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen()))),
            ],
          ]),
          const SizedBox(height: 12),
          _menuCard([
            _menuRow(Icons.info_rounded, context.tr('about'), AppColors.purpleLight,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen()))),
            _divider(),
            _menuRow(Icons.privacy_tip_rounded, context.tr('privacy_policy'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
            _divider(),
            _menuRow(Icons.star_rounded, context.tr('rate_us'), AppColors.diamond,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RateUsScreen()))),
            _divider(),
            _menuRow(Icons.settings_rounded, context.tr('settings_menu'), AppColors.purple,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );

    // ⚠️ FIX: as a tab inside the dashboard, the dashboard already provides the
    // background (and hides the bottom artwork behind its own nav bar). Wrapping
    // it again here drew a SECOND artwork copy right above the nav bar. So the
    // wrapper is only used when the screen is opened on its own.
    if (widget.embedded) return scaffold;
    return AppBrandBackground(watermarkWhenNormal: false, child: scaffold);
  }

  // White Diwali card (radius 20, soft shadow). The inner Material keeps the
  // ListTile ripple visible on top of the white card.
  Widget _menuCard(List<Widget> children) {
    return DiwaliCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          type: MaterialType.transparency,
          child: Column(children: children),
        ),
      ),
    );
  }

  // Every icon: rounded icon inside a light beige circle (same as dashboard).
  Widget _menuRow(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: DiwaliColors.iconCircle, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DiwaliColors.purpleDark)),
      trailing: const Icon(Icons.chevron_right, color: DiwaliColors.textDim),
      onTap: onTap,
    );
  }

  Widget _divider() => Divider(height: 1, color: DiwaliColors.cardBorder.withValues(alpha: 0.5));
}