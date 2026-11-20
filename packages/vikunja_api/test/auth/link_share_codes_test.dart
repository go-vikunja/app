import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';

void main() {
  test("the codes are Vikunja's", () {
    expect(LinkShareCodes.passwordRequired, 13001);
    expect(LinkShareCodes.wrongPassword, 13002);
    expect(LinkShareCodes.tokenInvalid, 13003);
  });
}
