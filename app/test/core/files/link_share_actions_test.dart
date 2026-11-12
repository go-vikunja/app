import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vikunja_mobile/core/files/link_share_actions.dart';

void main() {
  final url = Uri.parse('https://tasks.example.com/share/${'x' * 40}/auth');
  late List<ShareParams> shared;
  late ShareResultStatus status;

  PlatformLinkShareActions actions() => PlatformLinkShareActions(
    share: (params) async {
      shared.add(params);
      return ShareResult('raw', status);
    },
  );

  setUp(() {
    shared = [];
    status = ShareResultStatus.success;
  });

  test('hands the link to the share sheet as a URI with its subject and '
      'anchor', () async {
    const origin = Rect.fromLTWH(10, 20, 30, 40);

    expect(
      await actions().shareLink(url, subject: 'Garden', origin: origin),
      isTrue,
    );

    final params = shared.single;
    expect(params.uri, url);
    expect(params.text, isNull);
    expect(params.subject, 'Garden');
    expect(params.sharePositionOrigin, origin);
  });

  test('hands a text to the share sheet as text with its subject and '
      'anchor, without a URI', () async {
    const origin = Rect.fromLTWH(10, 20, 30, 40);

    expect(
      await actions().shareText(
        'Support details\nApp: 1.0.0',
        subject: 'Support details',
        origin: origin,
      ),
      isTrue,
    );

    final params = shared.single;
    expect(params.text, 'Support details\nApp: 1.0.0');
    expect(params.uri, isNull);
    expect(params.subject, 'Support details');
    expect(params.sharePositionOrigin, origin);

    status = ShareResultStatus.unavailable;
    expect(await actions().shareText('Support details'), isFalse);
  });

  test('a dismissed sheet counts as shown, a missing one does not', () async {
    status = ShareResultStatus.dismissed;
    expect(await actions().shareLink(url), isTrue);

    status = ShareResultStatus.unavailable;
    expect(await actions().shareLink(url), isFalse);
  });
}
