import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_icons.dart';
import 'app_decor.dart';

/// TubePilot popups (white card + purple), shared by the whole app.
///
///  * [AppPopupShell]               -> card jisme koi bhi popup ka content daalo
///  * [showWelcomePopup]            -> "Welcome to TubePilot" popup
///  * [showConnectYoutubePopup]     -> "Connect Your YouTube Channel" popup
///  * [showSubscriptionOfferPopup]  -> Rs1 payment popup
///
/// NEW-USER FLOW (signup ke baad, is order mein, har step tabhi jab pichla complete):
///   1. Rs1 payment popup
///   2. YouTube channel connect popup
///   3. Welcome popup
/// Current step SharedPreferences mein [kOnboardingStageKey] ke andar rehta hai;
/// Dashboard usi se flow aage badhata hai.

// ---------------------------------------------------------------------------
// Onboarding stage storage
// ---------------------------------------------------------------------------
const String kOnboardingStageKey = 'onboarding_stage_v2';

class OnboardingStage {
  static const payment = 'payment';
  static const connect = 'connect';
  static const welcome = 'welcome';
  static const done = 'done';
}

/// Stable id of the logged-in account (e-mail never changes between sign-up and later
/// screens; _id / id may not exist yet right after sign-up).
String onboardingOwnerKey(Map<String, dynamic>? user) {
  final u = user ?? const <String, dynamic>{};
  for (final k in const ['email', '_id', 'id', 'userId']) {
    final v = '${u[k] ?? ''}'.trim().toLowerCase();
    if (v.isNotEmpty) return v;
  }
  return '';
}

/// Call right after a NEW account is created (sign-up). The flow starts at the
/// Rs1 payment popup.
Future<void> markOnboardingPending(Map<String, dynamic>? user) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kOnboardingStageKey, '${OnboardingStage.payment}|${onboardingOwnerKey(user)}');
  } catch (_) {}
}

/// null = no flow running (normal app open / old user / another account).
Future<String?> getOnboardingStage(String owner) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kOnboardingStageKey);
    if (raw == null) return null;
    final i = raw.indexOf('|');
    final stage = i < 0 ? raw : raw.substring(0, i);
    final stored = i < 0 ? '' : raw.substring(i + 1);
    if (stage == OnboardingStage.done) return null;
    if (stored.isNotEmpty && owner.isNotEmpty && stored != owner) return null;
    return stage;
  } catch (_) {
    return null;
  }
}

