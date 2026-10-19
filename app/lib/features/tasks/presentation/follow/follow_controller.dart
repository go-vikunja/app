import 'dart:async';

import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

final _log = Logger('Follow');

sealed class FollowState {
  const new();
}

/// Not loaded, loading, or the load failed (offline included).
final class FollowUnknown extends FollowState {
  const new({this.loading = false, this.failure});

  final bool loading;
  final Object? failure;
}

final class FollowKnown extends FollowState {
  const new(this.subscription, {this.saving = false});

  /// Null when the user does not follow.
  final Subscription? subscription;
  final bool saving;

  bool get following => subscription != null;
}

typedef SubscriptionReader = Future<Subscription?> Function(int id);
typedef SubscriptionWriter = Future<Subscription?> Function(
  int id, {
  required bool subscribed,
});

/// Whether the user follows one task or project, as the server says: the
/// state only comes with a single read, so it is loaded when the screen
/// opens and written straight through.
final class FollowController extends ValueNotifier<FollowState> {
  new({required this.entity, required this._read, required this._write})
    : super(const FollowUnknown());

  final SubscriptionEntity entity;
  final SubscriptionReader _read;
  final SubscriptionWriter _write;
  int? _id;
  int _generation = 0;
  bool _disposed = false;

  int? get id => _id;

  /// True when [subscription] covers the entity through a parent project.
  bool inherits(Subscription subscription) =>
      subscription.entity != entity || subscription.entityId != _id;

  /// Reads the state, or takes it from [pending] when another read of the
  /// entity carries it, like the detail sheet's.
  Future<void> load(int id, {Future<Subscription?>? pending}) async {
    _id = id;
    final generation = ++_generation;
    _set(const FollowUnknown(loading: true));
    try {
      final subscription = await (pending ?? _read(id));
      if (generation == _generation) _set(FollowKnown(subscription));
    } on Object catch (error) {
      _log.fine('Loading the subscription failed: ${error.runtimeType}');
      if (generation == _generation) _set(FollowUnknown(failure: error));
    }
  }

  /// Null on success, else the failure, and the state stays as it was.
  Future<Object?> setFollowing({required bool following}) async {
    final (id, current) = (_id, value);
    if (id == null || current is! FollowKnown || current.saving) return null;
    final generation = ++_generation;
    _set(FollowKnown(current.subscription, saving: true));
    try {
      final subscription = await _write(id, subscribed: following);
      if (generation == _generation) _set(FollowKnown(subscription));
      return null;
    } on Object catch (error) {
      _log.warning('Changing the subscription failed: ${error.runtimeType}');
      if (generation == _generation) _set(current);
      return error;
    }
  }

  void _set(FollowState state) {
    if (!_disposed) value = state;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String followFailureText(AppLocalizations l10n, Object? failure) =>
    switch (failure) {
      NetworkFailure() || null => l10n.followNeedsConnection,
      TaskNotSyncedYet() => l10n.followTaskOnceSynced,
      _ => l10n.followFailed,
    };

/// Unfollowing a subscription inherited from [projectTitle] only opts this
/// task or project out, so the user is asked first.
Future<bool> confirmStopFollowingInherited(
  BuildContext context, {
  required SubscriptionEntity entity,
  required String projectTitle,
}) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: switch (entity) {
      SubscriptionEntity.task => l10n.followInheritedTaskTitle,
      SubscriptionEntity.project => l10n.followInheritedProjectTitle,
    },
    body: switch (entity) {
      SubscriptionEntity.task => l10n.followInheritedTaskBody(projectTitle),
      SubscriptionEntity.project => l10n.followInheritedProjectBody(
        projectTitle,
      ),
    },
    confirmLabel: l10n.followInheritedConfirm,
  );
}

/// A tap on the follow toggle of [id]: while the state is unknown it loads
/// again and returns why it cannot toggle; an inherited subscription asks
/// before opting out. Returns the message to show, null when there is none.
Future<String?> toggleFollowing(
  BuildContext context,
  FollowController controller, {
  required int id,
  required String Function(int projectId) projectTitle,
}) async {
  final l10n = context.l10n;
  switch (controller.value) {
    case FollowUnknown(loading: true) || FollowKnown(saving: true):
      return null;
    case FollowUnknown(:final failure):
      unawaited(controller.load(id));
      return followFailureText(l10n, failure);
    case FollowKnown(:final subscription?)
        when controller.inherits(subscription):
      final confirmed = await confirmStopFollowingInherited(
        context,
        entity: controller.entity,
        projectTitle: projectTitle(subscription.entityId),
      );
      if (!confirmed) return null;
      final failure = await controller.setFollowing(following: false);
      return failure == null ? null : followFailureText(l10n, failure);
    case FollowKnown(:final following):
      final failure = await controller.setFollowing(following: !following);
      return failure == null ? null : followFailureText(l10n, failure);
  }
}
