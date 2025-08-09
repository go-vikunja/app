import 'package:vikunja_app/core/network/client.dart';
import 'package:meta/meta.dart';

class RemoteDataSource {
  final Client _client;

  @protected
  Client get client => _client;

  RemoteDataSource(this._client);

  @protected
  List<T> convertList<T>(dynamic value, Mapper<T> mapper) {
    if (value == null) return [];
    return (value as List<dynamic>).map((map) => mapper(map)).toList();
  }
}

typedef T Mapper<T>(Map<String, dynamic> json);
