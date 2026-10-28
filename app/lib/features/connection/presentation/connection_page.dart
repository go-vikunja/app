import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/connection/presentation/certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/client_certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_texts.dart';
import 'package:vikunja_mobile/features/connection/presentation/fingerprint_view.dart';
import 'package:vikunja_mobile/features/connection/presentation/headers_page.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/insecure_connection_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

final _log = Logger('ConnectionPage');

/// One server address's connection settings (D65), or one of their
/// editors. An address that does not parse closes the page at once.
class ConnectionPage extends StatefulWidget {
  const new({required this.origin, this.editor, super.key});

  final OriginKey? origin;
  final ConnectionEditor? editor;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  @override
  void initState() {
    super.initState();
    if (widget.origin == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final origin = widget.origin;
    if (origin == null) return const Scaffold();
    return switch (widget.editor) {
      ConnectionEditor.headers => HeadersPage(origin: origin),
      // Certificates are for TLS only.
      ConnectionEditor.certificate when origin.isSecure => CertificatePage(
        origin: origin,
      ),
      ConnectionEditor.clientCertificate when origin.isSecure =>
        ClientCertificatePage(origin: origin),
      _ => _ConnectionOverview(origin: origin),
    };
  }
}

/// What is stored for the address and the ways to change it: for https the
/// server certificate, a client certificate and access headers; for http
/// the permission for unencrypted connections and, once given, headers.
class _ConnectionOverview extends ConsumerStatefulWidget {
  const new({required this.origin});

  final OriginKey origin;

  @override
  ConsumerState<_ConnectionOverview> createState() =>
      _ConnectionOverviewState();
}

class _ConnectionOverviewState extends ConsumerState<_ConnectionOverview> {
  var _busy = false;

  OriginKey get _origin => widget.origin;

  NetworkProfiles get _profiles => ref.read(networkProfilesProvider);

  Future<void> _edit(Future<void> Function() change) async {
    setState(() => _busy = true);
    try {
      await change();
    } on Object catch (error) {
      _log.warning(
        'Changing connection settings failed: '
        '${error.runtimeType}',
      );
      if (mounted) {
        final message = context.l10n.connectionSaveFailed;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmThen({
    required String title,
    required String body,
    required String confirmLabel,
    required Future<void> Function() change,
  }) async {
    final confirmed = await confirmAdaptive(
      context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      destructive: true,
    );
    if (confirmed && mounted) await _edit(change);
  }

  void _open(ConnectionEditor editor) => unawaited(
    context.pushPage<void>(AppRoutes.connectionFor(_origin, editor: editor)),
  );

  Future<void> _allowCleartext() async {
    final accepted = await confirmInsecureConnection(
      context,
      rootUri: _origin.uri,
    );
    if (accepted && mounted) {
      await _edit(() => _profiles.consentToCleartext(_origin));
    }
  }

  Future<void> _reload() async {
    await _profiles.reload();
    ref.invalidate(connectionProfileProvider(_origin));
  }

  Future<void> _reset() async {
    if (await confirmConnectionSettingsReset(context) && mounted) {
      await _edit(_profiles.resetAll);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(connectionProfileProvider(_origin));
    final host = _origin.authority;

    final content = switch (state) {
      AsyncValue(:final value?) => switch (value.status) {
        ConnectionProfileStatus.damaged => <Widget>[
          _Notice(
            title: l10n.connectionProfileDamagedTitle,
            body: l10n.connectionProfileDamagedExplanation,
            error: true,
            action: TextButton(
              onPressed: _busy ? null : () => unawaited(_reset()),
              child: Text(l10n.connectionReset),
            ),
          ),
        ],
        ConnectionProfileStatus.unavailable => <Widget>[
          _Notice(
            title: l10n.connectionProfileLockedTitle,
            body: l10n.connectionProfileLockedExplanation(host),
            action: TextButton(
              onPressed: () => unawaited(_reload()),
              child: Text(l10n.retry),
            ),
          ),
        ],
        _ => _settings(context, value),
      },
      AsyncError() => <Widget>[
        _Notice(
          title: l10n.connectionProfileLockedTitle,
          body: l10n.connectionProfileLockedExplanation(host),
          action: TextButton(
            onPressed: () => unawaited(_reload()),
            child: Text(l10n.retry),
          ),
        ),
      ],
      _ => <Widget>[LoadingPlaceholder(label: l10n.connectionTitle)],
    };

    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.connectionTitle),
        bottom: SavingProgressBar(saving: _busy),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.connectionOptionsFor('$_origin'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.connectionIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...content,
          ],
        ),
      ),
    );
  }

