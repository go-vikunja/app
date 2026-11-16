import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _log = Logger('AppLicenses');

/// The licence page's entries that Flutter's own collection (the Dart
/// packages, the engine and the repository's `LICENSE`) does not see.
abstract final class LegalAssets {
  /// The app's own notice; its package name is [ownLicensePackage].
  static const ownNotice = 'assets/legal/vikunja_app.md';

  /// The npm packages in the editor page, from `tool/build_editor.sh`.
  static const editor = 'assets/editor/NOTICES.md';

  /// The code that `vikunja_logic` translated from other projects.
  static const portedCode = 'packages/vikunja_logic/THIRD_PARTY_NOTICES.md';

  static const materialIcons = 'assets/legal/material_icons.md';

  /// The Android libraries, from `tool/build_android_notices.py`.
  static const android = 'assets/legal/android.md';
}

/// The workspace root's package name, under which Flutter's build lists the
/// repository's `LICENSE`, the MIT License; the app's own notice joins it
/// there.
const ownLicensePackage = 'vikunja_app';

var _registered = false;

/// Adds [appLicenses] to the [LicenseRegistry] once. The assets are read
/// only when the licence page asks for them.
void registerAppLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(
    () => appLicenses(rootBundle, platform: defaultTargetPlatform),
  );
}

/// The Android libraries only on Android. An asset that cannot be read is
/// left out, so that the rest of the page still shows.
Stream<LicenseEntry> appLicenses(
  AssetBundle bundle, {
  required TargetPlatform platform,
}) async* {
  for (final asset in [
    LegalAssets.ownNotice,
    LegalAssets.editor,
    LegalAssets.portedCode,
    LegalAssets.materialIcons,
    if (platform == TargetPlatform.android) LegalAssets.android,
  ]) {
    if (await _read(bundle, asset) case final notices?) {
      yield* Stream.fromIterable(parseNotices(notices));
    }
  }
}

Future<String?> _read(AssetBundle bundle, String asset) async {
  try {
    return await bundle.loadString(asset, cache: false);
  } on Object catch (error) {
    _log.warning('Could not read $asset: ${error.runtimeType}');
    return null;
  }
}

/// The licences in a notices file: each fenced block is one licence, for
/// the package of the `## ` heading above it or for the packages of the
/// `- ` list right above it, each item's first word being the name
/// (`- name version (licence)`), or the words in backticks it starts with.
/// Anything else is prose and skipped.
List<LicenseEntry> parseNotices(String markdown) {
  final entries = <LicenseEntry>[];
  var packages = <String>[];
  var inList = false;
  List<String>? text;
  for (final line in const LineSplitter().convert(markdown)) {
    final fence = line.startsWith('```');
    if (text != null) {
      if (!fence) {
        text.add(line);
        continue;
      }
      if (packages.isNotEmpty && text.isNotEmpty) {
        entries.add(LicenseEntryWithLineBreaks(packages, text.join('\n')));
      }
      packages = [];
      text = null;
    } else if (fence) {
      text = [];
      inList = false;
    } else if (line.startsWith('## ')) {
      packages = [line.substring(3).trim()];
      inList = false;
    } else if (line.startsWith('- ')) {
      if (!inList) packages = [];
      inList = true;
      packages.add(_listItemName(line.substring(2).trim()));
    } else {
      inList = false;
    }
  }
  return entries;
}

String _listItemName(String item) {
  final quotedEnd = item.startsWith('`') ? item.indexOf('`', 1) : -1;
  return quotedEnd > 1 ? item.substring(1, quotedEnd) : item.split(' ').first;
}
