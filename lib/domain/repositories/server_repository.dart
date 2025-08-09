import 'package:vikunja_app/domain/entities/server.dart';

abstract class ServerRepository {

  Future<Server?> getInfo();
}
