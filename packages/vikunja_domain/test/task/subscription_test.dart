import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('entities by wire name', () {
    expect(SubscriptionEntity.fromWire('task'), SubscriptionEntity.task);
    expect(SubscriptionEntity.fromWire('project'), SubscriptionEntity.project);
    expect(SubscriptionEntity.fromWire('namespace'), isNull);
    expect(SubscriptionEntity.fromWire(2), isNull);
    expect(SubscriptionEntity.fromWire(null), isNull);
  });

  test('subscriptions are equal by entity and id', () {
    const own = Subscription(entity: SubscriptionEntity.task, entityId: 5);

    expect(
      own,
      const Subscription(entity: SubscriptionEntity.task, entityId: 5),
    );
    expect(
      own.hashCode,
      const Subscription(entity: SubscriptionEntity.task, entityId: 5).hashCode,
    );
    expect(
      own,
      isNot(
        const Subscription(entity: SubscriptionEntity.project, entityId: 5),
      ),
    );
    expect(
      own,
      isNot(const Subscription(entity: SubscriptionEntity.task, entityId: 6)),
    );
  });
}