Future<void> setOnboardingStage(String owner, String stage) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kOnboardingStageKey, '$stage|$owner');
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------
class AppPopupShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const AppPopupShell({
    super.key,
    required this.child,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(26, 26, 26, 20),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: UiColors.cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(color: UiColors.purpleDark.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                SingleChildScrollView(padding: padding, child: child),
                if (onClose != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: UiColors.iconCircle,
                          shape: BoxShape.circle,
                          border: Border.all(color: UiColors.cardBorder),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: UiColors.purpleDark),
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

// Purple pill button.
class AppButton extends StatelessWidget {
  final String label;
  final IconData? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool loading;
  const AppButton({super.key, required this.label, required this.onTap, this.trailing, this.leading, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [UiColors.purple, UiColors.purpleDark]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: UiColors.purpleDark.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
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
      decoration: const BoxDecoration(shape: BoxShape.circle, color: UiColors.iconCircle),
      child: Icon(icon, color: UiColors.purpleDeep, size: iconSize),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome popup (3rd and last step of the new-user flow)
// ---------------------------------------------------------------------------
Future<void> showWelcomePopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (_) => const _WelcomeDialog(),
  );
}

class _WelcomeDialog extends StatelessWidget {
  const _WelcomeDialog();

  @override
  Widget build(BuildContext context) {
    const features = <(IconData, String)>[
      (Icons.video_call_rounded, 'Upload\nVideos'),
      (Icons.calendar_month_rounded, 'Smart\nScheduler'),
      (Icons.auto_awesome_rounded, 'AI\nIdeas'),
      (Icons.bar_chart_rounded, 'Analytics'),
      (Icons.diamond_outlined, 'Grow\nFaster'),
    ];

    return AppPopupShell(
      onClose: () => Navigator.of(context).pop(),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/splash.png', width: 34, height: 34),
              const SizedBox(width: 6),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
                  children: [
                    TextSpan(text: 'Tube', style: TextStyle(color: UiColors.inkBlack)),
                    TextSpan(text: 'Pilot', style: TextStyle(color: UiColors.plum)),
                  ],
                ),
              ),
            ],
          ),
          const Text(
            'Your YouTube Growth Partner',
            style: TextStyle(color: UiColors.textDim, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),
          const Text(
            'Welcome to',
            style: TextStyle(color: UiColors.purple, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Text(
            'TubePilot',
            style: TextStyle(color: UiColors.purpleDark, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.1),
          ),
          const SizedBox(height: 8),
          const Text(
            'Congratulations on joining TubePilot!',
            textAlign: TextAlign.center,
            style: TextStyle(color: UiColors.purpleDark, fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          const Text(
            "Let's make your YouTube journey bigger.",
            textAlign: TextAlign.center,
            style: TextStyle(color: UiColors.textDim, fontSize: 12.5, height: 1.3),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: UiColors.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UiColors.cardBorder),
            ),
            child: Row(
              children: [
                for (final f in features)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _IconCircle(icon: f.$1, size: 36, iconSize: 19),
                        const SizedBox(height: 4),
                        Text(
                          f.$2,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(color: UiColors.purpleDark, fontSize: 9.5, height: 1.15),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppButton(label: "Let's Go", trailing: Icons.arrow_forward_rounded, onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connect YouTube popup (short)
// ---------------------------------------------------------------------------
/// true = user ne "Connect" dabaya. Connect ka asli kaam (OAuth URL kholna)
/// jahan se call karte ho wahin karo: `if (await showConnectYoutubePopup(context)) { ... }`
Future<bool> showConnectYoutubePopup(
  BuildContext context, {
  String title = 'Connect Your YouTube Channel',
  String subtitle = 'Get your uploaded videos and optimize them with AI.',
  String buttonLabel = 'Connect YouTube Channel',
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => ConnectYoutubeDialog(title: title, subtitle: subtitle, buttonLabel: buttonLabel),
  );
  return r == true;
}

class ConnectYoutubeDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  const ConnectYoutubeDialog({
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
          _IconCircle(icon: icon, size: 34, iconSize: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: UiColors.purpleDark, fontSize: 12.5, fontWeight: FontWeight.w800)),
                Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: UiColors.textDim, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPopupShell(
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
                    border: Border.all(color: UiColors.cardBorder),
                    boxShadow: [BoxShadow(color: UiColors.purpleDark.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 4))],
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
                      gradient: const LinearGradient(colors: [UiColors.purple, UiColors.purpleDark]),
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
            style: const TextStyle(color: UiColors.purpleDark, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: UiColors.textDim, fontSize: 12.5, height: 1.3),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UiColors.cardBorder.withValues(alpha: 0.6)),
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
          AppButton(
            label: buttonLabel,
            trailing: Icons.chevron_right_rounded,
            leading: const YoutubeIcon(size: 20),
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, size: 13, color: UiColors.textDim),
              SizedBox(width: 5),
              Text('Secure & Read Only Access', style: TextStyle(color: UiColors.textDim, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}


// =============================================================================
// Bottom sheet helpers (used by Profile: Help & Support, YouTube options)
// =============================================================================

/// White bottom sheet with rounded top; content stays above the system bar.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        decoration: BoxDecoration(
          color: UiColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: UiColors.cardBorder),
        ),
        padding: EdgeInsets.fromLTRB(0, 10, 0, 12 + MediaQuery.paddingOf(sheetContext).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: UiColors.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Material(type: MaterialType.transparency, child: builder(sheetContext)),
            ],
          ),
        ),
      );
    },
  );
}

class AppSheetTitle extends StatelessWidget {
  final String text;
  const AppSheetTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Text(
        text,
        style: const TextStyle(color: UiColors.purpleDark, fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class AppSheetDivider extends StatelessWidget {
  const AppSheetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 24,
      endIndent: 24,
      color: UiColors.cardBorder.withValues(alpha: 0.6),
    );
  }
}

class AppSheetTile extends StatelessWidget {
  final Widget? leading;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool danger;
  final VoidCallback? onTap;
  const AppSheetTile({
    super.key,
    this.leading,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFC62828) : UiColors.purpleDark;
    final lead = leading ?? (icon != null ? Icon(icon, color: danger ? color : UiColors.purpleDeep, size: 20) : null);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: lead == null
          ? null
          : Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: UiColors.iconCircle, shape: BoxShape.circle),
              child: lead,
            ),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14.5)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: UiColors.textDim, fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: UiColors.textDim),
    );
  }
}


