import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/server.dart';

import '../service/services.dart';

class ServerAPIService extends APIService implements ServerService {
  ServerAPIService(Client client) : super(client);

  @override
  Future<Server> getInfo() {
    return client.get('/info').then((value) => Server.fromJson(value.body));
  }
}
