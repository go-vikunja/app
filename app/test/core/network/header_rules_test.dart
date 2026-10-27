import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/network/header_rules.dart';

void main() {
  group('names', () {
    test('RFC 7230 tokens pass', () {
      for (final name in [
        'CF-Access-Client-Id',
        'X-Auth_Token',
        r"X-!#$%&'*+.^`|~",
      ]) {
        expect(HeaderRules.validateName(name), isNull, reason: name);
      }
    });

    test('anything else is refused', () {
      expect(HeaderRules.validateName(''), HeaderProblem.emptyName);
      for (final name in ['X Auth', 'X:Auth', 'X-Ä', 'X(1)', 'X\nY']) {
        expect(
          HeaderRules.validateName(name),
          HeaderProblem.invalidName,
          reason: name,
        );
      }
    });

    test('names the stack, Vikunja or the upgrade own are refused in any '
        'case', () {
      for (final name in [
        'Host',
        'authorization',
        'COOKIE',
        'Content-Length',
        'Content-Type',
        'Content-Encoding',
        'Transfer-Encoding',
        'Connection',
        'Upgrade',
        'User-Agent',
        'Accept',
        'Accept-Encoding',
        'Origin',
        'Range',
        'If-Range',
        'Expect',
        'TE',
        'Trailer',
        'Keep-Alive',
        'Cache-Control',
        'Proxy-Authorization',
        'proxy-anything',
        'Sec-WebSocket-Key',
        'Sec-Foo',
      ]) {
        expect(
          HeaderRules.validateName(name),
          HeaderProblem.reservedName,
          reason: name,
        );
      }
    });
  });

  group('values', () {
    test('visible ASCII with inner spaces and tabs passes, trimmed', () {
      expect(HeaderRules.validateValue('abc DEF\t123'), isNull);
      expect(HeaderRules.validateValue('  padded  '), isNull);
      expect(HeaderRules.normalizeValue('  padded\t'), 'padded');
      expect(
        HeaderRules.validateValue('x' * HeaderRules.maxValueLength),
        isNull,
      );
    });

    test('empty, too long and non-ASCII values are refused', () {
      expect(HeaderRules.validateValue('   '), HeaderProblem.emptyValue);
      expect(
        HeaderRules.validateValue('x' * (HeaderRules.maxValueLength + 1)),
        HeaderProblem.valueTooLong,
      );
      for (final value in [
        'secret value',
        'secret​value',
        'zero﻿width',
        'grüße',
        'line\r\nbreak',
        'nul\u0000byte',
        'del\u007F',
      ]) {
        expect(
          HeaderRules.validateValue(value),
          HeaderProblem.nonAscii,
          reason: value.runes.toString(),
        );
      }
    });
  });

  group('sets', () {
    test('duplicates ignoring case are refused', () {
      expect(
        HeaderRules.validateAll([('X-Token', 'a'), ('x-token', 'b')]),
        HeaderProblem.duplicateName,
      );
    });

    test('at most ten headers', () {
      expect(
        HeaderRules.validateAll([for (var i = 0; i < 10; i++) ('X-$i', 'v')]),
        isNull,
      );
      expect(
        HeaderRules.validateAll([for (var i = 0; i < 11; i++) ('X-$i', 'v')]),
        HeaderProblem.tooManyHeaders,
      );
    });

    test('the first problem in entry order', () {
      expect(
        HeaderRules.validateAll([('Host', 'a'), ('X', ' ')]),
        HeaderProblem.reservedName,
      );
    });
  });

  test('the Cloudflare Access preset names both service-token headers', () {
    expect(HeaderPreset.cloudflareAccessServiceToken.names, [
      'CF-Access-Client-Id',
      'CF-Access-Client-Secret',
    ]);
    for (final name in HeaderPreset.cloudflareAccessServiceToken.names) {
      expect(HeaderRules.validateName(name), isNull);
    }
    expect(HeaderPreset.custom.names, isEmpty);
  });
}
