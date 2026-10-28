import 'scenarios_pane.dart';
import 'sweep_harness.dart';
import 'sweep_suites.dart';

void main() {
  sweep(sweepSuites['pane']!);
  sweepFoldable(paneFoldableScenarios);
}
