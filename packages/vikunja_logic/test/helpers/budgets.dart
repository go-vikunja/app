import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A time budget is checked only with `VIKUNJA_BENCHMARK=1`: on a busy
/// machine a correct run can take several times as long. Otherwise the
/// time is only printed.
void expectWithinBudget(int milliseconds, int budget, String what) {
  // ignore: avoid_print, every run shows the measured time.
  print('$what: $milliseconds ms (budget $budget ms)');
  if (Platform.environment['VIKUNJA_BENCHMARK'] == '1') {
    expect(milliseconds, lessThan(budget), reason: what);
  }
}
