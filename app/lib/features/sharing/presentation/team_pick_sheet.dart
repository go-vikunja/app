import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/team_repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/sharing/application/share_candidates.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_badges.dart';

final _log = Logger('TeamPick');

/// One of the user's teams (and the public ones when [includePublic]) to
/// share a project with, read from the server; [excludedTeamIds] are never
/// offered. Null when dismissed.
Future<Team?> pickTeam(
  BuildContext context, {
  required Set<int> excludedTeamIds,
  required bool includePublic,
}) => showPickerSheet<Team>(
  context,
  heightFactor: 0.8,
  builder: (context, scrollController) => TeamPickSheet(
    excludedTeamIds: excludedTeamIds,
    includePublic: includePublic,
    scrollController: scrollController,
  ),
);

class TeamPickSheet extends ConsumerStatefulWidget {
  const new({
    required this.excludedTeamIds,
    required this.includePublic,
    this.scrollController,
    super.key,
  });

  /// More teams than this get a field to filter them.
  static const filterFrom = 8;

  final Set<int> excludedTeamIds;
  final bool includePublic;
  final ScrollController? scrollController;

  @override
  ConsumerState<TeamPickSheet> createState() => _TeamPickSheetState();
}

class _TeamPickSheetState extends ConsumerState<TeamPickSheet> {
  final _filter = TextEditingController();
  List<Team>? _teams;
  Object? _failure;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(teamRepositoryProvider);
    if (repository == null || _loading) return;
    setState(() => _loading = true);
    try {
      final teams = await repository.list(includePublic: widget.includePublic);
      if (mounted) {
        setState(() {
          _teams = [
            for (final team in teams)
              if (!widget.excludedTeamIds.contains(team.id)) team,
          ];
          _failure = null;
        });
      }
    } on Object catch (error) {
      _log.info('Reading the teams failed: ${error.runtimeType}');
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final teams = _teams;
    final failure = _failure;
    final shown = teams == null
        ? const <Team>[]
        : filterTeams(teams, _filter.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(title: l10n.shareAddTeam),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (failure != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: DataFailureCard(
                    error: failure,
                    stale: teams != null,
                    onRetry: () => unawaited(_load()),
                  ),
                ),
              if (_loading && teams == null)
                LoadingPlaceholder(label: l10n.shareTeamsLoading),
              if (teams != null && teams.length > TeamPickSheet.filterFrom)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _filter,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: l10n.shareTeamsFilter,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              if (teams != null && teams.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.includePublic
                        ? l10n.shareTeamsNoneToAddPublic
                        : l10n.shareTeamsNoneToAdd,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              for (final team in shown)
                ListTile(
                  key: ValueKey(team.id),
                  leading: TeamAvatar(name: team.name, radius: 18),
                  title: Text(team.name),
                  subtitle: Text(
                    [
                      l10n.shareTeamMemberCount(team.members.length),
                      if (widget.includePublic && team.isPublic)
                        l10n.shareTeamPublic,
                    ].join(' · '),
                  ),
                  onTap: () => Navigator.of(context).pop(team),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
