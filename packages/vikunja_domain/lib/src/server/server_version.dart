import 'package:meta/meta.dart';

/// A Vikunja server version as reported by `GET /info`.
///
/// Release builds report `v2.7.0`, builds after a tag `v2.7.0-12-g0123abc`,
/// and untagged development builds `dev` or `unstable`. Development builds
/// sort above every release because they track `main`.
@immutable
final class ServerVersion implements Comparable<ServerVersion> {
  const new(this.major, this.minor, this.patch, {String? raw})
    : isDevelopmentBuild = false,
      raw = raw ?? '$major.$minor.$patch';

  const new development(this.raw)
    : major = 0,
      minor = 0,
      patch = 0,
      isDevelopmentBuild = true;

  static final _semver = RegExp(r'^v?(\d+)\.(\d+)(?:\.(\d+))?');
  static const _developmentNames = {'dev', 'unstable', 'main', 'master'};

  /// Returns null when [raw] carries neither a version number nor a known
  /// development build name.
  static ServerVersion? tryParse(String raw) {
    final trimmed = raw.trim();
    final match = _semver.firstMatch(trimmed);
    if (match != null) {
      final major = int.tryParse(match.group(1)!);
      final minor = int.tryParse(match.group(2)!);
      final patch = int.tryParse(match.group(3) ?? '0');
      if (major == null || minor == null || patch == null) return null;
      return ServerVersion(major, minor, patch, raw: trimmed);
    }
    if (_developmentNames.contains(trimmed.toLowerCase())) {
      return ServerVersion.development(trimmed);
    }
    return null;
  }

  final int major;
  final int minor;
  final int patch;
  final bool isDevelopmentBuild;
  final String raw;

  bool isAtLeast(int major, [int minor = 0, int patch = 0]) =>
      compareTo(ServerVersion(major, minor, patch)) >= 0;

  @override
  int compareTo(ServerVersion other) {
    if (isDevelopmentBuild || other.isDevelopmentBuild) {
      if (isDevelopmentBuild == other.isDevelopmentBuild) return 0;
      return isDevelopmentBuild ? 1 : -1;
    }
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(ServerVersion other) => compareTo(other) < 0;
  bool operator >=(ServerVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is ServerVersion && compareTo(other) == 0;

  @override
  int get hashCode => isDevelopmentBuild
      ? Object.hash(true, 0)
      : Object.hash(major, minor, patch);

  /// `2.7.0`, or the raw name for development builds.
  String get display => isDevelopmentBuild ? raw : '$major.$minor.$patch';

  @override
  String toString() => 'ServerVersion($raw)';
}
