// This is a wrapper class to be able to return the headers up to the provider
// to properly handle things like pagination with it.

sealed class Response<T> {
  Response();

  bool get isSuccessful => this is SuccessResponse;

  bool get isError => this is ErrorResponse;

  bool get isException => this is ExceptionResponse;

  SuccessResponse<T> toSuccess() {
    return this as SuccessResponse<T>;
  }

  ErrorResponse<T> toError() {
    return this as ErrorResponse<T>;
  }

  ExceptionResponse<T> toException() {
    return this as ExceptionResponse<T>;
  }
}

class SuccessResponse<T> extends Response<T> {
  final int statusCode;
  final Map<String, String> headers;
  final T body;

  SuccessResponse(this.body, this.statusCode, this.headers) : super();
}

class VoidResponse<T> extends SuccessResponse<T> {
  VoidResponse() : super(Object() as T, 200, {});
}

class ExceptionResponse<T> extends Response<T> {
  final Object exception;
  final StackTrace stackTrace;

  ExceptionResponse(this.exception, this.stackTrace) : super();

  String get message => exception.toString();
}

class ErrorResponse<T> extends Response<T> {
  final int statusCode;
  final Map<String, String> headers;
  final Map<String, dynamic> error;

  ErrorResponse(this.statusCode, this.headers, this.error) : super();
}
