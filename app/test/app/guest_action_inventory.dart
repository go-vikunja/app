/// What a link-share guest cannot use, by the reason: the providers of
/// the ports and repositories that need a user, the label and people
/// repositories, whose writes and server lookups need one, and the
/// project views and the board's columns, whose view is the owner's to set
/// up. Every use in `app/lib` needs an entry in [guestActionInventory]; a
/// use inside the annotated declaration that generates another provider
/// listed here is that provider's wiring.
const guestWatchedProviders = <String, List<String>>{
  'Follow': [
    'subscriptionRepositoryProvider',
    'accountSubscriptionRepositoryProvider',
  ],
  'teams': [
    'teamRepositoryProvider',
    'teamRepositoryForProvider',
    'teamsPortProvider',
  ],
  'project sharing': [
    'projectSharingRepositoryProvider',
    'projectSharingRepositoryForProvider',
    'projectSharingPortProvider',
  ],
  'saved filters': [
    'savedFilterRepositoryProvider',
    'accountSavedFilterRepositoryProvider',
  ],
  'project views': [
    'projectViewRepositoryProvider',
    'accountProjectViewRepositoryProvider',
  ],
  "the board's columns": [
    'bucketRepositoryProvider',
    'accountBucketRepositoryProvider',
  ],
  'account settings': [
    'accountSettingsRepositoryProvider',
    'accountSettingsRepositoryForProvider',
    'accountSettingsProvider',
    'userSettingsWritePortProvider',
  ],
  'sessions, API tokens, CalDAV, data export and deletion': [
    'accountSecurityRepositoryProvider',
    'accountSecurityRepositoryForProvider',
    'accountSecurityPortProvider',
  ],
  'the inbox and activity notifications': [
    'activityRepositoryProvider',
    'accountActivityRepositoryProvider',
    'activitySyncProvider',
    'inboxItemsProvider',
    'unreadActivityCountProvider',
  ],
  'the bin': [
    'trashRepositoryProvider',
    'trashRepositoryForProvider',
    'trashPortProvider',
  ],
  'creating, editing and deleting labels': [
    'labelRepositoryProvider',
    'accountLabelRepositoryProvider',
  ],
  'looking people up on the server': [
    'userRepositoryProvider',
    'accountUserRepositoryProvider',
  ],
};

/// The raw clients of an account, watched under `features/`: read there,
/// they would go around the repositories and the calls watched below.
const guestWatchedFeatureProviders = <String, List<String>>{
  "an account's clients": [
    'readClientProvider',
    'writeClientProvider',
    'accountDioProvider',
  ],
};

/// Calls on repositories a guest uses too that need a user or are not a
/// guest's to make, watched under `features/`, where actions are built.
const guestWatchedCalls = <String, List<String>>{
  'favourites': ['setFavorite'],
  'reactions': ['addReaction', 'removeReaction'],
  "the owner's project": [
    'createProject',
    'updateProject',
    'updateDescription',
    'moveProject',
    'duplicateProject',
    'deleteProject',
  ],
  "the owner's board view": ['setDoneBucket', 'setDefaultBucket'],
  'restores from the bin': ['restoreTask', 'restoreProject'],
};

/// How a use of the watch list is decided for guests.
sealed class GuestDecision {
  const new();
}

/// Kept from guests by a check of `activeAccountIsGuest`,
/// `accountIsGuest` or `isLinkShare` in the site's own file, or in each
/// file of [checkIn], paths under lib, where the action is offered.
final class Gated extends GuestDecision {
  const new(this.how, {this.checkIn = const []});

  final String how;
  final List<String> checkIn;
}

/// Its uses of the watch list run only on [routes], each closed to guests.
final class BehindClosedRoutes extends GuestDecision {
  const new(this.routes);

  final List<String> routes;
}

final class Open extends GuestDecision {
  const new(this.why);

  final String why;
}