  List<Widget> _settings(BuildContext context, ConnectionProfileState state) {
    final l10n = context.l10n;
    final profile = state.profile;
    final host = _origin.authority;
    final enabled = !_busy;
    return [
      if (state.status == ConnectionProfileStatus.needsReentry)
        _Notice(
          title: l10n.connectionNeedsReentryTitle,
          body: l10n.connectionNeedsReentryBody,
        ),
      if (profile?.lastPinMismatch case final mismatch?)
        _Notice(
          title: l10n.connectionMismatchTitle,
          body: l10n.connectionMismatchBody(
            formatConnectionDate(l10n, mismatch.seenAt),
          ),
          error: true,
          action: TextButton(
            onPressed: enabled
                ? () => _open(ConnectionEditor.certificate)
                : null,
            child: Text(l10n.connectionMismatchReview),
          ),
        ),
      if (_origin.isSecure) ...[
        _certificateSection(context, profile, host: host),
        _clientCertificateSection(context, profile, host: host),
      ] else
        _cleartextSection(context, profile, host: host),
      _headersSection(context, profile, host: host),
      if (profile != null && !profile.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Center(
            child: OutlinedButton.icon(
              onPressed: enabled
                  ? () => unawaited(
                      _confirmThen(
                        title: l10n.connectionForgetTitle,
                        body: l10n.connectionForgetBody(host),
                        confirmLabel: l10n.connectionForgetConfirm,
                        change: () => _profiles.forget(_origin),
                      ),
                    )
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.connectionForget),
            ),
          ),
        ),
    ];
  }

  Widget _certificateSection(
    BuildContext context,
    NetworkProfile? profile, {
    required String host,
  }) {
    final l10n = context.l10n;
    final enabled = !_busy;
    final check = TextButton(
      onPressed: enabled ? () => _open(ConnectionEditor.certificate) : null,
      child: Text(l10n.connectionCheckCertificate),
    );
    final remove = TextButton(
      onPressed: enabled
          ? () => unawaited(
              _confirmThen(
                title: l10n.connectionRemoveTrustTitle,
                body: l10n.connectionRemoveTrustBody(host),
                confirmLabel: l10n.connectionRemove,
                change: () => _profiles.removeCertificateTrust(_origin),
              ),
            )
          : null,
      child: Text(l10n.connectionRemove),
    );
    return SectionCard(
      title: l10n.connectionServerCertificateHeading,
      children: [
        if (profile?.pin case final pin?) ...[
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: Text(l10n.connectionPinnedTitle),
            subtitle: Text(
              l10n.connectionPinnedSince(
                formatConnectionDate(l10n, pin.trustedAt),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FingerprintView(pairs: pin.certificate.sha256Pairs),
          ),
          _Actions(children: [check, remove]),
        ] else if (profile?.caCertificate case final ca?) ...[
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(l10n.connectionCaTitle),
            subtitle: Text(
              l10n.connectionFileAdded(
                ca.fileName,
                formatConnectionDate(l10n, ca.importedAt),
              ),
            ),
          ),
          if (Theme.of(context).platform == TargetPlatform.iOS)
            SettingsNote(
              icon: Icons.info_outline,
              text: l10n.connectionCaIosHint,
            ),
          _Actions(children: [check, remove]),
        ] else
          SettingsNote(
            icon: Icons.phonelink_lock_outlined,
            text: l10n.connectionDeviceTrust,
            action: check,
          ),
      ],
    );
  }

