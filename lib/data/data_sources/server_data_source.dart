import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/server_dto.dart';

class ServerDataSource extends RemoteDataSource {
  ServerDataSource(Client client) : super(client);

  Future<ServerDto?> getInfo() {
    return client.get('/info').then((value) {
      if (value == null) return null;
      return ServerDto.fromJson(value.body);
    });
  }
}
