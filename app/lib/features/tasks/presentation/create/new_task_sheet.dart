import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/quick_add/application/project_references.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_lines.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_service_provider.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_suggestions.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_text_controller.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_tokens.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/quick_add_help_sheet.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/quick_add_preview.dart';
import 'package:vikunja_mobile/features/share/application/share_text.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/application/reminder_editing.dart';
import 'package:vikunja_mobile/features/tasks/application/repeat_editor.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/labels_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/reminders_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/repeat_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/shortcut_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

final _log = Logger('NewTaskSheet');

/// The quick way to new tasks: one line per task with Quick Add Magic, the
/// project the tasks go to unless a line names one, optionally a due date
/// and a priority for lines without their own, and under "More options" a
/// description, labels, reminders and a repeat for every task. [projectId]
/// preselects the list's own project; with [column] the tasks that go to
/// it are placed on top of that board column.
Future<void> showNewTaskSheet(
  BuildContext context, {
  int? projectId,
  NewTaskColumn? column,
}) => showModalBottomSheet<void>(
  context: context,
  // Over the tab bar, not inside the tab's own navigator.
  useRootNavigator: true,
  routeSettings: const RouteSettings(name: newTaskSheetRouteName),
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => NewTaskSheet(projectId: projectId, column: column),
);

/// The board column a project's new tasks go on top of.
@immutable
final class NewTaskColumn {
  const new({
    required this.viewId,
    required this.bucketId,
    required this.defaultBucket,
    this.topPosition,
    this.done = false,
    this.room,
  });

  final int viewId;
  final int bucketId;

  /// Where the server puts the tasks the column has no room for, and
  /// reopens a repeating task marked done.
  final Bucket defaultBucket;

  /// The position of the column's first card; null when it is empty.
  final double? topPosition;

  /// The view's done column, whose tasks are done.
  final bool done;

  /// How many more tasks the column takes; null without a limit.
  final int? room;
}

/// The New task sheet's route, so that the app shortcut does not stack a
/// second one on it.
const newTaskSheetRouteName = 'new-task';

const Set<DateShortcut> _quickShortcuts = {
  DateShortcut.today,
  DateShortcut.tomorrow,
  DateShortcut.nextWeek,
};

// The checkmark goes in the avatar's fixed box; without an avatar it takes
// a square as tall as the label, which grows with the text size.
const _chipIconBox = BoxConstraints.tightFor(width: 20, height: 20);

final List<TaskPriority> _priorities = [
  for (final priority in TaskPriority.values)
    if (priority != TaskPriority.unset) priority,
];

class NewTaskSheet extends ConsumerStatefulWidget {
  const new({this.projectId, this.column, super.key});

  final int? projectId;
  final NewTaskColumn? column;

  @override
  ConsumerState<NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends ConsumerState<NewTaskSheet> {
  final _text = MagicTextEditingController();
  final _description = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final GlobalKey _moreOptionsKey = GlobalKey();
  final GlobalKey _repeatAmountKey = GlobalKey();
  int? _pickedProjectId;
  DateTime? _due;
  int? _priority;
  bool _moreOptions = false;
  List<Label> _labels = const [];
  List<TaskReminder> _reminders = const [];
  RepeatSetting _repeat = RepeatSetting.none;
  bool _adding = false;
  String? _error;

  // After a partly failed add the sheet stays open for the rest, which
  // goes above what was placed and into the room that is left.
  late double? _columnTop = widget.column?.topPosition;
  late int? _columnRoom = widget.column?.room;

  // The plans of the lines typed so far, valid for what they were made with.
  QuickAddService? _service;
  QuickAddMagicMode _mode = QuickAddMagicMode.vikunja;
  QuickAddPrefixes? _prefixes;
  int? _fallbackId;
  DateTime? _plannedDue;
  int? _plannedPriority;
  DateTime? _plannedAt;
  final _plans = <String, QuickAddPlan>{};

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _text.dispose();
    _description.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() => _error = null);

