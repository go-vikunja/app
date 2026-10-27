import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const domains = [
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
  ];
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();
  final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
      .readAsStringSync()
      .replaceAll(RegExp('<!--.*?-->', dotAll: true), '');

  String applicationTag() =>
      RegExp(r'<application\b[^>]*>', dotAll: true).firstMatch(manifest)![0]!;

  test('the application keeps backups off and names the extraction rules', () {
    final application = applicationTag();

    expect(application, contains('android:allowBackup="false"'));
    expect(
      application,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(application, isNot(contains('android:fullBackupContent')));
  });

  for (final section in ['cloud-backup', 'device-transfer']) {
    test('$section excludes every domain and includes nothing', () {
      final body = RegExp(
        '<$section>(.*?)</$section>',
        dotAll: true,
      ).firstMatch(rules)?[1];
      expect(body, isNotNull, reason: '<$section> is missing');

      final excluded = [
        for (final match in RegExp(
          r'<exclude\s+domain="([a-z_]+)"\s+path="([^"]*)"\s*/>',
        ).allMatches(body!))
          (match[1]!, match[2]!),
      ];
      expect(excluded.map((e) => e.$1), unorderedEquals(domains));
      expect(excluded.map((e) => e.$2), everyElement('.'));
      expect(
        RegExp(r'<exclude\b').allMatches(body).length,
        domains.length,
        reason: 'every exclude names a domain and path "."',
      );
    });
  }

  test('no rule includes anything or opens another transfer', () {
    expect(rules, isNot(contains('<include')));
    // Android 16 QPR2's transfer to iOS; absent means nothing is offered.
    expect(rules, isNot(contains('<cross-platform-transfer')));
    expect(
      RegExp(r'<(cloud-backup|device-transfer)\s[^>]*>').hasMatch(rules),
      isFalse,
      reason:
          'no attribute such as disableIfNoEncryptionCapabilities '
          'narrows a section',
    );
  });
}
