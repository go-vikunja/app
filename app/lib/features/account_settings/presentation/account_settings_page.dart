import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/account_settings/application/server_languages.dart';
import 'package:vikunja_mobile/features/account_settings/application/time_zone_choices.dart';
import 'package:vikunja_mobile/features/account_settings/application/totp_status_reading.dart';
import 'package:vikunja_mobile/features/account_settings/application/web_settings_pages.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_deletion.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_security_sections.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_save.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_labels.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/default_project_picker.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/searchable_option_sheet.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sign_in_provider_name.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/web_password_note.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/web_settings_page_opener.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/connection/presentation/browser_leg_hint.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_confirmations.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/view_labels.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

final _log = Logger('AccountSettingsPage');

/// The account's settings on the server, which follow it to every device,
/// in the web's order where it has the same ones. A switch or a pick saves
/// at once and the name on Done, always online; offline the page only
/// shows them. A refused value is shown at its control. Password and email,
/// two-factor authentication, the data export's request and download and
/// the account's deletion are left to the web's own pages in the browser,
/// because they ask for the password or a code (D14); sessions, tokens and
/// CalDAV have pages of their own.
class AccountSettingsPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AccountSettingsPage> createState() =>
      _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
  final _name = TextEditingController();
  late final AppLifecycleListener _lifecycle;
  String? _storedName;
  AccountSettingsField? _saving;
  UserSettingsChanges? _pending;
  final _errors = <AccountSettingsField, String>{};

  /// Whether the server answered this page's last request; null before
  /// one, while the last sync run's outcome decides.
  bool? _reachable;
  SecurityOverview _security = const SecurityOverview();

  // Up to 2.6 and during a setup, the two-factor status comes with its
  // secret, so it is read when the page opens and after its web page only.
  bool _totpPageOpened = false;

  @override
  void initState() {
    super.initState();
    // Back from the web's email or two-factor page, a pending change shows
    // at once.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(_refresh());
        unawaited(_refreshSecurity(totp: _totpPageOpened));
        _totpPageOpened = false;
      },
    );
    ref.listenManual(
      accountSettingsProvider,
      (_, next) => _adoptName(next.value?.settings.name),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
      unawaited(_refreshSecurity(totp: true));
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Follows the stored name while the field holds it unchanged.
  void _adoptName(String? name) {
    if (name == null || name == _storedName) return;
    if (_storedName == null || _name.text == _storedName) _name.text = name;
    _storedName = name;
  }

  bool get _nameDirty =>
      _storedName != null && _name.text.trim() != _storedName!.trim();

  /// Never throws: offline the stored settings stay on screen.
  Future<void> _refresh() async {
    final repository = ref.read(accountSettingsRepositoryProvider);
    if (repository == null) return;
    try {
      await repository.refresh();
      if (mounted) setState(() => _reachable = true);
    } on NetworkFailure {
      if (mounted) setState(() => _reachable = false);
    } on Object catch (error) {
      _log.info('Refreshing the account settings failed: ${error.runtimeType}');
    }
  }

  /// Each part on its own and never throwing: one that cannot be read
  /// keeps what it showed. The two-factor status only with [totp].
  Future<void> _refreshSecurity({bool totp = false}) async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    final entry = ref.read(accountsProvider).value?.activeAccount;
    if (repository == null || entry == null) return;
    final UserProfile? profile;
    try {
      profile = (await ref.read(accountSettingsProvider.future)).profile;
    } on Object catch (error) {
      _log.info('Reading the stored profile failed: ${error.runtimeType}');
      return;
    }
    if (!mounted) return;
    Future<void> read<T>(
      String part,
      Future<T> Function() load,
      SecurityOverview Function(T value) apply, {
      SecurityOverview Function(Object error)? onError,
    }) async {
      try {
        final value = await load();
        if (mounted) setState(() => _security = apply(value));
      } on Object catch (error) {
        _log.info('Reading the $part failed: ${error.runtimeType}');
        if (mounted && onError != null) {
          setState(() => _security = onError(error));
        }
      }
    }

    await [
      if (totp &&
          entry.connection.capabilities.has(Capability.totp) &&
          (profile?.isLocalUser ?? true) &&
          canReadTotpStatus(entry.connection))
        read(
          'two-factor status',
          repository.totpStatus,
          (status) => _security.withTotp(status),
          onError: (error) => _security.withTotp(
            _security.totp,
            SecurityOverview.problemOf(error),
          ),
        ),
      read(
        'sessions',
        repository.sessions,
        (sessions) => _security.withSessionCount(sessions.length),
      ),
      read(
        'API tokens',
        repository.apiTokens,
        (tokens) => _security.withApiTokenCount(tokens.length),
      ),
      read(
        'data export',
        repository.dataExport,
        (export) => _security.withExport(export),
      ),
    ].wait;
  }

  Future<void> _openPage(String location, {Object? extra}) async {
    await context.pushPage<void>(location, extra: extra);
    if (mounted) await _refreshSecurity();
  }

  Future<void> _deleteAccount(RegisteredAccount entry) async {
    final profile = ref.read(accountSettingsProvider).value?.profile;
    if (profile?.deletionScheduledAt == null) {
      if (!allowsAccountDeletion(entry.connection)) {
        await explainAccountDeletionNotAllowed(context);
        return;
      }
      final confirmed = await confirmAccountDeletion(
        context,
        isLocalUser: profile?.isLocalUser ?? true,
        accountLockout: entry.connection.capabilities.has(
          Capability.accountLockout,
        ),
      );
      if (!confirmed || !mounted) return;
    }
    await _openWebPage(entry, WebSettingsPage.deletion);
  }

  Future<bool> _save(
    AccountSettingsField field,
    UserSettingsChanges changes,
  ) async {
    final repository = ref.read(accountSettingsRepositoryProvider);
    if (repository == null || _saving != null || changes.isEmpty) return false;
    setState(() {
      _saving = field;
      _pending = changes;
      _errors.remove(field);
    });
    try {
      final outcome = await saveAccountSettings(
        context,
        repository,
        field,
        changes,
      );
      if (mounted) {
        switch (outcome) {
          case AccountSettingsSaved():
            setState(() => _reachable = true);
          case AccountSettingsRefused(:final message):
            setState(() => _errors[field] = message);
          case AccountSettingsNotSaved(
            error: NetworkFailure(problem: NetworkProblem.unreachable),
          ):
            setState(() => _reachable = false);
          case AccountSettingsNotSaved():
            break;
        }
      }
      return outcome is AccountSettingsSaved;
    } finally {
      if (mounted) {
        setState(() {
          _saving = null;
          _pending = null;
        });
      }
    }
  }

  Future<void> _saveName() async {
    if (!_nameDirty) {
      _name.text = _storedName ?? _name.text;
      return;
    }
    final name = _name.text.trim();
    final saved = await _save(
      AccountSettingsField.name,
      UserSettingsChanges(name: name),
    );
    if (saved && mounted) {
      _name.text = name;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.accountSettingsNameSaved)),
        );
    }
  }

  Future<void> _leaveIfConfirmed() async {
    final router = GoRouter.of(context);
    final discard = await confirmDiscardChanges(
      context,
      body: context.l10n.accountSettingsNameDiscardBody,
    );
    if (discard && mounted) {
      _name.text = _storedName ?? '';
      router.pop();
    }
  }

  Future<void> _openWebPage(RegisteredAccount entry, WebSettingsPage page) {
    if (page == WebSettingsPage.totp) _totpPageOpened = true;
    return openWebSettingsPage(context, ref, entry, page);
  }

  Future<void> _choose<T extends Object>(
    AccountSettingsField field, {
    required String title,
    required List<SheetOption<T>> options,
    required UserSettingsChanges Function(T value) changes,
  }) async {
    final picked = await showOptionSheet<T>(
      context,
      title: title,
      options: options,
    );
    if (picked == null || !mounted) return;
    final selected = options.where((option) => option.selected).firstOrNull;
    if (selected?.value == picked) return;
    await _save(field, changes(picked));
  }

  void _chooseQuietly<T extends Object>(
    AccountSettingsField field, {
    required String title,
    required List<SheetOption<T>> options,
    required UserSettingsChanges Function(T value) changes,
  }) => unawaited(
    _choose<T>(field, title: title, options: options, changes: changes),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = ref.watch(
      accountsProvider.select((accounts) => accounts.value?.activeAccount),
    );
    final state = ref.watch(accountSettingsProvider).value;
    final lastSyncOffline = ref.watch(offlineProvider) != null;
    final offline = switch (_reachable) {
      null => lastSyncOffline,
      final reachable => !reachable,
    };
    final saving = _saving != null;
    final signingIn = ref.watch(signInControllerProvider) is SignInInProgress;

    return PopScope(
      canPop: !_nameDirty || saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !saving) unawaited(_leaveIfConfirmed());
      },
      child: Scaffold(
        appBar: AppBar(
          title: ScreenTitle(l10n.accountSettingsTitle),
          bottom: SavingProgressBar(saving: saving),
        ),
        body: switch ((entry, state)) {
          (final entry?, final state?) => _Settings(
            entry: entry,
            state: state,
            settings: _pending?.applyTo(state.settings) ?? state.settings,
            nameController: _name,
            nameDirty: _nameDirty,
            offline: offline,
            errors: _errors,
            canChange: !offline && !saving && !entry.account.needsReauth,
            onRetry: () => unawaited(_refresh()),
            onSignInAgain: signingIn
                ? null
                : () => unawaited(signInAgainAfterHint(context, ref, entry)),
            onNameChanged: () =>
                setState(() => _errors.remove(AccountSettingsField.name)),
            onSaveName: () => unawaited(_saveName()),
            onSave: (field, changes) => unawaited(_save(field, changes)),
            onChoose: _chooseQuietly,
            onOpenWeb: (page) => unawaited(_openWebPage(entry, page)),
            security: _security,
            onOpenPage: (location, {extra}) =>
                unawaited(_openPage(location, extra: extra)),
            onDeleteAccount: () => unawaited(_deleteAccount(entry)),
          ),
          _ => CenteredScrollView(
            maxWidth: ReadableWidth.form,
            child: LoadingPlaceholder(label: l10n.accountSettingsLoading),
          ),
        },
      ),
    );
  }
}

