import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import '../services/api_service.dart';

/// Step-by-step trace of the last payment attempt, saved to the phone IMMEDIATELY. If the app
/// dies (native crash) while PayU is open, the next app start shows where it stopped - no PC /
/// flutter run needed.
final List<String> _traceLines = [];
void _t(String s) {
  debugPrint(s);
  _traceLines.add('${DateTime.now().toIso8601String().substring(11, 19)} $s');
  if (_traceLines.length > 40) _traceLines.removeAt(0);
  SharedPreferences.getInstance().then((p) => p.setStringList('payu_trace_v1', List<String>.from(_traceLines)));
}

class PayuTrace {
  static void start() {
    _traceLines.clear();
    _t('[PayU] ---- new attempt ----');
  }

  static Future<void> showDialogWith(BuildContext context, String title, List<String> lines) async {
    final text = lines.join('\n');
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: SelectableText(text, style: const TextStyle(fontSize: 11.5))),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  /// App start: the last attempt never finished -> the app was killed while paying. Show where.
  static Future<void> showIfInterrupted(BuildContext context) async {
    try {
      final p = await SharedPreferences.getInstance();
      final lines = p.getStringList('payu_trace_v1') ?? const <String>[];
      await p.remove('payu_trace_v1');
      if (lines.isEmpty || lines.any((l) => l.contains('FINISHED'))) return;
      if (!context.mounted) return;
      await showDialogWith(context, 'Last payment was interrupted', lines);
    } catch (_) {}
  }

  static List<String> get lines => List<String>.from(_traceLines);
}

/// status: 'approved' | 'failed' | 'pending' | 'cancelled' | 'error'
class PayuResult {
  final String status;
  final String message;
  const PayuResult(this.status, [this.message = '']);
  bool get approved => status == 'approved';
}

class PayuCheckout implements PayUCheckoutProProtocol {
  late final PayUCheckoutProFlutter _pro;
  Completer<PayuResult>? _done;
  String _txnid = '';
  // UPDATE24: the same checkout now serves Diamonds AND Live Plans - only the
  // "verify" call and the pending text differ.
  Future<Map<String, dynamic>> Function(String txnid) _verify = (t) => ApiService.instance.verifyPayuPayment(t);
  String _pendingMsg = 'Payment is still being confirmed. Diamonds will be added automatically once it succeeds.';

  PayuCheckout() {
    _pro = PayUCheckoutProFlutter(this);
  }

  /// Diamond Store purchase.
  Future<PayuResult> pay(int diamonds) {
    _verify = (t) => ApiService.instance.verifyPayuPayment(t);
    _pendingMsg = 'Payment is still being confirmed. Diamonds will be added automatically once it succeeds.';
    return _run(() => ApiService.instance.createPayuOrder(diamonds));
  }

  /// Live Streaming plan purchase (category: 'day' | 'month').
  Future<PayuResult> payLivePlan({required String category, required String planName}) {
    _verify = (t) => ApiService.instance.verifyLivePlanPayment(t);
    _pendingMsg = 'Payment is still being confirmed. Your live plan will activate automatically once it succeeds.';
    return _run(() => ApiService.instance.createLivePlanOrder(category: category, planName: planName));
  }

  /// Rs1 now + Rs10/month autopay (PayU Standing Instruction).
  Future<PayuResult> paySubscription() {
    _verify = (t) => ApiService.instance.verifySubscriptionPayment(t);
    _pendingMsg = 'Payment is still being confirmed. Your subscription will start automatically once it succeeds.';
    return _run(() => ApiService.instance.startSubscription());
  }

