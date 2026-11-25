import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/widgets/sheet_title.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_confirmations.dart';
import 'package:vikunja_mobile/features/quick_add/application/project_references.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_hints.dart';
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
import 'package:vikunja_mobile/features/tasks/application/new_task_keep_open_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/reminder_editing.dart';
import 'package:vikunja_mobile/features/tasks/application/repeat_editor.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/labels_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/reminders_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/repeat_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/shortcut_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_form_parts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';
import 'package:vikunja_mobile/features/upcoming/application/upcoming_sections.dart';

final _log = Logger('NewTaskSheet');

/// The quick way to new tasks: one line per task with Quick Add Magic, the
/// project the tasks go to unless a line names one, optionally a due date
/// and a priority for lines without their own, and under "More options" a
/// description, labels, reminders and a repeat for every task. [projectId]
/// preselects the list's own project; with [column] the tasks that go to
/// it are placed on top of that board column; [dueDay] preselects a due
/// date on that local day. With its pin on, the sheet stays open after
/// each add for the next task. While a title or a description is typed,
/// leaving asks first. A single task added opens from the confirmation
/// where [context] opens a task.
Future<void> showNewTaskSheet(
  BuildContext context, {
  int? projectId,
  NewTaskColumn? column,
  DateTime? dueDay,
}) {
  // Over the tab bar, not inside the tab's own navigator.
  final navigator = Navigator.of(context, rootNavigator: true);
  final animation = BottomSheet.createAnimationController(navigator);
  return showModalBottomSheet<void>(
    context: context,
    barrierLabel: sheetBarrierLabel(context),
    useRootNavigator: true,
    routeSettings: const RouteSettings(name: newTaskSheetRouteName),
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    transitionAnimationController: animation,
    builder: (_) => NewTaskSheet(
      projectId: projectId,
      column: column,
      dueDay: dueDay,
      animation: animation,
      onOpenAdded: (task) {
        if (context.mounted) openTaskDetail(context, task: task);
      },
    ),
  );
}

/// The day a task added from a list of [range]'s days is due on, so that
/// it shows there: [selectedDay] while the strip shows it, else today, or
/// the range's first day while that is still ahead.
DateTime newTaskDayIn(
  DateRange range, {
  required DateTime? selectedDay,
  required DateTime now,
}) {
  if (selectedDay != null &&
      (stripDaysOf(range)?.contains(selectedDay) ?? false)) {
    return selectedDay;
  }
  final today = DateTime(now.year, now.month, now.day);
  final (first, _) = daysOf(range);
  return first.isAfter(today) ? first : today;
}

/// The board column a project's new tasks go on top of.
@immutable
final class NewTaskColumn {
  const new({
    required this.viewId,
    required this.bucketId,
    required this.defaultBucket,
    required this.top,
    this.done = false,
    this.room,
  });

  final int viewId;
  final int bucketId;

  /// Where the server puts the tasks the column has no room for, and
  /// reopens a repeating task marked done.
  final Bucket defaultBucket;

  /// The column's top as the board shows it when the tasks are placed:
  /// the position of its first card (null when it is empty), and the
  /// positions it shows its cards without a place at, which are placed
  /// there before the new tasks go above them (`madeUpPositionsOf`).
  final ({double? position, Map<int, double> madeUp}) Function() top;

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

// The hint's example stays English, as the grammar is.
const _englishDateExample = 'tomorrow at 17:00';

final List<TaskPriority> _priorities = [
  for (final priority in TaskPriority.values)
    if (priority != TaskPriority.unset) priority,
];

class NewTaskSheet extends ConsumerStatefulWidget {
  const new({
    this.projectId,
    this.column,
    this.dueDay,
    this.animation,
    this.onOpenAdded,
    super.key,
  });

  final int? projectId;
  final NewTaskColumn? column;

  /// The local day of the due date the sheet starts with, at the user's
  /// default due time like a day chip.
  final DateTime? dueDay;

