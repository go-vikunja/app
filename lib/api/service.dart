import 'package:fluttering_vikunja/api/client.dart';
import 'package:meta/meta.dart';

class APIService {
  final Client _client;

  @protected
  Client get client => _client;

  APIService(this._client);

  @protected
  List<T> convertList<T>(dynamic value, Mapper<T> mapper) {
    if (value == null) return [];
    return (value as List<dynamic>).map((map) => mapper(map)).toList();
  }
}

typedef T Mapper<T>(Map<String, dynamic> json);
