import 'package:vikunja_app/data/data_sources/version_data_source.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/domain/repositories/version_repository.dart';

class VersionRepositoryImpl extends VersionRepository {
  final VersionDataSource _dataSource;

  VersionRepositoryImpl(this._dataSource);

  @override
  Future<Version?> getLatestVersionTag() async {
    var latestVersionTag = await _dataSource.getLatestVersionTag();

    return latestVersionTag != null
        ? Version.fromString(latestVersionTag)
        : null;
  }

  @override
  Future<Version?> getCurrentVersionTag() async {
    var currentVersionTag = await _dataSource.getCurrentVersionTag();
    return Version.fromString(currentVersionTag);
  }
}
