import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/connection/application/certificate_checks.dart';
import 'package:vikunja_mobile/features/connection/application/certificate_file.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_texts.dart';
import 'package:vikunja_mobile/features/connection/presentation/fingerprint_view.dart';

final _log = Logger('CertificatePage');

const _fingerprintCommand =
    'openssl x509 -noout -fingerprint -sha256 -in '
    'cert.pem';

/// The certificate [origin] presents now, fetched without sending a byte
/// of HTTP, to trust it or a CA certificate for exactly that address.
/// With a trusted certificate that the server no longer presents, a review
/// of the trusted, the recorded and the current certificate.
class CertificatePage extends ConsumerStatefulWidget {
  const new({required this.origin, super.key});

  final OriginKey origin;

  @override
  ConsumerState<CertificatePage> createState() => _CertificatePageState();
}

class _CertificatePageState extends ConsumerState<CertificatePage> {
  CertificateProbeResult? _probe;
  _CaOutcome? _caOutcome;
  var _busy = false;

  OriginKey get _origin => widget.origin;

  NetworkProfiles get _profiles => ref.read(networkProfilesProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    setState(() {
      _probe = null;
      _caOutcome = null;
    });
    final result = await ref.read(certificateChecksProvider).fetch(_origin);
    if (mounted) setState(() => _probe = result);
  }

