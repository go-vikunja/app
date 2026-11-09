import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/filters/search_index.dart';
import 'package:vikunja_mobile/core/repositories/task_search_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/common/presentation/motion.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/filters/application/filter_check.dart';
import 'package:vikunja_mobile/features/filters/application/filter_syntax.dart';
import 'package:vikunja_mobile/features/filters/presentation/filter_error_text.dart';
import 'package:vikunja_mobile/features/filters/presentation/filter_text_controller.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/quick_add/application/known_users_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/label_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

final _log = Logger('FilterField');

/// The filter as the field holds it: [apiText] is what the server takes
/// (label and project ids), and [error] what the engine says about it.
@immutable
final class FilterInput {
  const new({required this.apiText, this.error, this.edited = false});

  final String apiText;
  final FilterError? error;

  /// Changed by the user; a stored filter left alone is the server's own
  /// and never blocks saving.
  final bool edited;

  bool get blocksSaving => edited && error != null;
}

/// The filter builder of the views form and the saved filter form: the
/// web's syntax with its parts highlighted, suggestions for the field,
/// operator or value at the caret (labels and projects by title, people by
/// username, ignoring case and accents; relative dates) right under the
/// text, the engine's verdict once typing pauses and how many of this
/// device's tasks match. Titles show where the stored filter has ids;
/// [onChanged] gets the filter with ids again, and its error at once.
class FilterField extends ConsumerStatefulWidget {
  const new({
    required this.initialFilter,
    required this.onChanged,
    this.projectId,
    this.includeNulls = false,
    this.search = '',
    this.timezone = '',
    this.completeFilter,
    this.enabled = true,
    this.serverError,
    super.key,
  });

  static const countDelay = Duration(milliseconds: 250);

  /// How long typing pauses before the engine's verdict shows: half-typed
  /// conditions are not worth a message each.
  static const errorDelay = Duration(milliseconds: 700);
  static const maxSuggestions = 30;

  /// As stored, with ids.
  final String initialFilter;
  final ValueChanged<FilterInput> onChanged;

  /// The project a view of which is counted; null counts like a saved
  /// filter, over every project that is not archived.
  final int? projectId;
  final bool includeNulls;
  final String search;
  final String timezone;

  /// The whole filter the field's text is a part of, for the count: the
  /// views form adds its "Show done tasks" switch.
  final String Function(String apiText)? completeFilter;
  final bool enabled;

  /// Why the server refused the filter, or another reason the form has;
  /// the engine's own verdict comes first.
  final String? serverError;

  @override
  ConsumerState<FilterField> createState() => _FilterFieldState();
}