  /// The `transitionAnimationController` of the sheet's route, which the
  /// sheet disposes once the route is gone. With it, a swipe down that
  /// would drop what was typed brings the sheet back up and asks.
  final AnimationController? animation;

  /// Opens a single task added, from the confirmation's Open (why on every
  /// add: the sheet cannot tell whether the list it came from shows it).
  final ValueChanged<Task>? onOpenAdded;

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

  /// A title or a description is typed, which leaving would drop.
  bool _typed = false;
  bool _leaving = false;
  ModalRoute<Object?>? _route;

  // A swipe down pops the route without asking its PopScope; while this
  // entry is in the route's local history, that pop removes it instead.
  LocalHistoryEntry? _swipeGuard;

  /// What the last add made, under the emptied title while the sheet stays
  /// open, until the next title is typed.
  String? _added;

  // After a partly failed add the sheet stays open for the rest, which
  // goes above what was placed and into the room that is left.
  double? _placedTop;
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
  static const _stalePlansAllowed = 500;
  int _plansLimit = _stalePlansAllowed;

  @override
  void initState() {
    super.initState();
    if (widget.dueDay case final day?) {
      _due = dayWithTime(
        day,
        current: null,
        now: ref.read(clockProvider)(),
        defaultTime: ref.read(displaySettingsProvider).defaultDueTime,
      ).toUtc();
    }
    _text.addListener(_onTextChanged);
    _description.addListener(_noteTyped);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _route = route;
    final animation = widget.animation;
    if (route != null && animation != null) {
      // The route drives it until its exit animation has ended.
      unawaited(route.completed.whenComplete(animation.dispose));
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _description.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _error = null;
      if (_text.text.isNotEmpty) _added = null;
    });
    _noteTyped();
  }

  void _noteTyped() {
    final typed =
        _text.text.trim().isNotEmpty || _description.text.trim().isNotEmpty;
    if (typed != _typed) setState(() => _typed = typed);
    _guardSwipe();
  }