/// A site's decision and the watched names it `uses`, each of them decided
/// by it: a name that comes into the declaration has to be decided too.
typedef GuestActionEntry = (GuestDecision, {Set<String> uses});

const _accountSettings = BehindClosedRoutes(['/home/account-settings']);
const _avatar = BehindClosedRoutes(['/home/account-settings/avatar']);
const _sessions = BehindClosedRoutes(['/home/account-settings/sessions']);
const _apiTokens = BehindClosedRoutes(['/home/account-settings/api-tokens']);
const _newApiToken = BehindClosedRoutes([
  '/home/account-settings/api-tokens/new',
]);
const _caldav = BehindClosedRoutes(['/home/account-settings/caldav']);
const _dataExport = BehindClosedRoutes(['/home/account-settings/data-export']);
const _inbox = BehindClosedRoutes(['/home/inbox']);
const _labels = BehindClosedRoutes(['/home/labels']);
const _labelForm = BehindClosedRoutes([
  '/home/labels/new',
  '/home/labels/:id/edit',
]);
const _projectShare = BehindClosedRoutes(['/home/project/:id/share']);
const _savedFilterForm = BehindClosedRoutes([
  '/home/filters/new',
  '/home/filters/:id/edit',
]);
const _teams = BehindClosedRoutes(['/home/teams']);
const _team = BehindClosedRoutes(['/home/teams/:id']);
const _trash = BehindClosedRoutes(['/home/trash']);

const _projectMenu = Gated(
  "the project screen's menu and star offer it only when the account is "
  'not a guest',
  checkIn: ['features/projects/presentation/project_tasks_screen.dart'],
);
const _knownPeople = Open(
  'reads the people stored on this device, which is all a guest is offered',
);
const _serverSearch = Gated(
  "a guest gets the people stored on this device; the server's user "
  'search refuses it',
);
const _themeRow = Gated(
  'built only in the Appearance section, which leaves the theme row out for '
  'a guest',
  checkIn: ['features/home/presentation/appearance_section.dart'],
);
const _activityTap = Gated(
  'only for a tapped activity notification, and the activity sync skips '
  'guests in front, in the background and over the socket',
  checkIn: [
    'core/activity/activity_providers.dart',
    'core/background/background_sync_runner.dart',
    'features/sync/application/realtime_connection_providers.dart',
  ],
);
const _noActivity = Gated(
  'the server keeps no activity for a guest, so this skips it',
);

