import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/people_search.dart';
import 'package:vikunja_mobile/features/tasks/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// Lets the user tick the people of [projectId] to assign, found on the
/// server or, without a connection, among the people this device knows.
/// Done returns the ticked people; null when dismissed.
Future<List<User>?> pickAssignees(
  BuildContext context, {
  required int projectId,
  required List<User> selected,
}) => showPickerSheet<List<User>>(
  context,
  heightFactor: 0.9,
  builder: (context, scrollController) => AssigneePicker(
    projectId: projectId,
    selected: selected,
    scrollController: scrollController,
  ),
);

class AssigneePicker extends ConsumerStatefulWidget {
  const new({
    required this.projectId,
    required this.selected,
    this.scrollController,
    super.key,
  });

  static const debounce = Duration(milliseconds: 300);

  final int projectId;
  final List<User> selected;
  final ScrollController? scrollController;

  @override
  ConsumerState<AssigneePicker> createState() => _AssigneePickerState();
}

class _AssigneePickerState extends ConsumerState<AssigneePicker> {
  final _query = TextEditingController();
  late final List<User> _selected = [...widget.selected];
  Timer? _debounce;
  int _latestSearch = 0;
  bool _searching = true;

  /// The server's answer to [_answeredQuery].
  List<User> _found = const [];
  String? _answeredQuery;

  /// The people this device knows and everyone found so far: the rows,
  /// filtered here, while the server has not answered the current query,
  /// which on a slow or dead connection can take its retries and timeouts.
  List<User> _known = const [];

  /// Set while the last search failed.
  String? _fallbackNotice;

  @override
  void initState() {
    super.initState();
    unawaited(_loadKnown());
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadKnown() async {
    List<User> known;
    try {
      known = await ref.read(userRepositoryProvider)?.knownUsers() ?? const [];
    } on Object {
      return;
    }
    if (mounted) setState(() => _known = _merged(known, _known));
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(AssigneePicker.debounce, () => unawaited(_search(query)));
    setState(() {});
  }

  Future<void> _search(String query) async {
    final search = ++_latestSearch;
    final repository = ref.read(userRepositoryProvider);
    if (!_searching) setState(() => _searching = true);
    List<User>? found;
    Object? failure;
    try {
      if (repository == null) {
        throw const NetworkFailure(NetworkProblem.unreachable);
      }
      found = await repository.searchAssignees(widget.projectId, query);
    } on Object catch (error) {
      failure = error;
    }
    // A slower answer to an earlier query must not replace a newer one.
    if (!mounted || search != _latestSearch) return;
    final l10n = context.l10n;
    setState(() {
      _searching = false;
      if (found != null) {
        _found = found;
        _answeredQuery = query;
        _known = _merged(_known, found);
      }
      _fallbackNotice = switch (failure) {
        null => null,
        NetworkFailure() => l10n.assigneePickerOffline,
        VikunjaFailure(:final message) when message.trim().isNotEmpty =>
          l10n.assigneePickerFallback(message.trim()),
        _ => l10n.assigneePickerFallback(l10n.assigneePickerSearchFailed),
      };
    });
  }

  static List<User> _merged(List<User> first, List<User> more) => [
    ...first,
    for (final user in more)
      if (!first.any((known) => known.id == user.id)) user,
  ];

  bool _isSelected(User user) => _selected.any((s) => s.id == user.id);

  void _toggle(User user) => setState(() {
    if (_isSelected(user)) {
      _selected.removeWhere((s) => s.id == user.id);
    } else {
      _selected.add(user);
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final query = _query.text;
    final rows = peoplePickerRows(
      assigned: widget.selected,
      selected: _selected,
      found: query == _answeredQuery ? _found : filterUsers(_known, query),
    );

    // Everything under the header scrolls: with the keyboard up, in
    // landscape or at a large text size, little room is left.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(
          title: l10n.assigneePickerTitle,
          actionLabel: l10n.pickerDone,
          onAction: () => Navigator.of(context).pop(_selected),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.assigneePickerSearch,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              SizedBox(
                height: 4,
                child: _searching
                    ? LinearProgressIndicator(
                        semanticsLabel: l10n.assigneePickerSearching,
                      )
                    : null,
              ),
              if (_fallbackNotice case final notice?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.cloud_off_outlined,
                            size: 20,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            notice,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              for (final user in rows)
                CheckboxListTile.adaptive(
                  value: _isSelected(user),
                  onChanged: (_) => _toggle(user),
                  secondary: InitialsAvatar(user: user, radius: 18),
                  title: Text(user.displayName),
                  subtitle: Text(l10n.assigneeUsername(user.username)),
                ),
              if (rows.isEmpty && !_searching)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.assigneePickerNoResults,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
