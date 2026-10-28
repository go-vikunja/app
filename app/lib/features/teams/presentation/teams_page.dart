import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/repositories/team_repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/online_only_fab.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/sync/application/page_reachability.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/teams/application/team_server_providers.dart';
import 'package:vikunja_mobile/features/teams/presentation/new_team_sheet.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_badges.dart';

final _log = Logger('Teams');

/// The teams the user is in, read from the server each time the page opens
/// and on pull to refresh (teams are not stored): name, members and what
/// sets a team apart. A team opens its page; "New team" creates one and
/// opens it.
class TeamsPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends ConsumerState<TeamsPage> with PageReachability {
  List<Team>? _teams;
  Object? _failure;
  var _loading = false;
  var _loads = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// The latest read wins: one that started before a change on a team's
  /// page would show the list without it.
  Future<void> _load() async {
    final repository = ref.read(teamRepositoryProvider);
    if (repository == null) return;
    final load = ++_loads;
    setState(() => _loading = true);
    bool latest() => mounted && load == _loads;
    try {
      final teams = await repository.list();
      if (latest()) {
        setState(() {
          _teams = teams;
          _failure = null;
          noteReached();
        });
      }
    } on Object catch (error) {
      _log.info('Reading the teams failed: ${error.runtimeType}');
      if (latest()) {
        setState(() {
          _failure = error;
          noteFailure(error);
        });
      }
    } finally {
      if (latest()) setState(() => _loading = false);
    }
  }

  Future<void> _open(int teamId) async {
    await context.pushPage<void>(AppRoutes.team(teamId));
    if (mounted) await _load();
  }

  Future<void> _create() {
    final l10n = context.l10n;
    return showNewTeamSheet(
      context,
      onCreated: (team) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.teamCreated)));
        setState(() => _teams = [...?_teams, team]);
        unawaited(_open(team.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final teams = _teams;
    final failure = _failure;
    final offline = watchOffline(
      onBackOnline: () {
        if (_failure is NetworkFailure) unawaited(_load());
      },
    );
    final userId = ref.watch(activeUserIdProvider);
    final publicTeams = ref.watch(activeServerHasPublicTeamsProvider);
    final notice = switch (failure) {
      NetworkFailure(
        problem: NetworkProblem(concernsConnectionSettings: false),
      ) =>
        const OfflineNotice(),
      final failure? when teams != null => DataFailureCard(
        error: failure,
        stale: true,
        onRetry: () => unawaited(_load()),
      ),
      null when offline => const OfflineNotice(),
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.teamsTitle),
        actions: [
          RefreshButton(onPressed: _loading ? null : () => unawaited(_load())),
        ],
      ),
      floatingActionButton: OnlineOnlyFab(
        icon: Icons.group_add_outlined,
        label: l10n.teamsNew,
        offline: offline,
        offlineReason: l10n.teamsNewOffline,
        onPressed: () => unawaited(_create()),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // The page's context still carries the status bar, which the app
          // bar already takes.
          padding:
              MediaQuery.paddingOf(context).copyWith(top: 0) +
              const EdgeInsets.only(top: 8, bottom: 96),
          children: [
            if (notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: notice,
              ),
            if (teams == null && failure != null && failure is! NetworkFailure)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DataFailureCard(
                  error: failure,
                  stale: false,
                  onRetry: () => unawaited(_load()),
                ),
              )
            else if (teams == null && _loading)
              LoadingPlaceholder(label: l10n.teamsLoading)
            else if (teams != null && teams.isEmpty)
              Column(
                children: [
                  EmptyState(
                    icon: Icons.groups_outlined,
                    title: l10n.teamsEmptyTitle,
                    body: l10n.teamsEmptyBody,
                  ),
                  FilledButton.tonalIcon(
                    onPressed: offline ? null : () => unawaited(_create()),
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(l10n.teamsNew),
                  ),
                ],
              )
            else if (teams != null)
              SectionCard(
                children: [
                  for (final team in teams)
                    _TeamRow(
                      key: ValueKey(team.id),
                      team: team,
                      badges: teamBadges(
                        l10n,
                        team,
                        admin:
                            userId != null &&
                            TeamGuards.of(team, currentUserId: userId).isAdmin,
                        publicTeams: publicTeams,
                      ),
                      onTap: () => unawaited(_open(team.id)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const new({
    required this.team,
    required this.badges,
    required this.onTap,
    super.key,
  });

  final Team team;
  final List<Widget> badges;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: TeamAvatar(name: team.name),
      title: Text(team.name.trim().isEmpty ? '–' : team.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.teamMemberCount(team.members.length)),
          if (badges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 6, runSpacing: 4, children: badges),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
