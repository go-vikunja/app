import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:http/http.dart';

class VikunjaErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final Object error;

  const VikunjaErrorWidget({required this.error, this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 80),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 32.0,
              ),
              child: getErrorWidget(context, error),
            ),
            SizedBox(height: 32),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).retry),
              ),
          ],
        ),
      ),
    );
  }

  Widget getErrorWidget(BuildContext context, Object error) {
    switch (error) {
      case AsyncError(:final error):
        return getErrorWidget(context, error);
      case ClientException():
        return Text(
          AppLocalizations.of(context).connectionError,
          style: Theme.of(context).textTheme.titleLarge,
        );
      case TimeoutException():
        return Text(
          AppLocalizations.of(context).connectionTimeout,
          style: Theme.of(context).textTheme.titleLarge,
        );
      case String():
        return Text(error, style: Theme.of(context).textTheme.titleLarge);
      default:
        return Text(
          error.toString(),
          style: Theme.of(context).textTheme.titleLarge,
        );
    }
  }
}
