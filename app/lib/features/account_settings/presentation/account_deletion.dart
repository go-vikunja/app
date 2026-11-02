import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';

// v2 ignores the server's switch, so the app must respect it.
bool allowsAccountDeletion(ServerConnection connection) =>
    connection.capabilities.has(Capability.userDeletion);

/// Where the server does not allow it, the row stays (App Store guideline
/// 5.1.1(v)) and says who can delete the account instead.
Future<void> explainAccountDeletionNotAllowed(BuildContext context) {
  final l10n = context.l10n;
  return showAdaptiveDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.accountDeletionNotAllowedTitle),
      content: Text(l10n.accountDeletionNotAllowedBody),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.accountDeletionNotAllowedOk),
        ),
      ],
    ),
  );
}

/// What deleting the account means, before the web's page takes over; true
/// for Continue in the browser. [isLocalUser] adds that the web asks for
/// the password.
Future<bool> confirmAccountDeletion(
  BuildContext context, {
  required bool isLocalUser,
}) async {
  final l10n = context.l10n;
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.accountDeletionDialogTitle),
      content: Text(
        [
          l10n.accountDeletionDialogPermanent,
          l10n.accountDeletionDialogEmail,
          l10n.accountDeletionDialogNoEmail,
          if (isLocalUser) l10n.accountSettingsWebAsksPassword,
        ].join('\n\n'),
      ),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: true,
          child: Text(l10n.accountDeletionContinue),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The day and time the server will delete the account, written out.
String deletionDate(MomentFormatter formatter, DateTime moment) =>
    formatter.l10n.momentDateAtTime(
      intl.DateFormat.yMMMMd(formatter.l10n.localeName)
          .format(moment.toLocal()),
      formatter.timeOfDay(moment),
    );

/// The account is scheduled for deletion: an emphasized note with the date
/// and the way to cancel it on the web. A date that has passed does not
/// mean the account is gone: the server's hourly deletion can fail.
class DeletionScheduledNote extends ConsumerWidget {
  const new({
    required this.scheduledAt,
    required this.onCancel,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    super.key,
  });

  final DateTime scheduledAt;
  final VoidCallback onCancel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final formatter = MomentFormatter.watch(context, ref);
    final date = deletionDate(formatter, scheduledAt);
    final overdue = scheduledAt.isBefore(ref.watch(clockProvider)());
    return Padding(
      padding: padding,
      child: Card.filled(
        margin: EdgeInsets.zero,
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.event_busy_outlined,
                        color: colors.onErrorContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        overdue
                            ? l10n.accountDeletionOverdue(date)
                            : l10n.accountDeletionScheduled(date),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onErrorContainer,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.accountDeletionCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
