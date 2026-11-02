import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/account_settings/application/api_token_permissions.dart';
import 'package:vikunja_mobile/features/account_settings/application/integration_addresses.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_security_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/security_list_body.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/external_link.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

final _log = Logger('ApiTokens');

/// The account's API tokens, read from the server each time: title, expiry
/// (an expired one in the error colour) and how many permissions; a token
/// opens its details with Delete, and "New token" opens the form.
class ApiTokensPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ApiTokensPage> createState() => _ApiTokensPageState();
}

class _ApiTokensPageState extends ConsumerState<ApiTokensPage> {
  List<ApiToken>? _tokens;
  Object? _failure;
  bool _loading = false;
  int? _busyTokenId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null || _loading) return;
    setState(() => _loading = true);
    try {
      final tokens = await repository.apiTokens();
      if (mounted) {
        setState(() {
          _tokens = tokens;
          _failure = null;
        });
      }
    } on Object catch (error) {
      _log.info('Reading the API tokens failed: ${error.runtimeType}');
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    await context.pushPage<void>(AppRoutes.accountApiTokenNew);
    if (mounted) await _load();
  }

  Future<void> _openDocs() async {
    final entry = ref.read(accountsProvider).value?.activeAccount;
    if (entry == null) return;
    await openExternalOrSay(context, ref, apiDocsUri(entry.connection));
  }

  Future<void> _showDetails(ApiToken token) async {
    final delete = await showPickerSheet<bool>(
      context,
      builder: (context, scrollController) =>
          _TokenDetails(token: token, scrollController: scrollController),
    );
    if ((delete ?? false) && mounted) await _delete(token);
  }

  Future<void> _delete(ApiToken token) async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null || _busyTokenId != null) return;
    final l10n = context.l10n;
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.apiTokensDeleteTitle(token.title),
      body: l10n.apiTokensDeleteBody,
      confirmLabel: l10n.apiTokensDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyTokenId = token.id);
    try {
      await repository.deleteApiToken(token.id);
      if (!mounted) return;
      setState(
        () => _tokens = _tokens?.where((each) => each.id != token.id).toList(),
      );
      unawaited(HapticFeedback.selectionClick());
      announce(context, l10n.apiTokensDeleted);
    } on Object catch (error) {
      _log.warning('Deleting an API token failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(accountSecurityFailureText(l10n, error))),
        );
      // Up to 2.7.0 a token deleted elsewhere is refused as forbidden.
      if (error is Forbidden && mounted) unawaited(_load());
    } finally {
      if (mounted) setState(() => _busyTokenId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatter = MomentFormatter.watch(context, ref);
    final now = ref.watch(clockProvider)();
    final tokens = _tokens;
    final intro = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.apiTokensIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton.icon(
            onPressed: () => unawaited(_openDocs()),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.apiTokensDocs),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.apiTokensTitle),
        actions: [
          RefreshButton(onPressed: _loading ? null : () => unawaited(_load())),
          IconButton(
            onPressed: () => unawaited(_create()),
            tooltip: l10n.apiTokensNew,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SecurityListBody(
        loading: _loading && tokens == null,
        loadingLabel: l10n.apiTokensLoading,
        failure: _failure,
        hasData: tokens != null,
        onRefresh: _load,
        header: intro,
        empty: tokens != null && tokens.isEmpty
            ? SecurityEmptyNote(
                icon: Icons.key_off_outlined,
                title: l10n.apiTokensEmptyTitle,
                body: l10n.apiTokensEmptyBody,
                action: FilledButton.tonalIcon(
                  onPressed: () => unawaited(_create()),
                  style: inlineFilledButtonStyle(context),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.apiTokensNew),
                ),
              )
            : null,
        children: [
          for (final token in tokens ?? const <ApiToken>[])
            _TokenRow(
              key: ValueKey(token.id),
              token: token,
              expiry: token.isExpiredAt(now)
                  ? l10n.apiTokensExpired(
                      formatter.relative(token.expiresAt, now: now),
                    )
                  : l10n.apiTokensExpires(formatter.absolute(token.expiresAt)),
              expired: token.isExpiredAt(now),
              busy: _busyTokenId == token.id,
              enabled: _busyTokenId == null,
              onTap: () => unawaited(_showDetails(token)),
            ),
        ],
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  const new({
    required this.token,
    required this.expiry,
    required this.expired,
    required this.busy,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final ApiToken token;
  final String expiry;
  final bool expired;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      enabled: enabled,
      leading: Icon(
        expired ? Icons.key_off_outlined : Icons.key_outlined,
        color: expired ? colors.error : colors.onSurfaceVariant,
      ),
      title: Text(token.title.trim().isEmpty ? '–' : token.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expiry,
            style: expired
                ? theme.textTheme.bodyMedium?.copyWith(color: colors.error)
                : null,
          ),
          Text(l10n.apiTokensPermissionCount(token.permissionCount)),
        ],
      ),
      trailing: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                semanticsLabel: l10n.accountSecurityWorking,
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// A token's permissions by group, when it was made and until when it
/// works; pops true for Delete.
class _TokenDetails extends ConsumerWidget {
  const new({required this.token, required this.scrollController});

  final ApiToken token;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final formatter = MomentFormatter.watch(context, ref);
    final now = ref.watch(clockProvider)();
    final created = token.created;
    final expired = token.isExpiredAt(now);
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Semantics(
          header: true,
          headingLevel: 1,
          child: Text(
            token.title.trim().isEmpty ? '–' : token.title,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          expired
              ? l10n.apiTokensExpired(
                  formatter.relative(token.expiresAt, now: now),
                )
              : l10n.apiTokensExpires(formatter.absolute(token.expiresAt)),
          style: expired
              ? theme.textTheme.bodyMedium?.copyWith(color: colors.error)
              : theme.textTheme.bodyMedium,
        ),
        if (created != null)
          Text(
            l10n.accountSecurityCreated(formatter.absolute(created)),
            style: theme.textTheme.bodyMedium,
          ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          headingLevel: 2,
          child: Text(
            l10n.apiTokensPermissions,
            style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
          ),
        ),
        const SizedBox(height: 8),
        for (final MapEntry(key: group, value: names)
            in token.permissions.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${humanizePermission(group)}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: names.map(humanizePermission).join(', ')),
                ],
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(foregroundColor: colors.error),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.apiTokensDelete),
          ),
        ),
      ],
    );
  }
}
