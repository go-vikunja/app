import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/filters/filter_zone.dart';
import 'package:vikunja_mobile/features/account_settings/application/server_languages.dart';
import 'package:vikunja_mobile/features/account_settings/application/square_avatar.dart';
import 'package:vikunja_mobile/features/account_settings/application/time_zone_choices.dart';
import 'package:vikunja_mobile/features/account_settings/application/web_settings_pages.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/searchable_option_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import 'avatar_fakes.dart';

void main() {
  group('the web settings pages', () {
    ServerConnection withFrontend(
      String? frontend, {
      String root = 'https://tasks.example.org/vikunja',
    }) {
      final connection = fullServer270(root: root);
      final info = connection.info;
      return ServerConnection(
        rootUri: connection.rootUri,
        apiVersions: connection.apiVersions,
        capabilities: connection.capabilities,
        info: ServerInfo(
          version: info.version,
          rawVersion: info.rawVersion,
          frontendUrl: frontend == null ? null : Uri.parse(frontend),
        ),
      );
    }

    test('are on the frontend the server reports', () {
      expect(
        webSettingsPageUri(
          withFrontend('https://web.example.org/'),
          WebSettingsPage.password,
        ),
        Uri.parse('https://web.example.org/user/settings/password-update'),
      );
      expect(
        webSettingsPageUri(
          withFrontend('https://web.example.org/sub'),
          WebSettingsPage.email,
        ),
        Uri.parse('https://web.example.org/sub/user/settings/email-update'),
      );
    });

    test("are under the server's address without a frontend", () {
      expect(
        webSettingsPageUri(withFrontend(null), WebSettingsPage.password),
        Uri.parse(
          'https://tasks.example.org/vikunja/user/settings/password-update',
        ),
      );
      expect(
        webSettingsPageUri(
          withFrontend(null, root: 'https://tasks.example.org'),
          WebSettingsPage.email,
        ),
        Uri.parse('https://tasks.example.org/user/settings/email-update'),
      );
    });
  });

  group('the server languages', () {
    test('are the web list by their own names, with the web codes', () {
      expect(serverLanguages, hasLength(32));
      expect(serverLanguageOf('de-DE')?.name, 'Deutsch');
      expect(serverLanguageOf('de-swiss')?.name, 'Schwizertütsch');
      expect(serverLanguageOf('xx'), isNull);
      final names = [for (final language in serverLanguages) language.name];
      expect(names.indexOf('Čeština'), lessThan(names.indexOf('Dansk')));
      expect(names.indexOf('Tiếng Việt'), lessThan(names.indexOf('Türkçe')));
      expect(names.first, 'Čeština');
    });
  });

  group('the time zones', () {
    test('every bundled zone by name, with its offset now', () {
      final choices = timeZoneChoices(DateTime.utc(2026, 1, 15, 12));
      final names = [for (final choice in choices) choice.name];
      expect(names, contains('Europe/Berlin'));
      expect(names, contains('Asia/Calcutta'));
      final berlin = choices.singleWhere((c) => c.name == 'Europe/Berlin');
      expect(berlin.offset, const Duration(hours: 1));
      final newYork = choices.singleWhere((c) => c.name == 'America/New_York');
      expect(newYork.label, 'America/New York');
      expect(
        names,
        [...names]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      );
    });

    test('the offset reads like the web', () {
      expect(formatUtcOffset(Duration.zero), 'UTC');
      expect(formatUtcOffset(const Duration(hours: 2)), 'UTC+02:00');
      expect(
        formatUtcOffset(const Duration(hours: -3, minutes: -30)),
        'UTC−03:30',
      );
      expect(
        formatUtcOffset(const Duration(hours: 5, minutes: 45)),
        'UTC+05:45',
      );
    });

    group('suggested for the device', () {
      final winter = DateTime.utc(2026, 1, 15);
      List<String> sameAs(String zone) {
        ensureTimeZones();
        final location = tz.getLocation(zone);
        return zonesWithDeviceOffsets(
          now: winter,
          deviceOffsetAt: (utc) =>
              location.timeZone(utc.millisecondsSinceEpoch).offset,
        );
      }

      test('the zone set already when it keeps the same time', () {
        expect(
          suggestedTimeZones(
            current: 'Europe/Berlin',
            sameAsDevice: sameAs('Europe/Berlin'),
          ),
          ['Europe/Berlin'],
        );
        expect(
          suggestedTimeZones(
            current: 'America/New_York',
            sameAsDevice: sameAs('America/New_York'),
          ),
          ['America/New_York'],
        );
      });

      test('else every zone with the same time, not one picked at random', () {
        final suggested = suggestedTimeZones(
          current: 'GMT',
          sameAsDevice: sameAs('Europe/Berlin'),
        );
        expect(suggested, contains('Europe/Berlin'));
        expect(suggested, contains('Africa/Ceuta'));
        expect(suggested, isNot(contains('Atlantic/Jan_Mayen')));
        expect(suggested, isNot(contains('Europe/London')));
        expect(suggested, [...suggested]..sort());
      });

      test('the zone TZ names when it is set', () {
        expect(
          suggestedTimeZones(
            current: 'GMT',
            sameAsDevice: sameAs('Europe/Berlin'),
            envZone: 'Europe/Berlin',
          ),
          ['Europe/Berlin'],
        );
      });

      test('only zones whose clocks match all year', () {
        expect(sameAs('Europe/Berlin'), isNot(contains('Africa/Lagos')));
        expect(sameAs('Asia/Kolkata'), [
          'Asia/Calcutta',
          'Asia/Colombo',
          'Asia/Kolkata',
        ]);
      });
    });
  });

  group('the searchable sheet', () {
    test('finds a time zone by its own name and its offset with a typed '
        'minus', () {
      const newYork = SearchableOption(
        value: 'America/New_York',
        label: 'America/New York',
        detail: 'UTC−05:00',
        searchTerms: ['America/New_York'],
      );
      expect(newYork.matches('new york'), isTrue);
      expect(newYork.matches('NEW_YORK'), isTrue);
      expect(newYork.matches('America/New_York'), isTrue);
      expect(newYork.matches('-05'), isTrue);
      expect(newYork.matches('utc−05'), isTrue);
      expect(newYork.matches('berlin'), isFalse);
      expect(newYork.matches('+05'), isFalse);
    });
  });

  group('the avatar square', () {
    test('the largest square in the middle', () {
      expect(centreSquare(40, 20), const ui.Rect.fromLTWH(10, 0, 20, 20));
      expect(centreSquare(30, 50), const ui.Rect.fromLTWH(0, 10, 30, 30));
    });

    test('what the viewport shows at the start, after a pan and a zoom', () {
      // A 4000 × 2000 photo covers a 200 dp square at 1/10.
      Matrix4 centred() => Matrix4.translationValues(-100, 0, 0);
      expect(
        cropInViewport(
          transform: centred(),
          viewportSide: 200,
          imageWidth: 4000,
          imageHeight: 2000,
        ),
        const ui.Rect.fromLTWH(1000, 0, 2000, 2000),
      );
      expect(
        cropInViewport(
          transform: Matrix4.translationValues(-200, 0, 0),
          viewportSide: 200,
          imageWidth: 4000,
          imageHeight: 2000,
        ),
        const ui.Rect.fromLTWH(2000, 0, 2000, 2000),
      );
      // Twice as close, with the viewport's corner at (300, 100) of the
      // laid-out photo.
      final zoomed = Matrix4.translationValues(-300, -100, 0)
        ..multiply(Matrix4.diagonal3Values(2, 2, 1));
      expect(
        cropInViewport(
          transform: zoomed,
          viewportSide: 200,
          imageWidth: 4000,
          imageHeight: 2000,
        ),
        const ui.Rect.fromLTWH(1500, 500, 1000, 1000),
      );
    });

    test('never outside the photo', () {
      expect(
        cropInViewport(
          transform: Matrix4.translationValues(50, 50, 0),
          viewportSide: 200,
          imageWidth: 400,
          imageHeight: 200,
        ),
        const ui.Rect.fromLTWH(0, 0, 200, 200),
      );
    });

    testWidgets('a PNG of the square, at most 1024 pixels', (tester) async {
      final image = await tester.runAsync(
        () => decodeAvatarSource(wideTestPng),
      );
      expect((image!.width, image.height), (40, 20));
      final png = await tester.runAsync(
        () => encodeSquareAvatar(image, centreSquare(40, 20)),
      );
      final square = await tester.runAsync(() => decodeAvatarSource(png!));
      expect((square!.width, square.height), (20, 20));
      expect(png!.sublist(1, 4), 'PNG'.codeUnits);
      expect(avatarMaxSide, 1024);
    });

    testWidgets('a file that is no picture is refused', (tester) async {
      Object? failure;
      await tester.runAsync(() async {
        try {
          await decodeAvatarSource(Uint8List.fromList([1, 2, 3]));
        } on Object catch (error) {
          failure = error;
        }
      });
      expect(failure, isNotNull);
    });
  });

  group('the failure wording', () {
    test('values the server refused are shown at their control', () {
      expect(
        accountSettingsFieldError(
          en,
          const DomainError(400, code: 1025),
          AccountSettingsField.timezone,
          const UserSettingsChanges(timezone: 'America/Ciudad_Juarez'),
        ),
        en.accountSettingsTimezoneInvalid('America/Ciudad Juarez'),
      );
      expect(
        accountSettingsFieldError(
          en,
          const DomainError(400, code: 3017),
          AccountSettingsField.defaultProject,
          const UserSettingsChanges(defaultProjectId: SettingChange.set(4)),
        ),
        en.accountSettingsDefaultProjectInvalid,
      );
      expect(
        accountSettingsFieldError(
          en,
          const ValidationFailed(code: 2002),
          AccountSettingsField.overdueTime,
          const UserSettingsChanges(overdueTasksRemindersTime: ClockTime(8, 0)),
        ),
        en.accountSettingsOverdueTimeInvalid,
      );
      expect(
        accountSettingsFieldError(
          en,
          const ValidationFailed(),
          AccountSettingsField.weekStart,
          const UserSettingsChanges(weekStart: 1),
        ),
        en.accountSettingsInvalid,
      );
      expect(
        accountSettingsFieldError(
          en,
          const NetworkFailure(NetworkProblem.unreachable),
          AccountSettingsField.timezone,
          const UserSettingsChanges(timezone: 'Europe/Berlin'),
        ),
        isNull,
      );
    });

    test('anything else in a message', () {
      expect(
        accountSettingsFailureText(
          en,
          const NetworkFailure(NetworkProblem.unreachable),
        ),
        en.accountSettingsNeedsConnection,
      );
      expect(
        accountSettingsFailureText(
          en,
          const NetworkFailure(NetworkProblem.timeout),
        ),
        en.accountSettingsUnconfirmed,
      );
      expect(
        accountSettingsFailureText(
          en,
          const SessionEnded(SessionEndReason.invalidRefreshToken),
        ),
        en.accountSettingsSignInAgain,
      );
      expect(
        accountSettingsFailureText(en, const Forbidden(message: 'Forbidden')),
        en.accountSettingsRefused('Forbidden'),
      );
      expect(
        accountSettingsFailureText(en, StateError('x')),
        en.accountSettingsFailed,
      );
    });

    test('an avatar upload names the picture', () {
      expect(
        avatarUploadFailureText(en, const FileTooLarge(code: 4035)),
        en.avatarImageTooLarge,
      );
      expect(
        avatarUploadFailureText(en, const DomainError(400, code: 4032)),
        en.avatarImageTooLarge,
      );
      expect(
        avatarUploadFailureText(en, const ValidationFailed()),
        en.avatarImageUnusable,
      );
      expect(
        avatarUploadFailureText(
          en,
          const NetworkFailure(NetworkProblem.unreachable),
        ),
        en.accountSettingsNeedsConnection,
      );
    });
  });
}
