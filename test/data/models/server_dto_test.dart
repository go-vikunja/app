import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/server_dto.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';

void main() {
  group('ServerDto.fromJson', () {
    test('reads every feature flag', () {
      final dto = ServerDto.fromJson(serverJson());

      expect(dto.caldavEnabled, isTrue);
      expect(dto.emailRemindersEnabled, isTrue);
      expect(dto.frontendUrl, 'https://vikunja.example.com/');
      expect(dto.linkSharingEnabled, isTrue);
      expect(dto.maxFileSize, '20MB');
      expect(dto.motd, 'Welcome');
      expect(dto.registrationEnabled, isFalse);
      expect(dto.taskAttachmentsEnabled, isTrue);
      expect(dto.taskCommentsEnabled, isTrue);
      expect(dto.totpEnabled, isFalse);
      expect(dto.userDeletion, isTrue);
      expect(dto.version, 'v0.24.0');
    });

    test('leaves every field null for an empty payload', () {
      final dto = ServerDto.fromJson({});

      expect(dto.version, isNull);
      expect(dto.caldavEnabled, isNull);
      expect(dto.motd, isNull);
    });
  });

  group('ServerDto domain conversion', () {
    test('toDomain carries every field', () {
      final server = ServerDto.fromJson(
        serverJson(version: 'v1.2.3'),
      ).toDomain();

      expect(server.version, 'v1.2.3');
      expect(server.maxFileSize, '20MB');
      expect(server.registrationEnabled, isFalse);
    });

    test('fromDomain round-trips', () {
      final back = ServerDto.fromDomain(
        buildServer(version: 'v9.9.9'),
      ).toDomain();

      expect(back.version, 'v9.9.9');
      expect(back.frontendUrl, 'https://vikunja.example.com');
      expect(back.totpEnabled, isFalse);
    });
  });
}
