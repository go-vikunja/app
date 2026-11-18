import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/about/application/support_details.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';

final _log = Logger('ReleaseErrorWidget');

/// Outside debug builds, which keep Flutter's red screen, a widget that
/// failed to build shows [ReleaseErrorWidget] instead of a grey box.
void installErrorWidget({bool debug = kDebugMode}) {
  if (debug) return;
  final grey = ErrorWidget.builder;
  // A failure while the message itself is built would otherwise nest it
  // without end and hang the app.
  ErrorWidget.builder = (details) => _ReleaseErrorElement._building > 0
      ? grey(details)
      : const ReleaseErrorWidget();
}

/// A short message and Copy support details in place of a widget that
/// failed to build; `FlutterError.onError` has already put the error into
/// the diagnostics log. It may stand in for the app's root, above
/// `MaterialApp`, so it brings the text direction it needs.
class ReleaseErrorWidget extends StatelessWidget {
  const new({super.key});

  @override
  StatelessElement createElement() => _ReleaseErrorElement(this);

  @override
  Widget build(BuildContext context) {
    const box = _ErrorBox();
    if (Directionality.maybeOf(context) != null) return box;
    return const Directionality(textDirection: TextDirection.ltr, child: box);
  }
}

/// Counts while its subtree is built and mounted, which happens within its
/// own rebuild.
final class _ReleaseErrorElement extends StatelessElement {
  new(super.widget);

  static var _building = 0;

  @override
  void performRebuild() {
    _building++;
    try {
      super.performRebuild();
    } finally {
      _building--;
    }
  }
}

class _ErrorBox extends StatefulWidget {
  const new();

  @override
  State<_ErrorBox> createState() => _ErrorBoxState();
}

class _ErrorBoxState extends State<_ErrorBox> {
  var _copying = false;
  String? _outcome;

  AppLocalizations get _l10n =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      appLocalizationsFor(const Locale('en'));

  /// The same text the support details page shares, servers hidden.
  Future<void> _copy() async {
    final l10n = _l10n;
    final announcer = Announcer.of(context);
    final language = Localizations.maybeLocaleOf(context)?.languageCode;
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } on Object {
      container = null;
    }
    setState(() => _copying = true);
    final text = await copyableSupportDetails(
      container,
      appLanguage: language ?? 'unknown',
    );
    String outcome;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      outcome = l10n.copiedToClipboard;
    } on Object catch (error) {
      _log.info('Copying the support details failed: ${error.runtimeType}');
      outcome = l10n.copyToClipboardFailed;
    }
    if (!mounted) return;
    setState(() {
      _copying = false;
      _outcome = outcome;
    });
    announcer.say(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Scaled down rather than cut where the failed widget had little room,
    // and no wider than a phone where it had much.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: colors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.errorWidgetMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _copying ? null : () => unawaited(_copy()),
                    child: Text(l10n.errorWidgetCopySupportDetails),
                  ),
                  if (_outcome case final outcome?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        outcome,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
