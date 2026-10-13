import 'package:meta/meta.dart';

enum SubscriptionEntity {
  project('project'),
  task('task');

  new(this.wireName);

  final String wireName;

  static SubscriptionEntity? fromWire(Object? name) =>
      values.where((entity) => entity.wireName == name).firstOrNull;
}

/// The user's subscription that covers a task or project: its own, or one
/// inherited from a parent project ([entity] and [entityId] then name that
/// project). Null on the reads means not subscribed.
@immutable
final class Subscription {
  const new({required this.entity, required this.entityId});

  final SubscriptionEntity entity;
  final int entityId;

  @override
  bool operator ==(Object other) =>
      other is Subscription &&
      other.entity == entity &&
      other.entityId == entityId;

  @override
  int get hashCode => Object.hash(entity, entityId);
}
