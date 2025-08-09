abstract class VersionRepository {
  Future<String> getLatestVersionTag();

  Future<String> getCurrentVersionTag();

  Future<bool> isUpToDate();

  postVersionCheckSnackbar();
}
