import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/repositories/local/shared_latest.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late int loads;

  Future<List<String>> names() async {
    loads++;
    return [for (final user in await db.usersDao.loadAll()) user.username];
  }

  Future<void> store(int id, String username) =>
      db.usersDao.upsertAll([User(id: id, username: username)]);

  setUp(() {
    db = testDatabase();
    loads = 0;
  });

  group('a paused subscriber', () {
    test('loads nothing per change, then once on resume with the newest '
        'state', () async {
      final seen = <List<String>>[];
      final subscription = db.watchTables({db.users}, names).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      subscription.pause();
      for (final (id, name) in [(1, 'ana'), (2, 'ben'), (3, 'cleo')]) {
        await store(id, name);
        await pumpEventQueue();
      }
      expect(loads, 1);
      expect(seen, [isEmpty]);

      subscription.resume();
      await pumpEventQueue();
      expect(loads, 2);
      expect(seen, [
        isEmpty,
        ['ana', 'ben', 'cleo'],
      ]);
    });

    test('that resumes without a change loads nothing and gets nothing '
        'again', () async {
      final seen = <List<String>>[];
      final subscription = db.watchTables({db.users}, names).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      subscription.pause();
      await pumpEventQueue();
      subscription.resume();
      await pumpEventQueue();

      expect(loads, 1);
      expect(seen, [isEmpty]);
    });

    test('ignores the extra trigger until it resumes', () async {
      final ticks = StreamController<void>.broadcast();
      addTearDown(ticks.close);
      final subscription = db
          .watchTables({db.users}, names, alsoOn: ticks.stream)
          .listen((_) {});
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      subscription.pause();
      for (var i = 0; i < 3; i++) {
        ticks.add(null);
        await pumpEventQueue();
      }
      expect(loads, 1);

      subscription.resume();
      await pumpEventQueue();
      expect(loads, 2);
    });

    test('that cancels loads nothing more', () async {
      final subscription = db.watchTables({db.users}, names).listen((_) {});
      await pumpEventQueue();

      subscription.pause();
      await store(1, 'ana');
      await pumpEventQueue();
      await subscription.cancel();
      await store(2, 'ben');
      await pumpEventQueue();

      expect(loads, 1);
    });
  });

  group('a load that runs when the pause comes', () {
    late List<Completer<int>> gates;
    Future<int> gated() {
      final gate = Completer<int>();
      gates.add(gate);
      return gate.future;
    }

    setUp(() => gates = []);

    test('delivers its value on resume without loading again', () async {
      final seen = <int>[];
      final subscription = db.watchTables({db.users}, gated).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      subscription.pause();
      gates.single.complete(1);
      await pumpEventQueue();
      expect(seen, isEmpty);

      subscription.resume();
      await pumpEventQueue();
      expect(seen, [1]);
      expect(gates, hasLength(1));
    });

    test('delivers its error on resume', () async {
      final errors = <Object>[];
      final subscription = db
          .watchTables({db.users}, gated)
          .listen((_) {}, onError: errors.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      subscription.pause();
      gates.single.completeError(StateError('query failed'));
      await pumpEventQueue();
      expect(errors, isEmpty);

      subscription.resume();
      await pumpEventQueue();
      expect(errors, [isA<StateError>()]);
      expect(gates, hasLength(1));
    });

    test('is dropped for one new load when a change came meanwhile', () async {
      final seen = <int>[];
      final subscription = db.watchTables({db.users}, gated).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      subscription.pause();
      await store(1, 'ana');
      await pumpEventQueue();
      gates.single.complete(1);
      await pumpEventQueue();
      await store(2, 'ben');
      await pumpEventQueue();
      expect(gates, hasLength(1), reason: 'nothing loads while paused');

      subscription.resume();
      await pumpEventQueue();
      expect(gates, hasLength(2));
      gates.last.complete(2);
      await pumpEventQueue();
      expect(seen, [2]);
    });
  });

  group('a list on a hidden tab', () {
    // As go_router's StatefulShellRoute keeps its branches; null is a
    // full-screen page over every tab.
    Widget tabs(ValueNotifier<int?> shown, List<Widget> children) =>
        ProviderScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder<int?>(
              valueListenable: shown,
              builder: (context, index, _) => Stack(
                children: [
                  for (final (i, child) in children.indexed)
                    Offstage(
                      offstage: i != index,
                      child: TickerMode(enabled: i == index, child: child),
                    ),
                ],
              ),
            ),
          ),
        );

    Widget list(String name, StreamProvider<List<String>> provider) => Consumer(
      builder: (context, ref, _) =>
          Text('$name: ${ref.watch(provider).value?.join(',')}'),
    );

    Finder shows(String text) => find.text(text, skipOffstage: false);

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
    }

    testWidgets('loads nothing per write and shows the newest state once '
        'shown again', (tester) async {
      final shown = ValueNotifier<int?>(0);
      addTearDown(shown.dispose);
      final provider = StreamProvider<List<String>>(
        (ref) => db.watchTables({db.users}, names),
      );
      await tester.pumpWidget(tabs(shown, [list('Upcoming', provider)]));
      await settle(tester);
      expect(shows('Upcoming: '), findsOneWidget);
      expect(loads, 1);

      shown.value = null;
      await settle(tester);
      for (final (id, name) in [(1, 'ana'), (2, 'ben'), (3, 'cleo')]) {
        await store(id, name);
        await settle(tester);
      }
      expect(loads, 1);
      expect(shows('Upcoming: '), findsOneWidget);

      shown.value = 0;
      await settle(tester);
      expect(loads, 2);
      expect(shows('Upcoming: ana,ben,cleo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('that shares its query with the shown one gets the newest '
        'state once when shown; under a page neither loads', (tester) async {
      final shown = ValueNotifier<int?>(1);
      addTearDown(shown.dispose);
      final shared = SharedLatest(() => db.watchTables({db.users}, names));
      var upcomingDeliveries = 0;
      final overview = StreamProvider<List<String>>((ref) => shared.stream);
      final upcoming = StreamProvider<List<String>>(
        (ref) => shared.stream.map((names) {
          upcomingDeliveries++;
          return names;
        }),
      );
      await tester.pumpWidget(
        tabs(shown, [list('Overview', overview), list('Upcoming', upcoming)]),
      );
      await settle(tester);
      shown.value = 0;
      await settle(tester);
      expect(shows('Overview: '), findsOneWidget);
      expect(upcomingDeliveries, 1);
      expect(loads, 1);

      for (final (id, name) in [(1, 'ana'), (2, 'ben'), (3, 'cleo')]) {
        await store(id, name);
        await settle(tester);
      }
      expect(loads, 4, reason: 'one load per write for the shown list');
      expect(shows('Overview: ana,ben,cleo'), findsOneWidget);
      expect(shows('Upcoming: '), findsOneWidget);
      expect(upcomingDeliveries, 1);

      shown.value = 1;
      await settle(tester);
      expect(shows('Upcoming: ana,ben,cleo'), findsOneWidget);
      expect(upcomingDeliveries, 2);
      expect(loads, 4);

      shown.value = null;
      await settle(tester);
      await store(4, 'dana');
      await store(5, 'eli');
      await settle(tester);
      expect(loads, 4);

      shown.value = 0;
      await settle(tester);
      expect(loads, 5);
      expect(shows('Overview: ana,ben,cleo,dana,eli'), findsOneWidget);
      expect(shows('Upcoming: ana,ben,cleo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('under a full-screen page loads nothing per write and '
        'once when the page closes', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final provider = StreamProvider<List<String>>(
        (ref) => db.watchTables({db.users}, names),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navigator,
            home: list('Overview', provider),
          ),
        ),
      );
      await settle(tester);
      expect(loads, 1);

      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('Task')),
      );
      await tester.pumpAndSettle();
      await store(1, 'ana');
      await settle(tester);
      await store(2, 'ben');
      await settle(tester);
      expect(loads, 1);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(find.text('Overview: ana,ben'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
