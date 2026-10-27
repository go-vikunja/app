import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _repoRoot = '..';

const _osvReusableWorkflow =
    'google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml'
    '@b1d267aea5211fa648d9d442fa64b90dbdcbdd36';

// What GitHub accepts on a job that calls a reusable workflow.
const _callerJobKeys = {
  'name',
  'uses',
  'with',
  'secrets',
  'permissions',
  'if',
  'needs',
  'strategy',
  'concurrency',
};

void main() {
  final workflows = _yamlFiles(Directory('$_repoRoot/.github/workflows'));
  final actions = Directory('$_repoRoot/.github/actions')
      .listSync()
      .whereType<Directory>()
      .expand(_yamlFiles)
      .toList();
  final allFiles = [...workflows, ...actions];

  test('finds the workflows and the composite action', () {
    expect(workflows.map(_name), containsAll(['ci.yaml', 'osv.yaml']));
    expect(actions, isNotEmpty);
  });

  test('every remote action and reusable workflow is pinned to a commit', () {
    final usesLine = RegExp(
      r'^\s*(?:-\s+)?uses:\s*(\S+)(.*)$',
      multiLine: true,
    );
    final pinnedRef = RegExp(r'^[\w.-]+/[\w.-]+(?:/[\w./-]+)?@[0-9a-f]{40}$');
    final versionComment = RegExp(r'^\s+# v\d');
    var remote = 0;

    for (final file in allFiles) {
      for (final match in usesLine.allMatches(file.readAsStringSync())) {
        final ref = match.group(1)!;
        if (ref.startsWith('./')) continue;
        remote++;
        expect(
          pinnedRef.hasMatch(ref) && versionComment.hasMatch(match.group(2)!),
          isTrue,
          reason: '${_name(file)}: $ref${match.group(2)}',
        );
      }
    }
    expect(remote, greaterThan(5));
  });

  test('every checkout leaves no credentials behind', () {
    var checkouts = 0;

    for (final file in allFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'uses:\s*actions/checkout@').hasMatch(lines[i])) {
          continue;
        }
        checkouts++;
        expect(
          _stepAround(lines, i),
          contains(matches(r'^\s*persist-credentials:\s*false\s*$')),
          reason: '${_name(file)}:${i + 1}',
        );
      }
    }
    expect(checkouts, greaterThan(0));
  });

  test('every workflow sets its permissions at the top level', () {
    for (final file in workflows) {
      expect(
        _blocks(file.readAsLinesSync()),
        contains('permissions'),
        reason: _name(file),
      );
    }
  });

  test('every script and file a workflow runs exists', () {
    final repoPath = RegExp(r'(?:^|[\s"])((?:tool|test_servers)/[\w./-]+)');
    final paths = {
      for (final file in allFiles)
        for (final match in repoPath.allMatches(file.readAsStringSync()))
          match.group(1)!,
    };

    expect(paths, contains('tool/check_exported_components.py'));
    for (final path in paths) {
      expect(File('$_repoRoot/$path').existsSync(), isTrue, reason: path);
    }
  });

  test("the DCO check that judges a pull request is the base commit's", () {
    final dco = _file(workflows, 'dco.yaml').readAsStringSync();

    expect(
      dco,
      contains(
        r'git show "$BASE_SHA:tool/check_dco.py" > "$RUNNER_TEMP/check_dco.py"',
      ),
    );
    expect(
      dco,
      contains(
        r'python3 -I "$RUNNER_TEMP/check_dco.py" --repository '
        r'"$GITHUB_WORKSPACE" "$BASE_SHA" "$HEAD_SHA"',
      ),
    );
    expect(dco, isNot(contains(r'tool/check_dco.py "$BASE_SHA"')));
  });

  test('CI runs on changes only, not on the weekly schedule', () {
    final ci = _blocks(_file(workflows, 'ci.yaml').readAsLinesSync());

    expect(_blocks(_body(ci['on']!)), isNot(contains('schedule')));
  });

  group('vulnerability scan', () {
    final osv = _blocks(_file(workflows, 'osv.yaml').readAsLinesSync());
    final jobs = _blocks(_body(osv['jobs']!));
    final job = _blocks(_body(jobs['osv-scan']!));
    final inputs = _blocks(_body(job['with']!));

    test('runs on changes and weekly', () {
      final triggers = _blocks(_body(osv['on']!));

      expect(
        triggers.keys,
        containsAll(['push', 'pull_request', 'workflow_dispatch', 'schedule']),
      );
      expect(
        _body(triggers['schedule']!),
        contains(matches(r'^\s*- cron: "[\d ]+\* \* \d"$')),
      );
    });

    test('grants nothing at the top level', () {
      expect(_value(osv['permissions']!), '{}');
    });

    test('is one job calling the pinned reusable workflow', () {
      expect(jobs.keys, ['osv-scan']);
      expect(job.keys.toSet().difference(_callerJobKeys), isEmpty);
      expect(_value(job['uses']!), _osvReusableWorkflow);
    });

    test('grants exactly what the reusable workflow requests', () {
      final permissions = {
        for (final entry in _blocks(_body(job['permissions']!)).entries)
          entry.key: _value(entry.value),
      };

      expect(permissions, {
        'actions': 'read',
        'contents': 'read',
        'security-events': 'write',
      });
    });

    test('fails on a vulnerability', () {
      expect(_value(inputs['fail-on-vuln']!), 'true');
    });

    test('scans the committed lockfiles', () {
      final args = _body(inputs['scan-args']!).map((line) => line.trim());
      final files = [
        for (final arg in args)
          if (arg.startsWith('--lockfile=') || arg.startsWith('--config='))
            arg.substring(arg.indexOf('=') + 1),
      ];

      // The reusable workflow sets these itself.
      expect(args, isNot(contains(startsWith('--format'))));
      expect(args, isNot(contains(startsWith('--output'))));
      expect(
        files,
        containsAll([
          'pubspec.lock',
          'app/editor/package-lock.json',
          'app/android/app/gradle.lockfile',
        ]),
      );
      for (final path in files) {
        expect(File('$_repoRoot/$path').existsSync(), isTrue, reason: path);
      }
    });
  });
}