  void _usePlanner({
    required QuickAddService? service,
    required QuickAddMagicMode mode,
    required QuickAddPrefixes? prefixes,
    required int? fallbackId,
    required DateTime now,
  }) {
    final minute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    if (!identical(service, _service) ||
        prefixes != _prefixes ||
        fallbackId != _fallbackId ||
        _due != _plannedDue ||
        _priority != _plannedPriority ||
        minute != _plannedAt ||
        _plans.length > 500) {
      _plans.clear();
    }
    _service = service;
    _mode = mode;
    _prefixes = prefixes;
    _fallbackId = fallbackId;
    _plannedDue = _due;
    _plannedPriority = _priority;
    _plannedAt = minute;
    _text.highlighter = service == null || prefixes == null ? null : _highlight;
  }

  QuickAddPlan? _plan(String line) {
    final cached = _plans[line];
    if (cached != null) return cached;
    final plan = _service?.plan(
      line,
      fallbackProjectId: _fallbackId,
      fallbackDueDate: _due,
      fallbackPriority: _priority,
    );
    if (plan != null) _plans[line] = plan;
    return plan;
  }

  List<MagicSpan> _lineSpans(String line) {
    final prefixes = _prefixes;
    final plan = _plan(line);
    if (prefixes == null || plan == null) return const [];
    return magicSpansForLine(line, plan, prefixes);
  }

  List<MagicSpan> _highlight(String text) => switch (_prefixes) {
    final prefixes? => magicSpansOf(text, prefixes, _plan),
    null => const [],
  };

  void _edit(TextEditingValue value) {
    _text.value = value;
    _focus.requestFocus();
  }

  void _removeParts(MagicSpanKind kind, {Iterable<String>? items}) {
    final lines = magicLines(_text.text);
    if (lines.isEmpty) return;
    final first = lines.first;
    final wanted = items?.map((item) => item.toLowerCase()).toSet();
    final spans = [
      for (final span in _lineSpans(first.text))
        if (span.kind == kind &&
            (wanted == null || wanted.contains(span.item?.toLowerCase())))
          span.shifted(first.offset),
    ];
    if (spans.isNotEmpty) _edit(removeMagicSpans(_text.value, spans));
  }

  Future<void> _showHelp(
    QuickAddMagicMode mode,
    QuickAddPrefixes prefixes,
    DateTime now,
  ) async {
    await showQuickAddHelp(
      context,
      mode: mode,
      prefixes: prefixes,
      now: now,
      guest: ref.read(activeAccountIsGuestProvider),
    );
    if (mounted) _focus.requestFocus();
  }

  Future<void> _pickProject(List<Project> projects, int? selectedId) async {
    final picked = await pickProject(
      context,
      projects: projects,
      selectedId: selectedId,
    );
    if (picked != null && mounted) setState(() => _pickedProjectId = picked.id);
  }

  Future<void> _pickDue(DateTime now) async {
    final picked = await pickDateTime(
      context,
      current: _due,
      now: now,
      display: ref.read(displaySettingsProvider),
    );
    if (picked != null && mounted) setState(() => _due = picked.toUtc());
  }

  /// What a relative reminder refers to: the first line's due date.
  ReminderDates get _reminderDates {
    final lines = magicLines(_text.text);
    final plan = lines.isEmpty ? null : _plan(lines.first.text);
    return (due: plan?.dueDate ?? _due, start: null, end: null);
  }

  /// A new label is created on Add, like a typed one.
  Future<void> _pickLabels() async {
    final picked = await pickLabels(
      context,
      selected: _labels,
      createLater: true,
    );
    if (picked != null && mounted) setState(() => _labels = picked);
  }

  /// Adds a reminder, or replaces the one at [index]; one the list already
  /// has is not added twice.
  Future<void> _pickReminder({int? index}) async {
    final picked = await pickReminder(
      context,
      dates: _reminderDates,
      now: ref.read(clockProvider)(),
      editing: index == null ? null : _reminders[index],
      existing: _reminders,
    );
    if (picked == null || !mounted) return;
    final reminders = withReminder(_reminders, picked, replacing: index);
    if (reminders != null) setState(() => _reminders = reminders);
  }

