import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/src/text/rich_text_parser.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

void main() {
  group('a host without a scheme gets https://', () {
    for (final (input, href) in [
      ('www.example.com', 'https://www.example.com'),
      ('example.com/docs?page=2#top', 'https://example.com/docs?page=2#top'),
      ('Example.COM', 'https://Example.COM'),
      ('example.com:8080', 'https://example.com:8080'),
      ('example.com:8080/a', 'https://example.com:8080/a'),
      ('localhost:3456/tasks/1', 'https://localhost:3456/tasks/1'),
      ('localhost', 'https://localhost'),
      ('192.168.1.20:3456', 'https://192.168.1.20:3456'),
      ('[::1]:8080/x', 'https://[::1]:8080/x'),
      ('bücher.de', 'https://bücher.de'),
      ('xn--bcher-kva.de', 'https://xn--bcher-kva.de'),
      ('  sub.example.org/a  ', 'https://sub.example.org/a'),
    ]) {
      test(input, () {
        expect(typedLinkAddress(input), LinkAddressAccepted(href));
      });
    }
  });

  test('an email address gets mailto:', () {
    expect(
      typedLinkAddress('anna@example.com'),
      const LinkAddressAccepted('mailto:anna@example.com'),
    );
  });

  group('a scheme the editor keeps stays as typed', () {
    for (final input in [
      'https://example.com',
      'HTTP://EXAMPLE.COM/A',
      'mailto:anna@example.com',
      'tel:+4912345',
      'ftp://files.example.com',
      'obsidian://open?vault=notes',
      'notion://www.notion.so/page',
      'message:%3Cid@example.com%3E',
      'git://example.com/repo.git',
    ]) {
      test(input, () {
        expect(typedLinkAddress(input), LinkAddressAccepted(input));
      });
    }
  });

  group('a relative address stays relative, as on the web', () {
    for (final input in [
      '/tasks/12',
      '#heading',
      '?page=2',
      './notes',
      '../notes',
      'notes',
      'tasks/12',
      'v1.2',
      'a.1',
      '//cdn.example.com/x',
    ]) {
      test(input, () {
        expect(typedLinkAddress(input), LinkAddressAccepted(input));
      });
    }
  });

  group('any other scheme is refused, named in lower case', () {
    for (final (input, scheme) in [
      ('javascript:alert(1)', 'javascript'),
      ('JavaScript:alert(1)', 'javascript'),
      ('java script:alert(1)', 'javascript'),
      ('java\u{2003}script:alert(1)', 'javascript'),
      ('data:text/html,<b>x</b>', 'data'),
      ('file:///etc/hosts', 'file'),
      ('vbscript:x', 'vbscript'),
      ('intent://scan/#Intent;end', 'intent'),
      ('example.com:abc', 'example.com'),
    ]) {
      test(input, () {
        expect(typedLinkAddress(input), LinkAddressRefused(scheme));
      });
    }
  });

  test('nothing for an empty or blank input', () {
    expect(typedLinkAddress(''), isNull);
    expect(typedLinkAddress(' \t\n'), isNull);
  });

  test('what it accepts, the web editor keeps as a link', () {
    for (final input in [
      'www.example.com',
      'anna@example.com',
      'tel:+4912345',
      '/tasks/12',
      'notes',
    ]) {
      final address = typedLinkAddress(input)! as LinkAddressAccepted;
      expect(allowedLinkHref(address.href), address.href, reason: input);
    }
  });
}