  /// Leaves the page once [change] is stored.
  Future<void> _save(Future<void> Function() change) async {
    setState(() => _busy = true);
    try {
      await change();
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      _log.warning(
        'Storing the certificate trust failed: '
        '${error.runtimeType}',
      );
      if (mounted) _say(context.l10n.connectionSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _trust(CertificateInfo certificate) =>
      _save(() => _profiles.trustCertificate(_origin, certificate));

  Future<void> _keepCurrent() =>
      _save(() => _profiles.dismissPinMismatch(_origin));

  Future<void> _useCa() async {
    final l10n = context.l10n;
    setState(() => _caOutcome = null);
    final PickedCertificateFile picked;
    try {
      picked = await pickCertificateFile(ref.read(attachmentPickerProvider));
    } on Object catch (error) {
      _log.info('The file picker failed: ${error.runtimeType}');
      if (mounted) _say(l10n.connectionPickerFailed);
      return;
    }
    if (!mounted) return;
    final String name;
    final String pem;
    switch (picked) {
      case CertificateFileCancelled():
        return;
      case CertificateFileTooLarge():
        setState(() => _caOutcome = _CaMessage(l10n.connectionFileTooLarge));
        return;
      case CertificateFileUnreadable():
        setState(() => _caOutcome = _CaMessage(l10n.connectionFileUnreadable));
        return;
      case CertificateFileRead(name: final fileName, :final bytes):
        try {
          pem = utf8.decode(bytes);
        } on FormatException {
          setState(() => _caOutcome = _CaMessage(l10n.connectionCaFileInvalid));
          return;
        }
        name = fileName;
    }
    setState(() => _busy = true);
    final check = await ref
        .read(certificateChecksProvider)
        .verifyWithCa(_origin, pem);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (check) {
      case CaTrusted():
        await _save(
          () => _profiles.trustCaCertificate(_origin, fileName: name, pem: pem),
        );
      case CaNotTrusted(:final leaf):
        setState(() => _caOutcome = _CaLeafNotTrusted(leaf));
      case CaCheckFailed():
        setState(() => _caOutcome = _CaUnchecked(fileName: name, pem: pem));
      case CaFileInvalid():
        setState(() => _caOutcome = _CaMessage(l10n.connectionCaFileInvalid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = ref
        .watch(connectionProfileProvider(_origin))
        .value
        ?.profile;
    final probe = _probe;
    final pin = profile?.pin;
    final review = switch (probe) {
      ProbedCertificate(:final certificate) when pin != null =>
        profile?.lastPinMismatch != null || certificate.sha256 != pin.sha256,
      _ => pin != null && profile?.lastPinMismatch != null,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          review
              ? l10n.connectionReviewTitle
              : l10n.connectionServerCertificateHeading,
        ),
        bottom: SavingProgressBar(saving: _busy),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text('$_origin', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...switch (probe) {
              null => [
                LoadingPlaceholder(
                  label: l10n.connectionCertificateChecking('$_origin'),
                ),
              ],
              CertificateProbeFailed(:final problem) => [
                _probeFailure(context, problem),
                if (review && profile != null) ...[
                  const SizedBox(height: 16),
                  ..._reviewDetails(context, profile, probed: null),
                ],
              ],
              ProbedCertificate(:final certificate, :final deviceTrusted) =>
                review && profile != null
                    ? _review(context, profile, certificate)
                    : _trustContent(
                        context,
                        profile,
                        certificate,
                        deviceTrusted: deviceTrusted,
                      ),
            },
          ],
        ),
      ),
    );
  }

  Widget _probeFailure(BuildContext context, CertificateProbeProblem problem) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final host = _origin.authority;
    return StatusCard(
      icon: Icons.error_outline,
      title: l10n.connectionServerCertificateHeading,
      body: switch (problem) {
        CertificateProbeProblem.unreachable => l10n.connectionProbeUnreachable(
          host,
        ),
        CertificateProbeProblem.timeout => l10n.connectionProbeTimeout(host),
        CertificateProbeProblem.notTls => l10n.connectionProbeNotTls(host),
      },
      background: colors.errorContainer,
      foreground: colors.onErrorContainer,
      liveRegion: true,
      action: TextButton(
        onPressed: _busy ? null : () => unawaited(_fetch()),
        style: TextButton.styleFrom(foregroundColor: colors.onErrorContainer),
        child: Text(l10n.retry),
      ),
    );
  }

  List<Widget> _trustContent(
    BuildContext context,
    NetworkProfile? profile,
    CertificateInfo certificate, {
    required bool deviceTrusted,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final enabled = !_busy;
    final alreadyTrusted = profile?.pin?.sha256 == certificate.sha256;
    final shortLived = certificate.isShortLived;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // A pin adds nothing for a certificate the device trusts, and one on a
    // short-lived certificate breaks at its next renewal.
    final trustIsPrimary = !deviceTrusted && !shortLived;
    final caIsPrimary = !deviceTrusted && shortLived;
    void onTrust() => unawaited(_trust(certificate));
    void onUseCa() => unawaited(_useCa());
    final trust = [
      Text(l10n.connectionTrustOnlyFor('$_origin'), style: secondary),
      if (profile?.caCertificate != null)
        Text(l10n.connectionPinReplacesCa, style: secondary),
      const SizedBox(height: 8),
      if (trustIsPrimary)
        FilledButton.icon(
          onPressed: enabled ? onTrust : null,
          icon: const Icon(Icons.verified_outlined),
          label: Text(l10n.connectionTrustCertificate),
        )
      else
        OutlinedButton.icon(
          onPressed: enabled ? onTrust : null,
          icon: const Icon(Icons.verified_outlined),
          label: Text(l10n.connectionTrustCertificate),
        ),
    ];
    final ca = [
      if (profile?.pin != null)
        Text(l10n.connectionCaReplacesPin, style: secondary),
      if (theme.platform == TargetPlatform.iOS)
        Text(l10n.connectionCaIosHint, style: secondary),
      const SizedBox(height: 8),
      if (caIsPrimary)
        FilledButton.icon(
          onPressed: enabled ? onUseCa : null,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(l10n.connectionUseCa),
        )
      else
        OutlinedButton.icon(
          onPressed: enabled ? onUseCa : null,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(l10n.connectionUseCa),
        ),
      if (_caOutcome case final outcome?) ...[
        const SizedBox(height: 16),
        _caOutcomeCard(context, outcome, shown: certificate),
      ],
    ];
    return [
      if (alreadyTrusted) ...[
        ListNote(
          icon: Icons.verified_outlined,
          text: l10n.connectionAlreadyTrusted,
        ),
        const SizedBox(height: 16),
      ] else if (deviceTrusted) ...[
        ListNote(
          icon: Icons.phonelink_lock_outlined,
          text: l10n.connectionTrustDeviceTrusted,
        ),
        const SizedBox(height: 16),
      ],
      if (shortLived) ...[
        ListNote(icon: Icons.autorenew, text: l10n.connectionTrustShortLived),
        const SizedBox(height: 16),
      ],
      _CertificateDetails(certificate: certificate),
      const SizedBox(height: 16),
      const _CompareHint(),
      if (!deviceTrusted) ...[
        const SizedBox(height: 16),
        ListNote(
          icon: Icons.open_in_browser,
          text: l10n.connectionBrowserWarnsToo,
        ),
      ],
      const SizedBox(height: 24),
      if (caIsPrimary) ...[
        ...ca,
        if (!alreadyTrusted) ...[const SizedBox(height: 16), ...trust],
      ] else ...[
        if (!alreadyTrusted) ...[...trust, const SizedBox(height: 16)],
        ...ca,
      ],
    ];
  }

  Widget _caOutcomeCard(
    BuildContext context,
    _CaOutcome outcome, {
    required CertificateInfo shown,
  }) {
    final l10n = context.l10n;
    final enabled = !_busy;
    return switch (outcome) {
      _CaMessage(:final text) => _OutcomeCard(text: text),
      _CaLeafNotTrusted(:final leaf) => _OutcomeCard(
        text: l10n.connectionCaNotTrusted,
        extra: leaf.sha256 == shown.sha256
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.connectionCaNotTrustedLeaf),
                  const SizedBox(height: 8),
                  FingerprintView(pairs: leaf.sha256Pairs, copyable: false),
                ],
              ),
        action: TextButton(
          onPressed: enabled ? () => unawaited(_trust(leaf)) : null,
          child: Text(l10n.connectionTrustCertificate),
        ),
      ),
      _CaUnchecked(:final fileName, :final pem) => _OutcomeCard(
        text: l10n.connectionCaCheckFailed(_origin.authority),
        action: TextButton(
          onPressed: enabled
              ? () => unawaited(
                  _save(
                    () => _profiles.trustCaCertificate(
                      _origin,
                      fileName: fileName,
                      pem: pem,
                    ),
                  ),
                )
              : null,
          child: Text(l10n.connectionCaSaveAnyway),
        ),
      ),
    };
  }

