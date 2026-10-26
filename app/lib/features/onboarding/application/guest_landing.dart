import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'guest_landing.g.dart';

/// Where a guest lands after the first sync: the shared project, in the
/// view the link named.
@immutable
final class GuestLanding {
  const new({required this.projectId, this.viewId});

  final int projectId;

  /// Null when the link named none; a view the project lacks is ignored.
  final int? viewId;

  @override
  bool operator ==(Object other) =>
      other is GuestLanding &&
      other.projectId == projectId &&
      other.viewId == viewId;

  @override
  int get hashCode => Object.hash(projectId, viewId);

  @override
  String toString() => 'GuestLanding($projectId, view: $viewId)';
}

/// The landings of links opened in this app run, per guest account; a
/// restart lands on the Overview as usual.
final class GuestLandings {
  final _pending = <String, GuestLanding>{};

  void remember(String accountId, GuestLanding landing) =>
      _pending[accountId] = landing;

  /// The account's landing once; null afterwards.
  GuestLanding? take(String accountId) => _pending.remove(accountId);
}

@Riverpod(keepAlive: true)
GuestLandings guestLandings(Ref ref) => GuestLandings();