typedef _ChooseSetting = void Function<T extends Object>(
  AccountSettingsField field, {
  required String title,
  required List<SheetOption<T>> options,
  required UserSettingsChanges Function(T value) changes,
});

class _Settings extends ConsumerWidget {
  const new({
    required this.entry,
    required this.state,
    required this.settings,
    required this.nameController,
    required this.nameDirty,
    required this.offline,
    required this.errors,
    required this.canChange,
    required this.onRetry,
    required this.onSignInAgain,
    required this.onNameChanged,
    required this.onSaveName,
    required this.onSave,
    required this.onChoose,
    required this.onOpenWeb,
    required this.security,
    required this.onOpenPage,
    required this.onDeleteAccount,
  });

  final RegisteredAccount entry;
  final AccountSettingsState state;

  /// With the change being saved applied.
  final UserSettings settings;
  final TextEditingController nameController;
  final bool nameDirty;
  final bool offline;
  final Map<AccountSettingsField, String> errors;
  final bool canChange;
  final VoidCallback onRetry;

  /// Null while a sign-in runs.
  final VoidCallback? onSignInAgain;
  final VoidCallback onNameChanged;
  final VoidCallback onSaveName;
  final void Function(AccountSettingsField field, UserSettingsChanges changes)
  onSave;
  final _ChooseSetting onChoose;
  final ValueChanged<WebSettingsPage> onOpenWeb;
  final SecurityOverview security;
  final void Function(String location, {Object? extra}) onOpenPage;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final account = entry.account;
    final profile = state.profile;
    // Until the profile is read, an OIDC or LDAP account must not be offered
    // what only local accounts can change.
    final isLocalUser = profile?.isLocalUser ?? false;
    final provider = signInProviderName(profile?.authProvider ?? '');
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final savedFilters =
        ref.watch(savedFiltersProvider).value ?? const <SavedFilterRef>[];
    final display = DisplaySettings.from(settings);
    final formatter = MomentFormatter.of(context, display);
    final now = ref.watch(clockProvider)();
    final theme = Theme.of(context);
    final locale = l10n.localeName;
    VoidCallback? whenChangeable(VoidCallback action) =>
        canChange ? action : null;