  List<Widget> _review(
    BuildContext context,
    NetworkProfile profile,
    CertificateInfo probed,
  ) {
    final l10n = context.l10n;
    final pin = profile.pin!;
    final mismatch = profile.lastPinMismatch;
    final enabled = !_busy;
    final sameAsPin = probed.sha256 == pin.sha256;
    final sameAsRecorded = mismatch?.sha256 == probed.sha256;
    final comparison = switch ((sameAsPin, mismatch)) {
      (true, _) => l10n.connectionReviewMatchesTrusted,
      (false, null) => l10n.connectionPinMismatchExplanation(_origin.authority),
      (false, _?) when sameAsRecorded => l10n.connectionReviewSame,
      (false, _?) => l10n.connectionReviewDiffers,
    };
    final accept = sameAsPin
        ? null
        : (mismatch == null || sameAsRecorded
              ? FilledButton.icon(
                  onPressed: enabled ? () => unawaited(_trust(probed)) : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(l10n.connectionReviewAccept),
                )
              // A third certificate since the change: nothing preselected.
              : OutlinedButton.icon(
                  onPressed: enabled ? () => unawaited(_trust(probed)) : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(l10n.connectionReviewAccept),
                ));
    final keep = sameAsPin
        ? FilledButton(
            onPressed: enabled ? () => unawaited(_keepCurrent()) : null,
            child: Text(l10n.connectionReviewKeep),
          )
        : OutlinedButton(
            onPressed: enabled ? () => unawaited(_keepCurrent()) : null,
            child: Text(l10n.connectionReviewKeep),
          );
    return [
      ..._reviewDetails(context, profile, probed: probed),
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        child: ListNote(
          icon: sameAsPin || sameAsRecorded
              ? Icons.info_outline
              : Icons.warning_amber_outlined,
          text: comparison,
        ),
      ),
      const SizedBox(height: 16),
      const _CompareHint(),
      const SizedBox(height: 24),
      if (mismatch != null && !sameAsRecorded && !sameAsPin) ...[
        keep,
        const SizedBox(height: 8),
        ?accept,
      ] else ...[
        ?accept,
        if (accept != null) const SizedBox(height: 8),
        keep,
      ],
    ];
  }

  List<Widget> _reviewDetails(
    BuildContext context,
    NetworkProfile profile, {
    required CertificateInfo? probed,
  }) {
    final l10n = context.l10n;
    final pin = profile.pin!;
    final mismatch = profile.lastPinMismatch;
    return [
      _Heading(l10n.connectionPinnedTitle),
      Text(
        l10n.connectionPinnedSince(formatConnectionDate(l10n, pin.trustedAt)),
      ),
      const SizedBox(height: 8),
      _CertificateDetails(certificate: pin.certificate, copyable: false),
      if (mismatch != null) ...[
        const SizedBox(height: 24),
        _Heading(
          l10n.connectionReviewRecorded(
            formatConnectionDate(l10n, mismatch.seenAt),
          ),
        ),
        const SizedBox(height: 8),
        _CertificateDetails(certificate: mismatch.certificate, copyable: false),
      ],
      if (probed != null) ...[
        const SizedBox(height: 24),
        _Heading(l10n.connectionReviewProbed),
        const SizedBox(height: 8),
        _CertificateDetails(certificate: probed),
      ] else if (mismatch != null) ...[
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _busy ? null : () => unawaited(_keepCurrent()),
          child: Text(l10n.connectionReviewKeep),
        ),
      ],
    ];
  }
}

