import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/subscription_pay.dart';
import 'app_popups.dart';

/// Welcome-time offer: shown exactly ONE time in the life of the install.
const String kSubscriptionOfferOnceKey = 'subscription_offer_first_shown_v2';

/// Action-time offer (upload / AI generate): at most once every 24 hours.
const String kSubscriptionActionShownKey = 'subscription_offer_action_shown_ms';

/// ₹1 offer popup (full screen with video) - never spams the dashboard.
///
///  * `onlyOnce: true`  -> call from the dashboard right after the welcome popup. Shows a single time ever.
///  * `onlyOnce: false` -> call when the user TRIES to upload or generate something and has no credits.
///                         Shows again, but not more than once per 24h.
///
/// Shown when the backend says `eligible` (₹1 never paid) or `planEligible` (₹1 used -> one-time ₹10 month).
/// Returns true if the user tapped "Pay ₹1 & Start" (payment screen was opened), so the
/// caller can refresh its data. Returns false in every other case (not shown / skipped / error).
Future<bool> showSubscriptionOfferIfNeeded(BuildContext context,
    {bool onlyOnce = false}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (onlyOnce) {
      if (prefs.getBool(kSubscriptionOfferOnceKey) == true) return false;
    } else {
      final last = prefs.getInt(kSubscriptionActionShownKey);
      if (last != null &&
          now - last < const Duration(hours: 24).inMilliseconds) {
        return false;
      }
    }

    final st = await ApiService.instance.getSubscriptionStatus();
    // Rs1 not used yet -> Rs1 offer. Rs1 used (uploads finished) -> one-time Rs10 month offer.
    final monthly = st['eligible'] != true && st['planEligible'] == true;
    if ((st['eligible'] != true && !monthly) || !context.mounted) return false;
    final offer = st['offer'] is Map
        ? Map<String, dynamic>.from(st['offer'])
        : <String, dynamic>{};
    final intro = offer['introAmount'] as num?;
    final plan = offer['planAmount'] as num?;
    if (intro == null || plan == null) return false;
    // backend sends introUploads / planUploads (older backend: `uploads`)
    final uploads = ((offer['introUploads'] ?? offer['uploads']) as num?)?.toInt() ?? 20;
    final planUploads = ((offer['planUploads'] ?? offer['uploads']) as num?)?.toInt();

    // Saved BEFORE showing, so even if the app is closed with the popup open it counts as shown.
    if (onlyOnce) {
      await prefs.setBool(kSubscriptionOfferOnceKey, true);
    } else {
      await prefs.setInt(kSubscriptionActionShownKey, now);
    }
    if (!context.mounted) return false;

    final start = await showSubscriptionOfferPopup(
      context,
      intro: intro,
      plan: plan,
      uploads: uploads,
      planUploads: planUploads,
      monthly: monthly,
      diamonds: ((offer['diamonds'] as num?) ?? 99).toInt(),
    );
    if (start && context.mounted) {
      await startSubscriptionPayment(context); // PayU opens directly
      return true;
    }
  } catch (e) {
    debugPrint('[SubscriptionOffer] skipped: $e');
  }
  return false;
}
