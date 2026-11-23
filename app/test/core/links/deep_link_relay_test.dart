import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/links/deep_link_providers.dart';
import 'package:vikunja_mobile/core/links/deep_link_relay.dart';

void main() {
  const scheme = 'vikunja-io.vikunja.app';
  final taskLink = Uri.parse('$scheme://task/12');
  final identifierLink = Uri.parse('$scheme://task/PROJ-12?account=abc');
  final oauthCallback = Uri.parse('$scheme://oauth/callback?code=x&state=y');
  final widgetLink = Uri.parse('$scheme://widget/task/12?account=abc');

  group('the start link', () {
    test('is a task link of the default route, answered once', () async {
      final relay = DeepLinkRelay(defaultRouteName: () => '$identifierLink');

      expect(await relay.initialLink(), identifierLink);
      expect(await relay.initialLink(), isNull);
    });

    test('is none for a route, a sign-in callback, another scheme or '
        'another host', () async {
      for (final route in [
        '/',
        '/home/tasks/12/edit',
        '$oauthCallback',
        'https://vikunja.example.com/tasks/12',
        '$scheme://project/3',
        '$widgetLink',
        '',
      ]) {
        final relay = DeepLinkRelay(defaultRouteName: () => route);
        expect(await relay.initialLink(), isNull, reason: route);
      }
    });

    testWidgets('comes from the platform dispatcher by default', (
      tester,
    ) async {
      tester.platformDispatcher.defaultRouteNameTestValue = '$taskLink';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final source = container.read(deepLinkSourceProvider);

      expect(source, same(container.read(deepLinkRelayProvider)));
      expect(await source.initialLink(), taskLink);
      expect(await source.initialLink(), isNull);
      expect(
        await container.read(widgetLinkSourceProvider).initialLink(),
        isNull,
      );
    });

    test('of a widget goes to the widget links only, once', () async {
      final relay = DeepLinkRelay(defaultRouteName: () => '$widgetLink');

      expect(await relay.initialLink(), isNull);
      expect(await relay.widgetLinks.initialLink(), widgetLink);
      expect(await relay.widgetLinks.initialLink(), isNull);
    });

    test('is replaced by a task or widget link that arrives before it is '
        'read, on either host', () async {
      for (final (start, arrives) in [
        (widgetLink, taskLink),
        (taskLink, widgetLink),
        (taskLink, identifierLink),
      ]) {
        final relay = DeepLinkRelay(defaultRouteName: () => '$start');
        addTearDown(relay.dispose);

        relay.accept(arrives);

        expect(await relay.initialLink(), isNull, reason: '$start');
        expect(await relay.widgetLinks.initialLink(), isNull, reason: '$start');
      }
    });

    test(
      'stays when a sign-in callback or another host arrives first',
      () async {
        final relay = DeepLinkRelay(defaultRouteName: () => '$taskLink');
        addTearDown(relay.dispose);

        relay
          ..accept(oauthCallback)
          ..accept(Uri.parse('$scheme://project/3'));

        expect(await relay.initialLink(), taskLink);
      },
    );
  });

  group('links while the app runs', () {
    late DeepLinkRelay relay;
    late List<Uri> received;
    StreamSubscription<Uri>? subscription;

    setUp(() {
      relay = DeepLinkRelay(defaultRouteName: () => '/');
      received = [];
      addTearDown(() async {
        await subscription?.cancel();
        await relay.dispose();
      });
    });

    void listen() => subscription = relay.links.listen(received.add);

    test('task links of the scheme are taken and passed on', () async {
      listen();

      expect(relay.accept(taskLink), isTrue);
      expect(relay.accept(identifierLink), isTrue);
      expect(
        relay.accept(Uri.parse('VIKUNJA-IO.Vikunja.APP://Task/7')),
        isTrue,
      );
      await pumpEventQueue();

      expect(received, [
        taskLink,
        identifierLink,
        Uri.parse('$scheme://task/7'),
      ]);
    });

    test('a sign-in callback and other hosts of the scheme are taken but '
        'dropped', () async {
      listen();

      expect(relay.accept(oauthCallback), isTrue);
      expect(relay.accept(Uri.parse('$scheme://project/3')), isTrue);
      expect(relay.accept(Uri.parse('$scheme:task/3')), isTrue);
      await pumpEventQueue();

      expect(received, isEmpty);
    });

    test(
      'widget links are taken and passed on to their own listeners',
      () async {
        final widgetReceived = <Uri>[];
        final widgetSubscription = relay.widgetLinks.links.listen(
          widgetReceived.add,
        );
        addTearDown(widgetSubscription.cancel);
        listen();

        expect(relay.accept(widgetLink), isTrue);
        expect(relay.accept(taskLink), isTrue);
        expect(relay.accept(Uri.parse('$scheme://Widget/open')), isTrue);
        await pumpEventQueue();

        expect(received, [taskLink]);
        expect(widgetReceived, [
          widgetLink,
          Uri.parse('$scheme://widget/open'),
        ]);
      },
    );

    test('a widget link that arrives before anyone listens waits for the '
        'first widget listener', () async {
      relay.accept(widgetLink);
      listen();
      await pumpEventQueue();
      expect(received, isEmpty);

      final widgetReceived = <Uri>[];
      final widgetSubscription = relay.widgetLinks.links.listen(
        widgetReceived.add,
      );
      addTearDown(widgetSubscription.cancel);
      await pumpEventQueue();

      expect(widgetReceived, [widgetLink]);
    });

    test('routes and other schemes are left to the router', () async {
      listen();

      for (final uri in [
        Uri.parse('/home'),
        Uri.parse('/home/tasks/12/edit'),
        Uri.parse('https://vikunja.example.com/tasks/12'),
        Uri.parse('vikunja-other://task/12'),
      ]) {
        expect(relay.accept(uri), isFalse, reason: '$uri');
      }
      await pumpEventQueue();

      expect(received, isEmpty);
    });

    test('a link that arrives before anyone listens waits for the first '
        'listener', () async {
      relay
        ..accept(taskLink)
        ..accept(identifierLink);
      listen();
      await pumpEventQueue();

      expect(received, [taskLink, identifierLink]);
    });
  });
}
