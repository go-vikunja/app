import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

typedef _Vector = ({
  String raw,
  DeviceKind kind,
  String? app,
  String? build,
  String? browser,
  String? os,
  String? osVersion,
});

_Vector _v(
  String raw,
  DeviceKind kind, {
  String? app,
  String? build,
  String? browser,
  String? os,
  String? osVersion,
}) => (
  raw: raw,
  kind: kind,
  app: app,
  build: build,
  browser: browser,
  os: os,
  osVersion: osVersion,
);

final List<_Vector> _rurana = [
  // What ClientIdentity.userAgent sends: Platform.operatingSystem in lower
  // case.
  _v(
    'Rurana/0.31.0+42 (android 15)',
    DeviceKind.rurana,
    app: '0.31.0',
    build: '42',
    os: 'Android',
    osVersion: '15',
  ),
  _v(
    'Rurana/1.0.0+7 (ios 17.4)',
    DeviceKind.rurana,
    app: '1.0.0',
    build: '7',
    os: 'iOS',
    osVersion: '17.4',
  ),
  _v(
    'Rurana/0.31.0+1 (Android 15)',
    DeviceKind.rurana,
    app: '0.31.0',
    build: '1',
    os: 'Android',
    osVersion: '15',
  ),
  _v(
    'Rurana/0.31.0 (android 14)',
    DeviceKind.rurana,
    app: '0.31.0',
    os: 'Android',
    osVersion: '14',
  ),
  _v(
    'Rurana/0.31.0+3 (android)',
    DeviceKind.rurana,
    app: '0.31.0',
    build: '3',
    os: 'Android',
  ),
  _v('Rurana/0.31.0+3 ()', DeviceKind.rurana, app: '0.31.0', build: '3'),
  _v('Rurana/0.31.0+3', DeviceKind.rurana, app: '0.31.0', build: '3'),
  _v(
    'Rurana/0.31.0-beta.2+5 (macos 15.1)',
    DeviceKind.rurana,
    app: '0.31.0-beta.2',
    build: '5',
    os: 'macOS',
    osVersion: '15.1',
  ),
  _v(
    'Rurana/0.31.0+5 (haiku r1)',
    DeviceKind.rurana,
    app: '0.31.0',
    build: '5',
    os: 'haiku',
    osVersion: 'r1',
  ),
  _v(
    '  Rurana/2.0.0+9 (ios 18.0)\n',
    DeviceKind.rurana,
    app: '2.0.0',
    build: '9',
    os: 'iOS',
    osVersion: '18.0',
  ),
];

final List<_Vector> _browsers = [
  _v(
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
    DeviceKind.browser,
    browser: 'Chrome',
    os: 'Windows',
  ),
  _v(
    'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:115.0) Gecko/20100101 '
    'Firefox/115.0',
    DeviceKind.browser,
    browser: 'Firefox',
    os: 'Windows',
    osVersion: '7',
  ),
  _v(
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0',
    DeviceKind.browser,
    browser: 'Edge',
    os: 'Windows',
  ),
  _v(
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/18.0 Safari/605.1.15',
    DeviceKind.browser,
    browser: 'Safari',
    os: 'macOS',
  ),
  _v(
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:140.0) Gecko/20100101 '
    'Firefox/140.0',
    DeviceKind.browser,
    browser: 'Firefox',
    os: 'macOS',
  ),
  _v(
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36',
    DeviceKind.browser,
    browser: 'Chrome',
    os: 'macOS',
    osVersion: '10.13.6',
  ),
  _v(
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0',
    DeviceKind.browser,
    browser: 'Edge',
    os: 'macOS',
  ),
  _v(
    'Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0',
    DeviceKind.browser,
    browser: 'Firefox',
    os: 'Linux',
  ),
  _v(
    'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:139.0) Gecko/20100101 '
    'Firefox/139.0',
    DeviceKind.browser,
    browser: 'Firefox',
    os: 'Linux',
  ),
  _v(
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/141.0.0.0 Safari/537.36',
    DeviceKind.browser,
    browser: 'Chrome',
    os: 'Linux',
  ),
  _v(
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0',
    DeviceKind.browser,
    browser: 'Edge',
    os: 'Linux',
  ),
  _v(
    'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
    DeviceKind.browser,
    browser: 'Chrome',
    os: 'ChromeOS',
  ),
  // Chrome's reduced User-Agent always claims Android 10 on a device "K".
  _v(
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36',
    DeviceKind.browser,
    browser: 'Chrome',
    os: 'Android',
  ),
  _v(
    'Mozilla/5.0 (Android 15; Mobile; rv:140.0) Gecko/140.0 Firefox/140.0',
    DeviceKind.browser,
    browser: 'Firefox',
    os: 'Android',
    osVersion: '15',
  ),
  _v(
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36 '
    'EdgA/141.0.0.0',
    DeviceKind.browser,
    browser: 'Edge',
    os: 'Android',
  ),
  _v(
    'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 '
    '(KHTML, like Gecko) SamsungBrowser/28.0 Chrome/130.0.0.0 Mobile '
    'Safari/537.36',
    DeviceKind.browser,
    browser: 'Samsung Internet',
    os: 'Android',
    osVersion: '14',
  ),
  _v(
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 '
    'Safari/604.1',
    DeviceKind.browser,
    browser: 'Safari',
    os: 'iOS',
    osVersion: '18.6',
  ),
  _v(
    'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
    DeviceKind.browser,
    browser: 'Safari',
    os: 'iOS',
    osVersion: '17.4',
  ),
  _v(
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/141.0.7390.96 '
    'Mobile/15E148 Safari/604.1',
    DeviceKind.browser,
    browser: 'Chrome',
    os: 'iOS',
    osVersion: '18.6',
  ),
  _v(
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/144.0 Mobile/15E148 '
    'Safari/605.1.15',
    DeviceKind.browser,
    browser: 'Firefox',
    os: 'iOS',
    osVersion: '18.6',
  ),
  _v(
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 EdgiOS/141.0 '
    'Mobile/15E148 Safari/605.1.15',
    DeviceKind.browser,
    browser: 'Edge',
    os: 'iOS',
    osVersion: '18.6',
  ),
  _v(
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 OPR/124.0.0.0',
    DeviceKind.browser,
    browser: 'Opera',
    os: 'Windows',
  ),
  _v('Mozilla/5.0', DeviceKind.browser),
  _v('Mozilla/5.0 (compatible; Konqueror/4.5; NetBSD)', DeviceKind.browser),
];