// Kept alive in a lazy list: the field holds what is typed.
class _FilterFieldState extends ConsumerState<FilterField>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final _controller = FilterTextEditingController(
    text: widget.initialFilter,
  );
  final _focus = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  final GlobalKey _chipsKey = GlobalKey();
  var _edited = false;
  var _shownWithTitles = false;
  FilterLookups? _lookups;
  FilterIds _keptIds = const FilterIds();
  Timer? _errorTimer;
  FilterError? _settledError;
  var _chipsShown = false;
  TextEditingValue? _revealedFor;
  var _revealScheduled = false;
  double? _keyboardInset;
  FilterInput? _reported;
  Timer? _countTimer;
  var _countRequest = 0;
  int? _matches;
  var _countable = true;
  var _counted = false;
  Object? _countKey;
  TextEditingValue? _lastValue;
  List<Label>? _lastLabels;
  List<Project>? _lastProjects;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_onFocusChanged);
    _controller.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _errorTimer?.cancel();
    _countTimer?.cancel();
    _controller
      ..removeListener(_onSelectionChanged)
      ..dispose();
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {
    if (!_focus.hasFocus) _settleError();
  });

  /// The verdict on what the field holds now becomes the one shown.
  void _settleError() {
    _errorTimer?.cancel();
    final input = _reported;
    _settledError = input != null && input.edited ? input.error : null;
  }

  /// The keyboard comes up after the focus, and the caret is all the field
  /// brings into view by itself.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final inset = View.of(context).viewInsets.bottom;
    if (inset == _keyboardInset) return;
    _keyboardInset = inset;
    if (_focus.hasFocus && _chipsShown) _revealChipsAfterFrame();
  }

  /// Scrolls just far enough for the suggestions to show above the
  /// keyboard, unless the text and they are taller than the room left,
  /// where it would push the caret out of view.
  void _revealChipsAfterFrame() {
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      final chips = _chipsKey.currentContext;
      final field = _fieldKey.currentContext;
      if (!mounted || chips == null || field == null) return;
      final scrollable = Scrollable.maybeOf(chips);
      final chipsBox = chips.findRenderObject();
      final fieldBox = field.findRenderObject();
      if (scrollable == null ||
          chipsBox is! RenderBox ||
          fieldBox is! RenderBox) {
        return;
      }
      final top = fieldBox.localToGlobal(Offset.zero).dy;
      final bottom = chipsBox.localToGlobal(Offset(0, chipsBox.size.height)).dy;
      if (bottom - top > scrollable.position.viewportDimension) return;
      Scrollable.ensureVisible(
        chips,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: reduceMotionOf(chips)
            ? Duration.zero
            : const Duration(milliseconds: 100),
      );
    });
  }

  /// The suggestions follow the caret, also when only it moved.
  void _onSelectionChanged() {
    if (_controller.value == _lastValue) return;
    _lastValue = _controller.value;
    if (mounted) setState(() {});
  }

  /// Until labels and projects are known, what is typed goes without
  /// titles resolved.
  String get _apiText {
    if (!_edited) return widget.initialFilter.trim();
    return (_lookups ?? FilterLookups()).toApi(
      _controller.text.trim(),
      keepIds: _keptIds,
    );
  }

  void _report() {
    final apiText = _apiText;
    final input = FilterInput(
      apiText: apiText,
      error: filterErrorOf(apiText),
      edited: _edited,
    );
    final reported = _reported;
    if (reported != null &&
        reported.apiText == input.apiText &&
        reported.edited == input.edited &&
        reported.error?.code == input.error?.code) {
      return;
    }
    _reported = input;
    widget.onChanged(input);
  }

  void _onEdited() {
    _edited = true;
    _report();
    _errorTimer?.cancel();
    _errorTimer = Timer(FilterField.errorDelay, () {
      if (mounted) setState(_settleError);
    });
  }

  /// Once labels and projects are known, a filter not yet edited shows
  /// their titles; later changes to them re-check what is typed.
  void _adoptLookups(FilterLookups lookups) {
    _lookups = lookups;
    if (!_edited && !_shownWithTitles) {
      _shownWithTitles = true;
      // An id nothing here has a title for stays that id, also where a
      // title is that number.
      _keptIds = lookups.untitledIds(widget.initialFilter.trim());
      final shown = lookups.fromApi(widget.initialFilter.trim());
      if (shown != _controller.text) {
        _controller.value = TextEditingValue(
          text: shown,
          selection: TextSelection.collapsed(offset: shown.length),
        );
      }
    }
    _report();
  }

  /// Counts again, shortly, whenever what is counted changed: the text,
  /// the switch the views form adds to it, search or include-nulls.
  void _countWhenChanged(FilterInput input) {
    final filter = input.error == null
        ? widget.completeFilter?.call(input.apiText) ?? input.apiText
        : null;
    final key = (
      filter,
      widget.search,
      widget.includeNulls,
      widget.projectId,
      widget.timezone,
    );
    if (key == _countKey) return;
    _countKey = key;
    _countTimer?.cancel();
    final request = ++_countRequest;
    if (filter == null) {
      _counted = false;
      return;
    }
    final search = widget.search;
    final includeNulls = widget.includeNulls;
    final projectId = widget.projectId;
    final timezone = widget.timezone;
    _countTimer = Timer(
      FilterField.countDelay,
      () => unawaited(
        _count(
          request,
          ViewFilter(
            filter: filter,
            search: search,
            includeNulls: includeNulls,
          ),
          projectId: projectId,
          timezone: timezone,
        ),
      ),
    );
  }

  Future<void> _count(
    int request,
    ViewFilter filter, {
    required int? projectId,
    required String timezone,
  }) async {
    final search = ref.read(taskSearchProvider);
    if (search == null) return;
    int? count;
    try {
      count = await search.countMatches(
        filter,
        projectId: projectId,
        timezone: timezone,
      );
    } on Object catch (error) {
      _log.warning('Counting a filter failed: ${error.runtimeType}');
      count = null;
    }
    // A slower count of an earlier text must not replace a newer one.
    if (!mounted || request != _countRequest) return;
    setState(() {
      _matches = count;
      _countable = count != null;
      _counted = true;
    });
  }

  void _complete(FilterCompletionContext context, String insert) {
    _controller.value = completeFilter(_controller.value, context, insert);
    _onEdited();
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final labels = ref.watch(allLabelsProvider).value;
    final projects = ref.watch(projectsProvider).value;
    final users = ref.watch(knownUsersProvider).value ?? const <User>[];
    if (labels != null && projects != null) {
      final lookups = FilterLookups(labels: labels, projects: projects);
      if (!identical(labels, _lastLabels) ||
          !identical(projects, _lastProjects)) {
        _lastLabels = labels;
        _lastProjects = projects;
        // Not within the build: the parent hears of the change.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _adoptLookups(lookups);
          setState(() {});
        });
      }
    }
    final input = _reported;
    if (input != null) _countWhenChanged(input);
    // A fixed filter loses its message at once; a new message waits for a
    // pause in typing.
    final localError = input != null && input.edited && input.error != null
        ? _settledError
        : null;
    final errorText = localError != null
        ? filterErrorText(l10n, localError)
        : widget.serverError;
    final completion = _focus.hasFocus && widget.enabled
        ? filterCompletionContext(_controller.value)
        : null;
    final chips = completion == null
        ? const <Widget>[]
        : _suggestions(
            context,
            completion,
            labels: labels ?? const [],
            projects: projects ?? const [],
            users: users,
          );
    // After the field's own reveal of the caret, which an edit runs.
    if (chips.isNotEmpty &&
        (!_chipsShown || _controller.value != _revealedFor)) {
      _revealedFor = _controller.value;
      _revealChipsAfterFrame();
    }
    _chipsShown = chips.isNotEmpty;
    _controller.highlighted = widget.enabled;
    final countText = errorText != null || !_counted
        ? null
        : _countable
        ? l10n.filterMatchCount(_matches ?? 0)
        : l10n.filterNotCountable;
    final theme = Theme.of(context);
    final subtextStyle = theme.textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          key: _fieldKey,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: widget.enabled,
            // Wraps, but Return confirms instead of adding a line.
            maxLines: null,
            keyboardType: TextInputType.text,
            autocorrect: false,
            enableSuggestions: false,
            smartQuotesType: SmartQuotesType.disabled,
            smartDashesType: SmartDashesType.disabled,
            textInputAction: TextInputAction.done,
            // The message goes under the suggestions, which stay right
            // under the text and never move when it comes or goes.
            decoration: InputDecoration(
              labelText: l10n.filterLabel,
              hintText: l10n.filterHint,
              error: errorText == null ? null : const SizedBox.shrink(),
            ),
            onChanged: (_) => _onEdited(),
            onSubmitted: (_) => setState(_settleError),
          ),
        ),
        if (chips.isNotEmpty)
          // Taps on a suggestion count as inside the field, which keeps
          // its focus and keyboard.
          TextFieldTapRegion(
            key: _chipsKey,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: l10n.filterSuggestions,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    for (final chip in chips.take(FilterField.maxSuggestions))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: chip,
                      ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          // Lined up with the text inside the outlined field.
          padding: const EdgeInsetsDirectional.fromSTEB(28, 4, 28, 0),
          child: errorText != null
              ? Semantics(
                  container: true,
                  liveRegion: localError != null,
                  child: Text(
                    errorText,
                    style: subtextStyle?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Text(
                  l10n.filterHelp,
                  style: subtextStyle?.copyWith(color: theme.hintColor),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        if (countText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    _countable ? Icons.checklist : Icons.cloud_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Counted after a pause in typing, so it is said once.
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    child: Text(
                      countText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _suggestions(
    BuildContext context,
    FilterCompletionContext completion, {
    required List<Label> labels,
    required List<Project> projects,
    required List<User> users,
  }) {
    final l10n = context.l10n;
    Widget join(int at) => _JoinChips(
      onSelected: (join) => _complete(JoinContext(start: at, end: at), join),
    );
    switch (completion) {
      case FieldContext():
        return [
          for (final field in fieldSuggestions(completion))
            _SuggestionChip(
              label: field,
              onPressed: () => _complete(completion, field),
            ),
        ];
      case OperatorContext():
        return [
          for (final operator in operatorSuggestions(completion))
            _SuggestionChip(
              label: operator,
              onPressed: () => _complete(completion, operator),
            ),
        ];
      case JoinContext():
        return [join(completion.start)];
      case ValueContext(:final partial, :final operator, :final kind):
        final list = isListOperator(operator);
        final typed = partial.trim().toLowerCase();
        final needle = foldForSearch(typed);
        // The filter matches a value ignoring case only, so one typed out is
        // not offered again, but "cafe" still offers "Café".
        bool fits(String value, {String? name}) =>
            value.toLowerCase() != typed &&
            (foldForSearch(value).contains(needle) ||
                (name != null && foldForSearch(name).contains(needle)));
        void insertValue(String value) =>
            _complete(completion, filterValueText(value, list: list));
        final values = switch (kind) {
          FilterFieldKind.done => [
            for (final value in const ['true', 'false'])
              if (fits(value))
                _SuggestionChip(
                  label: value,
                  onPressed: () => insertValue(value),
                ),
          ],
          FilterFieldKind.number when completion.field == 'priority' => [
            for (final priority in TaskPriority.values.skip(1))
              if (fits('${priority.value}'))
                _SuggestionChip(
                  label: '${priority.value}',
                  tooltip: priorityLabel(l10n, priority),
                  onPressed: () => insertValue('${priority.value}'),
                ),
          ],
          FilterFieldKind.date => [
            for (final shortcut in filterDateShortcuts)
              if (fits(shortcut))
                _SuggestionChip(
                  label: shortcut,
                  tooltip: _dateShortcutName(l10n, shortcut),
                  semanticsLabel: _dateShortcutName(l10n, shortcut),
                  onPressed: () => insertValue(shortcut),
                ),
          ],
          FilterFieldKind.labels => [
            for (final label in labels)
              if (fits(label.title))
                _SuggestionChip(
                  avatar: _dot(parseHexColor(label.hexColor)),
                  label: label.title,
                  onPressed: () {
                    // A title a value cannot hold goes as its id.
                    if (canBeFilterValue(label.title, list: list)) {
                      insertValue(label.title);
                      return;
                    }
                    _keptIds = _keptIds.union(FilterIds(labels: {label.id}));
                    insertValue('${label.id}');
                  },
                ),
          ],
          FilterFieldKind.project => [
            for (final project in _projectCandidates(projects))
              if (fits(project.title))
                _SuggestionChip(
                  avatar: project.isArchived
                      ? const Icon(Icons.archive_outlined)
                      : ProjectIcon(hexColor: project.hexColor),
                  label: project.title,
                  onPressed: () {
                    if (canBeFilterValue(project.title, list: list) &&
                        _titleIsUnique(project, projects)) {
                      insertValue(project.title);
                      return;
                    }
                    _keptIds = _keptIds.union(
                      FilterIds(projects: {project.id}),
                    );
                    insertValue('${project.id}');
                  },
                ),
          ],
          FilterFieldKind.users => [
            for (final user in users)
              if (fits(user.username, name: user.name))
                _SuggestionChip(
                  avatar: ExcludeSemantics(
                    child: InitialsAvatar(name: user.displayName, radius: 10),
                  ),
                  label: user.displayName,
                  tooltip: l10n.assigneeUsername(user.username),
                  onPressed: () => insertValue(user.username),
                ),
          ],
          FilterFieldKind.number || FilterFieldKind.text => const <Widget>[],
        };
        return [
          if (completion.joinable) join(_controller.selection.baseOffset),
          ...values,
        ];
    }
  }

  /// The ones the filter can name, active before archived.
  static List<Project> _projectCandidates(List<Project> projects) => [
    for (final project in projects)
      if (!project.isPseudo && !project.isArchived) project,
    for (final project in projects)
      if (!project.isPseudo && project.isArchived) project,
  ];

  /// The web turns a title into the first project of that title, ignoring
  /// case; another one of the same title goes as its id.
  static bool _titleIsUnique(Project project, List<Project> projects) {
    final title = project.title.toLowerCase();
    return !projects.any(
      (other) =>
          other.id != project.id &&
          !other.isPseudo &&
          other.title.toLowerCase() == title,
    );
  }

  Widget _dot(Color? color) {
    if (color == null) return const Icon(Icons.label_outline);
    return Center(
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

String _dateShortcutName(AppLocalizations l10n, String shortcut) =>
    switch (shortcut) {
      'now' => l10n.filterDateNow,
      'now/d' => l10n.filterDateStartOfToday,
      'now/d+1d' => l10n.filterDateStartOfTomorrow,
      'now+7d' => l10n.filterDateInSevenDays,
      'now/w' => l10n.filterDateStartOfWeek,
      'now/w+1w' => l10n.filterDateStartOfNextWeek,
      'now/M' => l10n.filterDateStartOfMonth,
      'now-7d' => l10n.filterDateSevenDaysAgo,
      _ => shortcut,
    };

class _JoinChips extends StatelessWidget {
  const new({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SuggestionChip(
          label: '&&',
          semanticsLabel: l10n.filterSuggestionAnd,
          onPressed: () => onSelected('&&'),
        ),
        const SizedBox(width: 8),
        _SuggestionChip(
          label: '||',
          semanticsLabel: l10n.filterSuggestionOr,
          onPressed: () => onSelected('||'),
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.avatar,
    this.tooltip,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? avatar;
  final String? tooltip;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: avatar == null
        ? null
        : IconTheme.merge(data: const IconThemeData(size: 18), child: avatar!),
    label: Text(label, semanticsLabel: semanticsLabel),
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
  );
}
