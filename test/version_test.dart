import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/version.dart';

void main() {
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
}
