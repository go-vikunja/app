// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Rurana';

  @override
  String get connectTagline =>
      'Your tasks from your own Vikunja server, right on your phone.';

  @override
  String get connectAddressLabel => 'Server address';

  @override
  String get connectAddressHint => 'vikunja.example.com';

  @override
  String get connectAddressHelper =>
      'The address you open Vikunja with in your browser, for example https://vikunja.example.com';

  @override
  String get connectAddressEmpty => 'Enter the address of your Vikunja server.';

  @override
  String get connectClearAddress => 'Clear address';

  @override
  String get connectContinue => 'Continue';

  @override
  String get connectCancel => 'Cancel';

  @override
  String get connectConnecting => 'Connecting…';

  @override
  String connectConnectingTo(String address) {
    return 'Looking for Vikunja at $address …';
  }

  @override
  String get connectTryDemo => 'Try the public demo';

  @override
  String get failureInvalidAddressTitle =>
      'That doesn’t look like a server address';

  @override
  String failureInvalidAddressExplanation(String input) {
    return '“$input” is not a web address the app can open.';
  }

  @override
  String get failureInvalidAddressSuggestion =>
      'Enter the address you use for Vikunja in your browser, for example vikunja.example.com.';

  @override
  String get failureUnreachableTitle => 'Server not reachable';

  @override
  String failureUnreachableExplanation(String host) {
    return '$host could not be reached. The address may be misspelled, the server may be offline, or your device has no internet connection.';
  }

  @override
  String get failureUnreachableSuggestion =>
      'Check the address and your connection, then try again. If the server runs at home, connect to the same Wi-Fi or VPN first.';

  @override
  String get failureTimeoutTitle => 'The server took too long to answer';

  @override
  String failureTimeoutExplanation(String host) {
    return '$host did not respond in time.';
  }

  @override
  String get failureTimeoutSuggestion =>
      'Try again in a moment. If it keeps happening, the server may be overloaded or a firewall may be blocking it.';

  @override
  String get failureTlsTitle => 'Secure connection failed';

  @override
  String failureTlsExplanation(String host) {
    return 'This device does not trust the certificate of $host. It may be self-signed, issued for a different address, or expired.';
  }

  @override
  String get failureTlsSuggestion =>
      'If your server uses its own certificate authority, install its certificate in your device settings. Trusting self-signed certificates directly in the app is planned.';

  @override
  String get failureTlsSuggestionIos =>
      'If your server uses its own certificate authority, install its certificate profile, then turn on full trust for it under Settings › General › About › Certificate Trust Settings. Trusting self-signed certificates directly in the app is planned.';

  @override
  String failureTlsHandshakeExplanation(String host) {
    return '$host did not complete a secure (HTTPS) connection. The address may only speak plain http, or the server’s HTTPS setup is incomplete.';
  }

  @override
  String get failureTlsHandshakeSuggestion =>
      'Check the port and whether the address should start with http:// instead of https://. If HTTPS should work, check the reverse proxy’s TLS configuration.';

  @override
  String get failureNotVikunjaTitle => 'No Vikunja server found';

  @override
  String failureNotVikunjaExplanation(String host) {
    return '$host answered, but not like a Vikunja server.';
  }

  @override
  String get failureNotVikunjaSuggestion =>
      'Check the address. If Vikunja runs in a subfolder, include it, for example example.com/vikunja.';

  @override
  String get failureUnavailableTitle => 'Server temporarily unavailable';

  @override
  String failureUnavailableExplanation(String host) {
    return '$host answered with an error instead of Vikunja. Vikunja may be down, restarting or overloaded.';
  }

  @override
  String get failureUnavailableSuggestion =>
      'Try again in a few minutes. If it keeps happening, ask whoever runs the server to check on it.';

  @override
  String get failureLoginProxyTitle => 'Server is behind a login page';

  @override
  String failureLoginProxyExplanation(String host) {
    return 'A proxy in front of $host asks for its own sign-in before Vikunja can be reached.';
  }

  @override
  String get failureLoginProxySuggestion =>
      'Ask whoever runs the server to let the app reach the Vikunja API directly. Support for custom proxy headers, such as Cloudflare Access tokens, is planned.';

  @override
  String get failureUnexpectedTitle => 'Something went wrong';

  @override
  String get failureUnexpectedExplanation =>
      'An unexpected error occurred while connecting.';

  @override
  String get failureUnexpectedSuggestion => 'Try again in a moment.';

  @override
  String get insecureDialogTitle => 'Unencrypted connection';

  @override
  String insecureDialogBody(String host) {
    return '$host uses http:// instead of https://. Your password and tasks would travel unencrypted, and anyone on the same network could read or change them.\n\nOnly continue on a network you trust, such as your home network or a VPN.';
  }

  @override
  String get insecureDialogCancel => 'Cancel';

  @override
  String get insecureDialogContinue => 'Continue anyway';

  @override
  String get overviewTitle => 'Server found';

  @override
  String overviewVikunjaVersion(String version) {
    return 'Vikunja $version';
  }

  @override
  String get overviewVikunjaVersionUnknown => 'Vikunja, version unknown';

  @override
  String overviewApiBadge(String version) {
    return 'API $version';
  }

  @override
  String get overviewDemoBadge => 'Demo server';

  @override
  String get overviewInsecureBadge => 'Unencrypted';

  @override
  String get tierFullTitle => 'Fully supported';

  @override
  String get tierFullBody =>
      'This server offers the modern API, so all of the app\'s features work with it.';

  @override
  String get tierOauthTitle => 'Supported';

  @override
  String get tierOauthBody =>
      'The app works with this server. A few newer features need Vikunja 2.4 or newer.';

  @override
  String get tierOauthV2UnreachableBody =>
      'The app works with this server, but its newer API (/api/v2) could not be reached, so a few features are unavailable. A reverse proxy may be blocking it.';

  @override
  String get unsupportedTitle => 'This server is too old';

  @override
  String unsupportedBody(String minimum, String found) {
    return 'Rurana needs Vikunja $minimum or newer. This server runs $found.';
  }

  @override
  String get unsupportedSuggestion =>
      'Ask whoever runs the server to update Vikunja.';

  @override
  String get unsupportedUnknownVersionTitle => 'Server version not recognized';

  @override
  String unsupportedUnknownVersionBody(String minimum) {
    return 'Rurana needs Vikunja $minimum or newer. This server reports a version the app does not recognize.';
  }

  @override
  String get unsupportedUnknownVersionSuggestion =>
      'Ask whoever runs the server which Vikunja version it runs.';

  @override
  String get signInMethodsHeading => 'Sign-in methods';

  @override
  String get signInBrowserTitle => 'Browser sign-in';

  @override
  String get signInBrowserSubtitle =>
      'Uses the Vikunja login page, including single sign-on.';

  @override
  String signInBrowserProvidersSubtitle(String providers) {
    return 'Uses the Vikunja login page, including $providers.';
  }

  @override
  String get featuresHeading => 'Server features';

  @override
  String get featuresNone => 'This server has no optional features enabled.';

  @override
  String get featureAttachments => 'Attachments';

  @override
  String featureAttachmentsWithLimit(String size) {
    return 'Attachments up to $size';
  }

  @override
  String get featureComments => 'Comments';

  @override
  String get featureLinkSharing => 'Link sharing';

  @override
  String get featureTotp => 'Two-factor authentication (TOTP)';

  @override
  String get featureCaldav => 'CalDAV sync';

  @override
  String get featureWebhooks => 'Webhooks';

  @override
  String get featureEmailReminders => 'Email reminders';

  @override
  String get featureRegistration => 'Open registration';

  @override
  String get featurePublicTeams => 'Public teams';

  @override
  String get featureUserDeletion => 'Account deletion';

  @override
  String get featureBackgrounds => 'Project backgrounds';

  @override
  String get motdHeading => 'Message from the server';

  @override
  String get legalImprint => 'Imprint';

  @override
  String get legalPrivacy => 'Privacy policy';

  @override
  String get legalOpenFailed => 'The link could not be opened.';

  @override
  String get continueToSignIn => 'Continue to sign-in';

  @override
  String get useDifferentServer => 'Use a different server';

  @override
  String get signInWaiting => 'Waiting for sign-in…';

  @override
  String get signInRateLimitedTitle => 'Too many sign-in attempts';

  @override
  String signInRateLimitedExplanation(String host) {
    return '$host is limiting sign-ins from your network for now.';
  }

  @override
  String get signInRateLimitedSuggestion => 'Wait a minute, then try again.';

  @override
  String signInRateLimitedSuggestionSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Wait $_temp0, then try again.';
  }

  @override
  String signInRateLimitedSuggestionMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'Wait $_temp0, then try again.';
  }

  @override
  String signInServerErrorExplanation(String host, String status) {
    return '$host answered the sign-in with an error (HTTP $status).';
  }

  @override
  String get signInExpiredTitle => 'Sign-in expired';

  @override
  String get signInExpiredExplanation =>
      'The sign-in took too long or was already used once.';

  @override
  String get signInRetrySuggestion => 'Please sign in again.';

  @override
  String get signInRejectedTitle => 'Sign-in rejected';

  @override
  String signInRejectedExplanation(String host, String code) {
    return '$host did not accept the sign-in from this app (error $code).';
  }

  @override
  String get signInRejectedSuggestion =>
      'Try again. If it keeps happening, ask whoever runs the server to check it.';

  @override
  String get signInDiscardedTitle => 'Sign-in discarded';

  @override
  String get signInDiscardedExplanation =>
      'The browser returned a sign-in that doesn’t belong to this attempt, so the app discarded it to protect your account.';

  @override
  String get signInIncompleteTitle => 'Sign-in not completed';

  @override
  String get signInIncompleteExplanation =>
      'The browser returned to the app without a finished sign-in.';

  @override
  String get signInIncompleteSuggestion =>
      'Try again and finish signing in on the server’s page.';

  @override
  String get signInNoBrowserTitle => 'No browser available';

  @override
  String get signInNoBrowserExplanation =>
      'Signing in needs a web browser, but none is available on this device.';

  @override
  String get signInNoBrowserSuggestion =>
      'Install or enable a browser, then try again.';

  @override
  String get signInBrowserFailedTitle => 'Sign-in page couldn’t be opened';

  @override
  String get signInBrowserFailedExplanation =>
      'The app could not show the sign-in page of the server.';

  @override
  String get signInBrowserFailedSuggestion =>
      'Try again. If it keeps happening, restart the app.';

  @override
  String get signInAccountDisabledTitle => 'Account disabled';

  @override
  String signInAccountDisabledExplanation(String host) {
    return 'Your account on $host is disabled.';
  }

  @override
  String get signInAccountLockedTitle => 'Account locked';

  @override
  String signInAccountLockedExplanation(String host) {
    return 'Your account on $host is locked.';
  }

  @override
  String get signInAccountBlockedSuggestion =>
      'Check your email for instructions, or ask whoever runs the server.';

  @override
  String signInSessionEndedExplanation(String host) {
    return '$host ended the new session right away.';
  }

  @override
  String get signInEndpointMissingTitle => 'Sign-in not available';

  @override
  String signInEndpointMissingExplanation(String host) {
    return '$host does not answer at the sign-in address the app needs. A reverse proxy may be blocking it.';
  }

  @override
  String get signInEndpointMissingSuggestion =>
      'Ask whoever runs the server to make the whole Vikunja API reachable.';

  @override
  String get signInUnexpectedExplanation =>
      'An unexpected error occurred while signing in.';

  @override
  String get signInDifferentUserTitle => 'Signed in as a different user';

  @override
  String signInDifferentUserExplanation(String signedIn, String expected) {
    return 'The sign-in page signed you in as @$signedIn, but this account is @$expected. Nothing was changed.';
  }

  @override
  String signInDifferentUserSuggestion(String expected, String host) {
    return 'Sign in again as @$expected. If the browser signs you in on its own, sign out of $host in the browser first.';
  }

  @override
  String get homeTitle => 'Signed in';

  @override
  String homeUsername(String username) {
    return '@$username';
  }

  @override
  String get homePlaceholder =>
      'Your projects and tasks will appear here in a later version.';

  @override
  String get homeSignOut => 'Sign out';

  @override
  String get homeSigningOut => 'Signing out…';

  @override
  String get signOutDialogTitle => 'Sign out?';

  @override
  String signOutDialogBody(String host) {
    return 'Rurana will sign you out of $host. You can sign in again at any time.';
  }

  @override
  String get signOutDialogCancel => 'Cancel';

  @override
  String get signOutDialogConfirm => 'Sign out';

  @override
  String get reauthTitle => 'Signed out by the server';

  @override
  String reauthBody(String host) {
    return '$host ended your session. Sign in again to keep your tasks in sync. Nothing on this device is lost.';
  }

  @override
  String get reauthAction => 'Sign in again';
}
