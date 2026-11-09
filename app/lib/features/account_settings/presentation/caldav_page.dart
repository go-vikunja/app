import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/application/integration_addresses.dart';
import 'package:vikunja_mobile/features/account_settings/application/totp_status_reading.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_security_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/one_time_secret_view.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/security_list_body.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sign_in_provider_name.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/external_link.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';

final _log = Logger('Caldav');

/// What a CalDAV app needs: the address and the username to copy, which
/// password works for this account, and the account's CalDAV tokens, read
/// from the server each time, with a new one shown once and Delete.
class CaldavPage extends ConsumerStatefulWidget {
  const new({this.knownTotp, super.key});

  /// The two-factor status the Account settings page read already, so it
  /// is not asked for again.
  final TotpStatus? knownTotp;

  @override
  ConsumerState<CaldavPage> createState() => _CaldavPageState();
}

class _CaldavPageState extends ConsumerState<CaldavPage> {
  List<CaldavToken>? _tokens;
  TotpStatus? _totp;
  Object? _failure;
  bool _loading = false;
  bool _creating = false;
  int? _busyTokenId;
  String? _copiedValue;
  Timer? _copiedReset;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _copiedReset?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null || _loading) return;
    setState(() => _loading = true);
    unawaited(_loadTotp());
    try {
      final tokens = await repository.caldavTokens();
      if (mounted) {
        setState(() {
          _tokens = tokens;
          _failure = null;
        });
      }
    } on Object catch (error) {
      _log.info('Reading the CalDAV tokens failed: ${error.runtimeType}');
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Whether the account password works for CalDAV depends on it.
  Future<void> _loadTotp() async {
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
    // A sign-in provider's account must use a token anyway.
    if (profile != null && !profile.isLocalUser) return;
    if (!entry.connection.capabilities.has(Capability.totp)) {
      setState(() => _totp = TotpStatus.notSetUp);
      return;
    }
    if (widget.knownTotp case final known?) {
      setState(() => _totp = known);
      return;
    }
    if (!canReadTotpStatus(entry.connection)) return;
    try {
      final status = await repository.totpStatus();
      if (mounted) setState(() => _totp = status);
    } on NotFound catch (failure) {
      // The server has two-factor authentication off.
      if (failure.routeAbsent && mounted) {
        setState(() => _totp = TotpStatus.notSetUp);
      }
    } on Object catch (error) {
      _log.info('Reading the two-factor status failed: ${error.runtimeType}');
    }
  }

  /// Ten wrong passwords lock the account there, also those a CalDAV app
  /// sends, and a token the server no longer knows counts as one.
  static bool _lockout(ServerConnection? connection) =>
      connection?.capabilities.has(Capability.accountLockout) ?? false;

  void _showSnackBar(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _copy(String text) async {
    final l10n = context.l10n;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on Object catch (error) {
      _log.info('Copying failed: ${error.runtimeType}');
      if (mounted) _showSnackBar(l10n.copyToClipboardFailed);
      return;
    }
    if (!mounted) return;
    unawaited(HapticFeedback.selectionClick());
    announce(context, l10n.copiedToClipboard);
    // Only Android 13 and later show a copy themselves.
    _copiedReset?.cancel();
    setState(() => _copiedValue = text);
    _copiedReset = Timer(
      const Duration(seconds: 2),
      () => setState(() => _copiedValue = null),
    );
  }

  Future<void> _create(String username) async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null || _creating) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    setState(() => _creating = true);
    try {
      final created = await repository.createCaldavToken();
      if (!mounted) return;
      setState(() => _tokens = [...?_tokens, created.token]);
      unawaited(HapticFeedback.selectionClick());
      await navigator.push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => OneTimeSecretPage(
            pageTitle: l10n.caldavNewToken,
            secret: created.secret,
            title: l10n.oneTimeSecretCaldavTitle,
            usage: l10n.oneTimeSecretCaldavUsage(username),
          ),
        ),
      );
    } on Object catch (error) {
      _log.warning('Creating a CalDAV token failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) _showSnackBar(accountSecurityFailureText(l10n, error));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _delete(CaldavToken token) async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null || _busyTokenId != null) return;
    final l10n = context.l10n;
    final lockout =
        _lockout(ref.read(accountsProvider).value?.activeAccount?.connection) &&
        (ref.read(accountSettingsProvider).value?.profile?.isLocalUser ?? true);
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.caldavDeleteTitle(token.id),
      body: lockout ? l10n.caldavDeleteBodyLockout : l10n.caldavDeleteBody,
      confirmLabel: l10n.caldavDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyTokenId = token.id);
    try {
      await repository.deleteCaldavToken(token.id);
      if (!mounted) return;
      setState(
        () => _tokens = _tokens?.where((each) => each.id != token.id).toList(),
      );
      unawaited(HapticFeedback.selectionClick());
      announce(context, l10n.caldavTokenDeleted);
    } on Object catch (error) {
      _log.warning('Deleting a CalDAV token failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) _showSnackBar(accountSecurityFailureText(l10n, error));
    } finally {
      if (mounted) setState(() => _busyTokenId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entry = ref.watch(
      accountsProvider.select((accounts) => accounts.value?.activeAccount),
    );
    final profile = ref.watch(accountSettingsProvider).value?.profile;
    final formatter = MomentFormatter.watch(context, ref);
    if (entry == null) return const Scaffold();
    final username = entry.account.username;
    final address = caldavPrincipalUri(entry.connection, username).toString();
    final tokens = _tokens;
    final password = switch ((profile, _totp)) {
      (final profile?, _) when !profile.isLocalUser => l10n.caldavTokenProvider(
        signInProviderName(profile.authProvider),
      ),
      (_?, TotpStatus.enabled) => l10n.caldavTokenTotp,
      _ when _lockout(entry.connection) => l10n.caldavTokenRecommended,
      (_?, TotpStatus.notSetUp || TotpStatus.setupStarted) =>
        l10n.caldavPasswordOrToken,
      _ => l10n.caldavTokenUnknown,
    };
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    Widget copyRow(IconData icon, String label, String value, String tooltip) =>
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: SelectableText(value, style: theme.textTheme.bodyLarge),
          trailing: IconButton(
            onPressed: () => unawaited(_copy(value)),
            tooltip: tooltip,
            icon: Icon(_copiedValue == value ? Icons.check : Icons.copy),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.caldavTitle),
        actions: [
          RefreshButton(onPressed: _loading ? null : () => unawaited(_load())),
        ],
      ),
      body: SecurityListBody(
        loading: _loading && tokens == null,
        loadingLabel: l10n.caldavTokensLoading,
        failure: _failure,
        hasData: tokens != null,
        onRefresh: _load,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(l10n.caldavIntro, style: mutedStyle),
            ),
            copyRow(
              Icons.link,
              l10n.caldavAddress,
              address,
              l10n.caldavCopyAddress,
            ),
            copyRow(
              Icons.person_outline,
              l10n.caldavUsername,
              username,
              l10n.caldavCopyUsername,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(password, style: theme.textTheme.bodyMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(l10n.caldavApiTokenHint, style: mutedStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => unawaited(
                      GoRouter.of(context).push(AppRoutes.accountApiTokens),
                    ),
                    icon: const Icon(Icons.key_outlined),
                    label: Text(l10n.accountSettingsApiTokens),
                  ),
                  TextButton.icon(
                    onPressed: () => unawaited(
                      openExternalOrSay(context, ref, caldavDocsUri),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.caldavDocs),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ListSectionHeader(
              title: l10n.caldavTokens,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            ),
          ],
        ),
        empty: tokens != null && tokens.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.caldavTokensEmpty, style: mutedStyle),
              )
            : null,
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: _creating ? null : () => unawaited(_create(username)),
              style: inlineFilledButtonStyle(context),
              icon: _creating
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: l10n.accountSecurityWorking,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(l10n.caldavNewToken),
            ),
          ),
        ),
        children: [
          for (final token in tokens ?? const <CaldavToken>[])
            ListTile(
              key: ValueKey(token.id),
              enabled: _busyTokenId == null,
              leading: Icon(Icons.key_outlined, color: colors.onSurfaceVariant),
              title: Text(l10n.caldavTokenName(token.id)),
              subtitle: switch (token.created) {
                final created? => Text(
                  l10n.accountSecurityCreated(formatter.absolute(created)),
                ),
                null => null,
              },
              trailing: _busyTokenId == token.id
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        semanticsLabel: l10n.accountSecurityWorking,
                      ),
                    )
                  : IconButton(
                      onPressed: _busyTokenId == null
                          ? () => unawaited(_delete(token))
                          : null,
                      tooltip: l10n.caldavDeleteToken(token.id),
                      icon: Icon(Icons.delete_outline, color: colors.error),
                    ),
            ),
        ],
      ),
    );
  }
}
