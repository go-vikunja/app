import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/label_dto.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';

void main() {
  group('LabelDto.fromJson', () {
    test('parses the scalar fields', () {
      final dto = LabelDto.fromJson(labelJson(id: 5, title: 'Bug'));

      expect(dto.id, 5);
      expect(dto.title, 'Bug');
      expect(dto.description, 'A defect');
      expect(dto.created, DateTime.parse(isoDate));
      expect(dto.updated, DateTime.parse(isoDate));
      expect(dto.createdBy.username, 'testuser');
    });

    test('turns a hex_color into an opaque Color', () {
      expect(
        LabelDto.fromJson(labelJson(hexColor: 'e8e8e8')).color,
        const Color(0xFFE8E8E8),
      );
    });

    test('treats an empty hex_color as no colour', () {
      expect(LabelDto.fromJson(labelJson(hexColor: '')).color, isNull);
    });
  });

  group('LabelDto.toJSON', () {
    test('writes hex_color back without the alpha channel', () {
      final json = LabelDto.fromJson(labelJson(hexColor: 'e8e8e8')).toJSON();

      expect(json['hex_color'], 'e8e8e8');
    });

    test('pads a short hex value to six digits', () {
      final dto = LabelDto(
        title: 'Dark',
        color: const Color(0xFF000102),
        createdBy: LabelDto.fromJson(labelJson()).createdBy,
      );

      expect(dto.toJSON()['hex_color'], '000102');
    });

    test('writes a null hex_color when the label has no colour', () {
      final json = LabelDto.fromJson(labelJson(hexColor: '')).toJSON();

      expect(json['hex_color'], isNull);
    });

    test('writes the api field names and utc timestamps', () {
      final json = LabelDto.fromJson(labelJson()).toJSON();

      expect(
        json.keys,
        containsAll(<String>[
          'id',
          'title',
          'description',
          'hex_color',
          'created_by',
          'created',
          'updated',
        ]),
      );
      expect(
        json['created'],
        DateTime.parse(isoDate).toUtc().toIso8601String(),
      );
    });
  });

  group('LabelDto domain conversion', () {
    test('toDomain carries every field', () {
      final label = LabelDto.fromJson(
        labelJson(id: 5, title: 'Bug', hexColor: 'ff0000'),
      ).toDomain();

      expect(label.id, 5);
      expect(label.title, 'Bug');
      expect(label.description, 'A defect');
      expect(label.color, const Color(0xFFFF0000));
      expect(label.createdBy.username, 'testuser');
    });

    test('fromDomain round-trips a coloured label', () {
      final back = LabelDto.fromDomain(
        buildLabel(id: 2, title: 'Feature', color: const Color(0xFF00FF00)),
      ).toDomain();

      expect(back.id, 2);
      expect(back.title, 'Feature');
      expect(back.color, const Color(0xFF00FF00));
    });

    test('fromDomain round-trips an uncoloured label', () {
      final back = LabelDto.fromDomain(buildLabel(color: null)).toDomain();

      expect(back.color, isNull);
    });

    test('a directly constructed dto defaults description and timestamps', () {
      final dto = LabelDto(
        title: 'Plain',
        createdBy: LabelDto.fromJson(labelJson()).createdBy,
      );

      expect(dto.id, 0);
      expect(dto.description, '');
      expect(dto.created, isNotNull);
      expect(dto.updated, isNotNull);
    });
  });
}
