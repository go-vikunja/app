import 'package:vikunja_app/domain/entities/version.dart';

abstract class VersionRepository {
  Future<Version?> getLatestVersionTag();

  Future<Version?> getCurrentVersionTag();
}
