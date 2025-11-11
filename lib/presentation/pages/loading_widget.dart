import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';


class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 32),
            Text(
            AppLocalizations.of(context).loading,
            style: Theme.of(context).textTheme.titleLarge,
          ),],
        ),
      ),
    );
  }
}
