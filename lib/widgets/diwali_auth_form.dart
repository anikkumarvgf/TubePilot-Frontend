import 'package:flutter/material.dart';
import 'diwali_decor.dart';

/// Complete Diwali Sign-up screen UI (all art drawn in code).
/// Wire your existing logic through the callbacks / controllers.
class DiwaliAuthForm extends StatefulWidget {
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback? onSwitch; // "Already have an account? Login"
  final bool loading;
  final String title;
  final String submitLabel;
  final bool showName;
  const DiwaliAuthForm({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    required this.onSubmit,
    required this.onGoogle,
    this.onSwitch,
    this.loading = false,
    this.title = 'Create Account',
    this.submitLabel = 'Sign Up',
    this.showName = true,
  });

  @override
  State<DiwaliAuthForm> createState() => _DiwaliAuthFormState();
}

class _DiwaliAuthFormState extends State<DiwaliAuthForm> {
  bool _hide = true;

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: DiwaliColors.purple),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: DiwaliColors.gold.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DiwaliColors.purple, width: 1.6),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DiwaliAuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 56, 28, 40),
            child: Column(
              children: [
                Image.asset('assets/splash.png', width: 84, height: 84,
                    errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_outline_rounded, size: 80, color: DiwaliColors.purple)),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                    children: [
                      TextSpan(text: 'Tube', style: TextStyle(color: Color(0xFF1B0F20))),
                      TextSpan(text: 'Pilot', style: TextStyle(color: DiwaliColors.purple)),
                    ],
                  ),
                ),
                const Text('Your YouTube Growth Partner', style: TextStyle(color: DiwaliColors.textDim)),
                const SizedBox(height: 18),
                const DiwaliTitleOrnament(),
                Text(widget.title, style: const TextStyle(color: DiwaliColors.purpleDark, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const DiwaliLotusDivider(width: 190),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: widget.onGoogle,
                  icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFDB4437))),
                  label: const Text('Sign up with Google', style: TextStyle(color: DiwaliColors.purpleDark, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    side: BorderSide(color: DiwaliColors.gold.withValues(alpha: 0.7)),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.showName) ...[
                  TextField(controller: widget.name, decoration: _dec('Full Name', Icons.person_outline)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: widget.email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('Email', Icons.mail_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.password,
                  obscureText: _hide,
                  decoration: _dec('Password', Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: DiwaliColors.textDim),
                        onPressed: () => setState(() => _hide = !_hide),
                      )),
                ),
                const SizedBox(height: 22),
                DiwaliAuthButton(label: widget.submitLabel, onPressed: widget.onSubmit, loading: widget.loading),
                if (widget.onSwitch != null) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: widget.onSwitch,
                    child: const Text('Already have an account? Login',
                        style: TextStyle(color: DiwaliColors.purple, fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(height: 150),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
