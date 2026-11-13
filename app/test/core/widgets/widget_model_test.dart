import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/links/widget_link.dart';
import 'package:vikunja_mobile/core/widgets/widget_catalog.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';

void main() {
  const account = '0123456789abcdef0123456789abcdef';

  group('WidgetConfig', () {
    const kinds = <WidgetKind>[
      TodayKind(),
      UpcomingKind(3),
      UpcomingKind(7),
      UpcomingKind(14),
      OverdueKind(),
      ProjectTasksKind(12),
      LabelTasksKind(3),
      FavoritesKind(),
      SavedFilterKind(1),
      QuickAddKind(),
    ];

    test('round-trips every kind through its JSON and its key', () {
      for (final kind in kinds) {
        final config = WidgetConfig(accountId: account, kind: kind);
        expect(WidgetConfig.decode(config.encode()), config);
        expect(WidgetConfig.fromKey(config.key), config, reason: config.key);
      }
    });

    test('writes a versioned JSON with the kind flattened in', () {
      expect(
        const WidgetConfig(accountId: account, kind: UpcomingKind(7)).toJson(),
        {'v': 1, 'account': account, 'kind': 'upcoming', 'days': 7},
      );
      expect(
        const WidgetConfig(
          accountId: account,
          kind: SavedFilterKind(1),
        ).toJson(),
        {'v': 1, 'account': account, 'kind': 'savedFilter', 'id': 1},
      );
    });

    test('keys are safe file names, the account first', () {
      final keys = [
        for (final kind in kinds)
          WidgetConfig(accountId: account, kind: kind).key,
      ];
      expect(keys, [
        '$account.today',
        '$account.upcoming_3',
        '$account.upcoming_7',
        '$account.upcoming_14',
        '$account.overdue',
        '$account.project_12',
        '$account.label_3',
        '$account.favorites',
        '$account.filter_1',
        '$account.quick_add',
      ]);
      for (final key in keys) {
        expect(key, matches(RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$')));
      }
    });

    test('refuses what it cannot read', () {
      for (final json in [
        '{"account":"$account","kind":"upcoming","days":5}',
        '{"account":"$account","kind":"project"}',
        '{"account":"$account","kind":"calendar"}',
        '{"kind":"today"}',
        '[]',
      ]) {
        expect(() => WidgetConfig.decode(json), throwsFormatException);
      }
      for (final key in [
        'today',
        '.today',
        '$account.upcoming_5',
        '$account.project_',
        '$account.project_x',
        '$account.label_-3',
        '$account.board',
      ]) {
        expect(WidgetConfig.fromKey(key), isNull, reason: key);
      }
    });

    test('a saved filter keeps its own id and knows its pseudo project', () {
      expect(const SavedFilterKind(1).pseudoProjectId, -2);
      expect(
        const SavedFilterKind(1).listLink(account),
        const WidgetListLink(
          accountId: account,
          kind: WidgetListKind.savedFilter,
          id: 1,
        ),
      );
      expect(const QuickAddKind().listLink(account), isNull);
    });
  });

  group('WidgetSnapshot', () {
    final generated = DateTime.utc(2026, 10, 26, 9, 30);
    final snapshot = WidgetSnapshot(
      key: '$account.today',
      accountId: account,
      state: WidgetSnapshotState.needsReauth,
      title: 'Today',
      subtitle: 'Alice · vikunja.example.com',
      generatedAt: generated,
      validUntil: DateTime.utc(2026, 10, 26, 23),
      changesAt: [DateTime.utc(2026, 10, 26, 13)],
      rows: [
        WidgetRow(
          taskId: 12,
          title: 'Water the plants',
          dueLabel: 'Today, 14:00',
          dueAt: DateTime.utc(2026, 10, 26, 13),
          tone: WidgetDueTone.today,
          priorityLabel: 'High',
          priorityLevel: 3,
          projectTitle: 'Home',
          projectColor: '1973ff',
          canDone: true,
          semanticsLabel: 'Water the plants',
          doneLabel: 'Mark “Water the plants” done',
          link: 'vikunja-io.vikunja.app://widget/task/12',
        ),
        const WidgetRow(
          taskId: -3,
          title: 'Not sent yet',
          tone: WidgetDueTone.none,
          canDone: false,
          semanticsLabel: 'Not sent yet',
          doneLabel: 'Mark “Not sent yet” done',
          link: 'vikunja-io.vikunja.app://widget/task/-3',
        ),
      ],
      total: 34,
      moreLabel: '+32 more',
      countLabel: '34 tasks',
      empty: const WidgetText('All done', body: 'Nothing is due today.'),
      message: const WidgetText(
        'Signed out by the server',
        action: 'Sign in again',
      ),
      messageLink: 'vikunja-io.vikunja.app://widget/account',
      link: 'vikunja-io.vikunja.app://widget/list',
      newTaskLink: 'vikunja-io.vikunja.app://widget/new-task',
      newTaskLabel: 'New task',
    );

    test('round-trips through its JSON', () {
      expect(WidgetSnapshot.decode(snapshot.encode()), snapshot);
    });

    test('dates are epoch milliseconds and the version comes first', () {
      final json = jsonDecode(snapshot.encode()) as Map<String, Object?>;
      expect(json['v'], 1);
      expect(json['generatedAt'], generated.millisecondsSinceEpoch);
      expect(json['changesAt'], [
        DateTime.utc(2026, 10, 26, 13).millisecondsSinceEpoch,
      ]);
      final rows = json['rows']! as List<Object?>;
      expect((rows.first! as Map)['dueAt'], isA<int>());
      expect(json['more'], 32);
      expect(rows.last, isNot(contains('due')), reason: 'unset is left out');
    });

    test('a reader refuses another version', () {
      final json = jsonDecode(snapshot.encode()) as Map<String, Object?>;
      expect(
        () => WidgetSnapshot.fromJson({...json, 'v': 2}),
        throwsFormatException,
      );
    });

    test('the fingerprint ignores when it was built', () {
      final later = WidgetSnapshot.decode(
        jsonEncode({
          ...jsonDecode(snapshot.encode()) as Map<String, Object?>,
          'generatedAt': generated
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
        }),
      );
      expect(later.contentFingerprint(), snapshot.contentFingerprint());
      expect(later, isNot(snapshot));
    });
  });

  test('a catalog lists its account and lists with their keys', () {
    final catalog = WidgetCatalog(
      account: const WidgetCatalogAccount(
        id: account,
        name: 'Alice',
        host: 'vikunja.example.com',
        isGuest: false,
        supportsV2: true,
      ),
      generatedAt: DateTime.utc(2026, 10, 26),
      canAddTasks: true,
      lists: const [
        WidgetCatalogList(
          config: WidgetConfig(accountId: account, kind: UpcomingKind(3)),
          section: WidgetCatalogSection.smart,
          title: 'Next 3 days',
        ),
        WidgetCatalogList(
          config: WidgetConfig(accountId: account, kind: ProjectTasksKind(7)),
          section: WidgetCatalogSection.project,
          title: 'Garden',
          color: '1973ff',
          writable: false,
          depth: 1,
          parent: 'Home',
        ),
      ],
    );
    expect(jsonDecode(catalog.encode()), {
      'v': 1,
      'generatedAt': DateTime.utc(2026, 10, 26).millisecondsSinceEpoch,
      'account': {
        'id': account,
        'name': 'Alice',
        'host': 'vikunja.example.com',
        'guest': false,
        'v2': true,
      },
      'canAddTasks': true,
      'quickAddKey': '$account.quick_add',
      'lists': [
        {
          'key': '$account.upcoming_3',
          'kind': 'upcoming',
          'days': 3,
          'section': 'smart',
          'title': 'Next 3 days',
        },
        {
          'key': '$account.project_7',
          'kind': 'project',
          'id': 7,
          'section': 'project',
          'title': 'Garden',
          'color': '1973ff',
          'writable': false,
          'depth': 1,
          'parent': 'Home',
        },
      ],
    });
  });
}
