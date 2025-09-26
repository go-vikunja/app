import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/data/models/server_dto.dart';

class ServerDataSource extends RemoteDataSource {
  ServerDataSource(super.client);

  Future<Response<ServerDto>> getInfo() {
    return client.get(
      url: '/info',
      mapper: (body) {
        return ServerDto.fromJson(body);
      },
    );
  }
}
