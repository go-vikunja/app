import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_user_settings_fixtures.dart from
// one user (id 898) whose frontend settings carry keys other clients wrote:
// play_sound_when_done, sidebar_width and rurana_unknown_key.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const Map<String, Object?> _foreignKeys = {
  'play_sound_when_done': false,
  'sidebar_width': 320,
  'rurana_unknown_key': {
    'nested': [1, 2],
  },
};

/// 2.7.0 merge-patches; 2.6.0 and v1 replace the settings whole.
UserSettingsWritePort _port(Dio dio, {String version = '2.7.0'}) {
  final hasV2 = version != 'v1';
  final info = ServerInfo(
    version: ServerVersion.tryParse(hasV2 ? version : '2.3.0'),
  );
  final apiVersions = {ApiVersion.v1, if (hasV2) ApiVersion.v2};
  return createUserSettingsWritePort(
    dio: dio,
    connection: ServerConnection(
      rootUri: Uri.parse(testServerRoot),
      apiVersions: apiVersions,
      info: info,
      capabilities: ServerCapabilities.derive(
        info: info,
        apiVersions: apiVersions,
      ),
    ),
  );
}

FakeRoute _captured(String name) =>
    capturedFixture('user_settings/${name}_2.7.0');

Object? _sent(String name) =>
    fixtureJson('user_settings/${name}_2.7.0.json')['sent'];

Map<String, Object?> _storedSettings(String name) {
  final body = jsonDecode(
    fixtureJson('user_settings/${name}_2.7.0.json')['body']! as String,
  );
  return (body as Map<String, Object?>)['settings']! as Map<String, Object?>;
}

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

Map<String, Object?> _body(Dio dio, int index) =>
    adapterOf(dio).decodedBodies[index]! as Map<String, Object?>;

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

Matcher _validation(String field, {int? code}) => isA<ValidationFailed>()
    .having((f) => f.fieldErrors.keys, 'fields', [field])
    .having((f) => f.code, 'code', code);

const _patched = UserSettingsChanges(
  name: 'Dora',
  discoverableByName: true,
  overdueTasksRemindersTime: ClockTime(18, 30),
  weekStart: 1,
  dateDisplay: SettingChange.clear(),
  minimumPriority: 4,
);

const _put = UserSettingsChanges(
  timezone: 'Europe/Berlin',
  emailRemindersEnabled: true,
  defaultViewKind: SettingChange.set(ProjectViewKind.kanban),
  timeFormat: SettingChange.set(TimeFormat.twelveHour),
);

const _posted = UserSettingsChanges(
  name: 'Dora Explorer',
  discoverableByEmail: true,
  quickAddMagicMode: QuickAddMagicMode.todoist,
  quickAddDefaultReminders: [Duration(hours: -1)],
);