sealed class _CaOutcome {
  const new();
}

final class _CaMessage extends _CaOutcome {
  const new(this.text);

  final String text;
}

final class _CaLeafNotTrusted extends _CaOutcome {
  const new(this.leaf);

  final CertificateInfo leaf;
}

/// The server could not be reached to check the file against it.
final class _CaUnchecked extends _CaOutcome {
  const new({required this.fileName, required this.pem});

  final String fileName;
  final String pem;
}

class _Heading extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// Validity warnings, the fingerprint, subject, issuer and validity.
class _CertificateDetails extends ConsumerWidget {
  const new({required this.certificate, this.copyable = true});

  final CertificateInfo certificate;
  final bool copyable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(clockProvider)();
    final warning = certificate.isExpiredAt(now)
        ? l10n.connectionCertificateExpired
        : certificate.isNotYetValidAt(now)
        ? l10n.connectionCertificateNotYetValid
        : null;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warning != null) ...[
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.warning_amber_outlined,
                    color: colors.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        FingerprintView(pairs: certificate.sha256Pairs, copyable: copyable),
        const SizedBox(height: 12),
        Text(l10n.connectionIssuedTo, style: labelStyle),
        Text(certificate.subject),
        const SizedBox(height: 8),
        Text(l10n.connectionIssuedBy, style: labelStyle),
        Text(
          certificate.selfSigned
              ? '${certificate.issuer} · ${l10n.connectionSelfSigned}'
              : certificate.issuer,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.connectionValidity(
            formatConnectionDate(l10n, certificate.notBefore),
            formatConnectionDate(l10n, certificate.notAfter),
          ),
        ),
      ],
    );
  }
}

class _CompareHint extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.connectionCompareHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              _fingerprintCommand,
              style: theme.textTheme.bodyMedium?.merge(AppTheme.monospace),
            ),
          ),
        ),
      ],
    );
  }
}

/// The outcome of choosing a CA file, announced as it appears.
class _OutcomeCard extends StatelessWidget {
  const new({required this.text, this.extra, this.action});

  final String text;
  final Widget? extra;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.filled(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
            if (extra case final extra?) ...[const SizedBox(height: 12), extra],
            if (action case final action?)
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        ),
      ),
    );
  }
}
