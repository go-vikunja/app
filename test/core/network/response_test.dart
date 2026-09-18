import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/response.dart';

void main() {
  group('Response predicates', () {
    test('a success response reports only isSuccessful', () {
      final Response<int> response = SuccessResponse<int>(1, 200, const {});

      expect(response.isSuccessful, isTrue);
      expect(response.isError, isFalse);
      expect(response.isException, isFalse);
    });

    test('an error response reports only isError', () {
      final Response<int> response = ErrorResponse<int>(
        400,
        const {},
        const {},
      );

      expect(response.isSuccessful, isFalse);
      expect(response.isError, isTrue);
      expect(response.isException, isFalse);
    });

    test('an exception response reports only isException', () {
      final Response<int> response = ExceptionResponse<int>(
        Exception('x'),
        StackTrace.empty,
      );

      expect(response.isSuccessful, isFalse);
      expect(response.isError, isFalse);
      expect(response.isException, isTrue);
    });

    test('a void response counts as successful', () {
      final Response<Object> response = VoidResponse<Object>();

      expect(response.isSuccessful, isTrue);
      expect(response.toSuccess().statusCode, 200);
      expect(response.toSuccess().headers, isEmpty);
    });
  });

  group('Response casts', () {
    test('toSuccess exposes body, status and headers', () {
      final response = SuccessResponse<String>('body', 201, {'a': 'b'});

      expect(response.toSuccess().body, 'body');
      expect(response.toSuccess().statusCode, 201);
      expect(response.toSuccess().headers, {'a': 'b'});
    });

    test('toError exposes the decoded error payload', () {
      final response = ErrorResponse<String>(422, {'h': 'v'}, {'code': 4001});

      expect(response.toError().statusCode, 422);
      expect(response.toError().error['code'], 4001);
    });

    test('toException exposes the exception, trace and message', () {
      final exception = StateError('nope');
      final response = ExceptionResponse<String>(exception, StackTrace.empty);

      expect(response.toException().exception, same(exception));
      expect(response.toException().stackTrace, StackTrace.empty);
      expect(response.toException().message, exception.toString());
    });

    test('casting to the wrong variant throws', () {
      final Response<String> response = SuccessResponse<String>(
        'x',
        200,
        const {},
      );

      expect(() => response.toError(), throwsA(isA<TypeError>()));
      expect(() => response.toException(), throwsA(isA<TypeError>()));
    });
  });
}