/// Every site `guest_action_sites.dart` finds, keyed as it keys them. A new
/// site needs an entry, a name that comes into or leaves a listed site a
/// change of its `uses`; an entry whose site is gone fails too.
const guestActionInventory = <String, GuestActionEntry>{
  'core/activity/activity_providers.dart _syncActiveAccount': (
    _noActivity,
    uses: {'activityRepositoryProvider'},
  ),
  'core/activity/activity_providers.dart _syncInactiveAccounts': (
    _noActivity,
    uses: {'activitySyncProvider'},
  ),
  'core/background/background_sync_runner.dart _Run._account': (
    _noActivity,
    uses: {'activitySyncProvider'},
  ),
  'core/repositories/repository_providers.dart accountProjectRepository': (
    Open(
      "hands the bin's port to the project repository, which uses it only "
      'in restoreProject, whose calls are sites of their own: the Undo of a '
      "project's delete, gated with the project menu's Delete, and the bin "
      "page's Restore, behind its closed route; a guest uses the rest of the "
      'repository for its shared project',
    ),
    uses: {'trashPortProvider'},
  ),
  'core/repositories/repository_providers.dart accountTaskRepository': (
    Open(
      "hands the bin's port to the task repository, which uses it only in "
      'restoreTask, whose calls are sites of their own: the Undo of a '
      "delete in the task sheet, open to a write guest, the opener's "
      "Restore, gated, and the bin page's Restore, behind its closed route; "
      'a guest uses the rest of the repository for its tasks',
    ),
    uses: {'trashPortProvider'},
  ),
  'features/account_settings/presentation/account_settings_page.dart '
      '_AccountSettingsPageState._deleteAccount': (
    _accountSettings,
    uses: {'accountSettingsProvider'},
  ),
  'features/account_settings/presentation/account_settings_page.dart '
      '_AccountSettingsPageState._refresh': (
    _accountSettings,
    uses: {'accountSettingsRepositoryProvider'},
  ),
  'features/account_settings/presentation/account_settings_page.dart '
      '_AccountSettingsPageState._refreshSecurity': (
    _accountSettings,
    uses: {'accountSecurityRepositoryProvider', 'accountSettingsProvider'},
  ),
  'features/account_settings/presentation/account_settings_page.dart '
      '_AccountSettingsPageState._save': (
    _accountSettings,
    uses: {'accountSettingsRepositoryProvider'},
  ),
  'features/account_settings/presentation/account_settings_page.dart '
      '_AccountSettingsPageState.build': (
    _accountSettings,
    uses: {'accountSettingsProvider'},
  ),
  'features/account_settings/presentation/account_settings_page.dart '
      '_AccountSettingsPageState.initState': (
    _accountSettings,
    uses: {'accountSettingsProvider'},
  ),
  'features/account_settings/presentation/api_token_form_page.dart '
      '_ApiTokenFormPageState._create': (
    _newApiToken,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/api_token_form_page.dart '
      '_ApiTokenFormPageState._load': (
    _newApiToken,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/api_tokens_page.dart '
      '_ApiTokensPageState._delete': (
    _apiTokens,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/api_tokens_page.dart '
      '_ApiTokensPageState._load': (
    _apiTokens,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/avatar_page.dart '
      '_AvatarPageState._choose': (
    _avatar,
    uses: {'accountSettingsRepositoryProvider'},
  ),
  'features/account_settings/presentation/avatar_page.dart '
      '_AvatarPageState._refresh': (
    _avatar,
    uses: {'accountSettingsRepositoryProvider'},
  ),
  'features/account_settings/presentation/avatar_page.dart '
      '_AvatarPageState._uploadPhoto': (
    _avatar,
    uses: {'accountSettingsRepositoryProvider'},
  ),
  'features/account_settings/presentation/avatar_page.dart '
      '_AvatarPageState.build': (
    _avatar,
    uses: {'accountSettingsProvider'},
  ),
  'features/account_settings/presentation/caldav_page.dart '
      '_CaldavPageState._create': (
    _caldav,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/caldav_page.dart '
      '_CaldavPageState._delete': (
    _caldav,
    uses: {'accountSecurityRepositoryProvider', 'accountSettingsProvider'},
  ),
  'features/account_settings/presentation/caldav_page.dart '
      '_CaldavPageState._load': (
    _caldav,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/caldav_page.dart '
      '_CaldavPageState._loadTotp': (
    _caldav,
    uses: {'accountSecurityRepositoryProvider', 'accountSettingsProvider'},
  ),
  'features/account_settings/presentation/caldav_page.dart '
      '_CaldavPageState.build': (
    _caldav,
    uses: {'accountSettingsProvider'},
  ),
  'features/account_settings/presentation/data_export_page.dart '
      '_DataExportPageState._load': (
    _dataExport,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/data_export_page.dart '
      '_DataExportPageState.build': (
    _dataExport,
    uses: {'accountSettingsProvider'},
  ),
  'features/account_settings/presentation/sessions_page.dart '
      '_SessionsPageState._end': (
    _sessions,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/sessions_page.dart '
      '_SessionsPageState._endOthers': (
    _sessions,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/sessions_page.dart '
      '_SessionsPageState._load': (
    _sessions,
    uses: {'accountSecurityRepositoryProvider'},
  ),
  'features/account_settings/presentation/theme_setting.dart '
      '_ThemeSettingState._save': (
    _themeRow,
    uses: {'accountSettingsRepositoryProvider'},
  ),
  'features/account_settings/presentation/theme_setting.dart '
      '_ThemeSettingState.build': (
    _themeRow,
    uses: {'accountSettingsProvider'},
  ),
  'features/description_editor/presentation/description_editor_page.dart '
      '_DescriptionEditorPageState._knownPeople': (
    _knownPeople,
    uses: {'userRepositoryProvider'},
  ),
  'features/description_editor/presentation/description_editor_page.dart '
      '_DescriptionEditorPageState._searchPeople': (
    _serverSearch,
    uses: {'userRepositoryProvider'},
  ),
  // Its task branch calls the task repository's updateDescription, on the
  // open task route; the watched one is the project repository's.
  'features/description_editor/presentation/description_editor_page.dart '
      '_DescriptionEditorPageState._write': (
    BehindClosedRoutes([
      '/home/project/:id/description',
      '/home/labels/:id/description',
      '/home/teams/:id/description',
    ]),
    uses: {
      'labelRepositoryProvider',
      'teamRepositoryProvider',
      'updateDescription',
    },
  ),
  'features/home/presentation/account_tab.dart AccountTab.build': (
    Gated(
      'a guest has no profile on the server, so its tab reads no deletion '
      'date and no local-user flag',
    ),
    uses: {'accountSettingsProvider'},
  ),
  'features/inbox/presentation/inbox_button.dart InboxButton.build': (
    Gated(
      'built only in the Overview header, which leaves the bell out for a '
      'guest',
      checkIn: ['features/overview/presentation/overview_header.dart'],
    ),
    uses: {'unreadActivityCountProvider'},
  ),
  'features/inbox/presentation/inbox_screen.dart '
      '_InboxScreenState._markAllRead': (
    _inbox,
    uses: {'activityRepositoryProvider'},
  ),
  'features/inbox/presentation/inbox_screen.dart _InboxScreenState._open': (
    _inbox,
    uses: {'activityRepositoryProvider'},
  ),
  'features/inbox/presentation/inbox_screen.dart _InboxScreenState.build': (
    _inbox,
    uses: {'inboxItemsProvider'},
  ),
  'features/inbox/presentation/inbox_screen.dart '
      '_InboxScreenState.repositoryProvider': (
    _inbox,
    uses: {'activityRepositoryProvider'},
  ),
  'features/inbox/presentation/inbox_screen.dart '
      '_InboxScreenState.startRefresh': (
    _inbox,
    uses: {'activityRepositoryProvider'},
  ),
  'features/labels/presentation/label_form_page.dart '
      '_LabelFormPageState._save': (
    _labelForm,
    uses: {'labelRepositoryProvider'},
  ),
  'features/labels/presentation/labels_page.dart _LabelsPageState._delete': (
    _labels,
    uses: {'labelRepositoryProvider'},
  ),
  'features/labels/presentation/labels_page.dart '
      '_LabelsPageState.repositoryProvider': (
    _labels,
    uses: {'labelRepositoryProvider'},
  ),
  'features/notifications/presentation/notification_tap_listener.dart '
      '_NotificationTapListenerState._commentOf': (
    _activityTap,
    uses: {'accountActivityRepositoryProvider'},
  ),
  'features/notifications/presentation/notification_tap_listener.dart '
      '_NotificationTapListenerState._markActivityRead': (
    _activityTap,
    uses: {'accountActivityRepositoryProvider'},
  ),
  'features/projects/presentation/board/project_board.dart '
      '_ProjectBoardState._changeColumns': (
    Open(
      'runs every column change through the bucket repository, which refuses '
      "a guest's change of the view before any write: the done or default "
      'column, and the delete of either or of the leftmost column holding '
      'tasks while none is the default; the rest (create, rename, limit, '
      'move and other deletes) needs project write permission only, and a '
      'read guest gets no column menu',
    ),
    uses: {'bucketRepositoryProvider'},
  ),
  'features/projects/presentation/board/project_board.dart '
      '_ProjectBoardState._onColumnAction': (
    Gated(
      'the column menu leaves the done and default column out for a guest, '
      "whatever the share's permission, and the bucket repository refuses "
      "a guest's change of them",
    ),
    uses: {'setDefaultBucket', 'setDoneBucket'},
  ),
  'features/projects/presentation/manage/duplicate_project_sheet.dart '
      '_DuplicateProjectSheetState._duplicate': (
    _projectMenu,
    uses: {'duplicateProject'},
  ),
  'features/projects/presentation/manage/new_project_sheet.dart '
      '_NewProjectSheetState._create': (
    Gated(
      "the Projects tab's New project and the project menu's New subproject "
      'are left out for a guest',
      checkIn: [
        'features/projects/presentation/projects_screen.dart',
        'features/projects/presentation/project_tasks_screen.dart',
      ],
    ),
    uses: {'createProject'},
  ),
  'features/projects/presentation/manage/project_actions.dart '
      'ProjectManagementActions.deleteProject': (
    _projectMenu,
    uses: {'deleteProject', 'restoreProject'},
  ),
  'features/projects/presentation/manage/project_actions.dart '
      'ProjectManagementActions.setProjectArchived': (
    _projectMenu,
    uses: {'updateProject'},
  ),
  'features/projects/presentation/manage/project_actions.dart '
      'ProjectManagementActions.toggleProjectFavourite': (
    _projectMenu,
    uses: {'updateProject'},
  ),
  'features/projects/presentation/manage/project_edit_page.dart '
      '_ProjectEditPageState._save': (
    BehindClosedRoutes(['/home/project/:id/edit']),
    uses: {'updateProject'},
  ),
  'features/projects/presentation/manage/project_views_page.dart '
      '_ProjectViewsPageState._change': (
    BehindClosedRoutes(['/home/project/:id/views']),
    uses: {'projectViewRepositoryProvider'},
  ),
  'features/projects/presentation/manage/view_form_sheet.dart '
      '_ViewFormSheetState._save': (
    BehindClosedRoutes(['/home/project/:id/views']),
    uses: {'projectViewRepositoryProvider'},
  ),
  'features/projects/presentation/project_tasks_screen.dart '
      '_ProjectTasksScreenState._onAction': (
    Gated(
      "runs the project menu's Duplicate and Delete, ProjectManagementActions' "
      'own methods, which the menu offers only when the account is not a '
      'guest',
    ),
    uses: {'deleteProject', 'duplicateProject'},
  ),
  'features/projects/presentation/project_tasks_screen.dart '
      '_ProjectTasksScreenState._subscriptions': (
    Gated(
      'Follow is left out of the menu and its state never loaded for a guest',
    ),
    uses: {'subscriptionRepositoryProvider'},
  ),
  'features/projects/presentation/projects_screen.dart _SectionsState._send': (
    Open(
      'never sent for a guest: its tree holds only the shared project, and '
      'a move needs another project to go before, after or into',
    ),
    uses: {'moveProject'},
  ),
  'features/quick_add/application/known_users_provider.dart knownUsers': (
    _knownPeople,
    uses: {'userRepositoryProvider'},
  ),
  'features/quick_add/application/quick_add_service_provider.dart '
      'quickAddService': (
    Gated(
      'tells the service about a guest, which then creates no labels and '
      'looks no one up',
    ),
    uses: {'labelRepositoryProvider', 'userRepositoryProvider'},
  ),
  'features/quick_add/presentation/magic_suggestions.dart '
      '_MagicSuggestionsState._search': (
    _serverSearch,
    uses: {'userRepositoryProvider'},
  ),
  'features/share/presentation/share_sheet.dart _ShareSheetState._addToTask': (
    Open(
      "appends to a task's description through the task repository's "
      "updateDescription, not the project repository's that is watched, "
      'a task edit a write guest may make; as for a read-only user, Add to '
      'task also offers the tasks a read guest may not change, and the '
      'server refuses the change',
    ),
    uses: {'updateDescription'},
  ),
  'features/sharing/presentation/link_share_form_sheet.dart '
      '_LinkShareFormSheetState._create': (
    _projectShare,
    uses: {'projectSharingRepositoryProvider'},
  ),
  'features/sharing/presentation/person_search_sheet.dart '
      '_PersonSearchSheetState._search': (
    BehindClosedRoutes(['/home/project/:id/share', '/home/teams/:id']),
    uses: {'userRepositoryProvider'},
  ),
  'features/sharing/presentation/project_share_page.dart '
      '_ProjectSharePageState._change': (
    _projectShare,
    uses: {'projectSharingRepositoryProvider'},
  ),
  'features/sharing/presentation/project_share_page.dart '
      '_ProjectSharePageState._load': (
    _projectShare,
    uses: {'projectSharingRepositoryProvider'},
  ),
  'features/sharing/presentation/team_pick_sheet.dart '
      '_TeamPickSheetState._load': (
    _projectShare,
    uses: {'teamRepositoryProvider'},
  ),
  'features/smart_lists/presentation/saved_filter_form_page.dart '
      '_SavedFilterFormPageState._editBody': (
    _savedFilterForm,
    uses: {'savedFilterRepositoryProvider'},
  ),
  'features/smart_lists/presentation/saved_filter_form_page.dart '
      '_SavedFilterFormPageState._read': (
    _savedFilterForm,
    uses: {'savedFilterRepositoryProvider'},
  ),
  'features/smart_lists/presentation/saved_filter_form_page.dart '
      '_SavedFilterFormPageState._save': (
    _savedFilterForm,
    uses: {'savedFilterRepositoryProvider'},
  ),
  'features/smart_lists/presentation/smart_list_screen.dart '
      '_SmartListScreenState._onAction': (
    Open(
      "never reached by a guest: only a stored saved filter of the account's "
      'own gets this menu, and the server lists a link share no saved '
      'filters, only its project',
    ),
    uses: {'savedFilterRepositoryProvider', 'setFavorite'},
  ),
  'features/sync/application/realtime_connection_providers.dart '
      'realtimeConnection': (
    Gated('a guest gets no socket'),
    uses: {'accountActivityRepositoryProvider'},
  ),
  'features/tasks/application/label_providers.dart allLabels': (
    Open('reads the labels the sync stored, which a guest assigns too'),
    uses: {'labelRepositoryProvider'},
  ),
  'features/tasks/presentation/details/comment_composer.dart '
      '_CommentComposerState._knownPeople': (
    _knownPeople,
    uses: {'userRepositoryProvider'},
  ),
  'features/tasks/presentation/details/comment_composer.dart '
      '_CommentComposerState._searchPeople': (
    _serverSearch,
    uses: {'userRepositoryProvider'},
  ),
  'features/tasks/presentation/open/task_opener.dart TaskOpener._restore': (
    Gated(
      "the opener offers the bin's Restore only when _mayRestore allows "
      'it, which a guest never does, as on the web (D79)',
    ),
    uses: {'restoreTask'},
  ),
  'features/tasks/presentation/open/task_opener.dart accountServerTaskRead': (
    Open(
      "reads a linked task through the account's own client, a guest's "
      'link-share session for a guest, which the server answers only for '
      "the shared project's tasks",
    ),
    uses: {'readClientProvider'},
  ),
  'features/tasks/presentation/pickers/assignee_picker.dart '
      '_AssigneePickerState._loadKnown': (
    _knownPeople,
    uses: {'userRepositoryProvider'},
  ),
  'features/tasks/presentation/pickers/assignee_picker.dart '
      '_AssigneePickerState._search': (
    _serverSearch,
    uses: {'userRepositoryProvider'},
  ),
  'features/tasks/presentation/pickers/label_picker.dart '
      '_LabelPickerState._create': (
    Gated('the picker offers a guest no new label and says why'),
    uses: {'labelRepositoryProvider'},
  ),
  'features/tasks/presentation/task_detail_sheet.dart '
      '_TaskDetailSheetState._delete': (
    Open(
      'the Undo of a delete restores the task by id from the bin, which a '
      'write guest may (D79)',
    ),
    uses: {'restoreTask'},
  ),
  'features/tasks/presentation/task_detail_sheet.dart '
      '_TaskDetailSheetState._react': (
    Gated(
      'the reaction chips of the task and its comments take no taps from a '
      'guest and offer it no Add reaction',
    ),
    uses: {'addReaction', 'removeReaction'},
  ),
  'features/tasks/presentation/task_detail_sheet.dart '
      '_TaskDetailSheetState._subscriptions': (
    Gated(
      'only the Follow button reads or writes through it, and a guest gets '
      'none; the sheet takes the state from the task details',
    ),
    uses: {'subscriptionRepositoryProvider'},
  ),
  'features/tasks/presentation/task_write_feedback.dart writeTaskFavorite': (
    Gated(
      'the star is left out of task rows and the task sheet for a guest',
      checkIn: [
        'features/tasks/presentation/task_row.dart',
        'features/tasks/presentation/task_detail_sheet.dart',
      ],
    ),
    uses: {'setFavorite'},
  ),
  'features/teams/presentation/new_team_sheet.dart _NewTeamSheetState._create':
      (_teams, uses: {'teamRepositoryProvider'}),
  'features/teams/presentation/team_edit_sheet.dart '
      '_TeamEditSheetState._save': (
    _team,
    uses: {'teamRepositoryProvider'},
  ),
  'features/teams/presentation/team_page.dart _TeamPageState._addMember': (
    _team,
    uses: {'teamRepositoryProvider'},
  ),
  'features/teams/presentation/team_page.dart _TeamPageState._delete': (
    _team,
    uses: {'teamRepositoryProvider'},
  ),
  'features/teams/presentation/team_page.dart _TeamPageState._leave': (
    _team,
    uses: {'teamRepositoryProvider'},
  ),
  'features/teams/presentation/team_page.dart _TeamPageState._load': (
    _team,
    uses: {'teamRepositoryProvider'},
  ),
  'features/teams/presentation/team_page.dart _TeamPageState._remove': (
    _team,
    uses: {'teamRepositoryProvider'},
  ),
  'features/teams/presentation/team_page.dart _TeamPageState._toggleAdmin': (
    _team,
    uses: {'teamRepositoryProvider'},
  ),
  'features/teams/presentation/teams_page.dart _TeamsPageState._load': (
    _teams,
    uses: {'teamRepositoryProvider'},
  ),
  'features/trash/presentation/trash_page.dart '
      '_TrashPageState._deleteProjectForever': (
    _trash,
    uses: {'trashRepositoryProvider'},
  ),
  'features/trash/presentation/trash_page.dart '
      '_TrashPageState._deleteTaskForever': (
    _trash,
    uses: {'trashRepositoryProvider'},
  ),
  'features/trash/presentation/trash_page.dart _TrashPageState._empty': (
    _trash,
    uses: {'trashRepositoryProvider'},
  ),
  'features/trash/presentation/trash_page.dart _TrashPageState._load': (
    _trash,
    uses: {'trashRepositoryProvider'},
  ),
  'features/trash/presentation/trash_page.dart '
      '_TrashPageState._restoreProject': (
    _trash,
    uses: {'restoreProject'},
  ),
  'features/trash/presentation/trash_page.dart _TrashPageState._restoreTask': (
    _trash,
    uses: {'restoreTask'},
  ),
  'features/upcoming/presentation/upcoming_screen.dart '
      '_UpcomingScreenState.build': (
    Gated(
      'the menu leaves the inbox and its count out for a guest; the count '
      'only reads the local table, empty for a guest',
    ),
    uses: {'unreadActivityCountProvider'},
  ),
  'features/widgets/application/widget_choices.dart widgetLabelChoices': (
    Open('reads the stored labels for a Label widget, which a guest has too'),
    uses: {'accountLabelRepositoryProvider'},
  ),
};
