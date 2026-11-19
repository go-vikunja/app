import 'package:vikunja_domain/vikunja_domain.dart';

/// [value] as one path segment. A name of only `.` or `..` would be read as
/// a dot segment and send the request to the parent path, `..` of
/// `/projects/1/users/..` to `/projects/1/`; percent-encoding does not
/// help, as `Uri` decodes the dots again. Such a name is refused here.
String pathSegment(String value) {
  if (value == '.' || value == '..') {
    throw const ValidationFailed(
      message: 'a name of only dots cannot be sent in a path',
    );
  }
  return Uri.encodeComponent(value);
}
