import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
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
import 'package:vikunja_mobile/features/quick_add/presentation/magic_toolbar.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/quick_add_help_sheet.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/quick_add_preview.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/shortcut_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';

final _log = Logger('NewTaskSheet');

/// The quick way to new tasks: one line per task with Quick Add Magic, the
/// project the tasks go to unless a line names one, and optionally a due
/// date for lines without a date. [projectId] preselects the list's own
/// project; with [column] the tasks that go to it are placed on top of that
/// board column.
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

// By default the icon boxes are squares as tall as the label, which leaves
// a wrapped label ever less width.
const _chipIconBox = BoxConstraints.tightFor(width: 20, height: 20);

class NewTaskSheet extends ConsumerStatefulWidget {
  const new({this.projectId, this.column, super.key});

  final int? projectId;
  final NewTaskColumn? column;

  @override
  ConsumerState<NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends ConsumerState<NewTaskSheet> {
  final _text = MagicTextEditingController();
  final _focus = FocusNode();
  int? _pickedProjectId;
  DateTime? _due;
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
    _focus.dispose();
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
        minute != _plannedAt ||
        _plans.length > 500) {
      _plans.clear();
    }
    _service = service;
    _mode = mode;
    _prefixes = prefixes;
    _fallbackId = fallbackId;
    _plannedDue = _due;
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

  void _setPriority(int priority) {
    final prefixes = _prefixes;
    if (prefixes == null) return;
    final token = '${prefixes.priority}$priority';
    // A selection stays text; the priority goes after it.
    final value = _text.value.selection.isValid
        ? _text.value.copyWith(
            selection: TextSelection.collapsed(
              offset: _text.value.selection.end,
            ),
          )
        : _text.value;
    final caret = value.selection.isValid
        ? value.selection.baseOffset
        : value.text.length;
    MagicLine? current;
    for (final line in magicLines(value.text)) {
      if (line.offset <= caret) current = line;
    }
    final existing = current == null
        ? null
        : _lineSpans(current.text)
              .where((span) => span.kind == MagicSpanKind.priority)
              .firstOrNull
              ?.shifted(current.offset);
    if (existing == null) {
      _edit(insertMagicText(value, token, trailingSpace: true));
      return;
    }
    _edit(
      TextEditingValue(
        text: value.text.replaceRange(existing.start, existing.end, token),
        selection: TextSelection.collapsed(
          offset: existing.start + token.length,
        ),
      ),
    );
  }

  Future<void> _showHelp(
    QuickAddMagicMode mode,
    QuickAddPrefixes prefixes,
    DateTime now,
  ) async {
    await showQuickAddHelp(context, mode: mode, prefixes: prefixes, now: now);
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

  Future<void> _add({required bool openEditor}) async {
    final service = _service;
    final text = _text.text;
    final lines = splitQuickAddLines(text, mode: _mode);
    if (_adding || service == null || lines.isEmpty) return;
    final l10n = context.l10n;
    final fallbackId = _fallbackId;
    final plans = [for (final line in lines) _plan(line)!];
    if (plans.any((plan) => plan.project == null)) {
      setState(() => _error = l10n.newTaskNoProjectError);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
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
      if (result.unresolvedAssignees.isNotEmpty)
        l10n.newTaskNamesKept(
          [
            for (final name in result.unresolvedAssignees)
              '${prefixes?.assignee ?? ''}$name',
          ].join(', '),
        ),
    ];
    final created = result.createdTaskIds;
    if (openEditor && created.isNotEmpty) {
      unawaited(router.push(AppRoutes.taskEdit(created.first)));
      if (warnings.isEmpty) return;
    }
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: warnings.isEmpty ? 4 : 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!openEditor)
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
  /// resolved, which are not always the ones the plan resolved.
  static String _createdTitle(
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
    final canAdd =
        service != null &&
        taskCount > 0 &&
        !_adding &&
        (plan?.project ?? project) != null;
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Semantics(
            header: true,
            child: Text(l10n.newTask, style: theme.textTheme.titleMedium),
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
            decoration: InputDecoration(
              labelText: l10n.taskEditTitleLabel,
              hintText: l10n.newTaskTitleHint,
              errorText: errorText,
              errorMaxLines: 4,
            ),
            // Keeps the keyboard up when there is nothing to add yet.
            onEditingComplete: () {},
            onSubmitted: (_) => unawaited(_add(openEditor: false)),
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
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ActionChip(
            avatar: Icon(
              Icons.folder_outlined,
              color: matchedProject != null
                  ? MagicColors.accentOf(context, MagicSpanKind.project)
                  : colors.onSurfaceVariant,
            ),
            label: Text(
              projectTitle,
              semanticsLabel: l10n.taskEditProjectSemantics(projectTitle),
            ),
            // A +project in the text decides until it is removed.
            onPressed: matchedProject != null
                ? null
                : () => unawaited(_pickProject(projects, fallback?.id)),
          ),
        ),
        const SizedBox(height: 8),
        DateShortcutChips(
          options: shortcuts,
          selectedDay: dueDay,
          wrap: true,
          enabled: !dueLocked,
          onSelected: (option) => setState(
            () => _due = option == null
                ? null
                : dayWithTime(option.day, current: _due, now: now).toUtc(),
          ),
          trailing: [
            if (shownDue case final due? when !dueOnShortcut)
              InputChip(
                // A label on one line fades out the written date displays
                // before their time at large text. The checkmark goes in
                // the avatar's fixed box; without an avatar it takes a
                // square as tall as the wrapped label.
                avatar: const SizedBox.shrink(),
                avatarBoxConstraints: _chipIconBox,
                deleteIconBoxConstraints: _chipIconBox,
                label: Text(
                  formatter.absolute(due),
                  semanticsLabel: formatter.semanticsLabel(due),
                  softWrap: true,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: true,
                onDeleted: dueLocked ? null : () => setState(() => _due = null),
                deleteButtonTooltipMessage: l10n.taskEditClearDueDate,
              ),
            ActionChip(
              avatar: Icon(Icons.event, color: colors.onSurfaceVariant),
              label: Text(l10n.newTaskPickDate),
              onPressed: dueLocked ? null : () => unawaited(_pickDue(now)),
            ),
          ],
        ),
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
        if (prefixes != null)
          MagicToolbar(
            prefixes: prefixes,
            onInsertPrefix: (prefix) =>
                _edit(insertMagicPrefix(_text.value, prefix)),
            onPriority: _setPriority,
            onHelp: () => unawaited(_showHelp(mode, prefixes, now)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          // Stacks the two buttons at large text scales.
          child: OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: 8,
            children: [
              TextButton(
                onPressed: canAdd
                    ? () => unawaited(_add(openEditor: true))
                    : null,
                child: Text(l10n.newTaskMoreOptions),
              ),
              FilledButton(
                onPressed: canAdd
                    ? () => unawaited(_add(openEditor: false))
                    : null,
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // The suggestions, the toolbar and the buttons stay above the keyboard
      // while the rest scrolls; with little room left they scroll too.
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: SingleChildScrollView(child: content)),
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
