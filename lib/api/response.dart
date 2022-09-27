// This is a wrapper class to be able to return the headers up to the provider
// to properly handle things like pagination with it.
class Response {
  Response(this.body, this.statusCode, this.headers, {this.error = false});

  final dynamic body;
  final int statusCode;
  final Map<String, String> headers;
  final bool error;
}
