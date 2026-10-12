import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
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
/// the server's matches for [projectId] once typing pauses). [onSelected]
/// gets the label title, project title or username.
class MagicSuggestions extends ConsumerStatefulWidget {
  const new({
    required this.token,
    required this.projectId,
    required this.onSelected,
    super.key,
  });

  static const debounce = Duration(milliseconds: 300);
  static const maxSuggestions = 30;

  final ActiveMagicToken token;
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
        _SuggestionChip(
          avatar: _dot(parseHexColor(label.hexColor)),
          label: label.title,
          onPressed: () => widget.onSelected(label.title),
        ),
    ];
  }

  /// Projects of the same title are told apart by their parents, and a
  /// tap completes what makes quick add take that one: the identifier
  /// when the title is not enough.
  List<Widget> _projectChips(String query) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final candidates = [
      for (final row in selectableProjects(projects)) row.node.project,
    ];
    final needle = query.trim().toLowerCase();
    return [
      for (final project in candidates)
        if (needle.isEmpty ||
            project.title.toLowerCase().contains(needle) ||
            project.identifier.toLowerCase().contains(needle))
          _SuggestionChip(
            avatar: const Icon(Icons.folder_outlined),
            label: projectLabel(project, candidates),
            onPressed: () => widget.onSelected(
              projectReference(project, candidates) ?? project.title,
            ),
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
        _SuggestionChip(
          avatar: ExcludeSemantics(
            child: InitialsAvatar(name: user.displayName, radius: 10),
          ),
          label: user.displayName,
          tooltip: context.l10n.assigneeUsername(user.username),
          onPressed: () => widget.onSelected(user.username),
        ),
    ];
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
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
  );
}
