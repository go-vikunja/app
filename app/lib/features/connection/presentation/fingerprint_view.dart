import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/platform/copy_confirmation.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';

final _log = Logger('Fingerprint');

/// A certificate's SHA-256 as 32 hex pairs, four to a row, the way users
/// compare it with `openssl` or a browser. It is no secret: selectable and
/// copied with the plain clipboard, colon-separated like `openssl` prints
/// it.
class FingerprintView extends ConsumerWidget {
  const new({required this.pairs, this.copyable = true, super.key});

  final List<String> pairs;
  final bool copyable;

  static const _pairsPerRow = 4;

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final systemConfirms = ref.read(systemConfirmsCopiesProvider.future);
    try {
      await Clipboard.setData(ClipboardData(text: pairs.join(':')));
    } on Object catch (error) {
      _log.info('Copying the fingerprint failed: ${error.runtimeType}');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.copyToClipboardFailed)));
      return;
    }
    final confirmed = await systemConfirms;
    if (!context.mounted) return;
    unawaited(HapticFeedback.selectionClick());
    if (confirmed) {
      announce(context, l10n.copiedToClipboard);
    } else {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rows = [
      for (var i = 0; i < pairs.length; i += _pairsPerRow)
        pairs.skip(i).take(_pairsPerRow).join(' '),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.connectionFingerprintLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          container: true,
          label: '${l10n.connectionFingerprintLabel}: ${pairs.join(' ')}',
          excludeSemantics: true,
          child: SelectableText(
            rows.join('\n'),
            style: theme.textTheme.titleMedium?.merge(AppTheme.monospace),
          ),
        ),
        if (copyable)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => unawaited(_copy(context, ref)),
              icon: const Icon(Icons.copy),
              label: Text(l10n.connectionCopyFingerprint),
            ),
          ),
      ],
    );
  }
}
