import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _widgetsAsScreens =
    'the home-screen widgets show tasks as the screens do: grouped, '
    'formatted and named by the same code (architecture.md, Layers)';

/// The imports from core/ up into features/ or app/ that are intended, by
/// file and target, each with its reason.
const _allowedUpward = <String, Map<String, String>>{
  'core/widgets/widget_snapshot_builder.dart': {
    'app/theme/legible_color.dart':
        "the widgets draw a project's colour with the lightness the app's "
        'folders get (decision log: Look and layout)',
    'features/overview/application/due_date_groups.dart': _widgetsAsScreens,
    'features/projects/application/project_access.dart': _widgetsAsScreens,
    'features/projects/application/project_list_model.dart': _widgetsAsScreens,
    'features/projects/application/project_tree.dart': _widgetsAsScreens,
    'features/tasks/application/default_project.dart': _widgetsAsScreens,
    'features/tasks/application/display_settings.dart': _widgetsAsScreens,
    'features/tasks/presentation/moment_formatter.dart': _widgetsAsScreens,
    'features/tasks/presentation/task_meta.dart': _widgetsAsScreens,
  },
  'core/widgets/widget_texts.dart': {
    'features/tasks/application/display_settings.dart': _widgetsAsScreens,
    'features/tasks/presentation/moment_formatter.dart': _widgetsAsScreens,
    'features/tasks/presentation/task_formatting.dart': _widgetsAsScreens,
    'features/tasks/presentation/task_meta.dart': _widgetsAsScreens,
  },
};

/// The localisation every part of the app starts from, the headless entry
/// points included, so core/ may use it; it stays a leaf with [_leaves].
const _localisation = 'app/l10n/';

/// What may import nothing of the app but the generated localisations and
/// each other.
const _leaves = <String>[_localisation, 'app/layout/'];

/// What core/ may import of the app: itself and the localisations; all
/// else, main.dart included, is above it.
const _coreLevel = <String>['core/', 'l10n/', _localisation];

const _package = 'package:vikunja_mobile/';

final _directive = RegExp(
  r'''^\s*(?:import|export)\s+(['"][^;]*);''',
  multiLine: true,
);
final _condition = RegExp(r'\bif\s*\([^)]*\)');
final _quoted = RegExp(r'''(['"])(.+?)\1''');

/// Every URI of a directive: the first and each conditional alternative.
Iterable<String> _uris(String directive) => _quoted
    .allMatches(directive.replaceAll(_condition, ' '))
    .map((match) => match[2]!);

/// What breaks the layers in [lib]: core/ importing from above it (other
/// than [_coreLevel] and [allowed]), a relative import in core/ that a
/// check by package path would miss, [_leaves] importing more, bootstrap/
/// imported from outside main.dart and bootstrap/, and an entry of
/// [allowed] that matches no import or gives no reason.
List<String> layerViolations(
  Directory lib, {
  Map<String, Map<String, String>> allowed = _allowedUpward,
}) {
  final violations = <String>[];
  final used = <String>{};
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File ||
        !entity.path.endsWith('.dart') ||
        entity.path.endsWith('.g.dart')) {
      continue;
    }
    final path = p.posix.joinAll(
      p.split(p.relative(entity.path, from: lib.path)),
    );
    for (final uri in [
      for (final match in _directive.allMatches(entity.readAsStringSync()))
        ..._uris(match[1]!),
    ]) {
      if (!uri.startsWith('package:') && !uri.startsWith('dart:')) {
        if (path.startsWith('core/')) violations.add('$path: relative $uri');
        continue;
      }
      if (!uri.startsWith(_package)) continue;
      final target = uri.substring(_package.length);
      if (path.startsWith('core/') && !_coreLevel.any(target.startsWith)) {
        if (allowed[path]?.containsKey(target) ?? false) {
          used.add('$path -> $target');
        } else {
          violations.add('$path -> $target');
        }
      }
      if (_leaves.any(path.startsWith) &&
          !target.startsWith('l10n/') &&
          !_leaves.any(target.startsWith)) {
        violations.add('$path -> $target');
      }
      if (target.startsWith('bootstrap/') &&
          !path.startsWith('bootstrap/') &&
          path != 'main.dart') {
        violations.add('$path -> $target');
      }
    }
  }
  for (final MapEntry(key: path, value: targets) in allowed.entries) {
    for (final MapEntry(key: target, value: reason) in targets.entries) {
      if (reason.trim().isEmpty) violations.add('no reason: $path -> $target');
      if (!used.contains('$path -> $target')) {
        violations.add('stale: $path -> $target');
      }
    }
  }
  return violations..sort();
}

