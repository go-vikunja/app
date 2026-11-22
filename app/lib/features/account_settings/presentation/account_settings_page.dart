import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_app_bar.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/failed_without_token.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/account_settings/application/totp_status_reading.dart';
import 'package:vikunja_mobile/features/account_settings/application/web_settings_pages.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_deletion.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_security_sections.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_save.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_sections.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sign_in_provider_name.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/web_settings_page_opener.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/connection/presentation/browser_leg_hint.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_confirmations.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';

final _log = Logger('AccountSettingsPage');

/// The account's settings on the server, which follow it to every device,
/// in the web's order where it has the same ones. A switch or a pick saves
/// at once and the name on Done, always online; offline the page only
/// shows them. A refused value is shown at its control. Password and email,
/// two-factor authentication, the data export's request and download and
/// the account's deletion are left to the web's own pages in the browser,
/// because they ask for the password or a code; sessions, tokens and
/// CalDAV have pages of their own.
class AccountSettingsPage extends ConsumerStatefulWidget {
  const new({super.key});

  /// A resume reads the server again only after this, after one of the
  /// web's pages was opened from here, while an email change waits for its
  /// confirmation, or after a read that failed: what another device changes
  /// meanwhile can wait that long, and a short trip to another app sends
  /// nothing.
  static const resumeReadAfter = Duration(minutes: 5);

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
  bool _webPageOpened = false;

  /// When the last read the server answered began.
  DateTime? _readAt;

  /// When the last security read whose every part was answered began.
  DateTime? _securityReadAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
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

  /// Back from the web's email or two-factor page, a pending change shows
  /// at once.
  void _onResume() {
    final now = ref.read(clockProvider)();
    bool fresh(DateTime? readAt) =>
        readAt != null &&
        now.difference(readAt) < AccountSettingsPage.resumeReadAfter;
    // The link in the confirmation mail is opened outside the app.
    final pendingEmail =
        ref.read(accountSettingsProvider).value?.profile?.pendingEmail ?? '';
    if (fresh(_readAt) &&
        fresh(_securityReadAt) &&
        !_webPageOpened &&
        pendingEmail.isEmpty) {
      return;
    }
    unawaited(_refresh());
    unawaited(_refreshSecurity(totp: _totpPageOpened));
    _webPageOpened = false;
    _totpPageOpened = false;
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
    final startedAt = ref.read(clockProvider)();
    try {
      await repository.refresh();
      _readAt = startedAt;
      if (mounted) setState(() => _reachable = true);
    } on Object catch (error) {
      if (failedOnTheNetwork(error)) {
        if (mounted) setState(() => _reachable = false);
        return;
      }
      _log.info('Refreshing the account settings failed: ${error.runtimeType}');
    }
  }

  /// Each part on its own and never throwing: one that cannot be read
  /// keeps what it showed. The two-factor status only with [totp].
  Future<void> _refreshSecurity({bool totp = false}) async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    final entry = ref.read(accountsProvider).value?.activeAccount;
    if (repository == null || entry == null) return;
    final startedAt = ref.read(clockProvider)();
    final UserProfile? profile;
    try {
      profile = (await ref.read(accountSettingsProvider.future)).profile;
    } on Object catch (error) {
      _log.info('Reading the stored profile failed: ${error.runtimeType}');
      return;
    }
    if (!mounted) return;
    Future<bool> read<T>(
      String part,
      Future<T> Function() load,
      SecurityOverview Function(T value) apply, {
      SecurityOverview Function(Object error)? onError,
    }) async {
      try {
        final value = await load();
        if (mounted) setState(() => _security = apply(value));
        return true;
      } on Object catch (error) {
        _log.info('Reading the $part failed: ${error.runtimeType}');
        if (mounted && onError != null) {
          setState(() => _security = onError(error));
        }
        return false;
      }
    }

    final answered = await [
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
    if (answered.every((ok) => ok)) _securityReadAt = startedAt;
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
                error: NetworkFailure(problem: NetworkProblem.unreachable) &&
                    final error,
              )
              when !failedWithoutToken(error):
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
    _webPageOpened = true;
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
      // The name's own save is on its way; another one keeps it unsaved.
      canPop: !_nameDirty || _saving == AccountSettingsField.name,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leaveIfConfirmed());
      },
      child: Scaffold(
        appBar: ReadableAppBar(
          maxWidth: ReadableWidth.form,
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
  final SaveSetting onSave;
  final ChooseSetting onChoose;
  final ValueChanged<WebSettingsPage> onOpenWeb;
  final SecurityOverview security;
  final void Function(String location, {Object? extra}) onOpenPage;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
    final editing = SettingsEditing(
      settings: settings,
      errors: errors,
      canChange: canChange,
      onSave: onSave,
      onChoose: onChoose,
    );

    final children = <Widget>[
      ...accountSettingsNotes(
        l10n: l10n,
        entry: entry,
        profile: profile,
        isLocalUser: isLocalUser,
        offline: offline,
        onRetry: onRetry,
        onSignInAgain: onSignInAgain,
        onOpenWeb: onOpenWeb,
      ),
      profileSection(
        context: context,
        l10n: l10n,
        entry: entry,
        avatarProvider: state.avatarProvider,
        profile: profile,
        isLocalUser: isLocalUser,
        provider: provider,
        nameController: nameController,
        nameDirty: nameDirty,
        canChange: canChange,
        error: errors[AccountSettingsField.name],
        onNameChanged: onNameChanged,
        onSaveName: onSaveName,
      ),
      signInSection(
        l10n: l10n,
        connection: entry.connection,
        profile: profile,
        isLocalUser: isLocalUser,
        provider: provider,
        onOpenWeb: onOpenWeb,
      ),
      securitySection(
        l10n: l10n,
        connection: entry.connection,
        profile: profile,
        overview: security,
        onOpenTotp: () => onOpenWeb(WebSettingsPage.totp),
        onOpenSessions: () => onOpenPage(AppRoutes.accountSessions),
      ),
      defaultsSection(
        context: context,
        l10n: l10n,
        editing: editing,
        projects: projects,
        savedFilters: savedFilters,
      ),
      timeAndLanguageSection(
        context: context,
        l10n: l10n,
        editing: editing,
        formatter: formatter,
        now: now,
      ),
      emailNotificationsSection(
        context: context,
        l10n: l10n,
        connection: entry.connection,
        editing: editing,
        formatter: formatter,
        display: display,
      ),
      privacySection(l10n: l10n, editing: editing),
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
