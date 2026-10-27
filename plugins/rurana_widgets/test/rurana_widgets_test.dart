import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rurana_widgets/rurana_widgets.dart';

const _account = '0123456789abcdef0123456789abcdef';
const _other = 'fedcba9876543210fedcba9876543210';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(RuranaWidgets.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory temp;
  late Directory files;
  late Directory widgetsRoot;
  late List<MethodCall> calls;
  late Map<String, Object? Function(MethodCall)> replies;

  void fakeAndroid() {
    replies['directory'] = (_) => {
      'widgets': widgetsRoot.path,
      'files': files.path,
      'appGroup': null,
    };
  }

  void fakeIos() {
    replies['directory'] = (_) => {
      'widgets': widgetsRoot.path,
      'appGroup': temp.path,
    };
  }

  File file(String relative) => File('${widgetsRoot.path}/$relative');

  String action(String id, {String account = _account, int at = 1000}) =>
      jsonEncode({
        'version': 1,
        'id': id,
        'accountId': account,
        'taskId': 7,
        'createdAt': at,
      });

  setUp(() {
    temp = Directory.systemTemp.createTempSync('rurana_widgets_test');
    files = Directory('${temp.path}/files')..createSync();
    widgetsRoot = Directory('${files.path}/widgets');
    calls = [];
    replies = {};
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final reply = replies[call.method];
      if (reply == null) throw MissingPluginException();
      return reply(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    temp.deleteSync(recursive: true);
  });

  group('snapshots and catalogs', () {
    setUp(fakeAndroid);

    test('writes atomically and only when the content changed', () async {
      final widgets = RuranaWidgets();
      const key = '$_account.today';

      expect(await widgets.writeSnapshot(key, '{"a":1}'), isTrue);
      expect(await widgets.writeSnapshot(key, '{"a":1}'), isFalse);
      expect(await widgets.writeSnapshot(key, '{"a":2}'), isTrue);

      expect(file('snapshots/$key.json').readAsStringSync(), '{"a":2}');
      expect(await widgets.readSnapshot(key), '{"a":2}');
      expect(
        Directory('${widgetsRoot.path}/snapshots').listSync(),
        hasLength(1),
        reason: 'no temp file stays behind',
      );
      expect(
        calls.where((call) => call.method == 'directory'),
        hasLength(1),
        reason: 'the directory is asked for once',
      );
    });

    test('lists keys, optionally of one account', () async {
      final widgets = RuranaWidgets();
      await widgets.writeSnapshot('$_account.today', '{}');
      await widgets.writeSnapshot('$_account.project_12', '{}');
      await widgets.writeSnapshot('$_other.today', '{}');
      await widgets.writeSnapshot('$_other.upcoming_7', '{}');
      file('snapshots/$_other.overdue.json.1-2-3.tmp').writeAsStringSync('');

      expect(await widgets.snapshotKeys(), [
        '$_account.project_12',
        '$_account.today',
        '$_other.today',
        '$_other.upcoming_7',
      ]);
      expect(await widgets.snapshotKeys(accountId: _other), [
        '$_other.today',
        '$_other.upcoming_7',
      ]);
      expect(await widgets.snapshotKeys(accountId: _account), [
        '$_account.project_12',
        '$_account.today',
      ]);

      await widgets.deleteSnapshot('$_other.today');
      expect(await widgets.readSnapshot('$_other.today'), isNull);
    });

    test('rejects keys and account ids that are not file-safe', () async {
      final widgets = RuranaWidgets();

      expect(
        () => widgets.writeSnapshot('../escape', '{}'),
        throwsArgumentError,
      );
      expect(() => widgets.writeSnapshot('', '{}'), throwsArgumentError);
      expect(() => widgets.writeCatalog('a/b', '{}'), throwsArgumentError);
    });

    test('writes the catalog and the host file', () async {
      final widgets = RuranaWidgets();

      expect(await widgets.writeCatalog(_account, '{"c":1}'), isTrue);
      expect(await widgets.writeCatalog(_account, '{"c":1}'), isFalse);
      expect(await widgets.readCatalog(_account), '{"c":1}');
      expect(
        await widgets.writeHost(activeAccountId: _account, dynamicColor: false),
        isTrue,
      );
      expect(
        await widgets.writeHost(activeAccountId: _account, dynamicColor: false),
        isFalse,
      );

      expect(file('catalogs/$_account.json').readAsStringSync(), '{"c":1}');
      expect(jsonDecode(file('host.json').readAsStringSync()), {
        'version': 1,
        'activeAccountId': _account,
        'dynamicColor': false,
      });
    });
  });

  group('Android instances', () {
    setUp(fakeAndroid);

    test('reads the placed widgets and their configs', () async {
      replies['configs'] = (_) => [
        {
          'appWidgetId': 4,
          'provider': 'list',
          'config': jsonEncode({
            'version': 1,
            'key': '$_account.today',
            'account': _account,
            'kind': 'today',
          }),
        },
        {'appWidgetId': 5, 'provider': 'list', 'config': null},
        {'appWidgetId': 6, 'provider': 'quickAdd', 'config': '{broken'},
        {'appWidgetId': 7, 'provider': 'other', 'config': null},
      ];

      final instances = await RuranaWidgets().configs();

      expect(instances, [
        const WidgetInstance(
          appWidgetId: 4,
          provider: WidgetProviderKind.list,
          snapshotKey: '$_account.today',
          config: {'account': _account, 'kind': 'today'},
        ),
        const WidgetInstance(appWidgetId: 5, provider: WidgetProviderKind.list),
        const WidgetInstance(
          appWidgetId: 6,
          provider: WidgetProviderKind.quickAdd,
        ),
        const WidgetInstance(
          appWidgetId: 7,
          provider: WidgetProviderKind.unknown,
        ),
      ]);
      expect(instances[1].isConfigured, isFalse);
    });

    test('saves a config in the shared file format', () async {
      final widgets = RuranaWidgets();

      await widgets.saveConfig(
        12,
        snapshotKey: '$_account.upcoming_7',
        config: {'account': _account, 'kind': 'upcoming', 'days': 7},
      );
      await widgets.saveConfig(
        13,
        snapshotKey: null,
        config: {'account': _account, 'kind': 'quickAdd', 'id': null},
      );

      expect(jsonDecode(file('configs/12.json').readAsStringSync()), {
        'version': 1,
        'key': '$_account.upcoming_7',
        'account': _account,
        'kind': 'upcoming',
        'days': 7,
      });
      expect(
        (jsonDecode(file('configs/13.json').readAsStringSync()) as Map)['key'],
        isNull,
      );
      expect(
        () => widgets.saveConfig(1, snapshotKey: null, config: {'key': 'x'}),
        throwsArgumentError,
      );
    });

    test(
      'shows the active account Today on unconfigured list widgets',
      () async {
        replies['configs'] = (_) => [
          {
            'appWidgetId': 4,
            'provider': 'list',
            'config': jsonEncode({'version': 1, 'key': '$_other.overdue'}),
          },
          {'appWidgetId': 5, 'provider': 'list', 'config': null},
          {'appWidgetId': 6, 'provider': 'quickAdd', 'config': null},
        ];
        final widgets = RuranaWidgets();

        expect(await widgets.displayedSnapshotKeys(), {'$_other.overdue'});

        await widgets.writeHost(activeAccountId: _account, dynamicColor: true);
        expect(await widgets.displayedSnapshotKeys(), {
          '$_other.overdue',
          '$_account.today',
        });
      },
    );

    test('asks for refreshes and pins through the channel', () async {
      replies['update'] = (_) => null;
      replies['updateAll'] = (_) => null;
      replies['canRequestPin'] = (_) => true;
      replies['requestPin'] = (call) =>
          (call.arguments as Map)['provider'] == 'quickAdd';
      final widgets = RuranaWidgets();

      await widgets.update(['a.today', 'a.today', 'b.overdue']);
      await widgets.update(const []);
      await widgets.updateAll();

      expect(await widgets.canRequestPin(), isTrue);
      expect(await widgets.requestPin(WidgetProviderKind.quickAdd), isTrue);
      expect(await widgets.requestPin(WidgetProviderKind.list), isFalse);
      replies['requestPin'] = (call) => true;
      await widgets.requestPin(
        WidgetProviderKind.list,
        snapshotKey: 'a.upcoming_7',
        config: {'account': 'a', 'kind': 'upcoming', 'days': 7},
      );
      final pinConfig = (calls.last.arguments as Map)['config'] as String;
      expect(jsonDecode(pinConfig), {
        'version': 1,
        'key': 'a.upcoming_7',
        'account': 'a',
        'kind': 'upcoming',
        'days': 7,
      });
      expect((calls[calls.length - 2].arguments as Map)['config'], isNull);
      expect(
        () => widgets.requestPin(WidgetProviderKind.unknown),
        throwsArgumentError,
      );
      final updates = calls.where((call) => call.method.startsWith('update'));
      expect(updates.map((call) => call.method), ['update', 'updateAll']);
      expect(updates.first.arguments, {
        'keys': ['a.today', 'b.overdue'],
      });
    });
  });

  group('actions on Android', () {
    setUp(fakeAndroid);

    File queue() => File('${files.path}/widget_actions.jsonl');
    List<File> claimed() =>
        files
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.claimed'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('claims the queue and keeps entries until they are acked', () async {
      File('${files.path}/widget_actions.0.claimed')
          .writeAsStringSync('${action('left-over', at: 3000)}\n');
      queue().writeAsStringSync(
        '${action('b', at: 2000)}\nnot json\n${action('a')}\n',
      );
      final widgets = RuranaWidgets();

      final taken = await widgets.takeActions();

      expect(taken.map((action) => action.id), ['a', 'b', 'left-over']);
      expect(taken.first.createdAt.isUtc, isTrue);
      expect(queue().existsSync(), isFalse);
      expect(claimed(), hasLength(2));
      expect(
        claimed().expand((file) => file.readAsLinesSync()),
        isNot(contains('not json')),
        reason: 'a malformed line is dropped',
      );
      expect((await widgets.takeActions()).map((action) => action.id), [
        'a',
        'b',
        'left-over',
      ], reason: 'taking twice gives the same entries');

      await widgets.ackActions(['a', 'left-over']);

      expect((await widgets.takeActions()).map((action) => action.id), ['b']);
      expect(claimed(), hasLength(1));
      await widgets.ackActions(['b']);
      expect(claimed(), isEmpty);
      expect(await widgets.takeActions(), isEmpty);
    });

    test('reports a duplicated entry once', () async {
      File('${files.path}/widget_actions.1.claimed')
          .writeAsStringSync('${action('a')}\n');
      queue().writeAsStringSync('${action('a')}\n${action('b')}\n');

      final taken = await RuranaWidgets().takeActions();

      expect(taken.map((action) => action.id), ['a', 'b']);
    });

    test(
      'deleteForAccount drops only that account and keeps configs',
      () async {
        final widgets = RuranaWidgets();
        await widgets.writeSnapshot('$_account.today', '{}');
        await widgets.writeSnapshot('$_account.quick_add', '{}');
        await widgets.writeSnapshot('$_other.today', '{}');
        await widgets.writeCatalog(_account, '{}');
        await widgets.writeCatalog(_other, '{}');
        await widgets.saveConfig(
          3,
          snapshotKey: '$_account.today',
          config: const {},
        );
        queue().writeAsStringSync(
          '${action('mine')}\n${action('theirs', account: _other)}\n',
        );

        await widgets.deleteForAccount(_account);

        expect(await widgets.snapshotKeys(), ['$_other.today']);
        expect(await widgets.readCatalog(_account), isNull);
        expect(await widgets.readCatalog(_other), '{}');
        expect(file('configs/3.json').existsSync(), isTrue);
        expect((await widgets.takeActions()).map((action) => action.id), [
          'theirs',
        ]);
      },
    );
  });

  group('actions on iOS', () {
    setUp(fakeIos);

    File outbox(String name) => file('outbox/$name');

    test('reads the outbox and deletes acked and broken files', () async {
      outbox('x')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
      outbox('B.json').writeAsStringSync(action('B', at: 2000));
      outbox('A.json').writeAsStringSync(action('A'));
      outbox('C.json').writeAsStringSync(action('C', account: _other));
      outbox('broken.json').writeAsStringSync('{"id":');
      outbox('.dat.nosync1.tmp').writeAsStringSync('{');
      final widgets = RuranaWidgets();

      expect(await widgets.appGroupDirectory(), isNotNull);
      final taken = await widgets.takeActions();

      expect(taken.map((action) => action.id), ['A', 'C', 'B']);
      expect(outbox('broken.json').existsSync(), isFalse);

      await widgets.ackActions(['A']);
      expect(outbox('A.json').existsSync(), isFalse);
      expect(outbox('B.json').existsSync(), isTrue);

      await widgets.deleteForAccount(_other);
      expect(outbox('C.json').existsSync(), isFalse);
      expect(outbox('x').existsSync(), isTrue);
      expect(outbox('.dat.nosync1.tmp').existsSync(), isTrue);
    });

    test("takes an outbox file in the extension's shape", () async {
      outbox('D.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '{"accountId":"$_account","createdAt":1793055664207.465,'
          '"id":"D","taskId":-2,"version":1}',
        );

      final taken = await RuranaWidgets().takeActions();

      expect(taken.single.taskId, -2);
      expect(outbox('D.json').existsSync(), isTrue);
    });

    test('displays the keys the extension asked for', () async {
      Directory('${widgetsRoot.path}/requests').createSync(recursive: true);
      file('requests/$_account.label_4').writeAsStringSync('');
      file('requests/not a key').writeAsStringSync('');

      expect(await RuranaWidgets().displayedSnapshotKeys(), {
        '$_account.label_4',
      });
    });
  });

  test('asks for the directory again after a native error', () async {
    var fail = true;
    replies['directory'] = (call) {
      if (fail) throw PlatformException(code: 'failed');
      return {'widgets': widgetsRoot.path, 'files': files.path};
    };
    final widgets = RuranaWidgets();

    await expectLater(
      widgets.widgetsDirectory(),
      throwsA(isA<PlatformException>()),
    );
    fail = false;

    expect((await widgets.widgetsDirectory())?.path, widgetsRoot.path);
  });

  test('gives neutral answers without a native side', () async {
    final widgets = RuranaWidgets();

    expect(await widgets.widgetsDirectory(), isNull);
    expect(await widgets.writeSnapshot('$_account.today', '{}'), isFalse);
    expect(await widgets.readSnapshot('$_account.today'), isNull);
    expect(await widgets.configs(), isEmpty);
    expect(await widgets.displayedSnapshotKeys(), isEmpty);
    expect(await widgets.takeActions(), isEmpty);
    expect(await widgets.canRequestPin(), isFalse);
    expect(await widgets.requestPin(WidgetProviderKind.list), isFalse);
    await widgets.updateAll();
    await widgets.deleteForAccount(_account);
  });

  group('WidgetAction', () {
    test('round-trips through JSON', () {
      final original = WidgetAction(
        id: 'E621E1F8-C36C-495A-93FC-0C247A3E6E5F',
        accountId: _account,
        taskId: -4,
        createdAt: DateTime.utc(2026, 10, 26, 12),
      );

      expect(
        WidgetAction.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
        ),
        original,
      );
      expect(original.toJson()['version'], 1);
    });

    test('reads fractional milliseconds as Foundation writes them', () {
      final action = WidgetAction.fromJson(const {
        'version': 1,
        'id': 'a',
        'accountId': _account,
        'taskId': 3,
        'createdAt': 1793055664207.465,
      });

      expect(action.createdAt.millisecondsSinceEpoch, 1793055664207);
    });

    test('rejects an incomplete entry', () {
      expect(
        () => WidgetAction.fromJson(const {'id': 'a', 'taskId': 1}),
        throwsFormatException,
      );
      expect(
        () => WidgetAction.fromJson(const {
          'id': '',
          'accountId': _account,
          'taskId': 1,
          'createdAt': 0,
        }),
        throwsFormatException,
      );
    });
  });
}