  void _toggleMoreOptions() {
    _setMoreOptions(expanded: !_moreOptions);
    if (!_moreOptions) return;
    // The first field comes into view under the rows above it.
    _afterLayout(() {
      final context = _moreOptionsKey.currentContext;
      if (context == null || !context.mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: kThemeAnimationDuration,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _setMoreOptions({required bool expanded}) {
    // The scroll direction flips with the form; each starts at its anchor.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _moreOptions = expanded);
  }

  void _afterLayout(VoidCallback callback) => WidgetsBinding.instance
    ..addPostFrameCallback((_) => callback())
    ..ensureVisualUpdate();

  /// Shows the invalid repeat that keeps the tasks from being added.
  void _revealInvalidRepeat() {
    final error = context.l10n.repeatAmountInvalid;
    if (_moreOptions) {
      announce(context, error);
    } else {
      _setMoreOptions(expanded: true);
      // The field's error, shown now, is a live region of its own.
      Announcer.of(context).say(error, onlyIfPlatformAnnounces: true);
    }
    _afterLayout(
      () => _repeatAmountKey.currentContext?.findRenderObject()?.showOnScreen(
        duration: kThemeAnimationDuration,
      ),
    );
  }

  QuickAddExtras get _extras => QuickAddExtras(
    description: sharedTextHtml(_description.text),
    labels: [
      for (final label in _labels)
        if (!isLabelToCreate(label)) label,
    ],
    newLabels: [
      for (final label in _labels)
        if (isLabelToCreate(label)) label.title,
    ],
    reminders: _reminders,
    repeatAfter: _repeat.repeatAfter,
    repeatMode: _repeat.repeatMode,
  );

  Future<void> _add() async {
    final service = _service;
    final text = _text.text;
    final lines = splitQuickAddLines(text, mode: _mode);
    if (_adding || service == null || lines.isEmpty) return;
    if (!_repeat.isValid) {
      _revealInvalidRepeat();
      return;
    }
    final l10n = context.l10n;
    final fallbackId = _fallbackId;
    final plans = [for (final line in lines) _plan(line)!];
    if (plans.any((plan) => plan.project == null)) {
      setState(() => _error = l10n.newTaskNoProjectError);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repository = ref.read(taskRepositoryProvider);
    final prefixes = _prefixes;
    setState(() {
      _adding = true;
      _error = null;
    });

    final QuickAddResult result;
    try {
      result = await service.submit(
        text,
        fallbackProjectId: fallbackId,
        fallbackDueDate: _due,
        fallbackPriority: _priority,
        extras: _extras,
      );
    } on QuickAddPartlyFailed catch (partly) {
      _log.warning(
        'Quick add failed after ${partly.createdTaskIds.length} of '
        '${partly.lineCount} lines: ${partly.cause.runtimeType}',
      );
      final left = await _placeInColumn(repository, partly.createdTaskIds);
      if (!mounted) return;
      // The lines added are queued; only the rest may be added again.
      _text.value = TextEditingValue(
        text: partly.remainingText,
        selection: TextSelection.collapsed(offset: partly.remainingText.length),
      );
      final added = l10n.newTaskAddedPartly(
        partly.createdTaskIds.length,
        partly.lineCount,
      );
      setState(() {
        _adding = false;
        _error = [
          added,
          ?_leftInDefaultColumn(l10n, left),
          _failureText(l10n, partly.cause),
        ].join(' ');
      });
      return;
    } on Object catch (error) {
      _log.warning('Quick add failed: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _adding = false;
        _error = _failureText(l10n, error);
      });
      return;
    }
    final left = await _placeInColumn(repository, result.createdTaskIds);
    if (!mounted) return;
    navigator.pop();

    final warnings = [
      ?_leftInDefaultColumn(l10n, left),
      if (result.labelsNotCreated.isNotEmpty)
        l10n.newTaskLabelsNotCreated(result.labelsNotCreated.join(', ')),
      if (result.labelsKept.isNotEmpty)
        l10n.newTaskLabelsKept(result.labelsKept.join(', ')),
      if (result.unresolvedAssignees.isNotEmpty)
        l10n.newTaskNamesKept(
          [
            for (final name in result.unresolvedAssignees)
              '${prefixes?.assignee ?? ''}$name',
          ].join(', '),
        ),
    ];
    final created = result.createdTaskIds;
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: warnings.isEmpty ? 4 : 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              created.length == 1
                  ? l10n.newTaskCreated(
                      _createdTitle(plans.first, result, prefixes),
                    )
                  : l10n.newTaskCreatedMany(created.length),
            ),
            for (final warning in warnings) Text(warning),
          ],
        ),
      ),
    );
  }

  /// Queues the board placement of the [created] tasks that went to the
  /// column's project, as many as the column has room for, and returns how
  /// many did not fit: those stay in the default column, as the server
  /// would refuse to move them. A line naming another project leaves its
  /// task there; a repeating task added to the done column is marked done
  /// as a drop there does (`MarkCardDone`).
  Future<int> _placeInColumn(
    TaskRepository? repository,
    List<int> created,
  ) async {
    final column = widget.column;
    if (column == null || repository == null || created.isEmpty) return 0;
    var left = 0;
    try {
      final placed = <int>[];
      final reopened = <int>[];
      for (final id in created) {
        final task = await repository.watchTask(id).first;
        if (task == null || task.projectId != widget.projectId) continue;
        if (column.done && task.repeats) {
          reopened.add(id);
        } else if (_columnRoom case final room? when placed.length >= room) {
          left++;
        } else {
          placed.add(id);
        }
      }
      final positions = positionsOnTop(_columnTop, count: placed.length);
      for (final (index, id) in placed.indexed) {
        await repository.placeTask(
          id,
          viewId: column.viewId,
          placement: BucketPlacement(
            bucketId: column.bucketId,
            position: positions[index],
          ),
          done: column.done ? true : null,
        );
      }
      for (final id in reopened) {
        await repository.placeTask(
          id,
          viewId: column.viewId,
          placement: BucketPlacement(bucketId: column.defaultBucket.id),
          done: true,
        );
      }
      _columnTop = positions.firstOrNull ?? _columnTop;
      if (_columnRoom case final room?) _columnRoom = room - placed.length;
    } on Object catch (error) {
      // The tasks are queued; without the placement they land in the
      // view's default column.
      _log.warning('Placing new tasks failed: ${error.runtimeType}');
    }
    return left;
  }

  String? _leftInDefaultColumn(AppLocalizations l10n, int count) =>
      switch (widget.column) {
        final column? when count > 0 => l10n.boardTasksLeftInDefaultColumn(
          count,
          column.defaultBucket.title,
        ),
        _ => null,
      };

  static String _failureText(AppLocalizations l10n, Object error) =>
      switch (error) {
        VikunjaFailure(:final message) when message.trim().isNotEmpty =>
          l10n.newTaskAddFailed(message.trim()),
        _ => l10n.newTaskAddFailedUnknown,
      };

  /// [plan]'s title as created: without the names the server search
  /// resolved, which are not always the ones the plan resolved, and with
  /// the labels that could not be created at its end.
  static String _createdTitle(
    QuickAddPlan plan,
    QuickAddResult result,
    QuickAddPrefixes? prefixes,
  ) {
    final title = _titleWithoutResolved(plan, result, prefixes);
    return [
      title,
      for (final token in result.labelsKept)
        if (!title.contains(token)) token,
    ].join(' ');
  }

  static String _titleWithoutResolved(
    QuickAddPlan plan,
    QuickAddResult result,
    QuickAddPrefixes? prefixes,
  ) {
    if (plan.magicOnly || prefixes == null) return plan.title;
    final unresolved = {
      for (final name in result.unresolvedAssignees) name.toLowerCase(),
    };
    final resolved = {
      for (final name in plan.parsed.assignees)
        if (!unresolved.contains(name.toLowerCase())) name.toLowerCase(),
    };
    final text = plan.parsed.text.trim();
    if (resolved.isEmpty) return text;
    final spans = [
      for (final token in prefixedTokens(text, prefixes.assignee))
        if (resolved.contains(token.item.toLowerCase()))
          MagicSpan(token.start, token.end, MagicSpanKind.assignee),
    ];
    final cleaned = removeMagicSpans(
      TextEditingValue(text: text),
      spans,
    ).text.trim();
    return cleaned.isEmpty ? text : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(clockProvider)();
    final service = ref.watch(quickAddServiceProvider);
    final settings =
        ref.watch(userSettingsProvider).value ?? const UserSettings();
    final mode = settings.quickAddMagicMode;
    final prefixes = quickAddPrefixes(mode);
    final projectsValue = ref.watch(projectsProvider);
    final projects = projectsValue.value ?? const <Project>[];
    final fallback = defaultProjectFor(
      projects,
      currentProjectId: _pickedProjectId ?? widget.projectId,
      defaultProjectId: settings.defaultProjectId,
    );
    _usePlanner(
      service: service,
      mode: mode,
      prefixes: prefixes,
      fallbackId: fallback?.id,
      now: now,
    );

    final lines = magicLines(_text.text);
    final taskLines = quickAddTaskLines(_text.text, mode: mode);
    final taskPlans = [for (final line in taskLines) ?_plan(line.text)];
    final taskCount = taskLines.length;
    final subtaskCount = taskLines
        .where((line) => line.parentIndex != null)
        .length;
    final plan = lines.isEmpty ? null : _plan(lines.first.text);
    // A fallback stays choosable while some line still goes without its
    // own value.
    bool everyLine(bool Function(QuickAddPlan plan) has) =>
        taskPlans.isNotEmpty && taskPlans.every(has);
    final textDue = everyLine((plan) => plan.dueDateFromText)
        ? taskPlans.first.dueDate
        : null;
    bool matchesProject(QuickAddPlan plan) =>
        !plan.magicOnly &&
        plan.parsed.project != null &&
        plan.unmatchedProject == null;
    // A subtask without a project of its own goes to its parent's.
    bool namesProject(int index) {
      final line = taskLines[index];
      if (matchesProject(taskPlans[index])) return true;
      final parent = line.parentIndex;
      return parent != null &&
          line.inheritedProject != null &&
          namesProject(parent);
    }

    final everyLineNamesProject =
        taskPlans.isNotEmpty &&
        taskPlans.length == taskCount &&
        Iterable<int>.generate(taskCount).every(namesProject);
    final matchedProject = everyLineNamesProject
        ? taskPlans.first.project
        : null;
    final project = matchedProject ?? fallback;
    final token = prefixes == null
        ? null
        : activeMagicToken(_text.value, prefixes);
    // Out of sight, an invalid repeat does not disable Add: Add shows it.
    final canAdd =
        service != null &&
        taskCount > 0 &&
        !_adding &&
        (plan?.project ?? project) != null &&
        (_repeat.isValid || !_moreOptions);
    final noProject = projectsValue.hasValue && project == null;
    final errorText = _error ?? (noProject ? l10n.newTaskNoProjectError : null);

    final shortcuts = [
      for (final option in buildDateShortcuts(now))
        if (_quickShortcuts.contains(option.shortcut)) option,
    ];
    final shownDue = textDue ?? _due;
    final dueLocal = shownDue?.toLocal();
    final dueDay = dueLocal == null
        ? null
        : DateTime(dueLocal.year, dueLocal.month, dueLocal.day);
    final dueOnShortcut = shortcuts.any((option) => option.day == dueDay);
    final dueLocked = textDue != null;
    final textPriority = everyLine((plan) => plan.priorityFromText)
        ? taskPlans.first.priority
        : null;
    final priorityLocked = textPriority != null;
    final shownPriority = textPriority ?? _priority;
    String titleOf(Project project) => project.displayTitle(l10n);
    final projectTitle = project == null
        ? l10n.newTaskNoProject
        : projectLabel(project, projects, titleOf: titleOf);
    final formatter = MomentFormatter.watch(context, ref);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Semantics(
            header: true,
            headingLevel: 1,
            child: Text(l10n.newTask, style: theme.textTheme.headlineSmall),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _text,
            focusNode: _focus,
            autofocus: true,
            // Several lines only when pasted; the action key adds.
            minLines: 1,
            maxLines: 6,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            // Curly quotes are no quotes to Quick Add Magic.
            smartQuotesType: SmartQuotesType.disabled,
            smartDashesType: SmartDashesType.disabled,
            inputFormatters: [FilteringTextInputFormatter.deny('\r')],
            // Revealing the caret with the default margin would scroll the
            // rows below out of view on a small phone.
            scrollPadding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: InputDecoration(
              labelText: l10n.taskEditTitleLabel,
              hintText: l10n.newTaskTitleHint,
              // With the help button a hint of as many lines as the field
              // takes makes the empty field 24 dp taller.
              hintMaxLines: 1,
              errorText: errorText,
              errorMaxLines: 4,
              suffixIcon: prefixes == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.help_outline),
                      tooltip: l10n.quickAddHelp,
                      onPressed: () =>
                          unawaited(_showHelp(mode, prefixes, now)),
                    ),
            ),
            // Keeps the keyboard up when there is nothing to add yet.
            onEditingComplete: () {},
            onSubmitted: (_) => unawaited(_add()),
          ),
        ),
        if (plan != null)
          QuickAddPreview(
            plan: plan,
            prefixes: prefixes,
            now: now,
            onRemove: _removeParts,
            projectLabel: plan.project == null
                ? null
                : projectLabel(plan.project!, projects, titleOf: titleOf),
            lineCount: taskCount,
            subtaskCount: subtaskCount,
            dueFromSheet: _due != null,
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ProjectField(
            title: projectTitle,
            hexColor: project?.hexColor ?? '',
            // A +project in the text decides until it is removed.
            leading: matchedProject == null
                ? null
                : Icon(
                    Icons.folder_outlined,
                    color: MagicColors.accentOf(context, MagicSpanKind.project),
                  ),
            onPressed: matchedProject != null
                ? null
                : () => unawaited(_pickProject(projects, fallback?.id)),
          ),
        ),
        // Closer to the chips than to the project field above; a row of
        // chips already leaves a gap with its tap targets.
        _SectionTitle(
          icon: Icons.calendar_today_outlined,
          text: l10n.taskDetailDueDate,
          top: 10,
          bottom: 0,
        ),
        DateShortcutChips(
          options: shortcuts,
          selectedDay: dueDay,
          selectedTime: shownDue == null ? null : formatter.timeOfDay(shownDue),
          enabled: !dueLocked,
          onSelected: (option) => setState(
            () => _due = option == null
                ? null
                : dayWithTime(option.day, current: _due, now: now).toUtc(),
          ),
          trailing: [
            if (shownDue case final due? when !dueOnShortcut)
              InputChip(
                avatar: const SizedBox.shrink(),
                avatarBoxConstraints: _chipIconBox,
                deleteIconBoxConstraints: _chipIconBox,
                label: Text(
                  formatter.absolute(due),
                  semanticsLabel: formatter.semanticsLabel(due),
                ),
                selected: true,
                onDeleted: dueLocked ? null : () => setState(() => _due = null),
                deleteButtonTooltipMessage: l10n.taskEditClearDueDate,
              ),
            ActionChip(
              avatar: Icon(
                Icons.calendar_month_outlined,
                color: colors.onSurfaceVariant,
              ),
              label: Text(l10n.newTaskPickDate),
              onPressed: dueLocked ? null : () => unawaited(_pickDue(now)),
            ),
          ],
        ),
        _SectionTitle(
          icon: Icons.flag_outlined,
          text: l10n.taskDetailPriority,
          bottom: 0,
        ),
        _ChipRow(
          children: [
            for (final priority in _priorities)
              ChoiceChip(
                label: Text(
                  priorityLabel(l10n, priority),
                  semanticsLabel: l10n.prioritySemantics(
                    priorityLabel(l10n, priority),
                  ),
                ),
                selected: shownPriority == priority.value,
                // Tapping the chosen one again unsets it.
                onSelected: priorityLocked
                    ? null
                    : (selected) => setState(
                        () => _priority = selected ? priority.value : null,
                      ),
              ),
          ],
        ),
        if (_moreOptions) ...[
          Padding(
            key: _moreOptionsKey,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _description,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.taskDetailDescription,
                alignLabelWithHint: true,
              ),
            ),
          ),
          _SectionTitle(icon: Icons.label_outline, text: l10n.taskDetailLabels),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LabelsSection(
              labels: _labels,
              onRemove: (label) => setState(
                () => _labels = [
                  for (final kept in _labels)
                    if (kept.id != label.id) kept,
                ],
              ),
              onAdd: () => unawaited(_pickLabels()),
            ),
          ),
          _SectionTitle(icon: Icons.alarm, text: l10n.taskDetailReminders),
          RemindersSection(
            reminders: _reminders,
            dates: _reminderDates,
            onEdit: (index) => unawaited(_pickReminder(index: index)),
            onRemove: (index) =>
                setState(() => _reminders = [..._reminders]..removeAt(index)),
            onAdd: () => unawaited(_pickReminder()),
          ),
          _SectionTitle(icon: Icons.repeat, text: l10n.taskEditRepeat),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RepeatSection(
              amountKey: _repeatAmountKey,
              value: _repeat,
              onChanged: (change) => setState(() => _repeat = change(_repeat)),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );

    final bottomBar = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 4,
          child: _adding ? const LinearProgressIndicator() : null,
        ),
        if (token != null)
          MagicSuggestions(
            token: token,
            projectId: (plan?.project ?? project)?.id,
            onSelected: (item) =>
                _edit(completeMagicToken(_text.value, token, item)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          // Stacks the two buttons at large text scales.
          child: OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: 8,
            children: [
              MergeSemantics(
                child: Semantics(
                  expanded: _moreOptions,
                  child: TextButton.icon(
                    onPressed: _toggleMoreOptions,
                    icon: Icon(
                      _moreOptions ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(
                      _moreOptions
                          ? l10n.newTaskFewerOptions
                          : l10n.newTaskMoreOptions,
                    ),
                  ),
                ),
              ),
              FilledButton(
                onPressed: canAdd ? () => unawaited(_add()) : null,
                child: Text(
                  taskCount > 1
                      ? l10n.newTaskAddMany(taskCount)
                      : l10n.newTaskAdd,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // The sheet reaches under the navigation bar or home indicator, which
    // the keyboard covers while it is up.
    final bottom = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      // The suggestions and the buttons stay above the keyboard while the
      // rest scrolls; with little room left they scroll too.
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                controller: _scroll,
                // Short of room, the headline goes out of view before the
                // due date and priority rows do; the field keeps its caret
                // in view itself. The longer form starts at its top.
                reverse: !_moreOptions,
                child: content,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight * 0.6
                    : double.infinity,
              ),
              child: SingleChildScrollView(child: bottomBar),
            ),
          ],
        ),
      ),
    );
  }
}

/// A muted label with its icon over the group it names.
class _SectionTitle extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    this.top = 6,
    this.bottom = 2,
  });

  final IconData icon;
  final String text;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
      child: Semantics(
        header: true,
        headingLevel: 2,
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.labelMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of chips that scrolls sideways, as [DateShortcutChips] lays
/// out its own.
class _ChipRow extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final child in children) ...[child, const SizedBox(width: 8)],
      ],
    ),
  );
}