  Future<PayuResult> _run(Future<Map<String, dynamic>> Function() createOrder) async {
    PayuTrace.start();
    Map<String, dynamic> p;
    Map<String, dynamic>? si;
    try {
      final res = await createOrder();
      if (res['payu'] is! Map) {
        throw Exception((res['message'] ?? 'Server did not return payment details.').toString());
      }
      p = Map<String, dynamic>.from(res['payu'] as Map);
      if (res['si'] is Map) si = Map<String, dynamic>.from(res['si'] as Map);
      _txnid = p['txnid'].toString();
    } catch (e) {
      _t('[PayU] create-order failed: $e');
      _t('[PayU] FINISHED create-order error');
      return PayuResult('error', e.toString());
    }

    _done = Completer<PayuResult>();

    // The SDK crashes / hangs on a null value, so every value is forced to a String.
    String v(dynamic x) => (x ?? '').toString();
    final Map<String, dynamic> params = {
      PayUPaymentParamKey.key: v(p['key']),
      PayUPaymentParamKey.amount: v(p['amount']),
      PayUPaymentParamKey.productInfo: v(p['productinfo']),
      PayUPaymentParamKey.firstName: v(p['firstname']),
      PayUPaymentParamKey.email: v(p['email']),
      PayUPaymentParamKey.phone: v(p['phone']),
      PayUPaymentParamKey.environment: v(p['environment']), // "0" = production
      PayUPaymentParamKey.transactionId: v(p['txnid']),
      PayUPaymentParamKey.userCredential: '${v(p['key'])}:${v(p['userId'])}',
      PayUPaymentParamKey.android_surl: v(p['surl']),
      PayUPaymentParamKey.android_furl: v(p['furl']),
      PayUPaymentParamKey.ios_surl: v(p['surl']),
      PayUPaymentParamKey.ios_furl: v(p['furl']),
    };
    _t('[PayU] params: key=${v(p['key']).isEmpty ? 'EMPTY' : 'ok'} amount=${v(p['amount'])} '
        'env=${v(p['environment'])} surl=${v(p['surl'])} phone=${v(p['phone']).length} si=${si != null}');
    // Autopay details (subscription only). Server decides every value.
    if (si != null) {
      params[PayUPaymentParamKey.payUSIParams] = {
        PayUSIParamsKeys.isFreeTrial: si['isFreeTrial'] == true,
        PayUSIParamsKeys.billingAmount: si['billingAmount'].toString(),
        PayUSIParamsKeys.billingInterval: si['billingInterval'].toString(),
        PayUSIParamsKeys.paymentStartDate: si['paymentStartDate'].toString(),
        PayUSIParamsKeys.paymentEndDate: si['paymentEndDate'].toString(),
        PayUSIParamsKeys.billingCycle: si['billingCycle'].toString(),
        PayUSIParamsKeys.remarks: si['remarks'].toString(),
        PayUSIParamsKeys.billingCurrency: si['billingCurrency'].toString(),
        PayUSIParamsKeys.billingLimit: si['billingLimit'].toString(),
        PayUSIParamsKeys.billingRule: si['billingRule'].toString(),
      };
    }
    final config = {
      PayUCheckoutProConfigKeys.merchantName: 'TubePilot',
      PayUCheckoutProConfigKeys.showExitConfirmationOnCheckoutScreen: true,
    };

    try {
      _t('[PayU] Opening checkout txn=$_txnid');
      _pro.openCheckoutScreen(payUPaymentParams: params, payUCheckoutProConfig: config);
    } catch (e) {
      _t('[PayU] open failed: $e');
      _t('[PayU] FINISHED open failed');
      return PayuResult('error', 'Could not open checkout: $e');
    }

    return _done!.future.timeout(const Duration(minutes: 10), onTimeout: () => _confirm(_txnid, attempts: 2));
  }

  Future<PayuResult> _confirm(String txnid, {int attempts = 6, String? sdkMsg}) async {
    try {
      for (var i = 1; i <= attempts; i++) {
        _t('[PayU] Verifying $txnid attempt $i/$attempts');
        final res = await _verify(txnid);
        final status = (res['status'] ?? '').toString();
        if (status == 'approved') return const PayuResult('approved');
        if (status == 'failed') return PayuResult('failed', sdkMsg ?? 'Payment was not completed.');
        if (i < attempts) await Future.delayed(const Duration(seconds: 3));
      }
      return PayuResult('pending', _pendingMsg);
    } catch (e) {
      return PayuResult('error', sdkMsg ?? e.toString());
    }
  }

  void _finish(PayuResult r) {
    _t('[PayU] FINISHED ${r.status} ${r.message}');
    if (_done != null && !_done!.isCompleted) _done!.complete(r);
  }

  // ---------------- PayUCheckoutProProtocol ----------------
  @override
  generateHash(Map response) async {
    final name = response['hashName']?.toString() ?? '';
    _t('[PayU] hash requested: $name');
    try {
      final r = await ApiService.instance.payuHash(
        hashName: name,
        hashString: response['hashString']?.toString() ?? '',
        hashType: response['hashType']?.toString(),
        postSalt: response['postSalt']?.toString(),
      );
      final h = (r['hash'] ?? '').toString();
      if (h.isEmpty) throw Exception('empty hash from server');
      _pro.hashGenerated(hash: {name: h});
    } catch (e) {
      // Without an answer the SDK would show its loader forever. Give it an empty hash (it then
      // reports onError) and end the payment with a clear message.
      _t('[PayU] hash failed for $name: $e');
      try {
        _pro.hashGenerated(hash: {name: ''});
      } catch (_) {}
      _finish(PayuResult('error', 'Could not start payment ($name). Please try again.'));
    }
  }

  @override
  onPaymentSuccess(dynamic response) async {
    _t('[PayU] onPaymentSuccess');
    _finish(await _confirm(_txnid)); // never trust the SDK alone
  }

  @override
  onPaymentFailure(dynamic response) async {
    _t('[PayU] onPaymentFailure: $response');
    _finish(await _confirm(_txnid, attempts: 2, sdkMsg: 'Payment failed. Please try again.'));
  }

  @override
  onPaymentCancel(Map? response) async {
    _t('[PayU] onPaymentCancel');
    final r = await _confirm(_txnid, attempts: 1);
    _finish(r.status == 'pending' ? const PayuResult('cancelled', 'Payment cancelled.') : r);
  }

  @override
  onError(Map? response) async {
    _t('[PayU] onError: $response');
    final r = await _confirm(_txnid, attempts: 1, sdkMsg: 'Checkout error: ${response ?? ''}');
    _finish(r.status == 'pending' ? PayuResult('error', 'Checkout error: ${response ?? ''}') : r);
  }
}