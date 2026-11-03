import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/user_dto.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';

void main() {
  group('UserDto.fromJson', () {
    test('parses the identity fields', () {
      final dto = UserDto.fromJson(
        userJson(id: 9, username: 'jdoe', name: 'Jane'),
      );

      expect(dto.id, 9);
      expect(dto.username, 'jdoe');
      expect(dto.name, 'Jane');
      expect(dto.created, DateTime.parse(isoDate));
      expect(dto.updated, DateTime.parse(isoDate));
    });

    test('defaults a missing id and name', () {
      final dto = UserDto.fromJson({
        'username': 'anon',
        'created': isoDate,
        'updated': isoDate,
      });

      expect(dto.id, 0);
      expect(dto.name, '');
    });

    test('leaves settings null when the payload omits them', () {
      expect(UserDto.fromJson(userJson()).settings, isNull);
    });

    test('parses nested settings when present', () {
      final dto = UserDto.fromJson(
        userJson(settings: userSettingsJson(defaultProjectId: 7)),
      );

      expect(dto.settings, isNotNull);
      expect(dto.settings!.defaultProjectId, 7);
    });
  });

  group('UserDto.toJSON', () {
    test('writes settings under the user_settings key', () {
      final dto = UserDto.fromJson(
        userJson(settings: userSettingsJson(defaultProjectId: 7)),
      );

      final json = dto.toJSON();

      expect(json['user_settings'], isA<Map<String, Object?>>());
      expect(json['user_settings']['default_project_id'], 7);
    });

    test('serialises timestamps as utc iso strings', () {
      final json = UserDto.fromJson(userJson()).toJSON();

      expect(
        json['created'],
        DateTime.parse(isoDate).toUtc().toIso8601String(),
      );
      expect(
        json['updated'],
        DateTime.parse(isoDate).toUtc().toIso8601String(),
      );
    });

    test('writes a null user_settings when there are none', () {
      expect(UserDto.fromJson(userJson()).toJSON()['user_settings'], isNull);
    });
  });

  group('UserDto domain conversion', () {
    test('toDomain carries every field including settings', () {
      final dto = UserDto.fromJson(
        userJson(
          id: 9,
          username: 'jdoe',
          name: 'Jane',
          settings: userSettingsJson(),
        ),
      );

      final user = dto.toDomain();

      expect(user.id, 9);
      expect(user.username, 'jdoe');
      expect(user.name, 'Jane');
      expect(user.settings!.language, 'en');
    });

    test('fromDomain round-trips a user without settings', () {
      final user = buildUser(id: 4, username: 'bob', name: 'Bob');

      final back = UserDto.fromDomain(user).toDomain();

      expect(back.id, 4);
      expect(back.username, 'bob');
      expect(back.name, 'Bob');
      expect(back.settings, isNull);
    });

    test('fromDomain round-trips a user with settings', () {
      final user = buildUser(
        settings: buildUserSettings(defaultProjectId: 11, language: 'de'),
      );

      final back = UserDto.fromDomain(user).toDomain();

      expect(back.settings!.defaultProjectId, 11);
      expect(back.settings!.language, 'de');
    });
  });

  group('UserSettingsDto', () {
    test('fromJson reads every setting', () {
      final dto = UserSettingsDto.fromJson(
        userSettingsJson(frontendSettings: {'filter_id_used_on_overview': 5}),
      );

      expect(dto.defaultProjectId, 3);
      expect(dto.discoverableByEmail, isTrue);
      expect(dto.discoverableByName, isFalse);
      expect(dto.emailRemindersEnabled, isTrue);
      expect(dto.frontendSettings, {'filter_id_used_on_overview': 5});
      expect(dto.language, 'en');
      expect(dto.name, 'Test User');
      expect(dto.overdueTasksRemindersEnabled, isTrue);
      expect(dto.overdueTasksRemindersTime, '09:00');
      expect(dto.timezone, 'Europe/Berlin');
      expect(dto.weekStart, 1);
    });

    test('toJson uses the snake_case names the api expects', () {
      final json = UserSettingsDto.fromJson(userSettingsJson()).toJson();

      expect(
        json.keys,
        containsAll(<String>[
          'default_project_id',
          'discoverable_by_email',
          'discoverable_by_name',
          'email_reminders_enabled',
          'frontend_settings',
          'language',
          'name',
          'overdue_tasks_reminders_enabled',
          'overdue_tasks_reminders_time',
          'timezone',
          'week_start',
        ]),
      );
    });

    test('a default-constructed dto round-trips through the domain', () {
      final back = UserSettingsDto.fromDomain(
        UserSettingsDto().toDomain(),
      ).toDomain();

      expect(back.defaultProjectId, 0);
      expect(back.language, '');
      expect(back.weekStart, 0);
      expect(back.frontendSettings, isNull);
    });
  });

  group('UserSettings.copyWith', () {
    test('keeps every field when given nothing', () {
      final settings = buildUserSettings(defaultProjectId: 3, language: 'it');

      final copy = settings.copyWith();

      expect(copy.defaultProjectId, 3);
      expect(copy.language, 'it');
      expect(copy.name, settings.name);
    });

    test('replaces only the fields it is given', () {
      final settings = buildUserSettings(defaultProjectId: 3);

      final copy = settings.copyWith(
        defaultProjectId: 8,
        discoverableByEmail: true,
        discoverableByName: true,
        emailRemindersEnabled: true,
        frontendSettings: {'a': 1},
        language: 'de',
        name: 'Other',
        overdueTasksRemindersEnabled: true,
        overdueTasksRemindersTime: '10:00',
        timezone: 'UTC',
        weekStart: 0,
      );

      expect(copy.defaultProjectId, 8);
      expect(copy.discoverableByEmail, isTrue);
      expect(copy.discoverableByName, isTrue);
      expect(copy.emailRemindersEnabled, isTrue);
      expect(copy.frontendSettings, {'a': 1});
      expect(copy.language, 'de');
      expect(copy.name, 'Other');
      expect(copy.overdueTasksRemindersEnabled, isTrue);
      expect(copy.overdueTasksRemindersTime, '10:00');
      expect(copy.timezone, 'UTC');
      expect(copy.weekStart, 0);
    });
  });
}
