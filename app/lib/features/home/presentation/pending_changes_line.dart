import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_message.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';

/// How many changes still wait for the server, with a button that sends
/// them now. Nothing while there are none; no button while every queued
/// change is a sync problem, which only Retry can send.
class PendingChangesLine extends ConsumerStatefulWidget {
  const new({required this.entry, required this.canSend, super.key});

  final RegisteredAccount entry;
  final bool canSend;

  @override
  ConsumerState<PendingChangesLine> createState() => _PendingChangesLineState();
}

class _PendingChangesLineState extends ConsumerState<PendingChangesLine> {
  bool _sending = false;

  /// A failure that still blocks the queue afterwards is shown; the count
  /// and the problems report the rest.
  Future<void> _send() async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    setState(() => _sending = true);
    try {
      final blockedBy = await repository.sendPendingChanges();
      if (blockedBy == null || !mounted) return;
      final l10n = context.l10n;
      final message = describeDataFailure(
        l10n,
        blockedBy,
        serverRoot: widget.entry.connection.rootUri,
        platform: Theme.of(context).platform,
        stale: true,
        guest: widget.entry.account.isLinkShare,
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.accountSendNowFailed(message.explanation)),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(pendingChangesProvider).unwrapPrevious().value ?? 0;
    if (count == 0) return const SizedBox.shrink();
    final problems =
        ref.watch(syncProblemsProvider).unwrapPrevious().value?.length ?? 0;
    final sendable = count > problems;

    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SettingsBlock(
      icon: Icons.cloud_upload_outlined,
      verticalPadding: 4,
      iconTopPadding: 12,
      // The button goes below the text when large text leaves no room.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.accountPendingChanges(count),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (sendable)
            TextButton.icon(
              onPressed: widget.canSend && !_sending
                  ? () => unawaited(_send())
                  : null,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? l10n.accountSending : l10n.accountSendNow),
            ),
        ],
      ),
    );
  }
}