    String weekdayName(int day) =>
        intl.DateFormat.EEEE(locale).format(DateTime(2023, 1, 1 + day));

    final children = <Widget>[
      if (profile?.deletionScheduledAt case final scheduledAt?)
        DeletionScheduledNote(
          scheduledAt: scheduledAt,
          isLocalUser: isLocalUser,
          accountLockout: entry.connection.capabilities.has(
            Capability.accountLockout,
          ),
          onCancel: () => onOpenWeb(WebSettingsPage.deletion),
        ),
      SettingsNote(
        text: l10n.accountSettingsIntro(displayHost(entry.connection.rootUri)),
      ),
      if (account.needsReauth)
        SettingsNote(
          text: l10n.accountSettingsSignInAgain,
          icon: Icons.lock_clock_outlined,
          emphasized: true,
          action: TextButton(
            onPressed: onSignInAgain,
            child: Text(l10n.reauthAction),
          ),
        )
      else if (offline)
        SettingsNote(
          text: l10n.accountSettingsOffline,
          icon: Icons.cloud_off_outlined,
          emphasized: true,
          action: TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ),
      SettingsSection(
        title: l10n.accountSettingsProfile,
        dividerAbove: false,
        children: [
          ListTile(
            leading: UserAvatar(
              user: User(
                id: account.userId,
                username: account.username,
                name: account.displayName,
              ),
              radius: 20,
              accountId: entry.id,
              primary: true,
            ),
            title: Text(l10n.accountSettingsAvatar),
            subtitle: switch (state.avatarProvider) {
              final provider? => Text(avatarProviderLabel(l10n, provider)),
              null => null,
            },
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                unawaited(GoRouter.of(context).push(AppRoutes.accountAvatar)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: nameController,
              enabled: canChange && isLocalUser,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.accountSettingsName,
                helperText: switch (profile) {
                  null => l10n.accountSettingsWaitingForProfile,
                  _ when isLocalUser => l10n.accountSettingsNameHelp(
                    account.username,
                  ),
                  _ => l10n.accountSettingsNameManaged(provider),
                },
                helperMaxLines: 4,
                errorText: errors[AccountSettingsField.name],
                errorMaxLines: 4,
                suffixIcon: nameDirty && canChange
                    ? IconButton(
                        onPressed: onSaveName,
                        tooltip: l10n.accountSettingsNameSave,
                        icon: const Icon(Icons.check),
                      )
                    : null,
              ),
              onChanged: (_) => onNameChanged(),
              onSubmitted: (_) => onSaveName(),
            ),
          ),
        ],
      ),
      SettingsSection(
        title: l10n.accountSettingsSignIn,
        children: [
          if (profile == null)
            SettingsNote(
              text: l10n.accountSettingsWaitingForProfile,
              icon: Icons.hourglass_empty,
            )
          else if (isLocalUser) ...[
            ListTile(
              leading: const Icon(Icons.password),
              title: Text(l10n.accountSettingsChangePassword),
              subtitle: Text(l10n.accountSettingsChangePasswordHint),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => onOpenWeb(WebSettingsPage.password),
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: Text(l10n.accountSettingsChangeEmail),
              subtitle: Text(switch (profile.pendingEmail) {
                final email? when email.isNotEmpty =>
                  l10n.accountSettingsPendingEmail(email),
                _ => l10n.accountSettingsOpensWeb,
              }),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => onOpenWeb(WebSettingsPage.email),
            ),
            if (entry.connection.capabilities.has(Capability.accountLockout))
              SettingsNote(
                text: webAsksPasswordNote(l10n, accountLockout: true),
                icon: Icons.lock_outline,
              ),
          ] else
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(l10n.accountSettingsManagedBySignInNamed(provider)),
            ),
        ],
      ),
      securitySection(
        l10n: l10n,
        connection: entry.connection,
        profile: profile,
        overview: security,
        onOpenTotp: () => onOpenWeb(WebSettingsPage.totp),
        onOpenSessions: () => onOpenPage(AppRoutes.accountSessions),
      ),
      SettingsSection(
        title: l10n.accountSettingsDefaults,
        children: [
          SettingChoiceTile(
            leading: const Icon(Icons.folder_outlined),
            title: l10n.accountSettingsDefaultProject,
            value: defaultProjectLabel(
              l10n,
              settings.defaultProjectId,
              projects,
            ),
            error: errors[AccountSettingsField.defaultProject],
            onTap: whenChangeable(() async {
              final picked = await pickDefaultProject(
                context,
                projects: projects,
                selectedId: settings.defaultProjectId,
              );
              if (picked == null ||
                  picked == (settings.defaultProjectId ?? 0)) {
                return;
              }
              onSave(
                AccountSettingsField.defaultProject,
                UserSettingsChanges(
                  defaultProjectId: picked == 0
                      ? const SettingChange.clear()
                      : SettingChange.set(picked),
                ),
              );
            }),
          ),
          SettingChoiceTile(
            leading: const Icon(Icons.view_agenda_outlined),
            title: l10n.accountSettingsDefaultView,
            value: _defaultViewLabel(l10n, settings.defaultViewKind),
            error: errors[AccountSettingsField.defaultView],
            onTap: whenChangeable(
              () => onChoose<SettingChange<ProjectViewKind>>(
                AccountSettingsField.defaultView,
                title: l10n.accountSettingsDefaultView,
                options: [
                  SheetOption(
                    value: const SettingChange.clear(),
                    label: l10n.accountSettingsDefaultViewFirst,
                    selected: settings.defaultViewKind == null,
                  ),
                  for (final kind in ProjectViewKind.values)
                    SheetOption(
                      value: SettingChange.set(kind),
                      label: viewKindLabel(l10n, kind),
                      selected: settings.defaultViewKind == kind,
                    ),
                ],
                changes: (value) => UserSettingsChanges(defaultViewKind: value),
              ),
            ),
          ),
          SettingChoiceTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: l10n.accountSettingsQuickAddMagic,
            value: _magicModeLabel(l10n, settings.quickAddMagicMode),
            error: errors[AccountSettingsField.quickAddMagic],
            onTap: whenChangeable(
              () => onChoose<QuickAddMagicMode>(
                AccountSettingsField.quickAddMagic,
                title: l10n.accountSettingsQuickAddMagic,
                options: [
                  for (final mode in QuickAddMagicMode.values)
                    SheetOption(
                      value: mode,
                      label: _magicModeLabel(l10n, mode),
                      selected: settings.quickAddMagicMode == mode,
                    ),
                ],
                changes: (value) =>
                    UserSettingsChanges(quickAddMagicMode: value),
              ),
            ),
          ),
          SettingChoiceTile(
            leading: const Icon(Icons.flag_outlined),
            title: l10n.accountSettingsMinimumPriority,
            value: priorityLabel(
              l10n,
              TaskPriority.fromValue(settings.effectiveMinimumPriority),
            ),
            error: errors[AccountSettingsField.minimumPriority],
            onTap: whenChangeable(
              () => onChoose<TaskPriority>(
                AccountSettingsField.minimumPriority,
                title: l10n.accountSettingsMinimumPriority,
                options: [
                  for (final priority in TaskPriority.values)
                    if (priority != TaskPriority.unset)
                      SheetOption(
                        value: priority,
                        label: priorityLabel(l10n, priority),
                        selected:
                            settings.effectiveMinimumPriority == priority.value,
                      ),
                ],
                changes: (value) =>
                    UserSettingsChanges(minimumPriority: value.value),
              ),
            ),
          ),
          SettingChoiceTile(
            leading: const Icon(Icons.filter_alt_outlined),
            title: l10n.accountSettingsOverviewFilter,
            value: _overviewFilterLabel(
              l10n,
              settings.filterIdUsedOnOverview,
              savedFilters,
            ),
            error: errors[AccountSettingsField.overviewFilter],
            onTap: whenChangeable(
              () => onChoose<SettingChange<int>>(
                AccountSettingsField.overviewFilter,
                title: l10n.accountSettingsOverviewFilter,
                options: [
                  SheetOption(
                    value: const SettingChange.clear(),
                    label: l10n.accountSettingsOverviewFilterNone,
                    selected: settings.filterIdUsedOnOverview == null,
                  ),
                  for (final filter in savedFilters)
                    SheetOption(
                      value: SettingChange.set(filter.projectId),
                      label: projectDisplayTitle(
                        l10n,
                        filter.title,
                        projectId: filter.projectId,
                      ),
                      selected:
                          settings.filterIdUsedOnOverview == filter.projectId,
                    ),
                ],
                changes: (value) =>
                    UserSettingsChanges(filterIdUsedOnOverview: value),
              ),
            ),
          ),
          SettingChoiceTile(
            leading: const Icon(Icons.date_range_outlined),
            title: l10n.accountSettingsWeekStart,
            value: weekdayName(settings.weekStart.clamp(0, 6)),
            error: errors[AccountSettingsField.weekStart],
            onTap: whenChangeable(
              () => onChoose<int>(
                AccountSettingsField.weekStart,
                title: l10n.accountSettingsWeekStart,
                options: [
                  for (var day = 0; day < 7; day++)
                    SheetOption(
                      value: day,
                      label: weekdayName(day),
                      selected: settings.weekStart == day,
                    ),
                ],
                changes: (value) => UserSettingsChanges(weekStart: value),
              ),
            ),
          ),
        ],
      ),
      SettingsSection(
        title: l10n.accountSettingsTimeAndLanguage,
        children: [
          SettingChoiceTile(
            leading: const Icon(Icons.public_outlined),
            title: l10n.accountSettingsTimezone,
            value: settings.timezone.isEmpty
                ? l10n.accountSettingsTimezoneServerDefault
                : settings.timezone.replaceAll('_', ' '),
            help: l10n.accountSettingsTimezoneHelp,
            error: errors[AccountSettingsField.timezone],
            onTap: whenChangeable(() async {
              final picked = await _pickTimeZone(context, settings.timezone);
              if (picked == null || picked == settings.timezone) return;
              onSave(
                AccountSettingsField.timezone,
                UserSettingsChanges(timezone: picked),
              );
            }),
          ),
          SettingChoiceTile(
            leading: const Icon(Icons.translate_outlined),
            title: l10n.accountSettingsLanguage,
            value: switch (settings.language) {
              '' => l10n.accountSettingsLanguageNotSet,
              final code => serverLanguageOf(code)?.name ?? code,
            },
            help: l10n.accountSettingsLanguageHelp,
            error: errors[AccountSettingsField.language],
            onTap: whenChangeable(() async {
              final picked = await _pickLanguage(context, settings.language);
              if (picked == null || picked == settings.language) return;
              onSave(
                AccountSettingsField.language,
                UserSettingsChanges(language: picked),
              );
            }),
          ),
          SettingChoiceTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: l10n.accountSettingsDateDisplay,
            value: l10n.accountSettingsDateExample(
              switch (settings.dateDisplay) {
                DateDisplay.relative => formatter.relative(
                  now.add(const Duration(days: 3)),
                  now: now,
                ),
                _ => formatter.absolute(now),
              },
            ),
            error: errors[AccountSettingsField.dateDisplay],
            onTap: whenChangeable(
              () => onChoose<SettingChange<DateDisplay>>(
                AccountSettingsField.dateDisplay,
                title: l10n.accountSettingsDateDisplay,
                options: [
                  SheetOption(
                    value: const SettingChange.clear(),
                    label: l10n.accountSettingsDateDisplayDevice,
                    selected: settings.dateDisplay == null,
                  ),
                  for (final displayOption in DateDisplay.values)
                    SheetOption(
                      value: SettingChange.set(displayOption),
                      label: _dateDisplayLabel(l10n, displayOption, now),
                      selected: settings.dateDisplay == displayOption,
                    ),
                ],
                changes: (value) => UserSettingsChanges(dateDisplay: value),
              ),
            ),
          ),
          SettingChoiceTile(
            leading: const Icon(Icons.schedule_outlined),
            title: l10n.accountSettingsTimeFormat,
            value: _timeFormatLabel(l10n, settings.timeFormat, now),
            error: errors[AccountSettingsField.timeFormat],
            onTap: whenChangeable(
              () => onChoose<SettingChange<TimeFormat>>(
                AccountSettingsField.timeFormat,
                title: l10n.accountSettingsTimeFormat,
                options: [
                  SheetOption(
                    value: const SettingChange.clear(),
                    label: l10n.accountSettingsTimeFormatDevice,
                    selected: settings.timeFormat == null,
                  ),
                  for (final format in TimeFormat.values)
                    SheetOption(
                      value: SettingChange.set(format),
                      label: _timeFormatLabel(l10n, format, now),
                      selected: settings.timeFormat == format,
                    ),
                ],
                changes: (value) => UserSettingsChanges(timeFormat: value),
              ),
            ),
          ),
        ],
      ),
      SettingsSection(
        title: l10n.accountSettingsEmailNotifications,
        children: [
          if (!entry.connection.info.emailRemindersEnabled)
            SettingsNote(
              text: l10n.accountSettingsEmailsOff,
              icon: Icons.unsubscribe_outlined,
            ),
          _SettingSwitch(
            icon: Icons.mail_outline,
            title: l10n.accountSettingsEmailReminders,
            subtitle: l10n.accountSettingsEmailRemindersSubtitle,
            value: settings.emailRemindersEnabled,
            error: errors[AccountSettingsField.emailReminders],
            onChanged: canChange
                ? (value) => onSave(
                    AccountSettingsField.emailReminders,
                    UserSettingsChanges(emailRemindersEnabled: value),
                  )
                : null,
          ),
          _SettingSwitch(
            icon: Icons.notification_important_outlined,
            title: l10n.accountSettingsOverdueReminders,
            subtitle: l10n.accountSettingsOverdueRemindersSubtitle,
            value: settings.overdueTasksRemindersEnabled,
            error: errors[AccountSettingsField.overdueReminders],
            onChanged: canChange
                ? (value) => onSave(
                    AccountSettingsField.overdueReminders,
                    UserSettingsChanges(overdueTasksRemindersEnabled: value),
                  )
                : null,
          ),
          if (settings.overdueTasksRemindersEnabled)
            SettingChoiceTile(
              leading: const Icon(Icons.alarm_outlined),
              title: l10n.accountSettingsOverdueTime,
              value: formatter.timeOfDay(
                DateTime(
                  2000,
                  1,
                  1,
                  settings.overdueTasksRemindersTime.hour,
                  settings.overdueTasksRemindersTime.minute,
                ),
              ),
              error: errors[AccountSettingsField.overdueTime],
              onTap: whenChangeable(() async {
                final current = settings.overdueTasksRemindersTime;
                final picked = await pickTimeOfDay(
                  context,
                  initial: TimeOfDay(
                    hour: current.hour,
                    minute: current.minute,
                  ),
                  display: display,
                  title: l10n.accountSettingsOverdueTime,
                );
                if (picked == null) return;
                final time = ClockTime(picked.hour, picked.minute);
                if (time == current) return;
                onSave(
                  AccountSettingsField.overdueTime,
                  UserSettingsChanges(overdueTasksRemindersTime: time),
                );
              }),
            ),
        ],
      ),
      SettingsSection(
        title: l10n.accountSettingsPrivacy,
        children: [
          _SettingSwitch(
            icon: Icons.person_search_outlined,
            title: l10n.accountSettingsDiscoverableByName,
            subtitle: l10n.accountSettingsDiscoverableByNameSubtitle,
            value: settings.discoverableByName,
            error: errors[AccountSettingsField.discoverableByName],
            onChanged: canChange
                ? (value) => onSave(
                    AccountSettingsField.discoverableByName,
                    UserSettingsChanges(discoverableByName: value),
                  )
                : null,
          ),
          _SettingSwitch(
            icon: Icons.contact_mail_outlined,
            title: l10n.accountSettingsDiscoverableByEmail,
            subtitle: l10n.accountSettingsDiscoverableByEmailSubtitle,
            value: settings.discoverableByEmail,
            error: errors[AccountSettingsField.discoverableByEmail],
            onChanged: canChange
                ? (value) => onSave(
                    AccountSettingsField.discoverableByEmail,
                    UserSettingsChanges(discoverableByEmail: value),
                  )
                : null,
          ),
        ],
      ),
      integrationsSection(
        l10n: l10n,
        connection: entry.connection,
        overview: security,
        onOpenApiTokens: () => onOpenPage(AppRoutes.accountApiTokens),
        onOpenCaldav: () =>
            onOpenPage(AppRoutes.accountCaldav, extra: security.totp?.name),
      ),
      yourDataSection(
        l10n: l10n,
        formatter: formatter,
        overview: security,
        now: now,
        onOpenExport: () => onOpenPage(AppRoutes.accountDataExport),
      ),
      ...deleteAccountSection(
        l10n: l10n,
        theme: theme,
        formatter: formatter,
        connection: entry.connection,
        profile: profile,
        now: now,
        onDelete: onDeleteAccount,
      ),
    ];

    return ReadableWidth.builder(
      maxWidth: ReadableWidth.form,
      builder: (_, _, inset) => ListView(
        // An explicit padding replaces the system bars' and cutouts'.
        padding:
            MediaQuery.paddingOf(context) +
            EdgeInsets.fromLTRB(inset, 8, inset, 32),
        children: children,
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.error,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final String? error;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return SwitchListTile.adaptive(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(subtitle), if (error != null) SettingErrorText(error)],
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

Future<String?> _pickTimeZone(BuildContext context, String current) {
  final l10n = context.l10n;
  final choices = timeZoneChoices(DateTime.now());
  final byName = {for (final choice in choices) choice.name: choice};
  final suggested = deviceTimeZoneSuggestions(current);
  SearchableOption<String> option(TimeZoneChoice choice) => SearchableOption(
    value: choice.name,
    label: choice.label,
    detail: formatUtcOffset(choice.offset),
    searchTerms: [choice.name],
    selected: choice.name == current,
  );
  return showSearchableOptionSheet<String>(
    context,
    title: l10n.accountSettingsTimezone,
    searchLabel: l10n.accountSettingsTimezoneSearch,
    options: [for (final choice in choices) option(choice)],
    suggested: [
      for (final name in suggested)
        if (byName[name] case final choice?) option(choice),
    ],
    suggestedHeading: suggested.length == 1
        ? l10n.accountSettingsTimezoneDevice
        : l10n.accountSettingsTimezoneSameAsDevice,
    allHeading: l10n.accountSettingsTimezoneAll,
  );
}

Future<String?> _pickLanguage(BuildContext context, String current) {
  final l10n = context.l10n;
  return showSearchableOptionSheet<String>(
    context,
    title: l10n.accountSettingsLanguage,
    searchLabel: l10n.accountSettingsLanguageSearch,
    options: [
      for (final language in serverLanguages)
        SearchableOption(
          value: language.code,
          label: language.name,
          detail: language.code,
          selected: language.code == current,
        ),
    ],
  );
}

String _defaultViewLabel(AppLocalizations l10n, ProjectViewKind? kind) =>
    kind == null
    ? l10n.accountSettingsDefaultViewFirst
    : viewKindLabel(l10n, kind);

String _magicModeLabel(AppLocalizations l10n, QuickAddMagicMode mode) =>
    switch (mode) {
      QuickAddMagicMode.disabled => l10n.accountSettingsQuickAddMagicDisabled,
      QuickAddMagicMode.vikunja => l10n.accountSettingsQuickAddMagicVikunja,
      QuickAddMagicMode.todoist => l10n.accountSettingsQuickAddMagicTodoist,
    };

String _overviewFilterLabel(
  AppLocalizations l10n,
  int? filterProjectId,
  List<SavedFilterRef> filters,
) {
  if (filterProjectId == null) return l10n.accountSettingsOverviewFilterNone;
  for (final filter in filters) {
    if (filter.projectId == filterProjectId) {
      return projectDisplayTitle(
        l10n,
        filter.title,
        projectId: filter.projectId,
      );
    }
  }
  return l10n.accountSettingsOverviewFilterUnknown;
}

/// The written forms are labelled with today's date, as on the web.
String _dateDisplayLabel(
  AppLocalizations l10n,
  DateDisplay display,
  DateTime now,
) => switch (display) {
  DateDisplay.relative => l10n.accountSettingsDateDisplayRelative,
  DateDisplay.monthDayYearDashed => l10n.accountSettingsDateMonthDayYearDashed,
  DateDisplay.dayMonthYearDashed => l10n.accountSettingsDateDayMonthYearDashed,
  DateDisplay.yearMonthDayDashed => l10n.accountSettingsDateYearMonthDayDashed,
  DateDisplay.monthDayYearSlashed =>
    l10n.accountSettingsDateMonthDayYearSlashed,
  DateDisplay.dayMonthYearSlashed =>
    l10n.accountSettingsDateDayMonthYearSlashed,
  DateDisplay.yearMonthDaySlashed =>
    l10n.accountSettingsDateYearMonthDaySlashed,
  DateDisplay.dayMonthYear => intl.DateFormat.yMMMMd(
    l10n.localeName,
  ).format(now),
  DateDisplay.weekdayDayMonthYear => intl.DateFormat.yMMMMEEEEd(
    l10n.localeName,
  ).format(now),
};

/// With an example time, `12-hour · 2:30 PM`.
String _timeFormatLabel(
  AppLocalizations l10n,
  TimeFormat? format,
  DateTime now,
) {
  final sample = DateTime(now.year, now.month, now.day, 14, 30);
  String example(String pattern) =>
      intl.DateFormat(pattern, l10n.localeName).format(sample);
  return switch (format) {
    null => l10n.accountSettingsTimeFormatDevice,
    TimeFormat.twelveHour =>
      '${l10n.accountSettingsTimeFormat12} · ${example('h:mm a')}',
    TimeFormat.twentyFourHour =>
      '${l10n.accountSettingsTimeFormat24} · ${example('HH:mm')}',
  };
}