void main() {
  group('update on 2.7.0', () {
    test('sends one merge-patch of the changed fields, the frontend keys '
        'inside frontend_settings, then reads the stored state', () async {
      final dio = fakeDio({
        '$_v2/user/settings/general': _captured('v2_patch'),
        '$_v2/user': _captured('v2_user_after_patch'),
      });

      final result = await _port(dio).update(_patched);

      expect(_calls(dio), [
        'PATCH $_v2/user/settings/general',
        'GET $_v2/user',
      ]);
      expect(
        adapterOf(dio).requests.first.headers['content-type'],
        'application/merge-patch+json',
      );
      expect(_body(dio, 0), _sent('v2_patch'));
      expect(result.profile.name, 'Dora');
      expect(result.profile.updated, DateTime.utc(2026, 10, 20, 21, 56, 5));
      expect(
        result.settings,
        const UserSettings(
          name: 'Dora',
          discoverableByName: true,
          overdueTasksRemindersTime: ClockTime(18, 30),
          defaultProjectId: 2942,
          weekStart: 1,
          timezone: 'GMT',
          minimumPriority: 4,
          colorSchema: ColorSchema.dark,
        ),
      );
    });

    test('the patch names no frontend key it does not change, so the '
        "server's deep merge keeps the foreign ones", () async {
      final dio = fakeDio({
        '$_v2/user/settings/general': _captured('v2_patch'),
        '$_v2/user': _captured('v2_user_after_patch'),
      });

      await _port(dio).update(_patched);

      expect(
        (_body(dio, 0)['frontend_settings']! as Map<String, Object?>).keys,
        unorderedEquals(['date_display', 'minimum_priority']),
      );
      expect(
        _storedSettings('v2_user_after_patch')['frontend_settings'],
        allOf(
          containsPair('play_sound_when_done', false),
          containsPair('sidebar_width', 320),
          containsPair(
            'rurana_unknown_key',
            _foreignKeys['rurana_unknown_key'],
          ),
        ),
      );
    });

    test('only top-level changes send no frontend_settings at all', () async {
      final dio = fakeDio({
        '$_v2/user/settings/general': _captured('v2_patch'),
        '$_v2/user': _captured('v2_user_after_patch'),
      });

      await _port(dio).update(
        const UserSettingsChanges(defaultProjectId: SettingChange.clear()),
      );

      expect(_body(dio, 0), {'default_project_id': 0});
    });

    test('an unchanged state (304) is a success', () async {
      final dio = fakeDio({
        '$_v2/user/settings/general': _captured('v2_patch_unchanged'),
        '$_v2/user': _captured('v2_user_after_patch'),
      });

      final result = await _port(dio).update(_patched);

      expect(result.settings.name, 'Dora');
      expect(_calls(dio).last, 'GET $_v2/user');
    });

    test('a server without the merge-patch after all (405) gets the full '
        'replace', () async {
      final dio = fakeDio({
        '$_v2/user/settings/general': _byMethod({
          'PATCH': json({'message': 'Method Not Allowed'}, status: 405),
          'PUT': _captured('v2_put'),
        }),
        '$_v2/user': sequence([
          _captured('v2_user_before_put'),
          _captured('v2_user_after_put'),
        ]),
      });

      final result = await _port(dio).update(_put);

      expect(_calls(dio), [
        'PATCH $_v2/user/settings/general',
        'GET $_v2/user',
        'PUT $_v2/user/settings/general',
        'GET $_v2/user',
      ]);
      expect(_body(dio, 2), _sent('v2_put'));
      expect(result.settings.timezone, 'Europe/Berlin');
    });

    test('empty changes only read', () async {
      final dio = fakeDio({'$_v2/user': _captured('v2_user')});

      final result = await _port(dio).update(const UserSettingsChanges());

      expect(_calls(dio), ['GET $_v2/user']);
      expect(result.settings.dateDisplay, DateDisplay.yearMonthDayDashed);
    });

    test('every field has its wire name and value', () async {
      final dio = fakeDio({
        '$_v2/user/settings/general': _captured('v2_patch'),
        '$_v2/user': _captured('v2_user_after_patch'),
      });

      await _port(dio).update(
        const UserSettingsChanges(
          name: 'Dora',
          emailRemindersEnabled: true,
          discoverableByName: false,
          discoverableByEmail: true,
          overdueTasksRemindersEnabled: false,
          overdueTasksRemindersTime: ClockTime(7, 5),
          defaultProjectId: SettingChange.set(12),
          weekStart: 6,
          timezone: '',
          language: 'de-DE',
          quickAddMagicMode: QuickAddMagicMode.disabled,
          quickAddDefaultReminders: [Duration(minutes: -15), Duration(days: 1)],
          filterIdUsedOnOverview: SettingChange.set(-553),
          minimumPriority: 5,
          commentSortOrder: CommentSortOrder.newestFirst,
          dateDisplay: SettingChange.set(DateDisplay.weekdayDayMonthYear),
          timeFormat: SettingChange.set(TimeFormat.twentyFourHour),
          colorSchema: ColorSchema.light,
          defaultViewKind: SettingChange.set(ProjectViewKind.table),
        ),
      );

      expect(_body(dio, 0), {
        'name': 'Dora',
        'email_reminders_enabled': true,
        'discoverable_by_name': false,
        'discoverable_by_email': true,
        'overdue_tasks_reminders_enabled': false,
        'overdue_tasks_reminders_time': '07:05',
        'default_project_id': 12,
        'week_start': 6,
        'timezone': '',
        'language': 'de-DE',
        'frontend_settings': {
          'quick_add_magic_mode': 'disabled',
          'quick_add_default_reminders': [
            {'relative_period': -900, 'relative_to': 'due_date'},
            {'relative_period': 86400, 'relative_to': 'due_date'},
          ],
          'filter_id_used_on_overview': -553,
          'minimum_priority': 5,
          'comment_sort_order': 'desc',
          'date_display': 'weekdayDayMonthYear',
          'time_format': '24h',
          'color_schema': 'light',
          'default_view': 'table',
        },
      });
    });

    test('clearing sends 0 for the default project and null for a frontend '
        'key, which the merge removes', () async {
      final dio = fakeDio({
        '$_v2/user/settings/general': _captured('v2_patch'),
        '$_v2/user': _captured('v2_user_after_patch'),
      });

      await _port(dio).update(
        const UserSettingsChanges(
          defaultProjectId: SettingChange.clear(),
          filterIdUsedOnOverview: SettingChange.clear(),
          dateDisplay: SettingChange.clear(),
          timeFormat: SettingChange.clear(),
          defaultViewKind: SettingChange.clear(),
        ),
      );

      expect(_body(dio, 0), {
        'default_project_id': 0,
        'frontend_settings': {
          'filter_id_used_on_overview': null,
          'date_display': null,
          'time_format': null,
          'default_view': null,
        },
      });
    });
  });

  group('update as a full replace', () {
    test('2.4 to 2.6: a fresh read, the changes applied to its JSON, a v2 '
        'PUT of the whole object, then the stored state', () async {
      final dio = fakeDio({
        '$_v2/user/settings/general': _captured('v2_put'),
        '$_v2/user': sequence([
          _captured('v2_user_before_put'),
          _captured('v2_user_after_put'),
        ]),
      });

      final result = await _port(dio, version: '2.6.0').update(_put);

      expect(_calls(dio), [
        'GET $_v2/user',
        'PUT $_v2/user/settings/general',
        'GET $_v2/user',
      ]);
      expect(_body(dio, 1), _sent('v2_put'));
      expect(result.settings.timezone, 'Europe/Berlin');
      expect(result.settings.emailRemindersEnabled, isTrue);
      expect(result.settings.defaultViewKind, ProjectViewKind.kanban);
      expect(result.settings.timeFormat, TimeFormat.twelveHour);
      expect(result.profile.updated, DateTime.utc(2026, 10, 20, 21, 56, 6));
    });

    test('2.3: the same over v1 GET and POST', () async {
      final dio = fakeDio({
        '$_v1/user/settings/general': _captured('v1_post'),
        '$_v1/user': sequence([
          _captured('v1_user_before_post'),
          _captured('v1_user_after_post'),
        ]),
      });

      final result = await _port(dio, version: 'v1').update(_posted);

      expect(_calls(dio), [
        'GET $_v1/user',
        'POST $_v1/user/settings/general',
        'GET $_v1/user',
      ]);
      expect(_body(dio, 1), _sent('v1_post'));
      expect(result.profile.name, 'Dora Explorer');
      expect(result.settings.quickAddMagicMode, QuickAddMagicMode.todoist);
      expect(result.settings.quickAddDefaultReminders, [
        const Duration(hours: -1),
      ]);
    });

    for (final version in ['2.6.0', 'v1']) {
      final base = version == 'v1' ? _v1 : _v2;

      test('$version: unknown frontend keys and unmodelled settings '
          'survive', () async {
        final dio = fakeDio({
          '$base/user/settings/general': _captured('v2_put'),
          '$base/user': sequence([
            _captured('v2_user'),
            _captured('v2_user_after_put'),
          ]),
        });

        await _port(
          dio,
          version: version,
        ).update(const UserSettingsChanges(colorSchema: ColorSchema.light));

        final stored = _storedSettings('v2_user');
        final sent = _body(dio, 1);
        expect(sent.keys, isNot(contains(r'$schema')));
        expect(sent.keys, isNot(contains('extra_settings_links')));
        expect(sent, {
          for (final MapEntry(:key, :value) in stored.entries)
            if (key != 'extra_settings_links') key: value,
          'frontend_settings': {
            ...stored['frontend_settings']! as Map<String, Object?>,
            'color_schema': 'light',
          },
        });
        expect(sent['frontend_settings'], containsPair('sidebar_width', 320));
      });

      test('$version: a cleared frontend key is removed, the default '
          'project becomes 0', () async {
        final dio = fakeDio({
          '$base/user/settings/general': _captured('v2_put'),
          '$base/user': sequence([
            _captured('v2_user'),
            _captured('v2_user_after_put'),
          ]),
        });

        await _port(dio, version: version).update(
          const UserSettingsChanges(
            dateDisplay: SettingChange.clear(),
            defaultProjectId: SettingChange.clear(),
          ),
        );

        final sent = _body(dio, 1);
        expect(sent['default_project_id'], 0);
        expect(sent['frontend_settings'], {
          'color_schema': 'dark',
          ..._foreignKeys,
        });
      });

      test(
        '$version: a frontend_settings of null stays null when no frontend '
        'key changes, and becomes an object with the key when one does',
        () async {
          final dio = fakeDio({
            '$base/user/settings/general': _captured('v2_put'),
            '$base/user': sequence([
              _captured('v2_user_new'),
              _captured('v2_user_new'),
              _captured('v2_user_new'),
              _captured('v2_user_new'),
            ]),
          });
          final port = _port(dio, version: version);

          await port.update(const UserSettingsChanges(name: 'Dora'));
          await port.update(const UserSettingsChanges(minimumPriority: 3));

          expect(_body(dio, 1), containsPair('frontend_settings', null));
          expect(_body(dio, 1)['name'], 'Dora');
          expect(_body(dio, 4)['frontend_settings'], {'minimum_priority': 3});
          expect(
            _body(dio, 4)['overdue_tasks_reminders_time'],
            '9:00',
            reason: 'the required time goes back as stored',
          );
        },
      );
    }
  });

  group('refusals', () {
    final patchRefusals = <String, Matcher>{
      'v2_patch_timezone': _domainError(400, 1025),
      'v2_patch_default_project_archived': _domainError(400, 3017),
      'v2_patch_week_start': _validation('week_start'),
      'v2_patch_overdue_time': _validation(
        'overdue_tasks_reminders_time',
        code: 2002,
      ),
    };
    for (final MapEntry(key: name, value: matcher) in patchRefusals.entries) {
      test('2.7.0: $name', () async {
        final dio = fakeDio({'$_v2/user/settings/general': _captured(name)});

        await expectLater(
          _port(dio).update(const UserSettingsChanges(timezone: 'x')),
          throwsA(matcher),
        );
        expect(_calls(dio), ['PATCH $_v2/user/settings/general']);
      });
    }

    final postRefusals = <String, Matcher>{
      'v1_post_timezone': _domainError(400, 1025),
      'v1_post_default_project_archived': _domainError(400, 3017),
      'v1_post_week_start': _validation('week_start', code: 2002),
      'v1_post_overdue_time': _validation(
        'overdue_tasks_reminders_time',
        code: 2002,
      ),
    };
    for (final MapEntry(key: name, value: matcher) in postRefusals.entries) {
      test('v1: $name', () async {
        final dio = fakeDio({
          '$_v1/user/settings/general': _captured(name),
          '$_v1/user': _captured('v1_user'),
        });

        await expectLater(
          _port(
            dio,
            version: 'v1',
          ).update(const UserSettingsChanges(weekStart: 1)),
          throwsA(matcher),
        );
        expect(_calls(dio), [
          'GET $_v1/user',
          'POST $_v1/user/settings/general',
        ]);
      });
    }

    test('a fresh read that is not a user fails before any write', () async {
      final dio = fakeDio({
        '$_v2/user': json({'id': 1, 'username': 'dora'}),
      });

      await expectLater(
        _port(
          dio,
          version: '2.6.0',
        ).update(const UserSettingsChanges(weekStart: 1)),
        throwsA(isA<UnexpectedResponse>()),
      );
      expect(_calls(dio), ['GET $_v2/user']);
    });
  });

  group('avatar provider', () {
    test('v2 and v1 read it from their own paths', () async {
      final v2 = fakeDio({
        '$_v2/user/settings/avatar/provider': _captured('v2_avatar_provider'),
      });
      final v1 = fakeDio({
        '$_v1/user/settings/avatar': _captured('v1_avatar_provider'),
      });

      expect(await _port(v2).avatarProvider(), AvatarProvider.initials);
      expect(
        await _port(v1, version: 'v1').avatarProvider(),
        AvatarProvider.initials,
      );
      expect(_calls(v2), ['GET $_v2/user/settings/avatar/provider']);
      expect(_calls(v1), ['GET $_v1/user/settings/avatar']);
    });

    test('a value this client does not know is null', () async {
      final dio = fakeDio({
        '$_v2/user/settings/avatar/provider': json({
          'avatar_provider': 'robohash',
        }),
      });

      expect(await _port(dio).avatarProvider(), isNull);
    });

    test('v2 puts and v1 posts the provider', () async {
      final v2 = fakeDio({
        '$_v2/user/settings/avatar/provider': _captured(
          'v2_avatar_provider_set',
        ),
      });
      final v1 = fakeDio({
        '$_v1/user/settings/avatar': _captured('v1_avatar_provider_set'),
      });

      await _port(v2).setAvatarProvider(AvatarProvider.marble);
      await _port(v1, version: 'v1').setAvatarProvider(AvatarProvider.gravatar);

      expect(_calls(v2), ['PUT $_v2/user/settings/avatar/provider']);
      expect(adapterOf(v2).decodedBodies, [_sent('v2_avatar_provider_set')]);
      expect(_calls(v1), ['POST $_v1/user/settings/avatar']);
      expect(adapterOf(v1).decodedBodies, [_sent('v1_avatar_provider_set')]);
    });

    for (final version in ['v2', 'v1']) {
      test('$version: a provider the server refuses is 1018', () async {
        final dio = fakeDio({
          '$_v2/user/settings/avatar/provider': _captured(
            'v2_avatar_provider_invalid',
          ),
          '$_v1/user/settings/avatar': _captured('v1_avatar_provider_invalid'),
        });

        await expectLater(
          _port(
            dio,
            version: version == 'v1' ? 'v1' : '2.7.0',
          ).setAvatarProvider(AvatarProvider.marble),
          throwsA(_domainError(412, 1018)),
        );
      });
    }

    test('the sign-in providers are refused before any request', () async {
      final dio = fakeDio({});

      for (final provider in [AvatarProvider.ldap, AvatarProvider.openid]) {
        await expectLater(
          _port(dio).setAvatarProvider(provider),
          throwsArgumentError,
        );
      }
      expect(adapterOf(dio).requests, isEmpty);
    });
  });

  group('avatar upload', () {
    final png = Uint8List.fromList(List.generate(64, (i) => i));

    Future<void> upload(
      UserSettingsWritePort port,
      List<int> bytes, {
      String fileName = 'avatar.png',
      Duration? timeout,
    }) => port.uploadAvatar(
      fileName: fileName,
      bytes: Stream.value(bytes),
      length: bytes.length,
      timeout: timeout,
    );

    for (final (version, url) in [
      ('2.7.0', '$_v2/user/settings/avatar'),
      ('v1', '$_v1/user/settings/avatar/upload'),
    ]) {
      test('$version puts one multipart part avatar with the file name, '
          'read once', () async {
        final dio = fakeDio({
          url: _captured(
            version == 'v1' ? 'v1_avatar_upload' : 'v2_avatar_upload',
          ),
        });

        await upload(
          _port(dio, version: version),
          png,
          timeout: const Duration(minutes: 1),
        );

        final request = adapterOf(dio).requests.single;
        expect('${request.method} ${request.uri}', 'PUT $url');
        expect(request.extra[AuthInterceptor.bodyReadOnceKey], isTrue);
        expect(request.sendTimeout, const Duration(minutes: 1));
        expect(request.receiveTimeout, const Duration(minutes: 1));
        final body = adapterOf(dio).requestBodyBytes.single!;
        final text = latin1.decode(body);
        expect(
          text,
          contains(
            'content-disposition: form-data; name="avatar"; '
            'filename="avatar.png"',
          ),
        );
        expect(_endsWithPart(body, png), isTrue);
      });
    }

    test('a blank file name is sent as avatar', () async {
      final dio = fakeDio({
        '$_v2/user/settings/avatar': _captured('v2_avatar_upload'),
      });

      await upload(_port(dio), png, fileName: ' ');

      expect(
        latin1.decode(adapterOf(dio).requestBodyBytes.single!),
        contains('filename="avatar"'),
      );
    });

    for (final version in ['v2', 'v1']) {
      test('$version: what the server cannot read as an image is a '
          'validation failure of avatar', () async {
        final dio = fakeDio({
          '$_v2/user/settings/avatar': _captured('v2_avatar_upload_not_image'),
          '$_v1/user/settings/avatar/upload': _captured(
            'v1_avatar_upload_not_image',
          ),
        });

        await expectLater(
          upload(_port(dio, version: version == 'v1' ? 'v1' : '2.7.0'), png),
          throwsA(
            isA<ValidationFailed>()
                .having((f) => f.fieldErrors, 'fieldErrors', {
                  'avatar': ['Uploaded file is no image.'],
                })
                .having((f) => f.code, 'code', isNull),
          ),
        );
      });

      test('$version: more than 50 megapixels is 4032', () async {
        final dio = fakeDio({
          '$_v2/user/settings/avatar': _captured(
            'v2_avatar_upload_too_many_pixels',
          ),
          '$_v1/user/settings/avatar/upload': _captured(
            'v1_avatar_upload_too_many_pixels',
          ),
        });

        await expectLater(
          upload(_port(dio, version: version == 'v1' ? 'v1' : '2.7.0'), png),
          throwsA(_domainError(400, 4032)),
        );
      });
    }

    test('a body above the request limit is FileTooLarge', () async {
      final fromServer = fakeDio({
        '$_v2/user/settings/avatar': json({
          'message': 'Request Entity Too Large',
          'code': 4035,
        }, status: 413),
      });
      final fromProxy = fakeDio({
        '$_v2/user/settings/avatar': html('<h1>413</h1>', status: 413),
      });

      for (final dio in [fromServer, fromProxy]) {
        await expectLater(
          upload(_port(dio), png),
          throwsA(
            isA<FileTooLarge>()
                .having((f) => f.code, 'code', 4035)
                .having((f) => f.statusCode, 'status', 413),
          ),
        );
      }
    });

    test('an error of the bytes is rethrown as it is', () async {
      final dio = fakeDio({
        '$_v2/user/settings/avatar': _captured('v2_avatar_upload'),
      });
      final broken = StreamController<List<int>>()
        ..add([1, 2])
        ..addError(const FormatException('unreadable'));
      unawaited(broken.close());

      await expectLater(
        _port(dio)
            .uploadAvatar(fileName: 'a.png', bytes: broken.stream, length: 8),
        throwsA(isA<FormatException>()),
      );
    });

    test('the upload bumps the user, which is the only sign of a new '
        'avatar', () {
      final before = parseUserProfile(
        jsonDecode(
          fixtureJson('user_settings/v1_user_after_post_2.7.0.json')['body']!
              as String,
        ),
      )!;
      final after = parseUserProfile(
        jsonDecode(
          fixtureJson('user_settings/v2_user_after_upload_2.7.0.json')['body']!
              as String,
        ),
      )!;

      expect(after.updated!.isAfter(before.updated!), isTrue);
      expect(
        fixtureJson(
          'user_settings/v2_avatar_provider_after_upload_2.7.0.json',
        )['body'],
        contains('"avatar_provider":"upload"'),
      );
    });
  });
}

/// Whether the last part of a multipart [body] holds exactly [content].
bool _endsWithPart(Uint8List body, List<int> content) {
  final text = latin1.decode(body);
  final end = text.lastIndexOf('\r\n--');
  final start = text.lastIndexOf('\r\n\r\n', end) + 4;
  final part = latin1.encode(text.substring(start, end));
  if (part.length != content.length) return false;
  for (var i = 0; i < part.length; i++) {
    if (part[i] != content[i]) return false;
  }
  return true;
}
