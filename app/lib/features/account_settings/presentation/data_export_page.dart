import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/account_settings/application/web_settings_pages.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/security_list_body.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/web_password_note.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/web_settings_page_opener.dart';
import 'package:vikunja_mobile/features/common/presentation/file_size_text.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';

final _log = Logger('DataExport');

/// The account's data export: what it holds, whether one is ready and
/// until when, read again on return from the browser. Requesting and
/// downloading need the password on the web (D14), so both open the web's
/// pages.
class DataExportPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends ConsumerState<DataExportPage> {
  late final AppLifecycleListener _lifecycle;
  UserDataExport? _export;
  bool _read = false;
  Object? _failure;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Back from the web, a requested export may be ready.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(accountSecurityRepositoryProvider);
    if (repository == null || _loading) return;
    setState(() => _loading = true);
    try {
      final export = await repository.dataExport();
      if (mounted) {
        setState(() {
          _export = export;
          _read = true;
          _failure = null;
        });
      }
    } on Object catch (error) {
      _log.info('Reading the data export failed: ${error.runtimeType}');
      if (mounted) setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWeb(WebSettingsPage page) async {
    final entry = ref.read(accountsProvider).value?.activeAccount;
    if (entry == null) return;
    await openWebSettingsPage(context, ref, entry, page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final formatter = MomentFormatter.watch(context, ref);
    final now = ref.watch(clockProvider)();
    final profile = ref.watch(accountSettingsProvider).value?.profile;
    final export = switch (_export) {
      final export? when !export.isExpiredAt(now) => export,
      _ => null,
    };
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final webAsksPassword = profile?.isLocalUser ?? true;
    final accountLockout = ref.watch(
      accountsProvider.select(
        (accounts) =>
            accounts.value?.activeAccount?.connection.capabilities.has(
              Capability.accountLockout,
            ) ??
            false,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: ScreenTitle(l10n.dataExportTitle)),
      body: SecurityListBody(
        loading: _loading && !_read,
        loadingLabel: l10n.dataExportLoading,
        failure: _failure,
        hasData: _read,
        onRefresh: _load,
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(l10n.dataExportIntro, style: theme.textTheme.bodyMedium),
        ),
        children: [
          if (_read)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: export == null
                  ? StatusCard(
                      icon: Icons.inventory_2_outlined,
                      title: l10n.dataExportNoneTitle,
                      body: l10n.dataExportNoneBody,
                      background: colors.surfaceContainerHighest,
                      foreground: colors.onSurfaceVariant,
                    )
                  : StatusCard(
                      icon: Icons.download_done_outlined,
                      title: l10n.dataExportReadyTitle,
                      body: l10n.dataExportReadyBody(
                        formatFileSize(l10n, export.size),
                        formatter.absolute(export.expires),
                      ),
                      background: colors.secondaryContainer,
                      foreground: colors.onSecondaryContainer,
                      action: FilledButton.icon(
                        onPressed: () =>
                            unawaited(_openWeb(WebSettingsPage.exportDownload)),
                        style: inlineFilledButtonStyle(context),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(l10n.dataExportDownload),
                      ),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () =>
                    unawaited(_openWeb(WebSettingsPage.dataExport)),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.dataExportRequest),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              [
                l10n.dataExportRequestNote,
                if (webAsksPassword)
                  webAsksPasswordNote(l10n, accountLockout: accountLockout),
              ].join(' '),
              style: mutedStyle,
            ),
          ),
        ],
      ),
    );
  }
}
