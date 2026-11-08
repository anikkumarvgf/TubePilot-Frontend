import 'package:flutter/material.dart';
import '../widgets/payu_checkout.dart';
import '../widgets/common.dart';
import 'payment_gate.dart';

/// Rs1 + Rs10 autopay: opens the PayU checkout DIRECTLY (no Diamond Store page in between).
/// Returns true only when the payment really went through (the backend confirmed it).
Future<bool> startSubscriptionPayment(BuildContext context) async {
  final nav = Navigator.of(context, rootNavigator: true);
  var overlayOpen = true;
  // Small loader while the order is created / the checkout opens.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    ),
  ).then((_) => overlayOpen = false);

  PayuResult r;
  try {
    r = await PayuCheckout().paySubscription();
  } catch (e) {
    r = PayuResult('error', e.toString());
  }
  if (overlayOpen && nav.mounted) nav.pop();

  await PaymentGate.instance.fetchStatus();
  if (!context.mounted) return r.approved;

  if (r.approved) {
    showToast(context, 'Subscription started. Uploads unlocked!', isSuccess: true);
  } else if (r.status == 'pending') {
    showToast(context, r.message);
  } else if (r.status != 'cancelled') {
    showToast(context, r.message.isEmpty ? 'Payment failed. Please try again.' : r.message, isError: true);
  }
  return r.approved;
}
