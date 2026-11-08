import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/app_brand_background.dart';
import '../widgets/app_decor.dart';
import '../widgets/app_popups.dart';
import 'dashboard_screen.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});
  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _usernameCtrl = TextEditingController();
  String _language = 'English';
  bool _loading = false;

  // NOTE: kept as language NAMES (not translated) since this list is sent
  // to the backend as-is and also drives ApiService.setupUsername(language: ...).
  final _languages = const [
    'English',
    'Hindi',
    'Hinglish',
    'Tamil',
    'Bengali',
    'Marathi',
    'Urdu'
  ];

  @override
  void initState() {
    super.initState();
    _prefillSuggestedUsername();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _prefillSuggestedUsername() {
    final user = context.read<AuthProvider>().user ?? {};
    String base = (user['name'] ?? '').toString().trim();
    if (base.isEmpty) {
      final email = (user['email'] ?? '').toString();
      base = email.contains('@') ? email.split('@').first : 'creator';
    }
    base = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (base.length < 3) base = 'creator';
    if (base.length > 15) base = base.substring(0, 15);
    final suffix = (DateTime.now().millisecondsSinceEpoch % 900 + 100).toString();
    _usernameCtrl.text = '${base}_$suffix';
  }

  // Language picker opens as a bottom sheet (drag handle + title + tick on the selected item).
  Future<void> _openLanguageSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.tr('select_language_label'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                ..._languages.map((lang) => ListTile(
                      title: Text(lang, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: lang == _language ? const Icon(Icons.check_rounded, color: AppColors.purple) : null,
                      onTap: () => Navigator.pop(sheetContext, lang),
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _language = selected);
    }
  }

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim().replaceFirst('@', '');
    if (username.length < 3) {
      showToast(context, context.tr('username_min_length_error'), isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().setupUsername(username: username, language: _language);
      if (!mounted) return;
      await _showReferralDialog();
      if (!mounted) return;
      // Connect-channel + Welcome popups now come from the Dashboard, AFTER the Rs1
      // payment popup (strict order: Rs1 -> Connect -> Welcome).
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Referral dialog (white).
  //   * empty box      -> stays open, shows "enter a code or tap Skip"
  //   * wrong/invalid  -> stays open, shows the backend's message under the box
  //   * valid code     -> success toast, then closes
  //   * "Skip"         -> the ONLY way to leave without a valid code
  Future<void> _showReferralDialog() async {
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
                        if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final avatar = auth.user?['avatar'];

    return Scaffold(
      // Same off-white base + watermark as Splash.
      backgroundColor: const Color(0xFFFAF7FC),
      body: AppBrandBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                Text(context.tr('setup_profile_title'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(gradient: AppColors.gradient, shape: BoxShape.circle),
                    child: avatar != null && avatar.toString().isNotEmpty
                        ? ClipOval(child: Image.network(avatar, fit: BoxFit.cover))
                        : const Center(child: Icon(Icons.person_rounded, color: Colors.white, size: 36)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(context.tr('username_label'),
                    style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
                const SizedBox(height: 4),
                Text(context.tr('username_suggested_hint'),
                    style: TextStyle(color: context.surfaces.textDim, fontSize: 11.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                      hintText: '@tech_creator', prefixIcon: Icon(Icons.alternate_email_rounded, size: 18)),
                ),
                const SizedBox(height: 16),
                Text(context.tr('select_language_label'),
                    style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
                const SizedBox(height: 6),
                // Bottom-sheet PickerField instead of CustomDropdown.
                PickerField(
                  value: _language,
                  onTap: _openLanguageSheet,
                  prefixIcon: const Icon(Icons.language_rounded, size: 18, color: AppColors.purple),
                ),
                const SizedBox(height: 30),
                GradientButton(label: context.tr('continue_btn'), loading: _loading, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
