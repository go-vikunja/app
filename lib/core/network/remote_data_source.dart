import 'package:vikunja_app/core/network/client.dart';
import 'package:meta/meta.dart';

class RemoteDataSource {
  final Client _client;

  @protected
  Client get client => _client;

  RemoteDataSource(this._client);

  @protected
  List<T> convertList<T>(List<dynamic> value, Mapper<T> mapper) {
    return value.map((map) => mapper(map)).toList();
  }
}

typedef Mapper<T> = T Function(Map<String, dynamic> json);
