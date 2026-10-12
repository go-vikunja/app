import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';

typedef QuickAddPlanner = QuickAddPlan Function(
  String line, {
  int? fallbackProjectId,
  DateTime? fallbackDueDate,
});

/// Quick add for widget tests. A `planner` decides every plan (by default
/// the line, trimmed, is the title and nothing is parsed, in [project]);
/// every `plan` and `submit` call is recorded. A submit answers [result],
/// or throws [submitError]; [beforeSubmit] can hold it.
final class FakeQuickAddService implements QuickAddService {
  new({
    this.project,
    this._planner,
    this.result = const QuickAddResult(createdTaskIds: [-1]),
  });

  final Project? project;
  final QuickAddPlanner? _planner;
  QuickAddResult result;
  Exception? submitError;
  Future<void> Function()? beforeSubmit;

  final List<({String line, int? fallbackProjectId})> plans = [];
  final List<({String text, int? fallbackProjectId, DateTime? fallbackDueDate})>
  submits = [];

  /// A plan of [line] with nothing recognised, in [project].
  static QuickAddPlan plainPlan(String line, {Project? project}) =>
      QuickAddPlan(
        input: line,
        parsed: ParsedTaskText(text: line.trim()),
        title: line.trim(),
        project: project,
      );

  @override
  QuickAddPlan plan(
    String line, {
    int? fallbackProjectId,
    DateTime? fallbackDueDate,
  }) {
    plans.add((line: line, fallbackProjectId: fallbackProjectId));
    return switch (_planner) {
      final planner? => planner(
        line,
        fallbackProjectId: fallbackProjectId,
        fallbackDueDate: fallbackDueDate,
      ),
      null => plainPlan(line, project: project),
    };
  }

  @override
  Future<QuickAddResult> submit(
    String text, {
    int? fallbackProjectId,
    DateTime? fallbackDueDate,
  }) async {
    submits.add((
      text: text,
      fallbackProjectId: fallbackProjectId,
      fallbackDueDate: fallbackDueDate,
    ));
    await beforeSubmit?.call();
    if (submitError case final error?) throw error;
    return result;
  }
}
