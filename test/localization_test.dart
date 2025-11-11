import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

void main() {
  group('AppLocalizations delegate direct load', () {
    test('loads English values', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.priorityHigh, 'High');
      expect(l10n.deleteBucketTitle, 'Delete Bucket');
    });

    test('loads Polish values', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('pl'));
      expect(l10n.priorityHigh, 'Wysoki');
      expect(l10n.deleteBucketTitle, 'Usuń kolumnę');
    });
  });
}
