import 'package:flutter/material.dart';
import '../widgets/app_decor.dart';
import '../widgets/app_popups.dart';
import '../widgets/common.dart';
import 'api_service.dart';
import 'subscription_pay.dart';

/// ONE place that knows "has this user paid yet?".
///
/// A user who has NOT paid (the Rs1 plan, or a diamond pack) can open the dashboard, but
///   * cannot upload videos / go live,
///   * cannot connect a YouTube channel,
/// until he pays. The backend enforces the same rule (utils/paywall.js, HTTP 402 + code
/// PAYMENT_REQUIRED), this class only makes the app show the right thing.
///
/// Source of truth = GET /subscription/status -> `locked` (old backends without that field:
/// `eligible`). Screens listen to [PaymentGate.instance] and rebuild when it changes.
class PaymentGate extends ChangeNotifier {
  PaymentGate._();
  static final PaymentGate instance = PaymentGate._();

  bool _locked = false;
  Map<String, dynamic>? _offer;
  DateTime? _planExpiresAt;

  /// When the current one-time Rs10 month ends (null = no active month).
  DateTime? get planExpiresAt => _planExpiresAt;

  /// Whole days left of the Rs10 month (rounded up), null = none / already over.
  int? get planDaysLeft {
    final e = _planExpiresAt;
    if (e == null) return null;
    final left = e.difference(DateTime.now());
    if (left.isNegative) return null;
    return (left.inHours / 24).ceil().clamp(1, 9999);
  }

  /// true = user has not paid yet (features locked). Starts false until the first status call
  /// answers; the backend blocks locked users anyway.
  bool get locked => _locked;

  /// `offer` block of the last status call (introAmount, planAmount, introUploads, planUploads ...).
  Map<String, dynamic>? get offer => _offer;

  static bool isLockedStatus(Map<String, dynamic>? st) {
    if (st == null) return false;
    if (st.containsKey('locked')) return st['locked'] == true;
    return st['eligible'] == true; // backend without the `locked` field
  }

  /// Reads the status from the backend and updates [locked]. Returns the raw status, null on error
  /// (then the last known state is kept).
  Future<Map<String, dynamic>?> fetchStatus() async {
    try {
      final st = Map<String, dynamic>.from(await ApiService.instance.getSubscriptionStatus());
      if (st['offer'] is Map) _offer = Map<String, dynamic>.from(st['offer']);
      final l = isLockedStatus(st);
      final exp = st['planExpiresAt'] == null ? null : DateTime.tryParse(st['planExpiresAt'].toString())?.toLocal();
      if (l != _locked || exp != _planExpiresAt) {
        _locked = l;
        _planExpiresAt = exp;
        notifyListeners();
      }
      return st;
    } catch (_) {
      return null;
    }
  }

  /// Set when the Rs1 screen was already shown right after sign-up, so the dashboard does not show
  /// it a second time in the same moment.
  bool offerShownAtSignup = false;

  /// Called right after sign-up (before the dashboard is ever visible). Shows the full-screen Rs1
  /// page; "Pay" opens PayU directly. Never throws.
  Future<void> showOfferAtSignup(BuildContext context) async {
    try {
      final st = await fetchStatus();
      if (st == null || !_locked || !context.mounted) return;
      final o = _offer ?? const <String, dynamic>{};
      final intro = o['introAmount'] as num?;
      final plan = o['planAmount'] as num?;
      final uploads = (o['introUploads'] ?? o['uploads']) as num?;
      final planUploads = (o['planUploads'] ?? o['uploads']) as num?;
      if (intro == null || plan == null || uploads == null) return;
      offerShownAtSignup = true;
      final start = await showSubscriptionOfferPopup(
        context,
        intro: intro,
        plan: plan,
        uploads: uploads.toInt(),
        planUploads: planUploads?.toInt(),
        barrierDismissible: false,
      );
      if (start && context.mounted) {
        await startSubscriptionPayment(context);
        await fetchStatus();
      }
    } catch (e) {
      debugPrint('[PaymentGate] signup offer failed: $e');
    }
  }

  Future<bool> refresh() async {
    await fetchStatus();
    return _locked;
  }

  /// Call before a locked action. Returns true when the user may continue (already paid, or he
  /// paid just now). Otherwise shows the Rs1 offer; returns false if he says "Maybe later".
  Future<bool> ensureUnlocked(BuildContext context) async {
    await fetchStatus();
    if (!_locked) return true;
    if (!context.mounted) return false;

    final o = _offer ?? const <String, dynamic>{};
    final intro = o['introAmount'] as num?;
    final plan = o['planAmount'] as num?;
    final uploads = (o['introUploads'] ?? o['uploads']) as num?;
    final planUploads = (o['planUploads'] ?? o['uploads']) as num?;
    if (intro == null || plan == null || uploads == null) {
      showToast(context, 'Payment is not available right now. Please try again later.', isError: true);
      return false;
    }

    final start = await showSubscriptionOfferPopup(
      context,
      intro: intro,
      plan: plan,
      uploads: uploads.toInt(),
      planUploads: planUploads?.toInt(),
    );
    if (!start || !context.mounted) return false;

    await startSubscriptionPayment(context); // opens PayU directly (no store page)
    await fetchStatus();
    return !_locked;
  }
}

/// Full-screen "locked" message with a pay button. Shown by Upload / Live Stream while the user has
/// not paid. [onUnlocked] runs after a successful payment.
class LockedFeatureView extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onUnlocked;
  const LockedFeatureView({super.key, required this.title, required this.message, this.onUnlocked});

  @override
  State<LockedFeatureView> createState() => _LockedFeatureViewState();
}

class _LockedFeatureViewState extends State<LockedFeatureView> {
  bool _busy = false;

  Future<void> _pay() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await PaymentGate.instance.ensureUnlocked(context);
      if (ok) widget.onUnlocked?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = PaymentGate.instance.offer?['introAmount'] ?? 1;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: UiColors.iconCircle),
              child: const Icon(Icons.lock_outline_rounded, color: UiColors.purpleDeep, size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiColors.purpleDark, fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiColors.textDim, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 22),
            GradientButton(
              label: 'Pay ₹$amount & Unlock',
              icon: Icons.lock_open_rounded,
              loading: _busy,
              onPressed: _pay,
            ),
          ],
        ),
      ),
    );
  }
}
