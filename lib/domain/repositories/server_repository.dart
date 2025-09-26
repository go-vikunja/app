import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/server.dart';

abstract class ServerRepository {
  Future<Response<Server>> getInfo();
}
