import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/repositories/team_repository_providers.dart';
import 'package:vikunja_mobile/core/text/html_to_text.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/sharing/application/access_cleanup.dart';
import 'package:vikunja_mobile/features/sharing/presentation/person_search_sheet.dart';
import 'package:vikunja_mobile/features/sync/application/page_reachability.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_html.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_link_actions.dart';
import 'package:vikunja_mobile/features/teams/application/team_server_providers.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_badges.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_confirmations.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_edit_sheet.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_failure.dart';

final _log = Logger('Team');

enum _MemberAction { toggleAdmin, remove }

/// What a change is on its way for: a member's row or the whole team.
sealed class _Busy {
  const new();
}

final class _MemberBusy extends _Busy {
  const new(this.userId);

  final int userId;
}

final class _TeamBusy extends _Busy {
  const new();
}

/// One team, read from the server when the page opens, after every change
/// and on pull to refresh: its name, description and badges, its members
/// with their roles, and what the user may do there. Admins of a team that
/// no sign-in provider manages edit it, add members, make them admins or
/// members and remove them, never on their own row; anyone but an external
/// team's members can leave, with the guards the server lacks. Leaving and
/// deleting close the page.
class TeamPage extends ConsumerStatefulWidget {
  const new({required this.teamId, super.key});

