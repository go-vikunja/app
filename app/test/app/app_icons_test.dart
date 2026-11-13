import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';
const Map<String, ({int launcher, int layer, int notification})> _sizes = {
  'mdpi': (launcher: 48, layer: 108, notification: 24),
  'hdpi': (launcher: 72, layer: 162, notification: 36),
  'xhdpi': (launcher: 96, layer: 216, notification: 48),
  'xxhdpi': (launcher: 144, layer: 324, notification: 72),
  'xxxhdpi': (launcher: 192, layer: 432, notification: 96),
};
const _blue = [0x19, 0x6A, 0xFF];

const _colourTypeRgb = 2;
const _colourTypeGreyAlpha = 4;
const _colourTypeRgba = 6;

({int width, int height, int colourType}) _header(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: path);
  expect(bytes.sublist(12, 16), 'IHDR'.codeUnits, reason: path);
  final data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colourType: bytes[25],
  );
}

Future<Uint8List> _straightRgba(WidgetTester tester, String path) async {
  final pixels = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    image.dispose();
    codec.dispose();
    return data!.buffer.asUint8List();
  });
  return pixels!;
}

void main() {
  test('launcher icons, adaptive layers and status bar icons have the size '
      'of their density', () {
    for (final MapEntry(key: density, value: sizes) in _sizes.entries) {
      final expected = {
        '$_res/mipmap-$density/ic_launcher.png': sizes.launcher,
        '$_res/drawable-$density/ic_launcher_background.png': sizes.layer,
        '$_res/drawable-$density/ic_launcher_foreground.png': sizes.layer,
        '$_res/drawable-$density/ic_launcher_monochrome.png': sizes.layer,
        '$_res/drawable-$density/ic_notification.png': sizes.notification,
      };
      for (final MapEntry(key: path, value: size) in expected.entries) {
        final header = _header(path);
        expect((header.width, header.height), (size, size), reason: path);
      }
    }
  });

  testWidgets('every status bar icon is white on transparency', (tester) async {
    for (final density in _sizes.keys) {
      final path = '$_res/drawable-$density/ic_notification.png';
      expect(
        _header(path).colourType,
        anyOf(_colourTypeGreyAlpha, _colourTypeRgba),
        reason: path,
      );

      final rgba = await _straightRgba(tester, path);
      final drawn = <int>[];
      final notWhite = <int>[];
      for (var i = 0; i < rgba.length; i += 4) {
        if (rgba[i + 3] == 0) continue;
        drawn.add(i ~/ 4);
        if (rgba[i] != 255 || rgba[i + 1] != 255 || rgba[i + 2] != 255) {
          notWhite.add(i ~/ 4);
        }
      }
      expect(notWhite, isEmpty, reason: path);
      expect(drawn.length, inExclusiveRange(0, rgba.length ~/ 4), reason: path);
    }
  });

  testWidgets('every adaptive background is Vikunja blue throughout', (
    tester,
  ) async {
    for (final density in _sizes.keys) {
      final path = '$_res/drawable-$density/ic_launcher_background.png';
      final rgba = await _straightRgba(tester, path);
      final offBlue = <int>[];
      for (var i = 0; i < rgba.length; i += 4) {
        // flutter_launcher_icons' scaling rounds a grid of pixels one step
        // down at hdpi.
        final near = [
          for (var channel = 0; channel < 3; channel++)
            (rgba[i + channel] - _blue[channel]).abs() <= 1,
        ];
        if (near.contains(false) || rgba[i + 3] != 255) offBlue.add(i ~/ 4);
      }
      expect(offBlue, isEmpty, reason: path);
    }
  });

  testWidgets('the App Store icon has no alpha channel and a blue corner', (
    tester,
  ) async {
    const path =
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png';
    final header = _header(path);
    expect((header.width, header.height), (1024, 1024));
    expect(header.colourType, _colourTypeRgb);

    final rgba = await _straightRgba(tester, path);
    expect(rgba.sublist(0, 4), [..._blue, 255]);
  });

  testWidgets('the in-app logo has its three sizes and transparent corners', (
    tester,
  ) async {
    const sizes = {
      'assets/branding/logo.png': 72,
      'assets/branding/2.0x/logo.png': 144,
      'assets/branding/3.0x/logo.png': 216,
    };
    for (final MapEntry(key: path, value: size) in sizes.entries) {
      final header = _header(path);
      expect((header.width, header.height), (size, size), reason: path);
      expect(header.colourType, _colourTypeRgba, reason: path);

      final rgba = await _straightRgba(tester, path);
      final corners = [0, size - 1, size * (size - 1), size * size - 1];
      expect(
        [for (final pixel in corners) rgba[pixel * 4 + 3]],
        [0, 0, 0, 0],
        reason: path,
      );
      final centre = size * (size ~/ 2) + size ~/ 2;
      expect(rgba[centre * 4 + 3], 255, reason: path);
    }
  });

  test('the logo source still has the hash its provenance records', () {
    final readme = File('../branding/README.md').readAsStringSync();
    final recorded = RegExp(r'\*\*SHA-256:\*\* `([0-9a-f]{64})`')
        .firstMatch(readme)
        ?.group(1);
    final source = File('../branding/source/logo.svg').readAsBytesSync();

    expect(recorded, isNotNull);
    expect(sha256.convert(source).toString(), recorded);
  });
}
