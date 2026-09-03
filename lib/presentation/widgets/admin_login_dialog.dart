import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/constants.dart';

class AdminLoginDialog extends ConsumerStatefulWidget {
  const AdminLoginDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const AdminLoginDialog(),
    );
  }

  @override
  ConsumerState<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

// Dev convenience: prefill the admin login form when these are provided
// via `--dart-define=ADMIN_DEV_EMAIL=... --dart-define=ADMIN_DEV_PASSWORD=...`.
// Empty by default so credentials never ship in the source or the binary.
const String _devAdminEmail = String.fromEnvironment('ADMIN_DEV_EMAIL');
const String _devAdminPassword = String.fromEnvironment('ADMIN_DEV_PASSWORD');

class _AdminLoginDialogState extends ConsumerState<AdminLoginDialog> {
  final _emailController = TextEditingController(text: _devAdminEmail);
  final _passwordController = TextEditingController(text: _devAdminPassword);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ref.read(authenticateAdminUserProvider)(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop(token);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Live Edit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activez le mode édition pour modifier le contenu de la boutique en temps réel. Vos changements seront visibles immédiatement.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            onSubmitted: (_) => _login(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(backgroundColor: kNavyBlue),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Connexion', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
