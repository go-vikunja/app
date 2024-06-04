import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionChecker {
  GlobalKey<ScaffoldMessengerState> snackbarKey;
  VersionChecker(this.snackbarKey);

  String repo = "https://github.com/go-vikunja/app/releases/latest";

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
    print("current: " + packageInfo.version);
    return packageInfo.version;
  }

  Future<bool> isUpToDate() async {
    String latest = await getLatestVersionTag();
    String current = await getCurrentVersionTag();
    return latest == current;
  }

  postVersionCheckSnackbar() async {
    String latest = await getLatestVersionTag();
    isUpToDate().then((value) {
      if (!value) {
        // not up to date
        SnackBar snackBar = SnackBar(
          content: Text("New version available: $latest"),
          action: SnackBarAction(
              label: "View on Github",
              onPressed: () => launchUrl(Uri.parse(repo),
                  mode: LaunchMode.externalApplication)),
        );
        snackbarKey.currentState?.showSnackBar(snackBar);
      }
    });
  }
}
