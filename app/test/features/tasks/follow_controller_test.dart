import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';

void main() {
  const own = Subscription(entity: SubscriptionEntity.task, entityId: 5);
  const inherited = Subscription(
    entity: SubscriptionEntity.project,
    entityId: 1,
  );

  test('a slower earlier load does not overwrite a later one', () async {
    final answers = <int, Completer<Subscription?>>{
      5: Completer(),
      6: Completer(),
    };
    final controller = FollowController(
      entity: SubscriptionEntity.task,
      read: (id) => answers[id]!.future,
      write: (id, {required subscribed}) async => null,
    );
    addTearDown(controller.dispose);

    final first = controller.load(5);
    final second = controller.load(6);
    answers[6]!.complete(null);
    await second;
    answers[5]!.complete(own);
    await first;

    expect(controller.id, 6);
    expect(
      controller.value,
      isA<FollowKnown>().having((s) => s.subscription, 'subscription', isNull),
    );
  });

  test('tells its own subscription from an inherited one', () async {
    final controller = FollowController(
      entity: SubscriptionEntity.task,
      read: (id) async => own,
      write: (id, {required subscribed}) async => null,
    );
    addTearDown(controller.dispose);
    await controller.load(5);

    expect(controller.inherits(own), isFalse);
    expect(controller.inherits(inherited), isTrue);
    expect(
      controller.inherits(
        const Subscription(entity: SubscriptionEntity.project, entityId: 5),
      ),
      isTrue,
    );
  });

  test('a failed write returns the failure and keeps the state', () async {
    final controller = FollowController(
      entity: SubscriptionEntity.task,
      read: (id) async => null,
      write: (id, {required subscribed}) async =>
          throw const NetworkFailure(NetworkProblem.unreachable),
    );
    addTearDown(controller.dispose);
    await controller.load(5);

    final failure = await controller.setFollowing(following: true);

    expect(failure, isA<NetworkFailure>());
    expect(
      controller.value,
      isA<FollowKnown>()
          .having((s) => s.following, 'following', isFalse)
          .having((s) => s.saving, 'saving', isFalse),
    );
  });

  test('a failed load keeps the failure for the hint', () async {
    final controller = FollowController(
      entity: SubscriptionEntity.project,
      read: (id) async => throw const Forbidden(),
      write: (id, {required subscribed}) async => null,
    );
    addTearDown(controller.dispose);

    await controller.load(3);

    expect(
      controller.value,
      isA<FollowUnknown>()
          .having((s) => s.loading, 'loading', isFalse)
          .having((s) => s.failure, 'failure', isA<Forbidden>()),
    );
    expect(await controller.setFollowing(following: true), isNull);
  });

  test('nothing is set after dispose', () async {
    final answer = Completer<Subscription?>();
    final controller = FollowController(
      entity: SubscriptionEntity.task,
      read: (id) => answer.future,
      write: (id, {required subscribed}) async => null,
    );
    final load = controller.load(5);
    controller.dispose();
    answer.complete(own);

    await expectLater(load, completes);
  });
}
