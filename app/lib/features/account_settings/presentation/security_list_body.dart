import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';

/// A list the page reads from the server each time it opens, with pull to
/// refresh: [header] first, then the failure of the last read with a
/// retry (above the older list when there is one), the loading state, the
/// [empty] note and the [children].
class SecurityListBody extends StatelessWidget {
  const new({
    required this.loading,
    required this.loadingLabel,
    required this.failure,
    required this.hasData,
    required this.onRefresh,
    required this.children,
    this.header,
    this.empty,
    this.footer,
    super.key,
  });

  final bool loading;
  final String loadingLabel;
  final Object? failure;
  final bool hasData;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final Widget? header;
  final Widget? empty;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // An explicit padding replaces the system bars' and cutouts'.
        padding:
            MediaQuery.paddingOf(context) + const EdgeInsets.only(bottom: 32),
        children: [
          ?header,
          if (failure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DataFailureCard(
                error: failure,
                stale: hasData,
                onRetry: () => unawaited(onRefresh()),
              ),
            ),
          if (loading) LoadingPlaceholder(label: loadingLabel),
          ?empty,
          ...children,
          ?footer,
        ],
      ),
    );
  }
}

/// What an empty list says, with an optional way to fill it.
class SecurityEmptyNote extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 40, color: colors.primary)),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (action case final action?) ...[
            const SizedBox(height: 12),
            action,
          ],
        ],
      ),
    );
  }
}
