import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/presentation/fingerprint_view.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';

final _log = Logger('BrowserLegHint');

/// What the browser sign-in meets that the app's connection settings do
/// not cover: the browser has its own trust, client certificates and
/// cookies (D65).
@immutable
final class BrowserLegHint {
  const new({this.pinnedFingerprint, this.notes = const []});

  /// The sign-in page's pinned certificate, for comparing in the browser.
  final List<String>? pinnedFingerprint;
  final List<String> notes;

  /// The whole hint as one text, for a dialog that has one already.
  String asText(AppLocalizations l10n) => [
    if (pinnedFingerprint case final pairs?) ...[
      l10n.connectionBrowserHintPinned,
      pairs.join(' '),
    ],
    ...notes,
  ].join('\n\n');
}

/// Null when neither the API's address nor the sign-in page's has a pinned
/// or CA certificate, a client certificate or headers; a permission for
/// http alone needs no hint. The sign-in page is where the authorize
/// request opens: the server's `frontend_url` when usable.
Future<BrowserLegHint?> browserLegHint(
  AppLocalizations l10n,
  NetworkProfiles profiles,
  ServerConnection connection,
) async {
  final apiOrigin = OriginKey.tryOf(connection.rootUri);
  final pageOrigin = OriginKey.tryOf(
    webFrontendBase(
      serverRoot: connection.rootUri,
      frontendUrl: connection.info.frontendUrl,
    ),
  );
  if (apiOrigin == null || pageOrigin == null) return null;
  final api = await _metadata(profiles, apiOrigin);
  final page = pageOrigin == apiOrigin
      ? api
      : await _metadata(profiles, pageOrigin);
  if (!_concernsBrowser(api) && !_concernsBrowser(page)) return null;
  return BrowserLegHint(
    pinnedFingerprint: page?.pin?.certificate.sha256Pairs,
    notes: [
      if (page?.pin == null && page?.caCertificate != null)
        l10n.connectionBrowserHintCa,
      if (api?.clientCertificate != null)
        l10n.connectionBrowserHintClientCertificate,
      if (api?.hasHeaders ?? false) l10n.connectionBrowserHintHeaders,
      if (pageOrigin != apiOrigin)
        l10n.connectionBrowserHintOtherHost(pageOrigin.authority),
    ],
  );
}

bool _concernsBrowser(NetworkProfile? profile) =>
    profile != null &&
    (profile.pin != null ||
        profile.caCertificate != null ||
        profile.clientCertificate != null ||
        profile.hasHeaders);

/// Unreadable settings fail the sign-in's own requests anyway, which then
/// says so; the hint is no place for that.
Future<NetworkProfile?> _metadata(
  NetworkProfiles profiles,
  OriginKey origin,
) async {
  try {
    return await profiles.metadataFor(origin);
  } on Object catch (error) {
    _log.info('No settings for the hint: ${error.runtimeType}');
    return null;
  }
}

/// Before the browser opens for [connection]'s sign-in: the hint, with
/// Continue and Cancel; true at once when there is nothing to say.
Future<bool> confirmBrowserLeg(
  BuildContext context,
  WidgetRef ref,
  ServerConnection connection,
) async {
  final l10n = context.l10n;
  final hint = await browserLegHint(
    l10n,
    ref.read(networkProfilesProvider),
    connection,
  );
  if (hint == null) return true;
  if (!context.mounted) return false;
  final go = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.connectionBrowserHintTitle),
      // A Cupertino dialog has no Material for the selectable fingerprint.
      content: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            if (hint.pinnedFingerprint case final pairs?) ...[
              Text(l10n.connectionBrowserHintPinned),
              FingerprintView(pairs: pairs, copyable: false),
            ],
            for (final note in hint.notes) Text(note),
          ],
        ),
      ),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.connectionBrowserHintContinue),
        ),
      ],
    ),
  );
  return go ?? false;
}

/// "Sign in again" with the browser hint first.
Future<void> signInAgainAfterHint(
  BuildContext context,
  WidgetRef ref,
  RegisteredAccount entry,
) async {
  final controller = ref.read(signInControllerProvider.notifier);
  if (!await confirmBrowserLeg(context, ref, entry.connection)) return;
  if (!context.mounted) return;
  await controller.signInAgain(entry);
}