void main() {
  test('core imports only core, l10n and app/l10n, main.dart and '
      "conditional imports' alternatives included, beyond the listed "
      'exceptions', () {
    expect(
      layerViolations(Directory('lib')),
      isEmpty,
      reason:
          'core is below every feature: move the code it needs into core, '
          'or list the import in _allowedUpward with its reason. A "stale" '
          'entry no longer matches an import: remove it',
    );
  });

  test('the check finds an import upward, the entry file and a '
      "conditional import's alternative included, a relative one, a leaf "
      'that imports more, bootstrap reached from elsewhere and a stale or '
      'unexplained exception', () {
    final lib = Directory.systemTemp.createTempSync('layer_imports');
    addTearDown(() => lib.deleteSync(recursive: true));
    void write(String path, String text) => (File(
      p.join(lib.path, path),
    )..createSync(recursive: true)).writeAsStringSync(text);
    write('core/a.dart', '''
import 'dart:async';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/b.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';
import "package:vikunja_mobile/features/x/application/y.dart";
export 'package:vikunja_mobile/app/theme/theme.dart';
import '../features/z.dart';
import 'package:vikunja_mobile/main.dart';
import 'package:vikunja_mobile/core/io_stub.dart'
    if (dart.library.io) 'package:vikunja_mobile/features/io.dart'
    if (dart.library.js_interop) "package:vikunja_mobile/core/web.dart";
export 'package:vikunja_mobile/core/d.dart' if (dart.library.io) 'package:vikunja_mobile/app/e.dart' show D;
part 'a.g.dart';
''');
    write('core/settings.dart', '''
import 'package:vikunja_mobile/core/b.dart';

final page = SettingsPage(
  export: _export.value,
  title: 'Export to features/x.dart',
  link: 'package:vikunja_mobile/features/y.dart',
);
''');
    write('core/a.g.dart', '''
import 'package:vikunja_mobile/features/generated_only.dart';
''');
    write('core/widgets/listed.dart', '''
import 'package:vikunja_mobile/features/tasks/task_meta.dart';
''');
    write('app/l10n/l10n.dart', '''
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/c.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';
''');
    write('features/x/application/y.dart', '''
import 'package:vikunja_mobile/bootstrap/start_values.dart';
import 'package:vikunja_mobile/core/a.dart';
''');
    write('main.dart', '''
import 'package:vikunja_mobile/bootstrap/bootstrap.dart';
''');

    expect(
      layerViolations(
        lib,
        allowed: {
          'core/widgets/listed.dart': {
            'features/tasks/task_meta.dart': 'a reason',
            'features/tasks/gone.dart': 'a reason',
          },
          'core/a.dart': {'features/x/application/y.dart': ' '},
        },
      ),
      [
        'app/l10n/l10n.dart -> core/c.dart',
        'core/a.dart -> app/e.dart',
        'core/a.dart -> app/theme/theme.dart',
        'core/a.dart -> features/io.dart',
        'core/a.dart -> main.dart',
        'core/a.dart: relative ../features/z.dart',
        'features/x/application/y.dart -> bootstrap/start_values.dart',
        'no reason: core/a.dart -> features/x/application/y.dart',
        'stale: core/widgets/listed.dart -> features/tasks/gone.dart',
      ],
    );
  });
}