// =============================================================================
// Rs1 payment popup: Rs1 now = 20 uploads, then Rs10 autopay when they finish
// =============================================================================
const String kSubscriptionPopupLastShownKey = 'subscription_popup_last_shown_ms';

/// Returns true when the user taps "Pay ₹1 & Start". Numbers come from the backend offer.
Future<bool> showSubscriptionOfferPopup(
  BuildContext context, {
  required num intro,
  required num plan,
  required int uploads,
  bool barrierDismissible = true,
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _SubscriptionOfferDialog(intro: intro, plan: plan, uploads: uploads),
  );
  return r == true;
}

class _SubscriptionOfferDialog extends StatelessWidget {
  final num intro;
  final num plan;
  final int uploads;
  const _SubscriptionOfferDialog({required this.intro, required this.plan, required this.uploads});

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          _IconCircle(icon: icon, size: 32, iconSize: 17),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: UiColors.purpleDark, fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AppPopupShell(
      onClose: () => Navigator.of(context).pop(false),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Start for just ₹$intro',
            textAlign: TextAlign.center,
            style: const TextStyle(color: UiColors.purpleDark, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'for $uploads video uploads',
            style: const TextStyle(color: UiColors.textDim, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _row(Icons.cloud_upload_outlined, '$uploads uploads right away'),
          _row(Icons.autorenew_rounded, 'When they finish: ₹$plan autopay for the next $uploads uploads'),
          _row(Icons.notifications_active_outlined, 'We notify you before every debit'),
          const SizedBox(height: 10),
          Text(
            'Your 1-month period starts on the day the ₹$plan is debited, from the same payment method. '
            'Cancel anytime in Profile → Subscription.',
            textAlign: TextAlign.center,
            style: TextStyle(color: UiColors.textDim, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          AppButton(label: 'Pay ₹$intro & Start', onTap: () => Navigator.of(context).pop(true)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Maybe later', style: TextStyle(color: UiColors.textDim)),
          ),
        ],
      ),
    );
  }
}


// =============================================================================
// Simple white dialog (icon + title + content + buttons). Used by the Referral popup.
// =============================================================================
class AppDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  const AppDialog({super.key, required this.icon, required this.title, required this.content, required this.actions});

  @override
  Widget build(BuildContext context) {
    return AppPopupShell(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconCircle(icon: icon, size: 64, iconSize: 30),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: UiColors.purpleDark, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 12),
          DefaultTextStyle(
            textAlign: TextAlign.center,
            style: const TextStyle(color: UiColors.textDim, fontSize: 14, height: 1.4),
            child: content,
          ),
          const SizedBox(height: 20),
          Row(children: actions),
        ],
      ),
    );
  }
}

/// Button for [AppDialog]. primary = filled plum, otherwise plain text. Fills half the row.
class AppDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;
  const AppDialogButton({super.key, required this.label, required this.onPressed, this.primary = true, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: primary
          ? AppButton(label: label, onTap: onPressed, loading: loading)
          : TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(label, style: const TextStyle(color: UiColors.purpleDark, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
    );
  }
}
