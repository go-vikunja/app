import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/inbox/application/inbox_providers.dart';

/// The bell beside the Overview's greeting, with the unread count; opens
/// the inbox over the shell.
class InboxButton extends ConsumerWidget {
  const new({super.key});

  static const maxBadgeTextScale = 1.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unread =
        ref.watch(unreadActivityCountProvider).unwrapPrevious().value ?? 0;
    void open() => unawaited(GoRouter.of(context).push(AppRoutes.inbox));
    return Semantics(
      container: true,
      button: true,
      label: l10n.inboxButton(unread),
      onTap: open,
      excludeSemantics: true,
      child: IconButton(
        onPressed: open,
        tooltip: l10n.inboxTitle,
        icon: Badge(
          isLabelVisible: unread > 0,
          // Like the tab bar's labels; the button's label speaks the count.
          label: MediaQuery.withClampedTextScaling(
            maxScaleFactor: maxBadgeTextScale,
            child: Text(unread > 99 ? '99+' : '$unread'),
          ),
          child: Icon(
            unread > 0 ? Icons.notifications : Icons.notifications_none,
          ),
        ),
      ),
    );
  }
}
