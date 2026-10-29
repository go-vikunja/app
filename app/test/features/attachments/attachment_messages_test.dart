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
      en.attachmentDownloadForbidden,
    );
  });

  for (final l10n in [en, de]) {
    group('${l10n.localeName}: server codes in our own words', () {
      test('a download without access', () {
        expect(
          attachmentFailureText(
            l10n,
            const Forbidden(code: 4013, message: 'Forbidden'),
            download: true,
          ),
          l10n.attachmentDownloadForbidden,
        );
      });

      test("a file missing from the server's storage", () {
        const missing = NotFound(code: 4034, message: 'file does not exist');
        expect(
          attachmentFailureText(l10n, missing, download: true),
          l10n.attachmentFileMissing,
        );
        expect(
          attachmentFailureText(l10n, missing),
          l10n.attachmentFileMissing,
        );
      });

      test('the task gone from the server', () {
        expect(
          attachmentFailureText(
            l10n,
            const NotFound(code: 4002, message: 'task does not exist'),
          ),
          l10n.syncProblemTaskMissing,
        );
      });

      test('a server error, also an upload whose storage failed', () {
        expect(
          attachmentFailureText(
            l10n,
            const ServerFailure(500, message: 'Internal Server Error'),
            download: true,
          ),
          l10n.actionFailureServerError,
        );
        expect(
          attachmentFailureText(l10n, const ServerFailure(500)),
          l10n.actionFailureServerError,
        );
      });

      test('a route without a code still means attachments are off', () {
        expect(
          attachmentFailureText(l10n, const NotFound(message: 'Not Found')),
          l10n.attachmentsDisabled,
        );
      });

      test('an unmapped refusal keeps the server detail', () {
        expect(
          attachmentFailureText(
            l10n,
            const DomainError(400, code: 4020, message: ' Odd. '),
          ),
          l10n.attachmentRefused('Odd.'),
        );
      });
    });
  }
}