  Widget _clientCertificateSection(
    BuildContext context,
    NetworkProfile? profile, {
    required String host,
  }) {
    final l10n = context.l10n;
    final enabled = !_busy;
    final client = profile?.clientCertificate;
    return SectionCard(
      title: l10n.connectionClientCertificateHeading,
      children: [
        if (client == null)
          SettingsNote(
            icon: Icons.badge_outlined,
            text: l10n.connectionClientCertificateNone,
            action: TextButton(
              onPressed: enabled
                  ? () => _open(ConnectionEditor.clientCertificate)
                  : null,
              child: Text(l10n.connectionAddClientCertificate),
            ),
          )
        else ...[
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(
              l10n.connectionFileAdded(
                client.fileName,
                formatConnectionDate(l10n, client.importedAt),
              ),
            ),
          ),
          _Actions(
            children: [
              TextButton(
                onPressed: enabled
                    ? () => _open(ConnectionEditor.clientCertificate)
                    : null,
                child: Text(l10n.connectionReplaceClientCertificate),
              ),
              TextButton(
                onPressed: enabled
                    ? () => unawaited(
                        _confirmThen(
                          title: l10n.connectionRemoveClientCertificateTitle,
                          body: l10n.connectionRemoveClientCertificateBody(
                            host,
                          ),
                          confirmLabel: l10n.connectionRemove,
                          change: () =>
                              _profiles.removeClientCertificate(_origin),
                        ),
                      )
                    : null,
                child: Text(l10n.connectionRemove),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _cleartextSection(
    BuildContext context,
    NetworkProfile? profile, {
    required String host,
  }) {
    final l10n = context.l10n;
    final enabled = !_busy;
    final consentAt = profile?.cleartextConsentAt;
    return SectionCard(
      title: l10n.connectionCleartextHeading,
      children: [
        if (consentAt == null)
          SettingsNote(
            icon: Icons.no_encryption_outlined,
            text: l10n.connectionCleartextNotAllowed,
            action: TextButton(
              onPressed: enabled ? () => unawaited(_allowCleartext()) : null,
              child: Text(l10n.connectionCleartextAllow),
            ),
          )
        else ...[
          ListTile(
            leading: const Icon(Icons.no_encryption_outlined),
            title: Text(
              l10n.connectionCleartextAllowedSince(
                formatConnectionDate(l10n, consentAt),
              ),
            ),
          ),
          _Actions(
            children: [
              TextButton(
                onPressed: enabled
                    ? () => unawaited(
                        _confirmThen(
                          title: l10n.connectionCleartextRevokeTitle,
                          body: l10n.connectionCleartextRevokeBody(host),
                          confirmLabel: l10n.connectionCleartextRevoke,
                          change: () => _profiles.revokeCleartext(_origin),
                        ),
                      )
                    : null,
                child: Text(l10n.connectionCleartextRevoke),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _headersSection(
    BuildContext context,
    NetworkProfile? profile, {
    required String host,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final enabled = !_busy;
    final names = profile?.headerNames ?? const <String>[];
    final blockedByCleartext =
        !_origin.isSecure && !(profile?.hasCleartextConsent ?? false);
    return SectionCard(
      title: l10n.connectionHeadersHeading,
      children: [
        if (blockedByCleartext && names.isEmpty)
          SettingsNote(
            icon: Icons.info_outline,
            text: l10n.connectionHeadersNeedCleartext,
          )
        else if (names.isEmpty)
          SettingsNote(
            icon: Icons.vpn_key_outlined,
            text: l10n.connectionHeadersNone,
            action: TextButton(
              onPressed: enabled ? () => _open(ConnectionEditor.headers) : null,
              child: Text(l10n.connectionAddHeaders),
            ),
          )
        else ...[
          for (final name in names)
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: Text(name),
              subtitle: Semantics(
                label: l10n.connectionHeaderValueHidden,
                excludeSemantics: true,
                child: Text('•' * 8, style: theme.textTheme.bodyMedium),
              ),
            ),
          // Revoking the consent keeps them for when it is given again.
          if (blockedByCleartext)
            SettingsNote(
              icon: Icons.info_outline,
              text: l10n.connectionHeadersHeldBack,
            ),
          _Actions(
            children: [
              if (!blockedByCleartext)
                TextButton(
                  onPressed: enabled
                      ? () => _open(ConnectionEditor.headers)
                      : null,
                  child: Text(l10n.connectionEditHeaders),
                ),
              TextButton(
                onPressed: enabled
                    ? () => unawaited(
                        _confirmThen(
                          title: l10n.connectionRemoveHeadersTitle,
                          body: l10n.connectionRemoveHeadersBody(host),
                          confirmLabel: l10n.connectionRemove,
                          change: () => _profiles.setHeaders(_origin, {}),
                        ),
                      )
                    : null,
                child: Text(l10n.connectionRemove),
              ),
            ],
          ),
        ],
        if (!_origin.isSecure && !blockedByCleartext)
          SettingsNote(
            icon: Icons.warning_amber_outlined,
            text: l10n.connectionHeadersUnencrypted,
          ),
      ],
    );
  }
}

/// What holds the page back, announced as it appears.
class _Notice extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    this.action,
    this.error = false,
  });

  final String title;
  final String body;
  final Widget? action;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: StatusCard(
        icon: error ? Icons.error_outline : Icons.info_outline,
        title: title,
        body: body,
        background: error ? colors.errorContainer : colors.secondaryContainer,
        foreground: error
            ? colors.onErrorContainer
            : colors.onSecondaryContainer,
        liveRegion: true,
        action: action,
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 4),
    child: Wrap(spacing: 8, children: children),
  );
}
