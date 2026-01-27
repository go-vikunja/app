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

  static Version? fromServerString(String versionString) {
    versionString = versionString.substring(1);
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
    try {
      if (major > other.major) return true;
      if (major < other.major) return false;
      if (minor > other.minor) return true;
      if (minor < other.minor) return false;
      if (patch > other.patch) return true;
      if (patch < other.patch) return false;

      if (label != null && label == other.label) {
        if (label == "beta") {
          return int.parse(label2 ?? "0") > int.parse(other.label2 ?? "0");
        }
      } else if (label?.startsWith("rc") == true &&
          other.label?.startsWith("rc") == true) {
        return int.parse(label?.substring(2) ?? "0") >
            int.parse(other.label?.substring(2) ?? "0");
      }
    } catch (e) {}

    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Version &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          label == other.label &&
          label2 == other.label2;

  @override
  int get hashCode => Object.hash(major, minor, patch, label, label2);

  @override
  String toString() {
    var versionString = '$major.$minor.$patch';

    if (label != null) {
      versionString += '-$label';
    }

    if (label2 != null && int.tryParse(label2!) != null) {
      versionString += '+$label2';
    }

    return versionString;
  }
}
