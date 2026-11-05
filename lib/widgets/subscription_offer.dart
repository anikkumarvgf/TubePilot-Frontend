import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../screens/diamond_store_screen.dart';
import 'diwali_popups.dart';

/// Welcome-time offer: shown exactly ONE time in the life of the install.
const String kSubscriptionOfferOnceKey = 'subscription_offer_first_shown_v2';

/// Action-time offer (upload / AI generate): at most once every 24 hours.
const String kSubscriptionActionShownKey = 'subscription_offer_action_shown_ms';

/// ₹1 offer popup — never spams the dashboard.
///
///  * `onlyOnce: true`  -> call from the dashboard right after the welcome popup. Shows a single time ever.
///  * `onlyOnce: false` -> call when the user TRIES to upload or generate something and has no credits.
///                         Shows again, but not more than once per 24h.
///
/// Only shown when the backend says the user is eligible (never paid the ₹1 before).
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
    if (st['eligible'] != true || !context.mounted) return false;
    final offer = st['offer'] is Map
        ? Map<String, dynamic>.from(st['offer'])
        : <String, dynamic>{};
    final intro = offer['introAmount'] as num?;
    final plan = offer['planAmount'] as num?;
    final diamonds = (offer['diamonds'] as num?)?.toInt();
    if (intro == null || plan == null || diamonds == null) return false;

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
      diamonds: diamonds,
      introUploads: (offer['introUploads'] as num?)?.toInt() ?? 20,
      planUploads: (offer['planUploads'] as num?)?.toInt() ?? 30,
    );
    if (start && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              const DiamondStoreScreen(autoStartSubscription: true)));
      return true;
    }
  } catch (e) {
    debugPrint('[SubscriptionOffer] skipped: $e');
  }
  return false;
}
