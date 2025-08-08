// This is a wrapper class to be able to return the headers up to the provider
// to properly handle things like pagination with it.

class Error {
  Error(this.message);
  final String message;
}

class Response {
  Response(this.body, this.statusCode, this.headers, {this.error});

  final dynamic body;
  final int statusCode;
  final Map<String, String> headers;
  final Error? error;
}
