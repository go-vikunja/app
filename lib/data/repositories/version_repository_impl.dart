import 'package:vikunja_app/data/data_sources/version_data_source.dart';
import 'package:vikunja_app/domain/repositories/version_repository.dart';

class VersionRepositoryImpl extends VersionRepository {

  VersionDataSource _dataSource;

  VersionRepositoryImpl(this._dataSource);

  Future<String> getLatestVersionTag() async {
    return _dataSource.getLatestVersionTag();
  }

  Future<String> getCurrentVersionTag() async {
    return _dataSource.getCurrentVersionTag();
  }

  Future<bool> isUpToDate() async {
    return _dataSource.isUpToDate();
  }

  postVersionCheckSnackbar() async {
    _dataSource.postVersionCheckSnackbar();
  }
}
