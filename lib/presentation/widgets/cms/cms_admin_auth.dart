import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/edit_mode_provider.dart';
import '../admin_login_dialog.dart';

/// Returns the current admin token if present; otherwise opens the
/// [AdminLoginDialog], stores the resulting token in [adminAuthTokenProvider]
/// and returns it. Returns `null` if the user dismisses the login dialog.
///
/// When [enableEditMode] is true and a fresh token was obtained via the dialog,
/// also flips [editModeProvider] to true.
Future<String?> ensureAdminToken(
  BuildContext context,
  WidgetRef ref, {
  bool enableEditMode = false,
}) async {
  final existing = ref.read(adminAuthTokenProvider);
  if (existing != null && existing.isNotEmpty) return existing;
  final fresh = await AdminLoginDialog.show(context);
  if (fresh == null || fresh.isEmpty) return null;
  ref.read(adminAuthTokenProvider.notifier).state = fresh;
  if (enableEditMode) {
    ref.read(editModeProvider.notifier).state = true;
  }
  return fresh;
}
