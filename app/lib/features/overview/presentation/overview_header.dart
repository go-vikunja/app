import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_button.dart';
import 'package:vikunja_mobile/features/common/presentation/search_pill.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_button.dart';

/// The top of the Overview in place of an app bar: the search bar with the
/// account button, then the date, a greeting, how many tasks are left for
/// today ([tasksLeft], left out while unknown) and the inbox's bell, which
/// a link-share guest has not.
class OverviewHeader extends StatelessWidget {
  const new({
    required this.now,
    required this.tasksLeft,
    required this.onRefresh,
    super.key,
  });

  final DateTime now;
  final int? tasksLeft;

  /// For screen readers, which cannot pull the list; null while a refresh
  /// runs.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SearchPill(
        hint: context.l10n.search,
        onTap: () => unawaited(GoRouter.of(context).push(AppRoutes.search)),
        trailing: const AccountSwitcherButton(),
      ),
      const SizedBox(height: 20),
      _Greeting(now: now, tasksLeft: tasksLeft, onRefresh: onRefresh),
    ],
  );
}

class _Greeting extends ConsumerWidget {
  const new({
    required this.now,
    required this.tasksLeft,
    required this.onRefresh,
  });

  final DateTime now;
  final int? tasksLeft;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final name =
        ref.watch(
          accountsProvider.select(
            (accounts) => accounts.value?.activeAccount?.account.displayName,
          ),
        ) ??
        '';
    // A guest has no name of its own, and the server keeps no
    // notifications for it.
    final guest = ref.watch(activeAccountIsGuestProvider);
    final local = now.toLocal();
    final greeting = switch ((local.hour, guest)) {
      (>= 5 && < 12, true) => l10n.overviewGreetingMorningGuest,
      (>= 12 && < 18, true) => l10n.overviewGreetingAfternoonGuest,
      (_, true) => l10n.overviewGreetingEveningGuest,
      (>= 5 && < 12, false) => l10n.overviewGreetingMorning(name),
      (>= 12 && < 18, false) => l10n.overviewGreetingAfternoon(name),
      (_, false) => l10n.overviewGreetingEvening(name),
    };
    final tasksLeft = this.tasksLeft;
    final onRefresh = this.onRefresh;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      // The bell at the top: at large text the greeting runs long, and the
      // floating button would cover a bell at its end.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MergeSemantics(
              // The heading and the route's name, as an app bar's title
              // is on the other tabs.
              child: Semantics(
                label: l10n.tabOverview,
                header: true,
                headingLevel: 1,
                namesRoute: switch (theme.platform) {
                  TargetPlatform.iOS || TargetPlatform.macOS => null,
                  _ => true,
                },
                customSemanticsActions: onRefresh == null
                    ? null
                    : {CustomSemanticsAction(label: l10n.refresh): onRefresh},
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      intl.DateFormat.MMMMEEEEd(l10n.localeName).format(local),
                      style: muted,
                    ),
                    Text(greeting, style: theme.textTheme.headlineMedium),
                    if (tasksLeft != null)
                      Text(
                        l10n.overviewTasksLeftToday(tasksLeft),
                        style: muted,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!guest) const InboxButton(),
        ],
      ),
    );
  }
}
