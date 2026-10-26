import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

final _log = Logger('PersonSearch');

/// One person found on the server, to share with or add to a team; null
/// when dismissed. [excludedUserIds] are never offered. [reachable] is
/// what the calling page's last request found, null for the last sync's
/// outcome.
Future<User?> pickPerson(
  BuildContext context, {
  required String title,
  required Set<int> excludedUserIds,
  bool? reachable,
}) => showPickerSheet<User>(
  context,
  heightFactor: 0.9,
  builder: (context, scrollController) => PersonSearchSheet(
    title: title,
    excludedUserIds: excludedUserIds,
    reachable: reachable,
    scrollController: scrollController,
  ),
);

/// Searches the server as the user types, after a pause; the server finds
/// people by their exact username, and by name or email only when they
/// allow it, so nothing is offered before something is typed.
class PersonSearchSheet extends ConsumerStatefulWidget {
  const new({
    required this.title,
    required this.excludedUserIds,
    this.reachable,
    this.scrollController,
    super.key,
  });

  static const debounce = Duration(milliseconds: 300);

  final String title;
  final Set<int> excludedUserIds;

  /// Whether the page below last reached the server; null when the last
  /// sync decides. A search that gets an answer settles it.
  final bool? reachable;
  final ScrollController? scrollController;

  @override
  ConsumerState<PersonSearchSheet> createState() => _PersonSearchSheetState();
}

class _PersonSearchSheetState extends ConsumerState<PersonSearchSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  int _latestSearch = 0;
  bool _searching = false;
  List<User> _found = const [];
  String? _answeredQuery;
  Object? _failure;
  late bool? _reachable = widget.reachable;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _latestSearch++;
      setState(() {
        _searching = false;
        _found = const [];
        _answeredQuery = null;
        _failure = null;
      });
      return;
    }
    _debounce = Timer(
      PersonSearchSheet.debounce,
      () => unawaited(_search(query)),
    );
  }

  Future<void> _search(String query) async {
    final search = ++_latestSearch;
    final repository = ref.read(userRepositoryProvider);
    setState(() => _searching = true);
    List<User>? found;
    Object? failure;
    try {
      if (repository == null) {
        throw const NetworkFailure(NetworkProblem.unreachable);
      }
      found = await repository.search(query);
    } on Object catch (error) {
      _log.info('Searching for people failed: ${error.runtimeType}');
      failure = error;
    }
    // A slower answer to an earlier query must not replace a newer one.
    if (!mounted || search != _latestSearch) return;
    setState(() {
      _searching = false;
      _failure = failure;
      if (found != null) {
        _found = found;
        _answeredQuery = query;
        _reachable = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final offline = switch (_reachable) {
      null => ref.watch(offlineProvider) != null,
      final reachable => !reachable,
    };
    // The last answer stays until the next one replaces it.
    final answered = _answeredQuery != null;
    final rows = [
      if (answered)
        for (final user in _found)
          if (!widget.excludedUserIds.contains(user.id)) user,
    ];
    final notice = switch (_failure) {
      _ when offline => l10n.sharePeopleSearchOffline,
      NetworkFailure() => l10n.sharePeopleSearchOffline,
      null => null,
      _ => l10n.sharePeopleSearchFailed,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(title: widget.title),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  enabled: !offline,
                  autofocus: !offline,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.sharePeopleSearchField,
                    helperText: l10n.sharePeopleSearchHint,
                    helperMaxLines: 4,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: _onQueryChanged,
                  onSubmitted: (query) {
                    _debounce?.cancel();
                    if (query.trim().isNotEmpty) unawaited(_search(query));
                  },
                ),
              ),
              SizedBox(
                height: 4,
                child: _searching
                    ? LinearProgressIndicator(
                        semanticsLabel: l10n.sharePeopleSearching,
                      )
                    : null,
              ),
              if (notice != null)
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
                ListTile(
                  key: ValueKey(user.id),
                  leading: UserAvatar(user: user, radius: 18),
                  title: Text(user.displayName),
                  subtitle: Text(l10n.assigneeUsername(user.username)),
                  onTap: () => Navigator.of(context).pop(user),
                ),
              if (answered && rows.isEmpty && !_searching && _failure == null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.sharePeopleNoResults,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
