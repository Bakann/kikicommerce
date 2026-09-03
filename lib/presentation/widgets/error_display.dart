import 'package:flutter/material.dart';

import '../../core/error/app_exception.dart';
import '../l10n/l10n_extension.dart';

class ErrorDisplay extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorDisplay({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final String message;
    if (error is NetworkException) {
      message = context.l10n.errorNetwork;
    } else if (error is ApiException) {
      message = context.l10n.errorServer;
    } else {
      message = context.l10n.errorGeneric(error.toString());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
