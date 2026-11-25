import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/filters/search_index.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/quick_add/application/known_users_provider.dart';
import 'package:vikunja_mobile/features/quick_add/application/project_references.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_tokens.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';
import 'package:vikunja_mobile/features/tasks/application/label_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/label_search.dart';
import 'package:vikunja_mobile/features/tasks/application/people_search.dart';

/// Completions for the prefixed token at the caret, in a strip that scrolls
/// sideways: labels, projects, or people (the ones this device knows, then
/// the server's matches for [projectId] once typing pauses), leaving out
/// the one the token already names in full. [onSelected] gets the label
/// title, project reference or username as written after the prefix; a
/// label or project that [mode] cannot write so that it reads back as
/// exactly that one is left out.
class MagicSuggestions extends ConsumerStatefulWidget {
  const new({
    required this.token,
    required this.typed,
    required this.mode,
    required this.projectId,
    required this.onSelected,
    super.key,
  });

  static const debounce = Duration(milliseconds: 300);
  static const maxSuggestions = 30;

  final ActiveMagicToken token;

  /// The token as it stands in the text, prefix included.
  final String typed;
  final QuickAddMagicMode mode;
  final int? projectId;
  final ValueChanged<String> onSelected;

  @override
  ConsumerState<MagicSuggestions> createState() => _MagicSuggestionsState();
}

class _MagicSuggestionsState extends ConsumerState<MagicSuggestions> {
  Timer? _debounce;
  int _latestSearch = 0;
  List<User> _found = const [];
  (int, String)? _answered;

  bool get _people => widget.token.kind == MagicTokenKind.assignee;

  @override
  void initState() {
    super.initState();
    if (_people) _scheduleSearch();
  }

  @override
  void didUpdateWidget(MagicSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_people) {
      _debounce?.cancel();
      return;
    }
    if (oldWidget.token.kind != widget.token.kind ||
        oldWidget.token.query != widget.token.query ||
        oldWidget.projectId != widget.projectId) {
      _scheduleSearch();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    final projectId = widget.projectId;
    if (projectId == null) return;
    final query = widget.token.query;
    _debounce = Timer(
      MagicSuggestions.debounce,
      () => unawaited(_search(projectId, query)),
    );
  }

  Future<void> _search(int projectId, String query) async {
    // The server's user search refuses a link-share guest.
    if (ref.read(activeAccountIsGuestProvider)) return;
    final search = ++_latestSearch;
    final repository = ref.read(userRepositoryProvider);
    if (repository == null) return;
    List<User> found;
    try {
      found = await repository.searchAssignees(projectId, query);
    } on Object {
      // Offline or refused: the people this device knows still show.
      return;
    }
    // A slower answer to an earlier query must not replace a newer one.
    if (!mounted || search != _latestSearch) return;
    setState(() {
      _found = found;
      _answered = (projectId, query);
    });
  }

  static List<User> _merged(List<User> first, List<User> more) => [
    ...first,
    for (final user in more)
      if (!first.any((known) => known.id == user.id)) user,
  ];

  @override
  Widget build(BuildContext context) {
    final query = widget.token.query;
    final chips = switch (widget.token.kind) {
      MagicTokenKind.label => _labelChips(query),
      MagicTokenKind.project => _projectChips(query),
      MagicTokenKind.assignee => _peopleChips(query),
    };
    if (chips.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: context.l10n.quickAddSuggestions,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            for (final chip in chips.take(MagicSuggestions.maxSuggestions)) ...[
              chip,
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _labelChips(String query) {
    final labels = ref.watch(allLabelsProvider).value ?? const <Label>[];
    return [
      for (final label in filterLabels(labels, query))
        if (!_named(label.title))
          if (writtenMagicItem(label.title, MagicTokenKind.label, widget.mode)
              case final written?)
            _SuggestionChip(
              avatar: _dot(parseHexColor(label.hexColor)),
              label: label.title,
              onPressed: () => widget.onSelected(written),
            ),
    ];
  }

  /// Projects show their display title and match it too, while a tap
  /// completes the server's title, which quick add matches.
  /// Projects of the same title are told apart by their parents, and a
  /// tap completes what makes quick add take that one: the identifier
  /// when the title is not enough, or cannot be written.
  List<Widget> _projectChips(String query) {
    final l10n = context.l10n;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final candidates = [
      for (final row in selectableProjects(writableProjects(projects)))
        row.node.project,
    ];
    final needle = foldForSearch(query.trim());
    String titleOf(Project project) => project.displayTitle(l10n);
    String? written(String reference) =>
        writtenMagicItem(reference, MagicTokenKind.project, widget.mode);
    return [
      for (final project in candidates)
        if (needle.isEmpty ||
            foldForSearch(project.title).contains(needle) ||
            foldForSearch(titleOf(project)).contains(needle) ||
            foldForSearch(project.identifier).contains(needle))
          if (projectReference(
                    project,
                    candidates,
                    usable: (reference) => written(reference) != null,
                  ) ??
                  project.title
              case final reference when !_named(reference))
            if (written(reference) case final text?)
              _SuggestionChip(
                avatar: ProjectIcon(hexColor: project.hexColor),
                label: projectLabel(project, candidates, titleOf: titleOf),
                onPressed: () => widget.onSelected(text),
              ),
    ];
  }

  List<Widget> _peopleChips(String query) {
    final known = ref.watch(knownUsersProvider).value ?? const <User>[];
    final answered = _answered == (widget.projectId, query);
    final people = _merged(
      answered ? _found : const [],
      filterUsers(known, query),
    );
    return [
      for (final user in people)
        if (!_named(user.username))
          _SuggestionChip(
            avatar: ExcludeSemantics(
              child: InitialsAvatar(name: user.displayName, radius: 10),
            ),
            label: user.displayName,
            tooltip: context.l10n.assigneeUsername(user.username),
            onPressed: () =>
                widget.onSelected(quoteQuickAddItem(user.username)),
          ),
    ];
  }

  /// Whether the token already names [item] in full, ignoring case, so that
  /// completing it would change nothing; an open quote still needs it.
  bool _named(String item) {
    final prefix = widget.token.prefix;
    if (!widget.typed.startsWith(prefix)) return false;
    var typed = widget.typed.substring(prefix.length);
    if (typed.startsWith('"') || typed.startsWith("'")) {
      if (typed.length < 2 || !typed.endsWith(typed[0])) return false;
      typed = typed.substring(1, typed.length - 1);
    }
    return typed.toLowerCase() == item.toLowerCase();
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

class _SuggestionChip extends StatelessWidget {
  const new({
    required this.avatar,
    required this.label,
    required this.onPressed,
    this.tooltip,
  });

  final Widget avatar;
  final String label;
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: IconTheme.merge(data: const IconThemeData(size: 18), child: avatar),
    label: Text(label),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}
