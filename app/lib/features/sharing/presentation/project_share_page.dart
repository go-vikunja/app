import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/project_sharing_repository.dart';
import 'package:vikunja_mobile/core/repositories/project_sharing_repository_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';
import 'package:vikunja_mobile/features/sharing/application/access_cleanup.dart';
import 'package:vikunja_mobile/features/sharing/application/link_share_links.dart';
import 'package:vikunja_mobile/features/sharing/application/share_candidates.dart';
import 'package:vikunja_mobile/features/sharing/presentation/link_share_form_sheet.dart';
import 'package:vikunja_mobile/features/sharing/presentation/link_share_sheet.dart';
import 'package:vikunja_mobile/features/sharing/presentation/person_search_sheet.dart';
import 'package:vikunja_mobile/features/sharing/presentation/share_texts.dart';
import 'package:vikunja_mobile/features/sharing/presentation/team_pick_sheet.dart';
import 'package:vikunja_mobile/features/sync/application/page_reachability.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/teams/application/team_server_providers.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_badges.dart';

final _log = Logger('ProjectShare');

enum _ShareChoice {
  read(Permission.read),
  write(Permission.write),
  admin(Permission.admin),
  remove(null);

  new(this.permission);

  final Permission? permission;
}

/// Who a project is shared with, read from the server each time it opens:
/// people, teams and, for admins on a server with link sharing, links.
/// Admins change a share's permission or remove it from its row, add
/// people and teams, and create, share and delete links; everyone else
/// sees the people and teams only. Each change goes to the server at once,
/// one at a time, and the lists are read again.
class ProjectSharePage extends ConsumerStatefulWidget {
  const new({required this.projectId, super.key});

  final int projectId;

  @override
  ConsumerState<ProjectSharePage> createState() => _ProjectSharePageState();
}

