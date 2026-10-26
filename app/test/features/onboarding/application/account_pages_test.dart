import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/onboarding/application/browser_sign_in_method.dart';
import 'package:vikunja_mobile/features/onboarding/application/web_auth_pages.dart';

import '../../../helpers/server_connections.dart';

void main() {
  group('passwordResetPageUri', () {
    test('opens the advertised frontend', () {
      expect(
        passwordResetPageUri(
          accountPagesServer270(
            root: 'https://api.example.org/vikunja',
            frontendUrl: Uri.parse('https://tasks.example.org/'),
          ),
        ),
        Uri.parse('https://tasks.example.org/get-password-reset'),
      );
    });

    test('keeps the path of a frontend given without a trailing slash', () {
      expect(
        passwordResetPageUri(
          accountPagesServer270(
            frontendUrl: Uri.parse('https://example.org/web?lang=de#top'),
          ),
        ),
        Uri.parse('https://example.org/web/get-password-reset'),
      );
    });

    test('falls back to the server address with its path', () {
      expect(
        passwordResetPageUri(accountPagesServer270()),
        Uri.parse('https://tasks.example.org/vikunja/get-password-reset'),
      );
    });

    test('never sends an https server to an http frontend', () {
      expect(
        passwordResetPageUri(
          accountPagesServer270(
            frontendUrl: Uri.parse('http://tasks.example.org/'),
          ),
        ),
        Uri.parse('https://tasks.example.org/vikunja/get-password-reset'),
      );
    });

    test('an http server may use its http frontend', () {
      expect(
        passwordResetPageUri(
          accountPagesServer270(
            root: 'http://192.168.1.20:3456',
            frontendUrl: Uri.parse('http://192.168.1.20:8080/'),
          ),
        ),
        Uri.parse('http://192.168.1.20:8080/get-password-reset'),
      );
    });
  });

  group('what the sign-in page offers', () {
    test('open registration offers both pages', () {
      final method = browserSignInMethodFor(accountPagesServer270())!;

      expect(method.offersRegistration, isTrue);
      expect(method.offersPasswordReset, isTrue);
      expect(method.registrationNeedsInvitation, isFalse);
    });

    test('closed registration still offers the password reset', () {
      final method = browserSignInMethodFor(
        accountPagesServer270(registration: false),
      )!;

      expect(method.offersRegistration, isFalse);
      expect(method.offersPasswordReset, isTrue);
      expect(method.registrationNeedsInvitation, isFalse);
    });

    test('closed registration with invite links needs an invitation', () {
      final method = browserSignInMethodFor(
        accountPagesServer270(registration: false, invites: true),
      )!;

      expect(method.offersRegistration, isFalse);
      expect(method.registrationNeedsInvitation, isTrue);
    });

    test('open registration needs no invitation, even with invite links', () {
      final method = browserSignInMethodFor(
        accountPagesServer270(invites: true),
      )!;

      expect(method.offersRegistration, isTrue);
      expect(method.registrationNeedsInvitation, isFalse);
    });

    test('single sign-on only offers neither', () {
      final method = browserSignInMethodFor(
        accountPagesServer270(localAuth: false, invites: true),
      )!;

      expect(method.openIdProviderNames, ['Keycloak']);
      expect(method.offersRegistration, isFalse);
      expect(method.offersPasswordReset, isFalse);
      expect(method.registrationNeedsInvitation, isFalse);
    });
  });
}
