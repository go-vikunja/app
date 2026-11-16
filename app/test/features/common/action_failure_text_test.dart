import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_security_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/attachments/presentation/attachment_messages.dart';
import 'package:vikunja_mobile/features/common/presentation/action_failure_text.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_change_failure.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('our own texts, not the English ones', () {
    expect(
      en.actionFailureServerError,
      'The server answered with an error. Try again in a few minutes.',
    );
    expect(
      de.actionFailureServerError,
      'Der Server hat mit einem Fehler geantwortet. Versuche es in ein paar '
      'Minuten noch einmal.',
    );
    expect(
      en.actionFailureSessionEnded,
      'Your session has ended. Sign in again on the Account tab.',
    );
    expect(
      de.actionFailureSessionEnded,
      'Deine Sitzung ist beendet. Melde dich im Tab „Account“ neu an.',
    );
    expect(
      en.actionFailureRateLimited,
      'The server is limiting requests for now. Wait a minute, then try '
      'again.',
    );
    expect(
      de.actionFailureRateLimited,
      'Der Server begrenzt Anfragen gerade. Warte eine Minute und versuche es '
      'dann noch einmal.',
    );
    expect(
      en.actionFailureGuestAccessEnded,
      'Your guest access has ended. Open the link again on the Account tab.',
    );
    expect(
      de.actionFailureGuestAccessEnded,
      'Dein Gastzugang ist beendet. Öffne den Link im Tab „Account“ erneut.',
    );
  });

  for (final l10n in [en, de]) {
    group(l10n.localeName, () {
      String? text(Object error) => actionFailureText(l10n, error);

      test('a server error, with or without a body or code', () {
        for (final error in const [
          ServerFailure(500, message: 'Internal Server Error'),
          ServerFailure(500, code: 4028, message: 'Could not save.'),
          ServerFailure(503, code: 4037, message: 'Service unavailable'),
          ServerFailure(502),
        ]) {
          expect(text(error), l10n.actionFailureServerError);
        }
      });

      test('a session that ended, however the server said so', () {
        for (final error in const [
          SessionEnded(
            SessionEndReason.invalidRefreshToken,
            code: 16002,
            message: 'The refresh token is invalid.',
          ),
          SessionEnded(SessionEndReason.expired, code: 16003),
          TokenRejected(message: 'missing, malformed, expired or otherwise '),
          RefreshRaceLost(message: 'Refresh already used.'),
        ]) {
          expect(text(error), l10n.actionFailureSessionEnded);
        }
      });

      test('a guest link that is gone, before the session that ended', () {
        for (final error in const [
          LinkShareGone(code: 13003, message: 'The link share is gone.'),
          LinkShareGone(code: 3006),
          LinkShareGone(),
        ]) {
          expect(text(error), l10n.actionFailureGuestAccessEnded);
        }
      });

      test('a rate limit', () {
        expect(
          text(
            const RateLimited(
              retryAfter: Duration(seconds: 30),
              message: 'Too Many Requests',
            ),
          ),
          l10n.actionFailureRateLimited,
        );
      });

      test('everything else is left to the action', () {
        for (final error in <Object>[
          const NetworkFailure(NetworkProblem.unreachable),
          const Forbidden(message: 'Forbidden'),
          const NotFound(code: 4002),
          const ValidationFailed(),
          const DomainError(400, code: 4020, message: 'Odd'),
          const FileTooLarge(code: 4035),
          const UnexpectedResponse(502, message: 'Bad Gateway'),
          StateError('x'),
        ]) {
          expect(text(error), isNull, reason: '$error');
        }
      });

      test("the actions' own words still win", () {
        const sessionEnded = SessionEnded(SessionEndReason.expired);
        expect(
          accountSettingsFailureText(l10n, sessionEnded),
          l10n.accountSettingsSignInAgain,
        );
        expect(
          accountSecurityFailureText(l10n, sessionEnded),
          l10n.accountSecuritySignInAgain,
        );
        expect(
          accountSecurityFailureText(l10n, const RateLimited()),
          l10n.accountSecurityRateLimited,
        );
        expect(
          attachmentFailureText(l10n, const FileTooLarge(code: 4035)),
          l10n.attachmentFileTooLarge,
        );
      });

      test('and reach the actions that had only the server detail', () {
        const busy = ServerFailure(500, message: 'Internal Server Error');
        expect(
          accountSettingsFailureText(l10n, busy),
          l10n.actionFailureServerError,
        );
        expect(
          accountSettingsFailureText(l10n, const RateLimited()),
          l10n.actionFailureRateLimited,
        );
        expect(
          accountSecurityFailureText(l10n, busy),
          l10n.actionFailureServerError,
        );
        expect(
          labelChangeFailureText(l10n, busy, LabelChange.edit),
          l10n.actionFailureServerError,
        );
        expect(
          labelChangeFailureText(
            l10n,
            const LinkShareGone(code: 13003),
            LabelChange.create,
          ),
          l10n.actionFailureGuestAccessEnded,
        );
      });
    });
  }
}
