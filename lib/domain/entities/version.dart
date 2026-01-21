import 'package:vikunja_app/core/utils/validator.dart';

class Version {
  int major;
  int minor;
  int patch;
  String? label;
  String? label2;

  Version(this.major, this.minor, this.patch, [this.label, this.label2]);

  static Version? fromString(String versionString) {
    if (versionRegex.hasMatch(versionString)) {
      Iterable<RegExpMatch> matches = versionRegex.allMatches(versionString);

      RegExpMatch version = matches.elementAt(0);
      var major = int.tryParse(version.group(1) ?? "");
      var minor = int.tryParse(version.group(2) ?? "");
      var patch = int.tryParse(version.group(3) ?? "");
      var label = version.group(4);
      var label2 = version.group(5);

      return Version(major ?? -1, minor ?? -1, patch ?? -1, label, label2);
    }

    return null;
  }

  bool isNewerThan(Version other) {
    if (major > other.major) return true;
    if (major < other.major) return false;
    if (minor > other.minor) return true;
    if (minor < other.minor) return false;
    if (patch > other.patch) return true;
    if (patch < other.patch) return false;

    if (label != null && other.label != null) {
      if (label == other.label) {
        if (label == "beta" && label2 != null && other.label2 != null) {
          return int.parse(label2 ?? "0") > int.parse(other.label2 ?? "0");
        }
      }
    }

    return false;
  }

  @override
  String toString() {
    if (label2 != null && int.tryParse(label2!) != null) {
      return '$major.$minor.$patch-$label+$label2';
    }
    return '$major.$minor.$patch-$label';
  }
}
