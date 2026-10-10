import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/sync/application/sync_status_queries.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';

/// The refresh of a list screen: one at a time, its failure a notice above
/// the stale list or the whole screen while there is no data, and both
/// forgotten when the repository is replaced, i.e. on an account switch. A
/// server that cannot be reached, by a refresh or by the quiet sync at
/// start, is only the offline notice above the saved data.
mixin RefreshableList<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  Object? _refreshFailure;
  bool _refreshing = false;

  bool get refreshing => _refreshing;

  /// The repository the list reads from; a new instance resets the screen.
  ProviderListenable<Object?> get repositoryProvider;

  /// Null when there is nothing to refresh, e.g. without an account.
  Future<void>? startRefresh();

  /// Also resets what the subclass keeps about one account's data.
  @mustCallSuper
  void onRepositoryReplaced() => _refreshFailure = null;

  /// Fails silently: the failure becomes the notice.
  Future<void> refresh() async {
    final load = startRefresh();
    if (load == null) return;
    setState(() {
      _refreshing = true;
      _refreshFailure = null;
    });
    try {
      await load;
    } on Object catch (error) {
      if (mounted) setState(() => _refreshFailure = error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// For the subclass's own `setState`, when the list it showed goes away.
  void clearRefreshFailure() => _refreshFailure = null;

  /// [builder] gets the data and, after a failed refresh or offline, the
  /// notice to show above it.
  Widget buildRefreshable<T>(
    AsyncValue<T> data, {
    required String loadingLabel,
    required Widget Function(T value, Widget? notice) builder,
  }) {
    ref.listen(repositoryProvider, (_, _) => setState(onRepositoryReplaced));
    final offline = ref.watch(
      syncStatusProvider.select((status) => isOffline(status.value)),
    );
    return RefreshIndicator.adaptive(
      onRefresh: refresh,
      child: switch (data) {
        // Loading again after an account switch still carries the old
        // value, which must not show.
        AsyncLoading() => CenteredScrollView(
          child: LoadingPlaceholder(label: loadingLabel),
        ),
        AsyncValue(:final value?) => builder(value, switch (_refreshFailure) {
          NetworkFailure() => const OfflineNotice(),
          final failure? => DataFailureCard(
            error: failure,
            stale: true,
            onRetry: refresh,
          ),
          null => offline ? const OfflineNotice() : null,
        }),
        AsyncError(:final error) when !_refreshing => CenteredScrollView(
          child: DataFailureCard(error: error, stale: false, onRetry: refresh),
        ),
        AsyncError() => CenteredScrollView(
          child: LoadingPlaceholder(label: loadingLabel),
        ),
      },
    );
  }
}

/// The app bar's single-tap alternative to pull-to-refresh.
class RefreshButton extends StatelessWidget {
  const new({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: context.l10n.refresh,
    icon: const Icon(Icons.refresh),
  );
}

/// A notice above the rows of a sliver list.
class NoticeSliver extends StatelessWidget {
  const new({required this.notice, super.key});

  final Widget notice;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    sliver: SliverToBoxAdapter(child: notice),
  );
}
