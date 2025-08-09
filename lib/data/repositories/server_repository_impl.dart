import 'package:vikunja_app/data/data_sources/server_data_source.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/repositories/server_repository.dart';

class ServerRepositoryImpl extends ServerRepository {
  final ServerDataSource _dataSource;

  ServerRepositoryImpl(this._dataSource);

  @override
  Future<Server?> getInfo() async {
    return (await _dataSource.getInfo())?.toDomain();
  }
}
