import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/dto.dart';

extension DtoResponseMapper on Response<Dto> {
  Response<T> toDomain<T>() {
    if (isSuccessful) {
      var successResponse = toSuccess();
      var body = successResponse.body;

      return SuccessResponse<T>(
        body.toDomain(),
        successResponse.statusCode,
        successResponse.headers,
      );
    } else if (isError) {
      var errorResponse = toError();
      return ErrorResponse<T>(
        errorResponse.statusCode,
        errorResponse.headers,
        errorResponse.error,
      );
    } else {
      var exceptionResponse = toException();
      return ExceptionResponse(
        exceptionResponse.exception,
        exceptionResponse.stackTrace,
      );
    }
  }
}

extension DtoListResponseMapping on Response<List<Dto>> {
  Response<List<T>> toDomain<T>() {
    if (isSuccessful) {
      var successResponse = toSuccess();
      var body = successResponse.body;

      return SuccessResponse<List<T>>(
        body.toDomain(),
        successResponse.statusCode,
        successResponse.headers,
      );
    } else if (isError) {
      var errorResponse = toError();
      return ErrorResponse<List<T>>(
        errorResponse.statusCode,
        errorResponse.headers,
        errorResponse.error,
      );
    } else {
      var exceptionResponse = toException();
      return ExceptionResponse(
        exceptionResponse.exception,
        exceptionResponse.stackTrace,
      );
    }
  }
}

extension DtoListMapper on List<Dto> {
  List<Q> toDomain<Q>() {
    return map((e) => e.toDomain() as Q).toList();
  }
}
