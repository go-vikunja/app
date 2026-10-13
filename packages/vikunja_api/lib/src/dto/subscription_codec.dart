import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The `subscription` of a single task or project read: null or absent
/// when the user does not follow it.
Subscription? subscriptionOf(Map<String, Object?> entity) {
  final value = entity['subscription'];
  if (value == null) return null;
  final map = objectOf(value, 'subscription');
  return Subscription(
    entity:
        SubscriptionEntity.fromWire(map['entity']) ??
        (throw const MalformedJson('subscription of an unknown entity')),
    entityId: requireInt(map, 'entity_id', 'subscription'),
  );
}