  final int teamId;

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> with PageReachability {
  Team? _team;
  Object? _failure;
  var _loading = false;
  var _loads = 0;
  _Busy? _busy;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// A read that started before a change would show the team without it,
  /// so the latest read wins.
  Future<void> _load() async {
    final repository = ref.read(teamRepositoryProvider);
    if (repository == null) return;
    final load = ++_loads;
    setState(() => _loading = true);
    bool latest() => mounted && load == _loads;
    try {
      final team = await repository.read(widget.teamId);
      if (latest()) {
        setState(() {
          _team = team;
          _failure = null;
          noteReached();
        });
      }
    } on Object catch (error) {
      _log.info('Reading a team failed: ${error.runtimeType}');
      if (latest()) {
        setState(() {
          _failure = error;
          noteFailure(error);
          // The user left it elsewhere, or it was deleted.
          if (error is Forbidden || error is NotFound) _team = null;
        });
      }
    } finally {
      if (latest()) setState(() => _loading = false);
    }
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// One change at a time; the team is read again after it, also when it
  /// failed, since the server may have changed meanwhile.
  Future<bool> _change(
    _Busy busy, {
    required TeamChange change,
    required Future<String> Function() send,
  }) async {
    if (_busy != null) return false;
    final l10n = context.l10n;
    setState(() => _busy = busy);
    try {
      final done = await send();
      if (!mounted) return true;
      unawaited(HapticFeedback.selectionClick());
      _showMessage(done);
      return true;
    } on Object catch (error) {
      _log.warning('Changing a team failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) _showMessage(teamFailureText(l10n, error, change));
      return false;
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _toggleAdmin(TeamMember member) async {
    final repository = ref.read(teamRepositoryProvider);
    if (repository == null) return;
    final l10n = context.l10n;
    final name = member.user.displayName;
    await _change(
      _MemberBusy(member.user.id),
      change: TeamChange.toggleAdmin,
      send: () async {
        final admin = await repository.toggleAdmin(
          widget.teamId,
          member.user.username,
        );
        return admin ? l10n.teamMadeAdmin(name) : l10n.teamMadeMember(name);
      },
    );
    if (mounted) await _load();
  }

  Future<void> _remove(TeamMember member) async {
    final repository = ref.read(teamRepositoryProvider);
    if (repository == null || _busy != null) return;
    final l10n = context.l10n;
    final name = member.user.displayName;
    final confirmed = await confirmRemoveMember(
      context,
      name: name,
      cleansUp: ref.read(activeServerCleansUpAccessProvider),
    );
    if (!confirmed || !mounted) return;
    await _change(
      _MemberBusy(member.user.id),
      change: TeamChange.removeMember,
      send: () async {
        await repository.removeMember(widget.teamId, member.user.username);
        return l10n.teamMemberRemoved(name);
      },
    );
    if (mounted) await _load();
  }

  Future<void> _addMember(Team team) async {
    final repository = ref.read(teamRepositoryProvider);
    if (repository == null || _busy != null) return;
    final l10n = context.l10n;
    final user = await pickPerson(
      context,
      title: l10n.teamAddMember,
      excludedUserIds: {for (final member in team.members) member.user.id},
      reachable: reachable,
    );
    if (user == null || !mounted) return;
    await _change(
      const _TeamBusy(),
      change: TeamChange.addMember,
      send: () async {
        await repository.addMember(widget.teamId, user.username);
        return l10n.teamMemberAdded(user.displayName);
      },
    );
    if (mounted) await _load();
  }

  Future<void> _edit(Team team) async {
    final l10n = context.l10n;
    final saved = await showTeamEditSheet(context, team: team);
    if (saved == null || !mounted) return;
    setState(() => _team = saved);
    _showMessage(l10n.teamSaved);
    await _load();
  }

  Future<void> _editDescription(Team team) async {
    final l10n = context.l10n;
    final saved = await context.pushPage<bool>(
      AppRoutes.teamDescription(team.id),
      extra: TeamDescriptionTarget(
        teamId: team.id,
        description: team.description,
      ),
    );
    if (!mounted) return;
    if (saved ?? false) _showMessage(l10n.descriptionEditorSaved);
    await _load();
  }

  Future<void> _leave(Team team, int userId) async {
    final repository = ref.read(teamRepositoryProvider);
    if (repository == null || _busy != null) return;
    final l10n = context.l10n;
    switch (TeamGuards.of(team, currentUserId: userId).leave) {
      case TeamLeaveRule.makeSomeoneAdminFirst:
        await explainOnlyAdmin(context);
      case TeamLeaveRule.deleteInstead:
        if (await offerDeleteInstead(context) && mounted) await _delete(team);
      case TeamLeaveRule.unavailable:
        break;
      case TeamLeaveRule.allowed:
        final confirmed = await confirmLeaveTeam(
          context,
          team: team.name,
          cleansUp: ref.read(activeServerCleansUpAccessProvider),
        );
        if (!confirmed || !mounted) return;
        final router = GoRouter.of(context);
        final left = await _change(
          const _TeamBusy(),
          change: TeamChange.leave,
          send: () async {
            await repository.leave(widget.teamId);
            return l10n.teamLeft;
          },
        );
        if (!mounted) return;
        if (left) {
          router.pop();
        } else {
          await _load();
        }
    }
  }

  Future<void> _delete(Team team) async {
    final repository = ref.read(teamRepositoryProvider);
    if (repository == null || _busy != null) return;
    final l10n = context.l10n;
    final confirmed = await confirmDeleteTeam(
      context,
      team: team.name,
      cleansUp: ref.read(activeServerCleansUpAccessProvider),
    );
    if (!confirmed || !mounted) return;
    final router = GoRouter.of(context);
    final deleted = await _change(
      const _TeamBusy(),
      change: TeamChange.delete,
      send: () async {
        await repository.delete(widget.teamId);
        return l10n.teamDeleted;
      },
    );
    if (!mounted) return;
    if (deleted) {
      router.pop();
    } else {
      await _load();
    }
  }

  void _openLink(String href) => unawaited(
    openRichTextLink(
      ref,
      href,
      openTask: _openTask,
      showMessage: (text) {
        if (mounted) _showMessage(text(context.l10n));
      },
    ),
  );

  void _openTask(int taskId) => unawaited(
    ref.read(taskOpenerProvider).openInActiveAccount(TaskById(taskId)),
  );

  void _onMemberAction(TeamMember member, _MemberAction action) =>
      unawaited(switch (action) {
        _MemberAction.toggleAdmin => _toggleAdmin(member),
        _MemberAction.remove => _remove(member),
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final team = _team;
    final failure = _failure;
    final userId = ref.watch(activeUserIdProvider);
    final offline = watchOffline(
      onBackOnline: () {
        if (_failure is NetworkFailure) unawaited(_load());
      },
    );
    final guards = team == null || userId == null
        ? null
        : TeamGuards.of(team, currentUserId: userId);
    final busy = _busy != null;
    final canEdit = (guards?.canEdit ?? false) && !offline && !busy;

    final Widget body;
    if (team == null) {
      body = switch (failure) {
        Forbidden() || NotFound() => CenteredScrollView(
          maxWidth: ReadableWidth.form,
          child: EmptyState(
            icon: Icons.group_off_outlined,
            title: l10n.teamGoneTitle,
            body: l10n.teamGoneBody,
          ),
        ),
        final failure? => CenteredScrollView(
          maxWidth: ReadableWidth.form,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DataFailureCard(
              error: failure,
              stale: false,
              onRetry: () => unawaited(_load()),
            ),
          ),
        ),
        null => CenteredScrollView(
          maxWidth: ReadableWidth.form,
          child: LoadingPlaceholder(label: l10n.teamLoading),
        ),
      };
    } else {
      body = _TeamView(
        team: team,
        guards: guards,
        userId: userId,
        notice: switch (failure) {
          NetworkFailure(
            problem: NetworkProblem(concernsConnectionSettings: false),
          ) =>
            const OfflineNotice(),
          final failure? => DataFailureCard(
            error: failure,
            stale: true,
            onRetry: () => unawaited(_load()),
          ),
          null when offline => const OfflineNotice(),
          null => null,
        },
        badges: teamBadges(
          l10n,
          team,
          admin: guards?.isAdmin ?? false,
          publicTeams: ref.watch(activeServerHasPublicTeamsProvider),
        ),
        busy: _busy,
        enabled: !busy && !offline,
        onEditDescription: canEdit
            ? () => unawaited(_editDescription(team))
            : null,
        onAddMember: (guards?.canAddMembers ?? false)
            ? () => unawaited(_addMember(team))
            : null,
        onMemberAction: _onMemberAction,
        onLeave: userId == null ? null : () => unawaited(_leave(team, userId)),
        onDelete: () => unawaited(_delete(team)),
        onLink: _openLink,
        onTaskLink: _openTask,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(team?.name ?? l10n.teamsTitle),
        actions: [
          if (team != null && (guards?.canEdit ?? false))
            IconButton(
              onPressed: canEdit ? () => unawaited(_edit(team)) : null,
              tooltip: l10n.teamEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          RefreshButton(onPressed: _loading ? null : () => unawaited(_load())),
        ],
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: RefreshIndicator.adaptive(onRefresh: _load, child: body),
    );
  }
}

class _TeamView extends StatelessWidget {
  const new({
    required this.team,
    required this.guards,
    required this.userId,
    required this.notice,
    required this.badges,
    required this.busy,
    required this.enabled,
    required this.onEditDescription,
    required this.onAddMember,
    required this.onMemberAction,
    required this.onLeave,
    required this.onDelete,
    required this.onLink,
    required this.onTaskLink,
  });

  final Team team;
  final TeamGuards? guards;
  final int? userId;
  final Widget? notice;
  final List<Widget> badges;
  final _Busy? busy;

  /// False while a change is on its way and offline.
  final bool enabled;
  final VoidCallback? onEditDescription;
  final VoidCallback? onAddMember;
  final void Function(TeamMember member, _MemberAction action) onMemberAction;
  final VoidCallback? onLeave;
  final VoidCallback onDelete;
  final ValueChanged<String> onLink;
  final ValueChanged<int> onTaskLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final guards = this.guards;
    final provider = team.isExternal ? externalTeamProvider(team.name) : null;
    final members = [...team.members]
      ..sort((a, b) {
        final byName = compareTitles(a.user.displayName, b.user.displayName);
        if (byName != 0) return byName;
        final byUsername = a.user.username.compareTo(b.user.username);
        return byUsername != 0 ? byUsername : a.user.id.compareTo(b.user.id);
      });
    final leave = guards?.leave ?? TeamLeaveRule.unavailable;
    final canDelete = guards?.canDelete ?? false;
    final hasDescription = htmlToPlainText(team.description).trim().isNotEmpty;
    final editsDescription = guards?.canEdit ?? false;

    return ReadableWidth.builder(
      maxWidth: ReadableWidth.form,
      builder: (_, _, inset) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            MediaQuery.paddingOf(context) +
            EdgeInsets.fromLTRB(inset, 8, inset, 32),
        children: [
          if (notice case final notice?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: notice,
            ),
          SectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TeamAvatar(name: team.name, radius: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                team.name,
                                style: theme.textTheme.titleLarge,
                              ),
                              Text(
                                l10n.teamMemberCount(team.members.length),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 4, children: badges),
                    ],
                    if (hasDescription) ...[
                      const SizedBox(height: 12),
                      SelectionArea(
                        child: RichHtml(
                          html: team.description,
                          onLink: onLink,
                          onTaskLink: onTaskLink,
                        ),
                      ),
                    ],
                    if (editsDescription)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton.icon(
                          onPressed: onEditDescription,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: Icon(
                            hasDescription ? Icons.edit_outlined : Icons.add,
                          ),
                          label: Text(
                            hasDescription
                                ? l10n.teamEditDescription
                                : l10n.teamAddDescription,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (team.isExternal)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ListNote(
                icon: Icons.sync_lock_outlined,
                text: provider == null
                    ? l10n.teamExternalNoteGeneric
                    : l10n.teamExternalNote(provider),
              ),
            ),
          SectionCard(
            title: l10n.teamMembersSection,
            count: members.length,
            children: [
              for (final member in members)
                _MemberRow(
                  key: ValueKey(member.user.id),
                  member: member,
                  isMe: member.user.id == userId,
                  busy: switch (busy) {
                    _MemberBusy(:final userId) => userId == member.user.id,
                    _ => false,
                  },
                  enabled: enabled,
                  canToggleAdmin: guards?.canToggleAdmin(member) ?? false,
                  canRemove: guards?.canRemoveMember(member) ?? false,
                  onAction: (action) => onMemberAction(member, action),
                ),
              if (onAddMember != null)
                ListTile(
                  enabled: enabled,
                  leading: Icon(
                    Icons.person_add_outlined,
                    color: colors.primary,
                  ),
                  title: Text(
                    l10n.teamAddMember,
                    style: TextStyle(color: enabled ? colors.primary : null),
                  ),
                  onTap: onAddMember,
                ),
            ],
          ),
          if (leave != TeamLeaveRule.unavailable || canDelete)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (leave != TeamLeaveRule.unavailable)
                    OutlinedButton.icon(
                      onPressed: enabled ? onLeave : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.teamLeave),
                    ),
                  if (canDelete)
                    OutlinedButton.icon(
                      onPressed: enabled ? onDelete : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.teamDelete),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const new({
    required this.member,
    required this.isMe,
    required this.busy,
    required this.enabled,
    required this.canToggleAdmin,
    required this.canRemove,
    required this.onAction,
    super.key,
  });

  final TeamMember member;
  final bool isMe;
  final bool busy;
  final bool enabled;
  final bool canToggleAdmin;
  final bool canRemove;
  final ValueChanged<_MemberAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final name = member.user.displayName;
    return ListTile(
      leading: UserAvatar(user: member.user, radius: 20, primary: isMe),
      title: Text(isMe ? l10n.teamMemberYou(name) : name),
      subtitle: Text(member.admin ? l10n.teamRoleAdmin : l10n.teamRoleMember),
      trailing: busy
          ? SizedBox.square(
              dimension: kMinInteractiveDimension,
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    semanticsLabel: l10n.teamSaving,
                  ),
                ),
              ),
            )
          : canToggleAdmin || canRemove
          ? PopupMenuButton<_MemberAction>(
              tooltip: l10n.teamMemberOptionsFor(name),
              enabled: enabled,
              icon: const Icon(Icons.more_vert),
              onSelected: onAction,
              itemBuilder: (context) => [
                if (canToggleAdmin)
                  PopupMenuItem(
                    value: _MemberAction.toggleAdmin,
                    child: IgnorePointer(
                      child: ListTile(
                        leading: Icon(
                          member.admin
                              ? Icons.remove_moderator_outlined
                              : Icons.add_moderator_outlined,
                        ),
                        title: Text(
                          member.admin
                              ? l10n.teamMakeMember
                              : l10n.teamMakeAdmin,
                        ),
                      ),
                    ),
                  ),
                if (canRemove)
                  PopupMenuItem(
                    value: _MemberAction.remove,
                    child: IgnorePointer(
                      child: ListTile(
                        leading: Icon(
                          Icons.person_remove_outlined,
                          color: colors.error,
                        ),
                        title: Text(
                          l10n.teamRemoveMember,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}