final List<_Vector> _others = [
  _v('Dart/3.9 (dart:io)', DeviceKind.dartClient, app: '3.9'),
  _v('Dart/3.13 (dart:io)', DeviceKind.dartClient, app: '3.13'),
  _v('', DeviceKind.other),
  _v('   ', DeviceKind.other),
  _v('Rurana contract tests', DeviceKind.other),
  _v('Rurana fixture capture', DeviceKind.other),
  _v('rurana-step31-probe', DeviceKind.other),
  _v('curl/8.7.1', DeviceKind.other),
  _v('python-requests/2.32.3', DeviceKind.other),
  _v('Rurana/', DeviceKind.other),
  _v('Rurana/(android 15)', DeviceKind.other),
  _v('Rurana/1.0 (a (b) c)', DeviceKind.other),
  _v('Dart/', DeviceKind.other),
  _v('Dart/abc', DeviceKind.other),
  _v('\u0000\u202e\uffff 日本 😀', DeviceKind.other),
];

void _expectVector(_Vector vector) {
  final description = describeUserAgent(vector.raw);
  expect(
    (
      description.kind,
      description.appVersion,
      description.appBuild,
      description.browserName,
      description.osName,
      description.osVersion,
    ),
    (
      vector.kind,
      vector.app,
      vector.build,
      vector.browser,
      vector.os,
      vector.osVersion,
    ),
    reason: vector.raw,
  );
  expect(description.raw, vector.raw.trim());
}

void main() {
  group('describeUserAgent', () {
    test("reads Rurana's own User-Agent", () {
      _rurana.forEach(_expectVector);
    });

    test('reads the browsers of the web logins', () {
      _browsers.forEach(_expectVector);
    });

    test('Dart clients without their own User-Agent, and everything else '
        'with the raw text only', () {
      _others.forEach(_expectVector);
    });

    test('never throws on garbage and stays fast on long input', () {
      final random = Random(31);
      final pieces = [
        'Mozilla/5.0 (',
        'iPhone',
        ' OS ',
        'Android ',
        'Rurana/',
        'Dart/',
        '+',
        '(',
        ')',
        ';',
        '_',
        '10',
        'Mac OS X ',
        'Windows NT ',
        '\u0000',
        '😀',
        ' ',
      ];
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 2000; i++) {
        final text = List.generate(
          random.nextInt(40),
          (_) => pieces[random.nextInt(pieces.length)],
        ).join();
        expect(describeUserAgent(text).raw, text.trim());
      }
      final long = 'Mozilla/5.0 (iPhone${' x' * 100000} Android 1${';' * 1000}';
      expect(describeUserAgent(long).kind, DeviceKind.browser);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });
}
