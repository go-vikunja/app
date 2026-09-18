import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/task_attachment_dto.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';

void main() {
  group('TaskAttachmentFileDto', () {
    test('fromJSON parses the file metadata', () {
      final dto = TaskAttachmentFileDto.fromJSON(
        attachmentFileJson(name: 'a.png'),
      );

      expect(dto.id, 3);
      expect(dto.mime, 'application/pdf');
      expect(dto.name, 'a.png');
      expect(dto.size, 1024);
      expect(dto.created, DateTime.parse(isoDate));
    });

    test('toJSON writes a utc timestamp', () {
      final json = TaskAttachmentFileDto.fromJSON(
        attachmentFileJson(),
      ).toJSON();

      expect(
        json['created'],
        DateTime.parse(isoDate).toUtc().toIso8601String(),
      );
      expect(json['size'], 1024);
    });

    test('round-trips through the domain', () {
      final back = TaskAttachmentFileDto.fromDomain(
        TaskAttachmentFileDto.fromJSON(attachmentFileJson()).toDomain(),
      ).toDomain();

      expect(back.name, 'report.pdf');
      expect(back.mime, 'application/pdf');
    });
  });

  group('TaskAttachmentDto', () {
    test('fromJSON parses the nested file and author', () {
      final dto = TaskAttachmentDto.fromJSON(attachmentJson(id: 4, taskId: 77));

      expect(dto.id, 4);
      expect(dto.taskId, 77);
      expect(dto.file.name, 'report.pdf');
      expect(dto.createdBy.username, 'testuser');
    });

    test('toJSON nests the file and author objects', () {
      final json = TaskAttachmentDto.fromJSON(attachmentJson()).toJSON();

      expect(json['task_id'], 100);
      expect(json['file'], isA<Map<String, Object>>());
      expect(json['created_by'], isA<Map<String, dynamic>>());
    });

    test('round-trips through the domain', () {
      final back = TaskAttachmentDto.fromDomain(
        buildAttachment(fileName: 'x.txt'),
      ).toDomain();

      expect(back.file.name, 'x.txt');
      expect(back.taskId, 100);
    });

    test('defaults created when constructed without it', () {
      final dto = TaskAttachmentDto(
        taskId: 1,
        createdBy: TaskAttachmentDto.fromJSON(attachmentJson()).createdBy,
        file: TaskAttachmentFileDto.fromJSON(attachmentFileJson()),
      );

      expect(dto.id, 0);
      expect(dto.created, isNotNull);
    });
  });
}
