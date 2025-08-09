import 'package:vikunja_app/data/data_sources/version_data_source.dart';
import 'package:vikunja_app/domain/repositories/version_repository.dart';

class VersionRepositoryImpl extends VersionRepository {
  final VersionDataSource _dataSource;

  VersionRepositoryImpl(this._dataSource);

  @override
  Future<String> getLatestVersionTag() async {
    return _dataSource.getLatestVersionTag();
  }

  @override
  Future<String> getCurrentVersionTag() async {
    return _dataSource.getCurrentVersionTag();
  }

  @override
  Future<bool> isUpToDate() async {
    return _dataSource.isUpToDate();
  }

  @override
  postVersionCheckSnackbar() async {
    _dataSource.postVersionCheckSnackbar();
  }
}
