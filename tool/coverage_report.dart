// Summarises `coverage/lcov.info` per area and enforces a minimum.
//
// Generated code is excluded: `lib/l10n/gen/**` is machine-written
// localisation and `*.g.dart` is Riverpod codegen. Neither is meaningful to
// cover, and together they are over half the repository's lines.
import 'dart:io';

const _threshold = 80.0;

bool _isGenerated(String path) =>
    path.startsWith('lib/l10n/gen') || path.endsWith('.g.dart');

void main(List<String> args) {
  final file = File(args.isNotEmpty ? args.first : 'coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('No ${file.path}. Run: flutter test --coverage');
    exit(2);
  }

  final totals = <String, List<int>>{};
  String? current;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3);
      totals.putIfAbsent(current, () => [0, 0]);
    } else if (line.startsWith('DA:') && current != null) {
      final hits = int.parse(line.substring(3).split(',')[1]);
      totals[current]![0]++;
      if (hits > 0) totals[current]![1]++;
    }
  }

  final byArea = <String, List<int>>{};
  var found = 0;
  var hit = 0;
  for (final entry in totals.entries) {
    if (_isGenerated(entry.key)) continue;
    found += entry.value[0];
    hit += entry.value[1];
    final parts = entry.key.split('/');
    final area = parts.length > 2 ? parts.take(3).join('/') : entry.key;
    final totalsForArea = byArea.putIfAbsent(area, () => [0, 0]);
    totalsForArea[0] += entry.value[0];
    totalsForArea[1] += entry.value[1];
  }

  final areas = byArea.entries.toList()
    ..sort((a, b) => b.value[0].compareTo(a.value[0]));
  for (final area in areas) {
    if (area.value[0] == 0) continue;
    final percent = 100 * area.value[1] / area.value[0];
    stdout.writeln(
      '${percent.toStringAsFixed(1).padLeft(6)}%  '
      '${area.value[1].toString().padLeft(5)}/${area.value[0].toString().padRight(5)}  '
      '${area.key}',
    );
  }

  if (found == 0) {
    stderr.writeln(
      'No coverage data for non-generated code. Either the run produced '
      'nothing, or every measured file is excluded as generated.',
    );
    exit(2);
  }

  final percent = 100 * hit / found;
  stdout.writeln('');
  stdout.writeln(
    'TOTAL (excluding generated): $hit/$found = '
    '${percent.toStringAsFixed(1)}%',
  );

  if (percent < _threshold) {
    stderr.writeln('Coverage is below the $_threshold% threshold.');
    exit(1);
  }
}
