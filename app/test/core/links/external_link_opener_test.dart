import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';

void main() {
  test('web links are http(s) with a host', () {
    expect(isWebLink(Uri.parse('https://example.com/a')), isTrue);
    expect(isWebLink(Uri.parse('HTTP://example.com')), isTrue);
    expect(isWebLink(Uri.parse('https:///path')), isFalse);
    expect(isWebLink(Uri.parse('/tasks/12')), isFalse);
    expect(isWebLink(null), isFalse);
  });

  test('system links are the other schemes the web editor keeps', () {
    for (final link in [
      'mailto:anna@example.com',
      'tel:+491234',
      'sms:+491234',
      'MAILTO:anna@example.com',
      'xmpp:anna@example.com',
    ]) {
      expect(isSystemLink(Uri.parse(link)), isTrue, reason: link);
    }
    for (final link in [
      'javascript:alert(1)',
      'data:text/html,<script>alert(1)</script>',
      'vbscript:msgbox',
      'intent://scan#Intent;scheme=zxing;end',
      'file:///etc/passwd',
      'vikunja-dev.coderoftime.vikunja://task/12',
      'https://example.com',
    ]) {
      expect(isSystemLink(Uri.parse(link)), isFalse, reason: link);
    }
  });

  test('anything else is refused before it reaches the platform', () async {
    const opener = ExternalLinkOpener();

    for (final link in [
      'javascript:alert(1)',
      'intent://scan#Intent;scheme=zxing;end',
      'file:///etc/passwd',
    ]) {
      expect(await opener.open(Uri.parse(link)), isFalse, reason: link);
    }
  });
}
