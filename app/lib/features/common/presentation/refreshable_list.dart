import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/failed_without_token.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_banner.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';

/// The refresh of a list screen: one at a time, its failure a notice above
/// the stale list or the whole screen while there is no data, and both
/// forgotten when the repository is replaced, i.e. on an account switch,
/// or when the subclass says the list it showed went away: a refresh
/// still running then ends unheard. A server that cannot be reached, by a
/// refresh or by a sync, is the shell's offline banner; only a list on a
/// page over the shell, where the banner does not show, puts the offline
/// notice above the saved data. The pull's spinner shows for
/// [spinnerLimit] at most: a refresh still waiting for the server then goes
/// on under the quiet sync bar, with a note above the saved data.
mixin RefreshableList<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  /// A server that takes the connection and never answers would otherwise
  /// keep the spinner up for the timeouts of two sync runs, about 50 s
  /// (a pull waits for the run under way, then runs its own).
  static const spinnerLimit = Duration(seconds: 9);

  Object? _refreshFailure;
  bool _refreshing = false;
  bool _waiting = false;
  int _generation = 0;
  Completer<void>? _spinner;
  Timer? _spinnerTimer;

  bool get refreshing => _refreshing;

  /// The repository the list reads from; a new instance resets the screen.
  ProviderListenable<Object?> get repositoryProvider;

  /// Null when there is nothing to refresh, e.g. without an account.
  Future<void>? startRefresh();

  /// Also resets what the subclass keeps about one account's data.
  @mustCallSuper
  void onRepositoryReplaced() => clearRefreshFailure();

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    super.dispose();
  }

  /// Fails silently: the failure becomes the notice. Ends with the newest
  /// refresh, or [spinnerLimit] after it started while it still runs.
  Future<void> refresh() {
    final load = startRefresh();
    if (load == null) return Future.value();
    final generation = ++_generation;
    setState(() {
      _refreshing = true;
      _waiting = false;
      _refreshFailure = null;
    });
    _spinnerTimer?.cancel();
    _spinnerTimer = null;
    unawaited(_finish(load, generation));
    return _spin();
  }

  Future<void> _finish(Future<void> load, int generation) async {
    try {
      await load;
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _refreshFailure = error);
      }
    } finally {
      if (generation == _generation) _stopSpinner();
      if (mounted && generation == _generation) {
        setState(() {
          _refreshing = false;
          _waiting = false;
        });
      }
    }
  }

  Future<void> _spin() {
    final spinner = _spinner ??= Completer<void>();
    _spinnerTimer ??= Timer(spinnerLimit, () {
      _spinnerTimer = null;
      _spinner?.complete();
      _spinner = null;
      if (mounted && _refreshing) setState(() => _waiting = true);
    });
    return spinner.future;
  }

  void _stopSpinner() {
    _spinnerTimer?.cancel();
    _spinnerTimer = null;
    _spinner?.complete();
    _spinner = null;
  }

  /// For the subclass's own `setState`, when the list it showed goes away:
  /// a refresh of that list still running is no longer this screen's.
  void clearRefreshFailure() {
    _refreshFailure = null;
    _refreshing = false;
    _waiting = false;
    _generation++;
    _stopSpinner();
  }

  /// The failure of the last refresh the user started, while its notice
  /// shows.
  Object? get refreshFailure => _refreshFailure;

  /// [builder] gets the data and, after a failed refresh or offline (on a
  /// page over the shell), the notice to show above it. [header] stays
  /// above the loading and failure states, for controls that must survive
  /// them. [notificationPredicate] picks the scrolls a pull starts from,
  /// e.g. nested ones too. [maxWidth] is the screen's readable width for
  /// the loading and failure states; [builder] applies its own.
  Widget buildRefreshable<T>(
    AsyncValue<T> data, {
    required String loadingLabel,
    required Widget Function(T value, Widget? notice) builder,
    Widget? header,
    double? maxWidth,
    ScrollNotificationPredicate notificationPredicate =
        defaultScrollNotificationPredicate,
  }) {
    ref.listen(repositoryProvider, (_, _) => setState(onRepositoryReplaced));
    final underBanner = OfflineBannerArea.contains(context);
    final offline = ref.watch(offlineProvider) != null;
    return RefreshIndicator.adaptive(
      onRefresh: refresh,
      notificationPredicate: notificationPredicate,
      child: switch (data) {
        // Loading again after an account switch still carries the old
        // value, which must not show.
        AsyncLoading() => CenteredScrollView(
          header: header,
          maxWidth: maxWidth,
          child: LoadingPlaceholder(label: loadingLabel),
        ),
        AsyncValue(:final value?) => builder(value, switch (_refreshFailure) {
          NetworkFailure(
            problem: NetworkProblem(concernsConnectionSettings: false),
          )
              when !failedWithoutToken(_refreshFailure) =>
            underBanner ? null : const OfflineNotice(),
          final failure? => DataFailureCard(
            error: failure,
            stale: true,
            onRetry: refresh,
          ),
          null when offline => underBanner ? null : const OfflineNotice(),
          null when _waiting => const ServerWaitNotice(),
          null => null,
        }),
        AsyncError(:final error) when !_refreshing => CenteredScrollView(
          header: header,
          maxWidth: maxWidth,
          child: DataFailureCard(error: error, stale: false, onRetry: refresh),
        ),
        AsyncError() => CenteredScrollView(
          header: header,
          maxWidth: maxWidth,
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
