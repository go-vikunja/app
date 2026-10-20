import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/attachments/presentation/attachment_messages.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('a change that timed out may have happened; a download did not', () {
    const timeout = NetworkFailure(NetworkProblem.timeout);
    expect(attachmentFailureText(en, timeout), en.attachmentUnconfirmed);
    expect(
      attachmentFailureText(en, timeout, download: true),
      en.attachmentNeedsConnection,
    );
  });

  test('a refused download does not speak of changing attachments', () {
    const forbidden = Forbidden(code: 4013);
    expect(attachmentFailureText(en, forbidden), en.attachmentForbidden);
    expect(
      attachmentFailureText(en, forbidden, download: true),
      isNot(en.attachmentForbidden),
    );
  });
}
