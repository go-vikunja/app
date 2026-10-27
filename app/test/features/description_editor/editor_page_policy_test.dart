import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// The built editor page as the app bundles it (D52): checked here too, so
// that a page swapped without the editor's own Node tests is noticed.
void main() {
  final page = File('assets/editor/editor.html').readAsStringSync();

  String policy() {
    final meta = RegExp(
      r'''<meta\s+http-equiv="Content-Security-Policy"\s+content="([^"]*)"''',
      caseSensitive: false,
    ).allMatches(page).toList();
    expect(meta, hasLength(1), reason: 'exactly one CSP meta tag');
    return meta.single[1]!;
  }

  test('the content security policy blocks every load but the inline '
      'script it names', () {
    final directives = {
      for (final directive in policy().split(';'))
        if (directive.trim().split(RegExp(r'\s+')) case [
          final name,
          ...final values,
        ])
          name: values.join(' '),
    };

    expect(directives, {
      'default-src': "'none'",
      'script-src': matches(RegExp(r"^'sha256-[A-Za-z0-9+/]{43}='$")),
      'style-src': "'unsafe-inline'",
      'img-src': 'data:',
      'base-uri': "'none'",
      'form-action': "'none'",
    });
  });

  test("the script hash is the page's only inline script", () {
    final scripts = RegExp(
      r'<script\b([^>]*)>(.*?)</script>',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(page).toList();
    expect(scripts, hasLength(1));
    expect(scripts.single[1]!.trim(), isEmpty, reason: 'no src, no type');

    final hash = base64.encode(
      sha256.convert(utf8.encode(scripts.single[2]!)).bytes,
    );
    expect(policy(), contains("script-src 'sha256-$hash'"));
  });

  test('no element or style loads anything from the network', () {
    for (final pattern in [
      r'''\b(?:src|href|srcset|action|poster|data)\s*=\s*["']?\s*(?:https?:)?//''',
      r'''url\(\s*["']?\s*(?:https?:)?//''',
      '@import',
      r'<\s*(?:link|iframe|object|embed|frame|base)\b',
    ]) {
      expect(
        RegExp(pattern, caseSensitive: false).hasMatch(page),
        isFalse,
        reason: pattern,
      );
    }
  });
}
