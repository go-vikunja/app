import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:http/http.dart';

class VersionDataSource {
  VersionDataSource();

  Future<String?> getLatestVersionTag() async {
    String api = "https://api.github.com/repos/go-vikunja/app";
    String endpoint = "/releases";

    return get(Uri.parse(api + endpoint)).then((response) {
      dynamic jsonResponse = json.decode(response.body);
      if (jsonResponse[0] == null) return null;

      String? latestVersion = jsonResponse[0]['tag_name'] ?? null;
      if (latestVersion != null && latestVersion.startsWith("v")) {
        latestVersion = latestVersion.replaceFirst("v", "");
      }
      return latestVersion;
    });
  }

  Future<String> getCurrentVersionTag() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    print("current: " + packageInfo.version);
    return packageInfo.version;
  }
}
