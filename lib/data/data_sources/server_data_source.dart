import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/server.dart';

import '../../core/services.dart';

class ServerDataSource extends RemoteDataSource implements ServerService {
  ServerDataSource(Client client) : super(client);

  @override
  Future<Server?> getInfo() {
    return client.get('/info').then((value) {
      if (value == null) return null;
      return Server.fromJson(value.body);
    });
  }
}
