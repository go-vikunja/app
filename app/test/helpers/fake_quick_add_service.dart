import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_lines.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';

typedef QuickAddPlanner = QuickAddPlan Function(
  String line, {
  int? fallbackProjectId,
  DateTime? fallbackDueDate,
  int? fallbackPriority,
});

/// One recorded submit.
typedef QuickAddSubmit = ({
  String text,
  int? fallbackProjectId,
  DateTime? fallbackDueDate,
  int? fallbackPriority,
  QuickAddExtras extras,
});

/// Quick add for widget tests. A `planner` decides every plan (by default
/// the line, trimmed, is the title and nothing is parsed, in [project]),
/// and `inherited` the project a subtask takes from its parent (by
/// default none); every `plan` and `submit` call is recorded. A submit
/// answers [result], with each line's planned title when it names no
/// titles, or throws [submitError]; [beforeSubmit] can hold it.
final class FakeQuickAddService implements QuickAddService {
  new({
    this.project,
    this._planner,
    this._inherited,
    this.result = const QuickAddResult(createdTaskIds: [-1]),
  });

  final Project? project;
  final QuickAddPlanner? _planner;
  final int? Function(IndentedLine line)? _inherited;
  QuickAddResult result;
  Exception? submitError;
  Future<void> Function()? beforeSubmit;

  final List<({String line, int? fallbackProjectId})> plans = [];
  final List<QuickAddSubmit> submits = [];

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
    int? fallbackPriority,
  }) {
    plans.add((line: line, fallbackProjectId: fallbackProjectId));
    return _planned(
      line,
      fallbackProjectId: fallbackProjectId,
      fallbackDueDate: fallbackDueDate,
      fallbackPriority: fallbackPriority,
    );
  }

  @override
  int? inheritedProjectId(IndentedLine line) => _inherited?.call(line);

  QuickAddPlan _planned(
    String line, {
    int? fallbackProjectId,
    DateTime? fallbackDueDate,
    int? fallbackPriority,
  }) => switch (_planner) {
    final planner? => planner(
      line,
      fallbackProjectId: fallbackProjectId,
      fallbackDueDate: fallbackDueDate,
      fallbackPriority: fallbackPriority,
    ),
    null => plainPlan(line, project: project),
  };

  @override
  Future<QuickAddResult> submit(
    String text, {
    int? fallbackProjectId,
    DateTime? fallbackDueDate,
    int? fallbackPriority,
    QuickAddExtras extras = const QuickAddExtras(),
  }) async {
    submits.add((
      text: text,
      fallbackProjectId: fallbackProjectId,
      fallbackDueDate: fallbackDueDate,
      fallbackPriority: fallbackPriority,
      extras: extras,
    ));
    await beforeSubmit?.call();
    if (submitError case final error?) throw error;
    final result = this.result;
    if (result.createdTitles.isNotEmpty) return result;
    return QuickAddResult(
      createdTaskIds: result.createdTaskIds,
      createdTitles: [
        for (final line in splitQuickAddLines(
          text,
        ).take(result.createdTaskIds.length))
          _planned(
            line,
            fallbackProjectId: fallbackProjectId,
            fallbackDueDate: fallbackDueDate,
            fallbackPriority: fallbackPriority,
          ).title,
      ],
      labelsNotCreated: result.labelsNotCreated,
      labelsKept: result.labelsKept,
      unresolvedAssignees: result.unresolvedAssignees,
    );
  }
}
