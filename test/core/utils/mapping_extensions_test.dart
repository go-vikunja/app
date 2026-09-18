import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/models/dto.dart';

/// Minimal DTO so these tests exercise the mapper and nothing else. Real DTO
/// conversion is covered in `test/data/models/`.
class _StubDto extends Dto<String> {
  _StubDto(this.value);

  final String value;

  @override
  String toDomain() => 'domain:$value';
}

void main() {
  final stackTrace = StackTrace.fromString('trace');

  group('DtoResponseMapper.toDomain', () {
    test('maps a success body while preserving status and headers', () {
      final Response<Dto> response = SuccessResponse<Dto>(_StubDto('a'), 201, {
        'x-total': '9',
      });

      final mapped = response.toDomain<String>();

      expect(mapped, isA<SuccessResponse<String>>());
      expect(mapped.toSuccess().body, 'domain:a');
      expect(mapped.toSuccess().statusCode, 201);
      expect(mapped.toSuccess().headers, {'x-total': '9'});
    });

    test('carries an error through untouched', () {
      final Response<Dto> response = ErrorResponse<Dto>(
        404,
        {'h': 'v'},
        {'message': 'not found'},
      );

      final mapped = response.toDomain<String>();

      expect(mapped, isA<ErrorResponse<String>>());
      expect(mapped.toError().statusCode, 404);
      expect(mapped.toError().error, {'message': 'not found'});
      expect(mapped.toError().headers, {'h': 'v'});
    });

    test('carries an exception through untouched', () {
      final exception = FormatException('bad json');
      final Response<Dto> response = ExceptionResponse<Dto>(
        exception,
        stackTrace,
      );

      final mapped = response.toDomain<String>();

      expect(mapped, isA<ExceptionResponse<String>>());
      expect(mapped.toException().exception, same(exception));
      expect(mapped.toException().stackTrace, same(stackTrace));
    });
  });

  group('DtoListResponseMapping.toDomain', () {
    test('maps every element of a success body', () {
      final Response<List<Dto>> response = SuccessResponse<List<Dto>>(
        [_StubDto('a'), _StubDto('b')],
        200,
        const {},
      );

      final mapped = response.toDomain<String>();

      expect(mapped.toSuccess().body, ['domain:a', 'domain:b']);
    });

    test('maps an empty list to an empty list', () {
      final Response<List<Dto>> response = SuccessResponse<List<Dto>>(
        [],
        200,
        const {},
      );

      expect(response.toDomain<String>().toSuccess().body, isEmpty);
    });

    test('carries an error through untouched', () {
      final Response<List<Dto>> response = ErrorResponse<List<Dto>>(
        403,
        const {},
        {'message': 'forbidden'},
      );

      final mapped = response.toDomain<String>();

      expect(mapped, isA<ErrorResponse<List<String>>>());
      expect(mapped.toError().statusCode, 403);
    });

    test('carries an exception through untouched', () {
      final Response<List<Dto>> response = ExceptionResponse<List<Dto>>(
        'offline',
        stackTrace,
      );

      final mapped = response.toDomain<String>();

      expect(mapped, isA<ExceptionResponse<List<String>>>());
      expect(mapped.toException().message, 'offline');
    });
  });

  group('DtoListMapper.toDomain', () {
    test('converts each DTO in the list', () {
      final list = <Dto>[_StubDto('x'), _StubDto('y')];

      expect(list.toDomain<String>(), ['domain:x', 'domain:y']);
    });

    test('returns an empty list for an empty input', () {
      expect(<Dto>[].toDomain<String>(), isEmpty);
    });
  });
}
