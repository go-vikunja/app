import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:http/http.dart';

class VersionDataSource {
  VersionDataSource();

  Future<String> getLatestVersionTag() async {
    String api = "https://api.github.com/repos/go-vikunja/app";
    String endpoint = "/releases";

    return get(Uri.parse(api + endpoint)).then((response) {
      dynamic jsonResponse = json.decode(response.body);
      String latestVersion = jsonResponse[0]['tag_name'];
      if (latestVersion.startsWith("v")) {
        latestVersion = latestVersion.replaceFirst("v", "");
      }
      return latestVersion;
    });
  }

  Future<String> getCurrentVersionTag() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;

    // Include build number if it exists and is not empty
    if (buildNumber.isNotEmpty && buildNumber != '1') {
      version = '$version+$buildNumber';
    }

    print("current: $version");
    return version;
  }
}
