import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/version.dart';

void main() {
  group("Version comparison", () {
    test('Test versions same', () {
      Version version = Version(1, 0, 0);
      Version version2 = Version(1, 0, 0);

      expect(version.isNewerThan(version2), false);
      expect(version2.isNewerThan(version), false);
    });

    test('Test patch version newer', () {
      Version version = Version(1, 0, 0);
      Version version2 = Version(1, 0, 1);

      expect(version.isNewerThan(version2), false);
      expect(version2.isNewerThan(version), true);
    });

    test('Test minor version newer', () {
      Version version = Version(1, 0, 0);
      Version version2 = Version(1, 1, 0);

      expect(version.isNewerThan(version2), false);
      expect(version2.isNewerThan(version), true);
    });

    test('Test major version newer', () {
      Version version = Version(1, 0, 0);
      Version version2 = Version(2, 0, 0);

      expect(version.isNewerThan(version2), false);
      expect(version2.isNewerThan(version), true);
    });

    test('Test beta newer', () {
      Version version = Version(1, 0, 0, "beta", "1");
      Version version2 = Version(1, 0, 0, "beta", "2");

      expect(version.isNewerThan(version2), false);
      expect(version2.isNewerThan(version), true);
    });

    test('Test rc newer', () {
      Version version = Version(1, 0, 0, "rc1");
      Version version2 = Version(1, 0, 0, "rc2");

      expect(version.isNewerThan(version2), false);
      expect(version2.isNewerThan(version), true);
    });

    test('Test final newer than rc', () {
      Version version = Version(1, 0, 0);
      Version version2 = Version(1, 0, 0, "rc2");

      expect(version.isNewerThan(version2), true);
      expect(version2.isNewerThan(version), false);
    });

    test('Test final newer than beta', () {
      Version version = Version(1, 0, 0);
      Version version2 = Version(1, 0, 0, "beta", "1");

      expect(version.isNewerThan(version2), true);
      expect(version2.isNewerThan(version), false);
    });

    test('Test rc newer than beta', () {
      Version version = Version(1, 0, 0, "rc1");
      Version version2 = Version(1, 0, 0, "beta", "1");

      expect(version.isNewerThan(version2), true);
      expect(version2.isNewerThan(version), false);
    });
  });

  group("Semver compatibility", () {
    test('Exact match is compatible', () {
      var server = Version(2, 1, 0);
      var minimum = Version(2, 1, 0);
      expect(server.isCompatibleWith(minimum), true);
    });

    test('Higher minor is compatible', () {
      var server = Version(2, 2, 0);
      var minimum = Version(2, 1, 0);
      expect(server.isCompatibleWith(minimum), true);
    });

    test('Higher patch is compatible', () {
      var server = Version(2, 1, 5);
      var minimum = Version(2, 1, 0);
      expect(server.isCompatibleWith(minimum), true);
    });

    test('Higher major is incompatible', () {
      var server = Version(3, 0, 0);
      var minimum = Version(2, 1, 0);
      expect(server.isCompatibleWith(minimum), false);
    });

    test('Lower major is incompatible', () {
      var server = Version(1, 9, 0);
      var minimum = Version(2, 1, 0);
      expect(server.isCompatibleWith(minimum), false);
    });

    test('Same major, lower minor is incompatible', () {
      var server = Version(2, 0, 0);
      var minimum = Version(2, 1, 0);
      expect(server.isCompatibleWith(minimum), false);
    });

    test('Same major and minor, lower patch is incompatible', () {
      var server = Version(2, 1, 0);
      var minimum = Version(2, 1, 3);
      expect(server.isCompatibleWith(minimum), false);
    });

    test('Pre-release of minimum version is incompatible', () {
      var server = Version(2, 1, 0, "beta", "1");
      var minimum = Version(2, 1, 0);
      expect(server.isCompatibleWith(minimum), false);
    });

    test('Pre-release of higher version is compatible', () {
      var server = Version(2, 2, 0, "rc1");
      var minimum = Version(2, 1, 0);
      expect(server.isCompatibleWith(minimum), true);
    });
  });

  group("Server version parsing", () {
    test('Test regular version', () {
      Version? version = Version.fromServerString("v1.2.3");

      expect(version?.major, 1);
      expect(version?.minor, 2);
      expect(version?.patch, 3);
      expect(version?.label, null);
      expect(version?.label2, null);
    });

    test('Test rc version', () {
      Version? version = Version.fromServerString("v1.0.0-rc3");

      expect(version?.major, 1);
      expect(version?.minor, 0);
      expect(version?.patch, 0);
      expect(version?.label, "rc3");
      expect(version?.label2, null);
    });

    test('Test beta version', () {
      Version? version = Version.fromServerString("v1.0.0-beta+4");

      expect(version?.major, 1);
      expect(version?.minor, 0);
      expect(version?.patch, 0);
      expect(version?.label, "beta");
      expect(version?.label2, "4");
    });
  });
}
