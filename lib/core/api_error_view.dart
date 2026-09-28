import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'api_exception.dart';

/// The one place that decides how an error from any screen's `.when(error:
/// ...)` branch gets shown. Milestone 12's error-handling audit asked for
/// distinct treatment of 401 (session expired → re-auth) and 429 (throttled
/// → "too many attempts" messaging) rather than a bare `Text(error.toString())`
/// everywhere — this widget is that distinct treatment, applied uniformly
/// instead of screen-by-screen.
class ApiErrorView extends StatelessWidget {
  const ApiErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final apiError = error;
    if (apiError is UnauthorizedException) {
      return _ErrorCard(
        icon: Icons.lock_outline,
        message: 'Your session has expired. Please sign in again.',
        actionLabel: 'Sign in',
        onAction: () => context.push('/sign-in'),
      );
    }
    if (apiError is ThrottledException) {
      return const _ErrorCard(
        icon: Icons.hourglass_bottom,
        message: 'Too many attempts. Please wait a minute and try again.',
      );
    }
    return _ErrorCard(
      icon: Icons.error_outline,
      message: apiError is ApiException
          ? apiError.message
          : apiError.toString(),
      actionLabel: onRetry == null ? null : 'Retry',
      onAction: onRetry,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