  /// Keeps the swipe guard in the route's local history while leaving
  /// would drop what was typed or an add runs.
  void _guardSwipe() {
    final route = _route;
    final wanted =
        route != null &&
        widget.animation != null &&
        !_leaving &&
        (_typed || _adding);
    final guard = _swipeGuard;
    if (wanted == (guard != null)) return;
    if (guard != null) {
      _swipeGuard = null;
      guard.remove();
    } else {
      final added = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: _onSwipeGuardTaken,
      );
      _swipeGuard = added;
      route!.addLocalHistoryEntry(added);
    }
  }

  /// A pop took the guard: a swipe down, or the drag handle's dismiss.
  void _onSwipeGuardTaken() {
    // Null when the sheet removed it itself.
    if (_swipeGuard == null) return;
    _swipeGuard = null;
    // The navigator is still busy with that pop.
    scheduleMicrotask(() {
      if (!mounted) return;
      widget.animation?.forward();
      _guardSwipe();
      if (!_adding) unawaited(_askToLeave());
    });
  }

  Future<void> _askToLeave() async {
    final l10n = context.l10n;
    final discard = await confirmDiscardChanges(
      context,
      title: l10n.newTaskDiscardTitle,
      body: l10n.newTaskDiscardBody,
    );
    if (discard && mounted && (_route?.isCurrent ?? false)) {
      _close();
    }
  }

  /// Closes the sheet with what it opened over itself. False when the sheet
  /// was already taken (by an account switch, a sign-out or an opening),
  /// and then it closes nothing.
  bool _close() {
    _leaving = true;
    _guardSwipe();
    final route = _route;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return false;
    // A picker or the help opened while an add ran is still over the sheet.
    navigator
      ..popUntil((top) => top == route)
      ..pop();
    return true;
  }

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
        minute != _plannedAt) {
      _plans.clear();
      _plansLimit = _stalePlansAllowed;
    } else if (_plans.length > _plansLimit) {
      // Only the lines no longer in the text go, so that a long paste is
      // not planned again on every keystroke and caret move.
      final current = {for (final line in magicLines(_text.text)) line.text};
      _plans.removeWhere((line, _) => !current.contains(line));
      _plansLimit = _plans.length + _stalePlansAllowed;
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

  /// The plan of the task line [token] stands in, as Add plans it: a
  /// subtask naming no project of its own goes to its parent's. [lines]
  /// and [taskLines] are the text's, which are cut alike.
  QuickAddPlan? _planOfTokenLine(
    ActiveMagicToken token,
    List<MagicLine> lines,
    List<IndentedLine> taskLines,
  ) {
    if (lines.length != taskLines.length) return null;
    final index = lines.indexWhere(
      (line) =>
          line.offset <= token.start &&
          token.start < line.offset + line.text.length,
    );
    if (index < 0) return null;
    final line = taskLines[index];
    final inherited = _service?.inheritedProjectId(line);
    if (inherited == null) return _plan(line.text);
    return _service?.plan(
      line.text,
      fallbackProjectId: inherited,
      fallbackDueDate: _due,
      fallbackPriority: _priority,
    );
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
    if (mounted && !_leaving) _focus.requestFocus();
  }

  Future<void> _pickProject(List<Project> projects, int? selectedId) async {
    final picked = await pickProject(
      context,
      projects: projects,
      selectedId: selectedId,
    );
    if (picked != null && mounted) setState(() => _pickedProjectId = picked.id);
  }

  Future<void> _pickDue() async {
    final picked = await pickDateTime(
      context,
      current: _due,
      now: ref.read(clockProvider)(),
      display: ref.read(displaySettingsProvider),
    );
    if (picked != null && mounted) setState(() => _due = picked.toUtc());
  }

  /// The due date [option]'s chip sets, dated at the tap: the chips can be
  /// a minute old, from before midnight or before a default time passed.
  DateTime _shortcutDue(DateShortcutOption option, ClockTime? defaultTime) {
    final now = ref.read(clockProvider)();
    final day = buildDateShortcuts(now)
        .firstWhere(
          (current) => current.shortcut == option.shortcut,
          orElse: () => option,
        )
        .day;
    return dayWithTime(
      day,
      current: _due,
      now: now,
      defaultTime: defaultTime,
    ).toUtc();
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
    final description = _description.text;
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
      final guest = ref.read(activeAccountIsGuestProvider);
      setState(() => _error = _noProjectText(l10n, guest: guest));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final announcer = Announcer.of(context);
    final repository = ref.read(taskRepositoryProvider);
    final prefixes = _prefixes;
    setState(() {
      _adding = true;
      _error = null;
    });
    _guardSwipe();

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
      _guardSwipe();
      return;
    } on Object catch (error) {
      _log.warning('Quick add failed: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _adding = false;
        _error = _failureText(l10n, error);
      });
      _guardSwipe();
      return;
    }
    final left = await _placeInColumn(repository, result.createdTaskIds);
    if (!mounted) return;

    final created = result.createdTaskIds;
    final confirmation = created.length == 1
        ? l10n.newTaskCreated(result.createdTitles.single)
        : l10n.newTaskCreatedMany(created.length);
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
    if (ref.read(newTaskKeepOpenProvider).value ?? false) {
      _keepOpenForNext(
        [confirmation, ...warnings].join('\n'),
        announcer,
        added: text,
        addedDescription: description,
      );
      return;
    }
    final open = widget.onOpenAdded;
    // A stand-in until the opened detail follows the stored task.
    final single = created.length == 1
        ? Task(
            id: created.single,
            title: result.createdTitles.single,
            projectId: plans.first.project!.id,
          )
        : null;
    final persist = MediaQuery.accessibleNavigationOf(context);
    if (!_close()) return;
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: warnings.isEmpty ? 4 : 8),
        persist: persist,
        action: open == null || single == null
            ? null
            : SnackBarAction(
                label: l10n.taskDuplicateOpen,
                onPressed: () => open(single),
              ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(confirmation),
            for (final warning in warnings) Text(warning),
          ],
        ),
      ),
    );
  }

  /// Takes the [added] title and [addedDescription] out of their fields for
  /// the next task, keeping what was typed during the add; the project,
  /// the due date, the priority, the labels, the reminders and the repeat
  /// stay, as they would for several pasted lines. The confirmation shows
  /// under the title, since the sheet covers the snackbar.
  void _keepOpenForNext(
    String confirmation,
    Announcer announcer, {
    required String added,
    required String addedDescription,
  }) {
    _text.value = _withoutAdded(_text.value, added);
    _description.value = _withoutAdded(_description.value, addedDescription);
    setState(() {
      _adding = false;
      _added = confirmation;
    });
    _guardSwipe();
    _focus.requestFocus();
    announcer.say(confirmation);
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
      final top = _placedTop == null ? column.top() : null;
      final positions = positionsOnTop(
        _placedTop ?? top?.position,
        count: placed.length,
      );
      if (placed.isNotEmpty && top != null) {
        try {
          await placeMadeUp(
            repository,
            top.madeUp,
            viewId: column.viewId,
            bucketId: column.bucketId,
          );
        } on Object catch (error) {
          _log.warning('Placing the cards on top failed: ${error.runtimeType}');
        }
      }
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
      _placedTop = positions.firstOrNull ?? _placedTop;
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

  /// A guest cannot create the project a user is asked to create.
  static String _noProjectText(AppLocalizations l10n, {required bool guest}) =>
      guest ? l10n.newTaskNoProjectGuest : l10n.newTaskNoProjectError;

  static String _failureText(AppLocalizations l10n, Object error) =>
      switch (error) {
        VikunjaFailure(:final message) when message.trim().isNotEmpty =>
          l10n.newTaskAddFailed(message.trim()),
        _ => l10n.newTaskAddFailedUnknown,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Redrawn by the minute tick, but dated by the clock as a chip tap is:
    // the tick can be a minute behind, and the chips drawn after a tap must
    // show the day it set.
    ref.watch(clockTickProvider);
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
    final tokenPlan = token == null
        ? null
        : _planOfTokenLine(token, lines, taskLines) ?? plan;
    // Out of sight, an invalid repeat does not disable Add: Add shows it.
    final canAdd =
        service != null &&
        taskCount > 0 &&
        !_adding &&
        (plan?.project ?? project) != null &&
        (_repeat.isValid || !_moreOptions);
    final noProject = projectsValue.hasValue && project == null;
    final guest = ref.watch(activeAccountIsGuestProvider);
    final errorText =
        _error ?? (noProject ? _noProjectText(l10n, guest: guest) : null);

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
    final defaultDueTime = ref.watch(
      displaySettingsProvider.select((display) => display.defaultDueTime),
    );
    final dateHint = plan == null || prefixes == null
        ? null
        : quickAddDateHint(plan);

    final keepOpen = ref.watch(newTaskKeepOpenProvider).value ?? false;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The pin is here and not beside Add: in German the two buttons
        // already take most of a 360 dp row, and stacking them would push
        // the chip rows out from above the keyboard.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
          child: Row(
            children: [
              Expanded(child: SheetTitle(l10n.newTask)),
              // One node: the button's own node would otherwise sit below
              // the flag.
              MergeSemantics(
                child: Semantics(
                  toggled: keepOpen,
                  child: IconButton(
                    onPressed: () => unawaited(
                      ref
                          .read(listPreferencesProvider)
                          ?.saveNewTaskKeepOpen(keepOpen: !keepOpen),
                    ),
                    tooltip: l10n.newTaskKeepOpen,
                    isSelected: keepOpen,
                    icon: const Icon(Icons.push_pin_outlined),
                    selectedIcon: const Icon(Icons.push_pin),
                  ),
                ),
              ),
            ],
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
        // Not the field's helper text, which cuts lines off: a warning ends
        // with the names it is about.
        if (_added case final added? when errorText == null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(28, 4, 28, 0),
            child: Text(
              added,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (dateHint != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(28, 4, 28, 0),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                switch (dateHint) {
                  ForeignDateWords() => l10n.quickAddHintEnglishDates(
                    _englishDateExample,
                  ),
                  TimeWithoutAt(:final time) => l10n.quickAddHintAddAt(time),
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
            note: matchedProject == null ? null : l10n.newTaskSetInTitle,
            onPressed: matchedProject != null
                ? null
                : () => unawaited(_pickProject(projects, fallback?.id)),
          ),
        ),
        // Closer to the chips than to the project field above; a row of
        // chips already leaves a gap with its tap targets.
        TaskFormHeading(
          icon: Icons.calendar_today_outlined,
          text: l10n.taskDetailDueDate,
          note: dueLocked ? l10n.newTaskSetInTitle : null,
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
                : _shortcutDue(option, defaultDueTime),
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
              onPressed: dueLocked ? null : () => unawaited(_pickDue()),
            ),
          ],
        ),
        TaskFormHeading(
          icon: Icons.flag_outlined,
          text: l10n.taskDetailPriority,
          note: priorityLocked ? l10n.newTaskSetInTitle : null,
          bottom: 0,
        ),
        ChipRow(
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
          TaskFormHeading(
            icon: Icons.label_outline,
            text: l10n.taskDetailLabels,
          ),
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
          TaskFormHeading(icon: Icons.alarm, text: l10n.taskDetailReminders),
          RemindersSection(
            reminders: _reminders,
            dates: _reminderDates,
            onEdit: (index) => unawaited(_pickReminder(index: index)),
            onRemove: (index) =>
                setState(() => _reminders = [..._reminders]..removeAt(index)),
            onAdd: () => unawaited(_pickReminder()),
          ),
          TaskFormHeading(icon: Icons.repeat, text: l10n.taskEditRepeat),
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
            typed: _text.text.substring(token.start, token.end),
            mode: mode,
            projectId: (tokenPlan?.project ?? project)?.id,
            onSelected: (written) =>
                _edit(completeMagicToken(_text.value, token, written)),
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
    return PopScope(
      // Discard could not stop an add under way, which closes the sheet
      // itself.
      canPop: !_typed && !_adding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_adding) unawaited(_askToLeave());
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        // The suggestions and the buttons stay above the keyboard while the
        // rest scrolls; with little room left they scroll too.
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                // A sliver viewport, so a field it cuts keeps its whole size
                // for screen readers.
                child: CustomScrollView(
                  controller: _scroll,
                  shrinkWrap: true,
                  // Short of room, the headline goes out of view before the
                  // due date and priority rows do; the field keeps its
                  // caret in view itself. The longer form starts at its top.
                  reverse: !_moreOptions,
                  slivers: [SliverToBoxAdapter(child: content)],
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
      ),
    );
  }
}

/// [value] without the [added] text it still starts with, and the spaces
/// after it; anything else typed while the add ran stays, with the caret
/// where it was.
TextEditingValue _withoutAdded(TextEditingValue value, String added) {
  if (added.isEmpty || !value.text.startsWith(added)) return value;
  final rest = value.text.substring(added.length);
  final removed = value.text.length - rest.trimLeft().length;
  int shift(int offset) => offset < 0 ? offset : math.max(0, offset - removed);
  return TextEditingValue(
    text: value.text.substring(removed),
    selection: value.selection.copyWith(
      baseOffset: shift(value.selection.baseOffset),
      extentOffset: shift(value.selection.extentOffset),
    ),
    composing: value.composing.isValid
        ? TextRange(
            start: shift(value.composing.start),
            end: shift(value.composing.end),
          )
        : TextRange.empty,
  );
}