List<File> _yamlFiles(Directory directory) =>
    directory
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.endsWith('.yaml') || file.path.endsWith('.yml'),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

String _name(File file) => file.uri.pathSegments.last;

File _file(List<File> files, String name) =>
    files.singleWhere((file) => _name(file) == name);

int _indent(String line) => line.length - line.trimLeft().length;

bool _isContent(String line) {
  final trimmed = line.trimLeft();
  return trimmed.isNotEmpty && !trimmed.startsWith('#');
}

// The keys at the shallowest indentation of [lines], each with its own line
// followed by the lines nested under it. Enough for the block style these
// files use; flow mappings and anchors are not understood.
Map<String, List<String>> _blocks(List<String> lines) {
  final blocks = <String, List<String>>{};
  int? keyIndent;
  List<String>? current;

  for (final line in lines.where(_isContent)) {
    final indent = _indent(line);
    keyIndent ??= indent;
    if (indent < keyIndent) break;
    if (indent == keyIndent) {
      current = blocks[line.trim().split(':').first] = [line];
    } else {
      current!.add(line);
    }
  }
  return blocks;
}

List<String> _body(List<String> block) => block.sublist(1);

String _value(List<String> block) {
  final afterKey = block.first.substring(block.first.indexOf(':') + 1);
  final comment = afterKey.indexOf(' #');
  return (comment < 0 ? afterKey : afterKey.substring(0, comment)).trim();
}

// The lines of the list item (a step) that contains line [index].
List<String> _stepAround(List<String> lines, int index) {
  var start = index;
  while (start > 0 && !lines[start].trimLeft().startsWith('- ')) {
    start--;
  }
  final indent = _indent(lines[start]);
  var end = start + 1;
  while (end < lines.length &&
      (!_isContent(lines[end]) || _indent(lines[end]) > indent)) {
    end++;
  }
  return lines.sublist(start, end);
}
