import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/inbox/presentation/activity_texts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';

/// One notification: who did what, the comment for a comment, the task's
/// title and when; bold with a dot while unread.
class InboxRow extends ConsumerWidget {
  const new({
    required this.item,
    required this.now,
    required this.onTap,
    super.key,
  });

  final ActivityItem item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final formatter = MomentFormatter.watch(context, ref);
    final unread = !item.isRead;
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    // Without an identifier the text names the task by its title already.
    final title = item.taskIdentifier != null ? item.taskTitle : null;
    final details = [
      ?title,
      formatter.relative(item.created, now: now),
    ].join(' · ');
    final spokenDetails = switch (formatter.semanticsLabel(item.created)) {
      final created? => [?title, created].join(' · '),
      null => null,
    };

    return ListTile(
      onTap: onTap,
      leading: _ActivityAvatar(item: item),
      title: Text(
        describeInboxRow(l10n, item),
        style: unread ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          if (item.comment case final comment?)
            Text(
              l10n.inboxQuoted(comment),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          Text(details, semanticsLabel: spokenDetails, style: detailStyle),
        ],
      ),
      trailing: unread
          ? Semantics(
              label: l10n.inboxUnread,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

/// The doer's initials with the kind's icon on its edge; the icon alone
/// for a notification without a doer (the server's reminder).
class _ActivityAvatar extends StatelessWidget {
  const new({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The icon's ring takes the colour of what lies below: a card's or the
    // screen's.
    final ring = switch (Material.maybeOf(context)?.color) {
      final Color color when color.a > 0 => color,
      _ => colors.surface,
    };
    final icon = activityIcon(item.kind);
    final doer = item.doerName;
    if (doer == null) {
      return ExcludeSemantics(
        child: CircleAvatar(
          radius: 20,
          backgroundColor: colors.secondaryContainer,
          child: Icon(icon, size: 20, color: colors.onSecondaryContainer),
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            InitialsAvatar(name: doer, radius: 20),
            PositionedDirectional(
              end: -4,
              bottom: -4,
              child: DecoratedBox(
                decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(icon, size: 14, color: colors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