class _ProjectSharePageState extends ConsumerState<ProjectSharePage>
    with PageReachability {
  List<ProjectUserShare>? _users;
  List<ProjectTeamShare>? _teams;
  List<LinkShare>? _links;
  Object? _failure;
  Object? _linksFailure;
  bool _loading = false;
  int _loads = 0;

  /// The row (or add row) a change is on its way for.
  String? _busy;

  /// The view each link opens, as picked on this page.
  final _linkViewIds = <int, int>{};

  /// The user removed their own share here; the project may go with the
  /// next sync, which is no sign that it was deleted.
  bool _removedSelf = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  ServerConnection? _connection() =>
      ref.read(accountsProvider).value?.activeAccount?.connection;

  bool _offersLinks(ServerConnection? connection, ProjectAccess access) =>
      access.canManageShares &&
      (connection?.capabilities.has(Capability.linkSharing) ?? false);

  Future<void> _load() async {
    final repository = ref.read(projectSharingRepositoryProvider);
    if (repository == null) return;
    final load = ++_loads;
    setState(() => _loading = true);
    final withLinks = _offersLinks(
      _connection(),
      ref.read(projectAccessProvider(widget.projectId)),
    );
    final links = withLinks
        ? _readLinks(repository)
        : Future.value((null, null));
    try {
      final lists = await Future.wait<Object>([
        repository.userShares(widget.projectId),
        repository.teamShares(widget.projectId),
      ]);
      final (linkShares, linksFailure) = await links;
      if (!mounted || load != _loads) return;
      setState(() {
        _users = lists[0] as List<ProjectUserShare>;
        _teams = lists[1] as List<ProjectTeamShare>;
        _links = linkShares;
        _linksFailure = linksFailure;
        _failure = null;
        noteReached();
      });
    } on Object catch (error) {
      _log.info('Reading the shares failed: ${error.runtimeType}');
      if (mounted && load == _loads) {
        setState(() {
          _failure = error;
          noteFailure(error);
        });
      }
    } finally {
      if (mounted && load == _loads) setState(() => _loading = false);
    }
  }

  Future<(List<LinkShare>?, Object?)> _readLinks(
    ProjectSharingRepository repository,
  ) async {
    try {
      return (await repository.linkShares(widget.projectId), null);
    } on Object catch (error) {
      _log.info('Reading the link shares failed: ${error.runtimeType}');
      return (null, error);
    }
  }

  /// True when the change went through.
  Future<bool> _change(
    String busy,
    ShareChange change, {
    required String done,
    required Future<void> Function(ProjectSharingRepository repository) send,
  }) async {
    final repository = ref.read(projectSharingRepositoryProvider);
    if (repository == null || _busy != null) return false;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = busy);
    var reload = true;
    var changed = false;
    try {
      await send(repository);
      changed = true;
      unawaited(HapticFeedback.selectionClick());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
    } on Object catch (error) {
      _log.warning('Changing a share failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(shareFailureText(l10n, error, change))),
        );
      reload = shareListOutdatedBy(error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
    if (reload && mounted) await _load();
    return changed;
  }

  Future<Permission?> _choosePermission(String name) {
    final l10n = context.l10n;
    return showOptionSheet<Permission>(
      context,
      title: l10n.sharePermissionFor(name),
      options: [
        for (final permission in Permission.values)
          SheetOption(
            value: permission,
            label: permissionLabel(l10n, permission),
            selected: permission == Permission.read,
          ),
      ],
    );
  }

  Future<_ShareChoice?> _chooseChange(String name, Permission current) {
    final l10n = context.l10n;
    return showOptionSheet<_ShareChoice>(
      context,
      title: l10n.shareAccessFor(name),
      options: [
        for (final choice in _ShareChoice.values)
          switch (choice.permission) {
            final permission? => SheetOption(
              value: choice,
              label: permissionLabel(l10n, permission),
              selected: permission == current,
            ),
            null => SheetOption(
              value: choice,
              label: l10n.shareRemove,
              destructive: true,
            ),
          },
      ],
    );
  }

  Future<bool> _confirmRemoval(
    String name, {
    required String loss,
    bool self = false,
  }) {
    final l10n = context.l10n;
    return confirmAdaptive(
      context,
      title: l10n.shareRemoveTitle(name),
      body: accessRemovalBody(
        l10n,
        loss: loss,
        self: self,
        listsCleanup: ref.read(activeServerCleansUpAccessProvider),
      ),
      confirmLabel: l10n.shareRemove,
      destructive: true,
    );
  }

  Future<void> _addPerson(Project? project) async {
    final l10n = context.l10n;
    final user = await pickPerson(
      context,
      title: l10n.shareAddPerson,
      excludedUserIds: peopleNotToOffer(
        shares: _users ?? const [],
        currentUserId: ref.read(activeUserIdProvider),
        ownerId: project?.owner?.id,
      ),
      reachable: reachable,
    );
    if (user == null || !mounted) return;
    final name = user.displayName;
    final permission = await _choosePermission(name);
    if (permission == null || !mounted) return;
    await _change(
      'add-person',
      ShareChange.addPerson,
      done: l10n.shareAdded(name),
      send: (repository) =>
          repository.shareWithUser(widget.projectId, user.username, permission),
    );
  }

  Future<void> _changePerson(
    ProjectUserShare share, {
    required bool isMe,
  }) async {
    final l10n = context.l10n;
    final user = share.user;
    final name = user.displayName;
    final choice = await _chooseChange(name, share.permission);
    if (choice == null || !mounted) return;
    final busy = 'user:${user.id}';
    switch (choice.permission) {
      case null:
        final confirmed = await _confirmRemoval(
          name,
          loss: isMe
              ? l10n.shareRemoveSelfBody
              : l10n.shareRemovePersonBody(name),
          self: isMe,
        );
        if (!confirmed || !mounted) return;
        // Before the request: the share lists read after it, or the sync it
        // starts, may already find the project out of reach.
        if (isMe) setState(() => _removedSelf = true);
        final removed = await _change(
          busy,
          ShareChange.removePerson,
          done: isMe ? l10n.shareRemovedSelf : l10n.shareRemoved(name),
          send: (repository) =>
              repository.removeUserShare(widget.projectId, user.username),
        );
        if (isMe && !removed && mounted) setState(() => _removedSelf = false);
      case final permission when permission == share.permission:
        return;
      case final permission:
        if (isMe &&
            permission.value < share.permission.value &&
            !await _confirmLoweringOwn(share.permission)) {
          return;
        }
        if (!mounted) return;
        await _change(
          busy,
          ShareChange.changePerson,
          done: l10n.sharePermissionChanged(name),
          send: (repository) => repository.setUserPermission(
            widget.projectId,
            user.username,
            permission,
          ),
        );
    }
  }

  /// The user's own share loses rights the user may need to undo it.
  Future<bool> _confirmLoweringOwn(Permission current) {
    final l10n = context.l10n;
    return confirmAdaptive(
      context,
      title: l10n.shareLowerOwnAccessTitle,
      body: current.isAdmin
          ? l10n.shareLowerOwnAccessAdminBody
          : l10n.shareLowerOwnAccessWriteBody,
      confirmLabel: l10n.shareLowerOwnAccessConfirm,
      destructive: true,
    );
  }

  Future<void> _addTeam() async {
    final l10n = context.l10n;
    final team = await pickTeam(
      context,
      excludedTeamIds: {
        for (final share in _teams ?? const <ProjectTeamShare>[]) share.teamId,
      },
      includePublic: ref.read(activeServerHasPublicTeamsProvider),
    );
    if (team == null || !mounted) return;
    final permission = await _choosePermission(team.name);
    if (permission == null || !mounted) return;
    await _change(
      'add-team',
      ShareChange.addTeam,
      done: l10n.shareAdded(team.name),
      send: (repository) =>
          repository.shareWithTeam(widget.projectId, team.id, permission),
    );
  }

  Future<void> _changeTeam(ProjectTeamShare share) async {
    final l10n = context.l10n;
    final name = share.teamName ?? l10n.shareHiddenTeam;
    final choice = await _chooseChange(name, share.permission);
    if (choice == null || !mounted) return;
    final busy = 'team:${share.teamId}';
    switch (choice.permission) {
      case null:
        final confirmed = await _confirmRemoval(
          name,
          loss: l10n.shareRemoveTeamBody(name),
        );
        if (!confirmed || !mounted) return;
        await _change(
          busy,
          ShareChange.removeTeam,
          done: l10n.shareRemoved(name),
          send: (repository) =>
              repository.removeTeamShare(widget.projectId, share.teamId),
        );
      case final permission when permission == share.permission:
        return;
      case final permission:
        await _change(
          busy,
          ShareChange.changeTeam,
          done: l10n.sharePermissionChanged(name),
          send: (repository) => repository.setTeamPermission(
            widget.projectId,
            share.teamId,
            permission,
          ),
        );
    }
  }

  Future<void> _createLink(Project? project, List<ProjectView> views) =>
      createLinkShare(
        context,
        projectId: widget.projectId,
        onCreated: (share) {
          if (!mounted) return;
          unawaited(HapticFeedback.selectionClick());
          unawaited(_load());
          unawaited(_openLink(share, project, views, created: true));
        },
      );

  Future<void> _openLink(
    LinkShare share,
    Project? project,
    List<ProjectView> views, {
    bool created = false,
  }) async {
    final l10n = context.l10n;
    final delete = await showLinkShareSheet(
      context,
      share: share,
      projectTitle: project?.displayTitle(l10n) ?? l10n.projectUnknownTitle,
      views: views,
      viewId: _linkViewIds[share.id],
      onViewChanged: (viewId) {
        if (mounted) setState(() => _linkViewIds[share.id] = viewId);
      },
      created: created,
    );
    if ((delete ?? false) && mounted) await _deleteLink(share);
  }

  Future<void> _deleteLink(LinkShare share) async {
    final l10n = context.l10n;
    final name = share.name.trim();
    final confirmed = await confirmAdaptive(
      context,
      title: name.isEmpty
          ? l10n.linkShareDeleteUnnamedTitle
          : l10n.linkShareDeleteTitle(name),
      body: l10n.linkShareDeleteBody,
      confirmLabel: l10n.linkShareDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _change(
      'link:${share.id}',
      ShareChange.deleteLink,
      done: l10n.linkShareDeleted,
      send: (repository) =>
          repository.deleteLinkShare(widget.projectId, share.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    watchOffline(
      onBackOnline: () {
        if (_failure is NetworkFailure) unawaited(_load());
      },
    );
    // A sync after the user's own share changed may bring other rights.
    ref.listen(projectAccessProvider(widget.projectId), (previous, next) {
      if (previous?.canManageShares != next.canManageShares) {
        unawaited(_load());
      }
    });
    final projects = ref.watch(projectsProvider);
    final project = (projects.value ?? const <Project>[])
        .where((project) => project.id == widget.projectId)
        .firstOrNull;
    final title = l10n.sharePageTitle(
      project?.displayTitle(l10n) ?? l10n.projectUnknownTitle,
    );
    final gone = project == null && projects.hasValue;
    if (_removedSelf &&
        (gone || _failure is Forbidden || _failure is NotFound)) {
      return Scaffold(
        appBar: AppBar(title: ScreenTitle(title)),
        body: CenteredScrollView(
          maxWidth: ReadableWidth.form,
          child: EmptyState(
            icon: Icons.lock_outline,
            title: l10n.shareNoAccessTitle,
            body: l10n.shareNoAccessBody,
          ),
        ),
      );
    }
    if (gone) {
      return Scaffold(
        appBar: AppBar(title: ScreenTitle(title)),
        body: CenteredScrollView(
          maxWidth: ReadableWidth.form,
          child: EmptyState(
            icon: Icons.search_off,
            title: l10n.projectGoneTitle,
            body: l10n.projectGoneBody,
          ),
        ),
      );
    }
    final access = ref.watch(projectAccessProvider(widget.projectId));
    final admin = access.canManageShares;
    final me = ref.watch(activeUserIdProvider);
    final connection = ref.watch(
      accountsProvider.select(
        (accounts) => accounts.value?.activeAccount?.connection,
      ),
    );
    final bases = ref.watch(activeLinkBasesProvider);
    final views = linkViewChoices(project);
    final users = _users;
    final teams = _teams;
    final links = _links;
    final failure = _failure;
    final linksFailure = _linksFailure;
    final hasData = users != null && teams != null;
    final busy = _busy;
    final idle = busy == null;
    final showsLinks =
        hasData &&
        _offersLinks(connection, access) &&
        linksFailure is! Forbidden;

    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(title),
        actions: [
          RefreshButton(onPressed: _loading ? null : () => unawaited(_load())),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _load,
        child: ReadableWidth.builder(
          maxWidth: ReadableWidth.form,
          builder: (_, _, inset) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // An explicit padding replaces the system bars' and cutouts'; the
            // page's context still carries the status bar, which the app bar
            // already takes.
            padding:
                MediaQuery.paddingOf(context).copyWith(top: 0) +
                EdgeInsets.fromLTRB(inset, 0, inset, 32),
            children: [
              if (failure is NetworkFailure)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: OfflineNotice(),
                )
              else if (failure != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: DataFailureCard(
                    error: failure,
                    stale: hasData,
                    onRetry: () => unawaited(_load()),
                  ),
                ),
              if (_loading && !hasData)
                LoadingPlaceholder(label: l10n.sharePageLoading),
              if (hasData) ...[
                if (!admin)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: ListNote(
                      icon: Icons.lock_outline,
                      text: l10n.shareReadOnlyNote,
                    ),
                  ),
                SectionCard(
                  title: l10n.sharePeopleSection,
                  children: [
                    for (final share in users)
                      _PersonRow(
                        key: ValueKey('user-${share.user.id}'),
                        share: share,
                        isMe: share.user.id == me,
                        busy: busy == 'user:${share.user.id}',
                        onTap: admin && idle
                            ? () => unawaited(
                                _changePerson(share, isMe: share.user.id == me),
                              )
                            : null,
                      ),
                    if (users.isEmpty) _NoteRow(text: l10n.sharePeopleEmpty),
                    if (admin)
                      _AddRow(
                        icon: Icons.person_add_alt_outlined,
                        label: l10n.shareAddPerson,
                        busy: busy == 'add-person',
                        onTap: idle
                            ? () => unawaited(_addPerson(project))
                            : null,
                      ),
                  ],
                ),
                SectionCard(
                  title: l10n.shareTeamsSection,
                  children: [
                    for (final share in teams)
                      _TeamRow(
                        key: ValueKey('team-${share.teamId}'),
                        share: share,
                        busy: busy == 'team:${share.teamId}',
                        onTap: admin && idle
                            ? () => unawaited(_changeTeam(share))
                            : null,
                      ),
                    if (teams.isEmpty) _NoteRow(text: l10n.shareTeamsEmpty),
                    if (admin)
                      _AddRow(
                        icon: Icons.group_add_outlined,
                        label: l10n.shareAddTeam,
                        busy: busy == 'add-team',
                        onTap: idle ? () => unawaited(_addTeam()) : null,
                      ),
                  ],
                ),
                if (showsLinks) ...[
                  if (linksFailure != null &&
                      linksFailure is! NotFound &&
                      linksFailure is! NetworkFailure)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: DataFailureCard(
                        error: linksFailure,
                        stale: false,
                        onRetry: () => unawaited(_load()),
                      ),
                    ),
                  SectionCard(
                    title: l10n.shareLinksSection,
                    children: [
                      if (linksFailure case NotFound(routeAbsent: true))
                        _NoteRow(text: l10n.shareFailureLinkSharingOff)
                      else ...[
                        for (final share in links ?? const <LinkShare>[])
                          _LinkRow(
                            key: ValueKey('link-${share.id}'),
                            share: share,
                            url: bases == null
                                ? null
                                : linkShareUriFor(
                                    bases,
                                    share,
                                    viewId: linkViewIdFor(
                                      views,
                                      _linkViewIds[share.id],
                                    ),
                                  ),
                            view: views.length > 1
                                ? views
                                      .where(
                                        (view) =>
                                            view.id ==
                                            linkViewIdFor(
                                              views,
                                              _linkViewIds[share.id],
                                            ),
                                      )
                                      .firstOrNull
                                : null,
                            projectTitle:
                                project?.displayTitle(l10n) ??
                                l10n.projectUnknownTitle,
                            busy: busy == 'link:${share.id}',
                            onTap: idle
                                ? () => unawaited(
                                    _openLink(share, project, views),
                                  )
                                : null,
                          ),
                        if (links != null && links.isEmpty)
                          _NoteRow(
                            text: l10n.shareLinksEmpty,
                            detail: l10n.shareLinksIntro,
                          ),
                        _AddRow(
                          icon: Icons.add_link,
                          label: l10n.linkShareCreate,
                          busy: false,
                          onTap: idle && linksFailure == null
                              ? () => unawaited(_createLink(project, views))
                              : null,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: kMinInteractiveDimension,
    child: Center(
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          semanticsLabel: context.l10n.shareSaving,
        ),
      ),
    ),
  );
}

/// Shows that tapping the row offers more.
class _MoreIcon extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(
      Icons.more_vert,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _PersonRow extends StatelessWidget {
  const new({
    required this.share,
    required this.isMe,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final ProjectUserShare share;
  final bool isMe;
  final bool busy;

  /// Null for who may not change it, and while a change is on its way.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = share.user.displayName;
    return _ChangeAccessHint(
      enabled: onTap != null,
      child: ListTile(
        leading: UserAvatar(user: share.user, radius: 20, primary: isMe),
        title: Text(isMe ? l10n.shareUserIsYou(name) : name),
        subtitle: Text(permissionLabel(l10n, share.permission)),
        trailing: busy
            ? const _Spinner()
            : onTap == null
            ? null
            : const _MoreIcon(),
        onTap: onTap,
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const new({
    required this.share,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final ProjectTeamShare share;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final name = share.teamName;
    final memberCount = share.memberCount;
    return _ChangeAccessHint(
      enabled: onTap != null,
      child: ListTile(
        leading: name == null
            ? ExcludeSemantics(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.group_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              )
            : TeamAvatar(name: name),
        title: Text(name ?? l10n.shareHiddenTeam),
        subtitle: Text(
          [
            permissionLabel(l10n, share.permission),
            if (memberCount != null) l10n.shareTeamMemberCount(memberCount),
          ].join(' · '),
        ),
        trailing: busy
            ? const _Spinner()
            : onTap == null
            ? null
            : const _MoreIcon(),
        onTap: onTap,
      ),
    );
  }
}

class _LinkRow extends ConsumerWidget {
  const new({
    required this.share,
    required this.url,
    required this.view,
    required this.projectTitle,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final LinkShare share;
  final Uri? url;

  /// The view the link opens, when the project has more than one.
  final ProjectView? view;
  final String projectTitle;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final sharedBy = share.sharedBy;
    final view = this.view;
    final url = this.url;
    final title = linkShareTitle(l10n, share);
    final tile = ListTile(
      leading: Icon(
        share.passwordProtected ? Icons.lock_outline : Icons.link,
        color: colors.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              permissionLabel(l10n, share.permission),
              if (share.passwordProtected) l10n.linkSharePasswordProtected,
            ].join(' · '),
          ),
          if (sharedBy != null)
            Text(l10n.linkShareCreatedBy(sharedBy.displayName)),
          if (view != null) Text(l10n.linkShareView(viewTitle(l10n, view))),
        ],
      ),
      trailing: busy
          ? const _Spinner()
          : Builder(
              builder: (context) => IconButton(
                onPressed: url == null || onTap == null
                    ? null
                    : () => unawaited(
                        shareLinkShareUrl(
                          context,
                          ref,
                          url: url,
                          subject: l10n.linkShareSubject(projectTitle),
                        ),
                      ),
                tooltip: l10n.linkShareShareNamed(title),
                icon: const Icon(Icons.share_outlined),
              ),
            ),
      onTap: onTap,
    );
    return Semantics(
      onTapHint: onTap == null ? null : l10n.linkShareRowHint,
      child: tile,
    );
  }
}

/// Says what tapping a person's or team's row does, for screen readers.
class _ChangeAccessHint extends StatelessWidget {
  const new({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? MergeSemantics(
          child: Semantics(
            onTapHint: context.l10n.shareChangeAccessHint,
            child: child,
          ),
        )
      : child;
}

/// What a section says instead of rows.
class _NoteRow extends StatelessWidget {
  const new({required this.text, this.detail});

  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final detail = this.detail;
    return ListTile(
      title: Text(text, style: TextStyle(color: colors.onSurfaceVariant)),
      subtitle: detail == null ? null : Text(detail),
    );
  }
}

class _AddRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? colors.primary : null),
      title: Text(
        label,
        style: TextStyle(color: enabled ? colors.primary : null),
      ),
      trailing: busy ? const _Spinner() : null,
      onTap: onTap,
    );
  }
}
