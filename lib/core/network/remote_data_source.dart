import 'package:vikunja_app/core/network/client.dart';

class RemoteDataSource {
  final Client _client;

  Client get client => _client;

  RemoteDataSource(this._client);

  List<T> convertList<T>(List<dynamic> value, Mapper<T> mapper) {
    return value.map((map) => mapper(map)).toList();
  }
}

typedef Mapper<T> = T Function(Map<String, dynamic> json);
