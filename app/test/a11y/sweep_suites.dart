import 'scenarios_account.dart';
import 'scenarios_onboarding.dart';
import 'scenarios_overlays.dart';
import 'scenarios_pages.dart';
import 'scenarios_pane.dart';
import 'scenarios_shell.dart';
import 'sweep_harness.dart';

/// Every scenario of the sweep, by the file that runs it:
/// `<name>_sweep_test.dart` sweeps `sweepSuites['<name>']`. The
/// completeness checks count what is here, so a scenario counts only once a
/// file sweeps it.
final Map<String, List<SweepScenario>> sweepSuites = {
  'shell': [...shellRouteScenarios, ...shellStateScenarios],
  'pages': [...pageRouteScenarios, ...guestStateScenarios],
  'account': [...accountRouteScenarios, ...accountStateScenarios],
  'onboarding': [...onboardingRouteScenarios, ...onboardingStateScenarios],
  'overlays': [...overlayScenarios, ...guestOverlayScenarios],
  'pane': paneRouteScenarios,
};
