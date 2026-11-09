import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'app_decor.dart';
import 'app_popups.dart';
import 'common.dart';

// Referral dialog (white).
//   * empty box      -> stays open, shows "enter a code or tap Skip"
//   * wrong/invalid  -> stays open, shows the backend's message under the box
//   * valid code     -> success toast, then closes
//   * "Skip"         -> the ONLY way to leave without a valid code
Future<void> showReferralDialog(BuildContext context) async {
  final referralCtrl = TextEditingController();
  bool submitting = false;
  String? errorText;

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AppDialog(
        icon: Icons.card_giftcard_rounded,
        title: context.tr('referral_dialog_title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('referral_dialog_body')),
            const SizedBox(height: 14),
            TextField(
              controller: referralCtrl,
              enabled: !submitting,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiColors.inkBlack, fontWeight: FontWeight.w700, letterSpacing: 1),
              onChanged: (_) {
                if (errorText != null) setDialogState(() => errorText = null);
              },
              decoration: InputDecoration(
                hintText: 'e.g. 102458XK9F2',
                errorText: errorText,
                errorMaxLines: 3,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: UiColors.cardBorder),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: UiColors.cardBorder.withValues(alpha: 0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: UiColors.plum, width: 1.6),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
                ),
              ),
            ),
          ],
        ),
        actions: [
          AppDialogButton(
            label: context.tr('skip'),
            primary: false,
            onPressed: submitting ? null : () => Navigator.pop(dialogContext),
          ),
          const SizedBox(width: 10),
          AppDialogButton(
            label: context.tr('apply'),
            loading: submitting,
            onPressed: submitting
                ? null
                : () async {
                    final code = referralCtrl.text.trim();
                    if (code.isEmpty) {
                      setDialogState(() => errorText = 'Please enter a referral code, or tap Skip.');
                      return;
                    }
                    setDialogState(() {
                      submitting = true;
                      errorText = null;
                    });
                    try {
                      final res = await ApiService.instance.applyReferralCode(code);
                      // Even a 200 response can mean "not matched" (success:false) -> stay open.
                      if (res['success'] == false) {
                        final failMsg = (res['message'] ?? '').toString().trim();
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            submitting = false;
                            errorText = failMsg.isNotEmpty
                                ? failMsg
                                : 'Referral code did not match. Please check and try again.';
                          });
                        }
                        return;
                      }
                      if (context.mounted) {
                        showToast(context, res['message'] ?? context.tr('referral_applied'), isSuccess: true);
                      }
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      final msg = (e is ApiException && e.message.trim().isNotEmpty)
                          ? e.message
                          : 'Referral code did not match. Please check and try again.';
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          submitting = false;
                          errorText = msg;
                        });
                      }
                    }
                  },
          ),
        ],
      ),
    ),
  );
}
