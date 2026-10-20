import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the Flutter SDK's Roboto, so that text is measured as on an
/// Android phone instead of in the test font, whose glyphs are all one
/// em wide. False when the SDK's fonts are not there. Loaded for the whole
/// test file: call it in `setUpAll`.
Future<bool> loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return false;
  final loader = FontLoader('Roboto');
  for (final weight in const ['Regular', 'Medium', 'Bold']) {
    final file = File(
      '$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
    );
    if (!file.existsSync()) return false;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
  return true;
}
