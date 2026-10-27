import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
  ];

  /// Name of the app, shown in the task switcher and on the connect screen. A brand name: do not translate.
  ///
  /// In en, this message translates to:
  /// **'Rurana'**
  String get appTitle;

  /// No description provided for @connectTagline.
  ///
  /// In en, this message translates to:
  /// **'Your tasks from your own Vikunja server, right on your phone.'**
  String get connectTagline;

  /// No description provided for @connectAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get connectAddressLabel;

  /// No description provided for @connectAddressHint.
  ///
  /// In en, this message translates to:
  /// **'vikunja.example.com'**
  String get connectAddressHint;

  /// No description provided for @connectAddressHelper.
  ///
  /// In en, this message translates to:
  /// **'The address you open Vikunja with in your browser, for example https://vikunja.example.com'**
  String get connectAddressHelper;

  /// No description provided for @connectAddressEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of your Vikunja server.'**
  String get connectAddressEmpty;

  /// No description provided for @connectClearAddress.
  ///
  /// In en, this message translates to:
  /// **'Clear address'**
  String get connectClearAddress;

  /// No description provided for @connectContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get connectContinue;

  /// No description provided for @connectCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get connectCancel;

  /// No description provided for @connectConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectConnecting;

  /// No description provided for @connectConnectingTo.
  ///
  /// In en, this message translates to:
  /// **'Looking for Vikunja at {address} …'**
  String connectConnectingTo(String address);

  /// No description provided for @connectTryDemo.
  ///
  /// In en, this message translates to:
  /// **'Try the public demo'**
  String get connectTryDemo;

  /// No description provided for @failureInvalidAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'That doesn’t look like a server address'**
  String get failureInvalidAddressTitle;

  /// No description provided for @failureInvalidAddressExplanation.
  ///
  /// In en, this message translates to:
  /// **'“{input}” is not a web address the app can open.'**
  String failureInvalidAddressExplanation(String input);

  /// No description provided for @failureInvalidAddressSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Enter the address you use for Vikunja in your browser, for example vikunja.example.com.'**
  String get failureInvalidAddressSuggestion;

  /// No description provided for @failureUnreachableTitle.
  ///
  /// In en, this message translates to:
  /// **'Server not reachable'**
  String get failureUnreachableTitle;

  /// No description provided for @failureUnreachableExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} could not be reached. The address may be misspelled, the server may be offline, or your device has no internet connection.'**
  String failureUnreachableExplanation(String host);

  /// No description provided for @failureUnreachableSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check the address and your connection, then try again. If the server runs at home, connect to the same Wi-Fi or VPN first.'**
  String get failureUnreachableSuggestion;

  /// No description provided for @failureTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to answer'**
  String get failureTimeoutTitle;

  /// No description provided for @failureTimeoutExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} did not respond in time.'**
  String failureTimeoutExplanation(String host);

  /// No description provided for @failureTimeoutSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Try again in a moment. If it keeps happening, the server may be overloaded or a firewall may be blocking it.'**
  String get failureTimeoutSuggestion;

  /// No description provided for @failureTlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure connection failed'**
  String get failureTlsTitle;

  /// No description provided for @failureTlsExplanation.
  ///
  /// In en, this message translates to:
  /// **'This device does not trust the certificate of {host}. It may be self-signed, issued for a different address, or expired.'**
  String failureTlsExplanation(String host);

  /// No description provided for @failureTlsSuggestion.
  ///
  /// In en, this message translates to:
  /// **'If your server uses its own certificate authority, install its certificate in your device settings. Trusting self-signed certificates directly in the app is planned.'**
  String get failureTlsSuggestion;

  /// No description provided for @failureTlsSuggestionIos.
  ///
  /// In en, this message translates to:
  /// **'If your server uses its own certificate authority, install its certificate profile, then turn on full trust for it under Settings › General › About › Certificate Trust Settings. Trusting self-signed certificates directly in the app is planned.'**
  String get failureTlsSuggestionIos;

  /// No description provided for @failureTlsHandshakeExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} did not complete a secure (HTTPS) connection. The address may only speak plain http, or the server’s HTTPS setup is incomplete.'**
  String failureTlsHandshakeExplanation(String host);

  /// No description provided for @failureTlsHandshakeSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check the port and whether the address should start with http:// instead of https://. If HTTPS should work, check the reverse proxy’s TLS configuration.'**
  String get failureTlsHandshakeSuggestion;

  /// No description provided for @failureNotVikunjaTitle.
  ///
  /// In en, this message translates to:
  /// **'No Vikunja server found'**
  String get failureNotVikunjaTitle;

  /// No description provided for @failureNotVikunjaExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} answered, but not like a Vikunja server.'**
  String failureNotVikunjaExplanation(String host);

  /// No description provided for @failureNotVikunjaSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check the address. If Vikunja runs in a subfolder, include it, for example example.com/vikunja.'**
  String get failureNotVikunjaSuggestion;

  /// No description provided for @failureUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Server temporarily unavailable'**
  String get failureUnavailableTitle;

  /// No description provided for @failureUnavailableExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} answered with an error instead of Vikunja. Vikunja may be down, restarting or overloaded.'**
  String failureUnavailableExplanation(String host);

  /// No description provided for @failureUnavailableSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Try again in a few minutes. If it keeps happening, ask whoever runs the server to check on it.'**
  String get failureUnavailableSuggestion;

  /// No description provided for @failureLoginProxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Server is behind a login page'**
  String get failureLoginProxyTitle;

  /// No description provided for @failureLoginProxyExplanation.
  ///
  /// In en, this message translates to:
  /// **'A proxy in front of {host} asks for its own sign-in before Vikunja can be reached.'**
  String failureLoginProxyExplanation(String host);

  /// No description provided for @failureLoginProxySuggestion.
  ///
  /// In en, this message translates to:
  /// **'Ask whoever runs the server to let the app reach the Vikunja API directly. Support for custom proxy headers, such as Cloudflare Access tokens, is planned.'**
  String get failureLoginProxySuggestion;

  /// No description provided for @failureUnexpectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get failureUnexpectedTitle;

  /// No description provided for @failureUnexpectedExplanation.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while connecting.'**
  String get failureUnexpectedExplanation;

  /// No description provided for @failureUnexpectedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Try again in a moment.'**
  String get failureUnexpectedSuggestion;

  /// No description provided for @insecureDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted connection'**
  String get insecureDialogTitle;

  /// No description provided for @insecureDialogBody.
  ///
  /// In en, this message translates to:
  /// **'{host} uses http:// instead of https://. Your password and tasks would travel unencrypted, and anyone on the same network could read or change them.\n\nOnly continue on a network you trust, such as your home network or a VPN.'**
  String insecureDialogBody(String host);

  /// No description provided for @insecureDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get insecureDialogCancel;

  /// No description provided for @insecureDialogContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get insecureDialogContinue;

  /// No description provided for @overviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Server found'**
  String get overviewTitle;

  /// No description provided for @overviewVikunjaVersion.
  ///
  /// In en, this message translates to:
  /// **'Vikunja {version}'**
  String overviewVikunjaVersion(String version);

  /// No description provided for @overviewVikunjaVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Vikunja, version unknown'**
  String get overviewVikunjaVersionUnknown;

  /// No description provided for @overviewApiBadge.
  ///
  /// In en, this message translates to:
  /// **'API {version}'**
  String overviewApiBadge(String version);

  /// No description provided for @overviewDemoBadge.
  ///
  /// In en, this message translates to:
  /// **'Demo server'**
  String get overviewDemoBadge;

  /// No description provided for @overviewInsecureBadge.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted'**
  String get overviewInsecureBadge;

  /// No description provided for @tierFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Fully supported'**
  String get tierFullTitle;

  /// No description provided for @tierFullBody.
  ///
  /// In en, this message translates to:
  /// **'This server offers the modern API, so all of the app\'s features work with it.'**
  String get tierFullBody;

  /// No description provided for @tierOauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get tierOauthTitle;

  /// No description provided for @tierOauthBody.
  ///
  /// In en, this message translates to:
  /// **'The app works with this server. A few newer features need Vikunja 2.4 or newer.'**
  String get tierOauthBody;

  /// No description provided for @tierOauthV2UnreachableBody.
  ///
  /// In en, this message translates to:
  /// **'The app works with this server, but its newer API (/api/v2) could not be reached, so a few features are unavailable. A reverse proxy may be blocking it.'**
  String get tierOauthV2UnreachableBody;

  /// No description provided for @unsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'This server is too old'**
  String get unsupportedTitle;

  /// No description provided for @unsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'Rurana needs Vikunja {minimum} or newer. This server runs {found}.'**
  String unsupportedBody(String minimum, String found);

  /// No description provided for @unsupportedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Ask whoever runs the server to update Vikunja.'**
  String get unsupportedSuggestion;

  /// No description provided for @unsupportedUnknownVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Server version not recognized'**
  String get unsupportedUnknownVersionTitle;

  /// No description provided for @unsupportedUnknownVersionBody.
  ///
  /// In en, this message translates to:
  /// **'Rurana needs Vikunja {minimum} or newer. This server reports a version the app does not recognize.'**
  String unsupportedUnknownVersionBody(String minimum);

  /// No description provided for @unsupportedUnknownVersionSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Ask whoever runs the server which Vikunja version it runs.'**
  String get unsupportedUnknownVersionSuggestion;

  /// No description provided for @signInMethodsHeading.
  ///
  /// In en, this message translates to:
  /// **'Sign-in methods'**
  String get signInMethodsHeading;

  /// No description provided for @signInBrowserTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser sign-in'**
  String get signInBrowserTitle;

  /// No description provided for @signInBrowserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses the Vikunja login page, including single sign-on.'**
  String get signInBrowserSubtitle;

  /// No description provided for @signInBrowserProvidersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses the Vikunja login page, including {providers}.'**
  String signInBrowserProvidersSubtitle(String providers);

  /// No description provided for @featuresHeading.
  ///
  /// In en, this message translates to:
  /// **'Server features'**
  String get featuresHeading;

  /// No description provided for @featuresNone.
  ///
  /// In en, this message translates to:
  /// **'This server has no optional features enabled.'**
  String get featuresNone;

  /// No description provided for @featureAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get featureAttachments;

  /// No description provided for @featureAttachmentsWithLimit.
  ///
  /// In en, this message translates to:
  /// **'Attachments up to {size}'**
  String featureAttachmentsWithLimit(String size);

  /// No description provided for @featureComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get featureComments;

  /// No description provided for @featureLinkSharing.
  ///
  /// In en, this message translates to:
  /// **'Link sharing'**
  String get featureLinkSharing;

  /// No description provided for @featureTotp.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication (TOTP)'**
  String get featureTotp;

  /// No description provided for @featureCaldav.
  ///
  /// In en, this message translates to:
  /// **'CalDAV sync'**
  String get featureCaldav;

  /// No description provided for @featureWebhooks.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get featureWebhooks;

  /// No description provided for @featureEmailReminders.
  ///
  /// In en, this message translates to:
  /// **'Email reminders'**
  String get featureEmailReminders;

  /// No description provided for @featureRegistration.
  ///
  /// In en, this message translates to:
  /// **'Open registration'**
  String get featureRegistration;

  /// No description provided for @featurePublicTeams.
  ///
  /// In en, this message translates to:
  /// **'Public teams'**
  String get featurePublicTeams;

  /// Server capability shown in the feature list (noun), not an action.
  ///
  /// In en, this message translates to:
  /// **'Account deletion'**
  String get featureUserDeletion;

  /// No description provided for @featureBackgrounds.
  ///
  /// In en, this message translates to:
  /// **'Project backgrounds'**
  String get featureBackgrounds;

  /// No description provided for @motdHeading.
  ///
  /// In en, this message translates to:
  /// **'Message from the server'**
  String get motdHeading;

  /// No description provided for @legalImprint.
  ///
  /// In en, this message translates to:
  /// **'Imprint'**
  String get legalImprint;

  /// No description provided for @legalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legalPrivacy;

  /// No description provided for @legalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'The link could not be opened.'**
  String get legalOpenFailed;

  /// No description provided for @continueToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue to sign-in'**
  String get continueToSignIn;

  /// No description provided for @useDifferentServer.
  ///
  /// In en, this message translates to:
  /// **'Use a different server'**
  String get useDifferentServer;

  /// No description provided for @signInWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for sign-in…'**
  String get signInWaiting;

  /// No description provided for @signInRateLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-in attempts'**
  String get signInRateLimitedTitle;

  /// No description provided for @signInRateLimitedExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} is limiting sign-ins from your network for now.'**
  String signInRateLimitedExplanation(String host);

  /// No description provided for @signInRateLimitedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Wait a minute, then try again.'**
  String get signInRateLimitedSuggestion;

  /// No description provided for @signInRateLimitedSuggestionSeconds.
  ///
  /// In en, this message translates to:
  /// **'Wait {seconds, plural, =1{1 second} other{{seconds} seconds}}, then try again.'**
  String signInRateLimitedSuggestionSeconds(int seconds);

  /// No description provided for @signInRateLimitedSuggestionMinutes.
  ///
  /// In en, this message translates to:
  /// **'Wait {minutes, plural, =1{1 minute} other{{minutes} minutes}}, then try again.'**
  String signInRateLimitedSuggestionMinutes(int minutes);

  /// No description provided for @signInServerErrorExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} answered the sign-in with an error (HTTP {status}).'**
  String signInServerErrorExplanation(String host, String status);

  /// No description provided for @signInExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in expired'**
  String get signInExpiredTitle;

  /// No description provided for @signInExpiredExplanation.
  ///
  /// In en, this message translates to:
  /// **'The sign-in took too long or was already used once.'**
  String get signInExpiredExplanation;

  /// No description provided for @signInRetrySuggestion.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get signInRetrySuggestion;

  /// No description provided for @signInRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in rejected'**
  String get signInRejectedTitle;

  /// No description provided for @signInRejectedExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} did not accept the sign-in from this app (error {code}).'**
  String signInRejectedExplanation(String host, String code);

  /// No description provided for @signInRejectedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Try again. If it keeps happening, ask whoever runs the server to check it.'**
  String get signInRejectedSuggestion;

  /// No description provided for @signInDiscardedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in discarded'**
  String get signInDiscardedTitle;

  /// No description provided for @signInDiscardedExplanation.
  ///
  /// In en, this message translates to:
  /// **'The browser returned a sign-in that doesn’t belong to this attempt, so the app discarded it to protect your account.'**
  String get signInDiscardedExplanation;

  /// No description provided for @signInIncompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in not completed'**
  String get signInIncompleteTitle;

  /// No description provided for @signInIncompleteExplanation.
  ///
  /// In en, this message translates to:
  /// **'The browser returned to the app without a finished sign-in.'**
  String get signInIncompleteExplanation;

  /// No description provided for @signInIncompleteSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Try again and finish signing in on the server’s page.'**
  String get signInIncompleteSuggestion;

  /// No description provided for @signInNoBrowserTitle.
  ///
  /// In en, this message translates to:
  /// **'No browser available'**
  String get signInNoBrowserTitle;

  /// No description provided for @signInNoBrowserExplanation.
  ///
  /// In en, this message translates to:
  /// **'Signing in needs a web browser, but none is available on this device.'**
  String get signInNoBrowserExplanation;

  /// No description provided for @signInNoBrowserSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Install or enable a browser, then try again.'**
  String get signInNoBrowserSuggestion;

  /// No description provided for @signInBrowserFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in page couldn’t be opened'**
  String get signInBrowserFailedTitle;

  /// No description provided for @signInBrowserFailedExplanation.
  ///
  /// In en, this message translates to:
  /// **'The app could not show the sign-in page of the server.'**
  String get signInBrowserFailedExplanation;

  /// No description provided for @signInBrowserFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Try again. If it keeps happening, restart the app.'**
  String get signInBrowserFailedSuggestion;

  /// No description provided for @signInAccountDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Account disabled'**
  String get signInAccountDisabledTitle;

  /// No description provided for @signInAccountDisabledExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your account on {host} is disabled.'**
  String signInAccountDisabledExplanation(String host);

  /// No description provided for @signInAccountLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account locked'**
  String get signInAccountLockedTitle;

  /// No description provided for @signInAccountLockedExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your account on {host} is locked.'**
  String signInAccountLockedExplanation(String host);

  /// No description provided for @signInAccountBlockedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check your email for instructions, or ask whoever runs the server.'**
  String get signInAccountBlockedSuggestion;

  /// No description provided for @signInSessionEndedExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} ended the new session right away.'**
  String signInSessionEndedExplanation(String host);

  /// No description provided for @signInEndpointMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in not available'**
  String get signInEndpointMissingTitle;

  /// No description provided for @signInEndpointMissingExplanation.
  ///
  /// In en, this message translates to:
  /// **'{host} does not answer at the sign-in address the app needs. A reverse proxy may be blocking it.'**
  String signInEndpointMissingExplanation(String host);

  /// No description provided for @signInEndpointMissingSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Ask whoever runs the server to make the whole Vikunja API reachable.'**
  String get signInEndpointMissingSuggestion;

  /// No description provided for @signInUnexpectedExplanation.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while signing in.'**
  String get signInUnexpectedExplanation;

  /// No description provided for @signInDifferentUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed in as a different user'**
  String get signInDifferentUserTitle;

  /// No description provided for @signInDifferentUserExplanation.
  ///
  /// In en, this message translates to:
  /// **'The sign-in page signed you in as @{signedIn}, but this account is @{expected}. Nothing was changed.'**
  String signInDifferentUserExplanation(String signedIn, String expected);

  /// No description provided for @signInDifferentUserSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Sign in again as @{expected}. If the browser signs you in on its own, sign out of {host} in the browser first.'**
  String signInDifferentUserSuggestion(String expected, String host);

  /// No description provided for @homeSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get homeSignOut;

  /// No description provided for @homeSignOutOfThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this account'**
  String get homeSignOutOfThisAccount;

  /// No description provided for @homeSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get homeSigningOut;

  /// No description provided for @signOutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutDialogTitle;

  /// No description provided for @signOutDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Rurana will sign {account} out of {host} and delete this account’s tasks saved on this device. You can sign in again at any time.'**
  String signOutDialogBody(String account, String host);

  /// How the sign-out dialog names an account whose display name differs from its username.
  ///
  /// In en, this message translates to:
  /// **'{name} (@{username})'**
  String signOutDialogAccount(String name, String username);

  /// No description provided for @signOutDialogSwitchesTo.
  ///
  /// In en, this message translates to:
  /// **'Rurana then switches to {name}.'**
  String signOutDialogSwitchesTo(String name);

  /// No description provided for @signOutDialogPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One change has not been sent to the server yet and will be lost; tap Send now first to keep it.} other{{count} changes have not been sent to the server yet and will be lost; tap Send now first to keep them.}}'**
  String signOutDialogPendingChanges(int count);

  /// No description provided for @signOutDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get signOutDialogCancel;

  /// No description provided for @signOutDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutDialogConfirm;

  /// No description provided for @removeAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove account?'**
  String get removeAccountDialogTitle;

  /// No description provided for @removeAccountDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAccountDialogConfirm;

  /// No description provided for @removeAccountDialogPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One change has not been sent to the server yet and will be lost; switch to this account and tap Send now first to keep it.} other{{count} changes have not been sent to the server yet and will be lost; switch to this account and tap Send now first to keep them.}}'**
  String removeAccountDialogPendingChanges(int count);

  /// No description provided for @removeAccountDialogPendingChangesSignInFirst.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One change has not been sent to the server yet and will be lost; switch to this account, sign in again and tap Send now first to keep it.} other{{count} changes have not been sent to the server yet and will be lost; switch to this account, sign in again and tap Send now first to keep them.}}'**
  String removeAccountDialogPendingChangesSignInFirst(int count);

  /// No description provided for @reauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed out by the server'**
  String get reauthTitle;

  /// No description provided for @reauthBody.
  ///
  /// In en, this message translates to:
  /// **'{host} ended your session. Sign in again to keep your tasks in sync. Nothing on this device is lost.'**
  String reauthBody(String host);

  /// No description provided for @reauthAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get reauthAction;

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get tabProjects;

  /// No description provided for @tabAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tabAccount;

  /// No description provided for @accountsHeading.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsHeading;

  /// Screen reader label of the avatar button that opens the account switcher.
  ///
  /// In en, this message translates to:
  /// **'Accounts, signed in as {name} on {host}'**
  String accountSwitcherButton(String name, String host);

  /// No description provided for @accountCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get accountCurrent;

  /// No description provided for @accountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'@{username} · {host}'**
  String accountSubtitle(String username, String host);

  /// No description provided for @accountBadgeSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get accountBadgeSignInAgain;

  /// Badge on an account with changes that have not reached the server yet.
  ///
  /// In en, this message translates to:
  /// **'{count} unsent'**
  String accountBadgeUnsent(int count);

  /// No description provided for @accountAdd.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountAdd;

  /// No description provided for @accountManage.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts'**
  String get accountManage;

  /// No description provided for @accountMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More for {name}'**
  String accountMoreActions(String name);

  /// No description provided for @accountRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove…'**
  String get accountRemove;

  /// No description provided for @accountSwitchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String accountSwitchedTo(String name);

  /// No description provided for @accountSignedOutOf.
  ///
  /// In en, this message translates to:
  /// **'Signed out of {name}'**
  String accountSignedOutOf(String name);

  /// No description provided for @addAccountTagline.
  ///
  /// In en, this message translates to:
  /// **'Sign in with another account, on one of your servers or a new one.'**
  String get addAccountTagline;

  /// No description provided for @addAccountYourServers.
  ///
  /// In en, this message translates to:
  /// **'Your servers'**
  String get addAccountYourServers;

  /// No description provided for @addAccountAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'You’re already signed in to this account — switched to it'**
  String get addAccountAlreadyAdded;

  /// No description provided for @addAccountAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'You’re already signed in to this account'**
  String get addAccountAlreadyActive;

  /// No description provided for @overviewLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your tasks…'**
  String get overviewLoading;

  /// No description provided for @overviewEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get overviewEmptyTitle;

  /// No description provided for @overviewEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No open tasks right now. Enjoy the quiet, or add one with New task.'**
  String get overviewEmptyBody;

  /// No description provided for @sectionOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get sectionOverdue;

  /// No description provided for @sectionToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sectionToday;

  /// No description provided for @sectionNextSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get sectionNextSevenDays;

  /// No description provided for @sectionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get sectionLater;

  /// No description provided for @sectionNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get sectionNoDueDate;

  /// No description provided for @projectsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your projects…'**
  String get projectsLoading;

  /// No description provided for @projectsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get projectsEmptyTitle;

  /// No description provided for @projectsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create your first project to start adding tasks.'**
  String get projectsEmptyBody;

  /// No description provided for @projectsFavouritesHeading.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get projectsFavouritesHeading;

  /// The row of the Favorites list in the Favourites section of the Projects tab; the list's own title is projectFavouritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favourite tasks'**
  String get projectsFavouriteTasks;

  /// No description provided for @projectsAllHeading.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get projectsAllHeading;

  /// No description provided for @projectsShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived projects'**
  String get projectsShowArchived;

  /// Semantic label of the icon on an archived project in the project tree.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get projectArchived;

  /// No description provided for @projectArchivedNote.
  ///
  /// In en, this message translates to:
  /// **'This project is archived. It is not possible to create new or edit tasks for it.'**
  String get projectArchivedNote;

  /// No description provided for @savedFiltersHeading.
  ///
  /// In en, this message translates to:
  /// **'Saved filters'**
  String get savedFiltersHeading;

  /// App bar title of a saved filter's list while the filter is not among those the last sync saw.
  ///
  /// In en, this message translates to:
  /// **'Saved filter'**
  String get savedFilterUnknownTitle;

  /// Under the Favorites list in the Projects tab.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 open task} other{{count} open tasks}}'**
  String smartListOpenTaskCount(int count);

  /// Above a saved filter's list, which shows its last download.
  ///
  /// In en, this message translates to:
  /// **'The server applies this filter. Shown as of {when}; new tasks and changes made elsewhere appear after the next download.'**
  String smartListFilterNotice(String when);

  /// No description provided for @smartListFilterNotLoadedBody.
  ///
  /// In en, this message translates to:
  /// **'The server applies the saved filter “{title}”. Its tasks download when you open it online.'**
  String smartListFilterNotLoadedBody(String title);

  /// No description provided for @smartListFilterDownloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading this filter…'**
  String get smartListFilterDownloadingTitle;

  /// No description provided for @smartListFilterDownloadingBody.
  ///
  /// In en, this message translates to:
  /// **'The server applies the saved filter “{title}”. Its tasks are on their way.'**
  String smartListFilterDownloadingBody(String title);

  /// No description provided for @smartListFilterGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This saved filter is gone'**
  String get smartListFilterGoneTitle;

  /// No description provided for @smartListFilterGoneBody.
  ///
  /// In en, this message translates to:
  /// **'The last sync no longer found it. It may have been deleted on the web.'**
  String get smartListFilterGoneBody;

  /// No description provided for @smartListFilterDownloadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download this filter'**
  String get smartListFilterDownloadFailedTitle;

  /// No description provided for @smartListFilterDownloadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The server applies the saved filter “{title}”. Pull down to try again.'**
  String smartListFilterDownloadFailedBody(String title);

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No favourite tasks'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Mark a task as a favourite with its star to find it here.'**
  String get favoritesEmptyBody;

  /// No description provided for @appearanceHeading.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceHeading;

  /// No description provided for @appearanceSystemColors.
  ///
  /// In en, this message translates to:
  /// **'Use system colours'**
  String get appearanceSystemColors;

  /// Under the switch for Android's dynamic colours; the switch applies to the whole device.
  ///
  /// In en, this message translates to:
  /// **'The colours of your wallpaper instead of the app\'s blue'**
  String get appearanceSystemColorsSubtitle;

  /// No description provided for @appearanceLightDarkHint.
  ///
  /// In en, this message translates to:
  /// **'Light or dark is your account\'s colour scheme, in Account settings.'**
  String get appearanceLightDarkHint;

  /// No description provided for @projectChildCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subproject} other{{count} subprojects}}'**
  String projectChildCount(int count);

  /// Semantic label of the expand control in the project tree.
  ///
  /// In en, this message translates to:
  /// **'Show subprojects of {title}'**
  String projectExpand(String title);

  /// No description provided for @projectCollapse.
  ///
  /// In en, this message translates to:
  /// **'Hide subprojects of {title}'**
  String projectCollapse(String title);

  /// Screen reader action on a task of a list sorted manually (among the top-level tasks), on a project in the project tree (among its siblings) and on a kanban card (within its column): one place up.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @movedUp.
  ///
  /// In en, this message translates to:
  /// **'Moved up'**
  String get movedUp;

  /// Screen reader action on a task of a list sorted manually (among the top-level tasks), on a project in the project tree (among its siblings) and on a kanban card (within its column): one place down.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @movedDown.
  ///
  /// In en, this message translates to:
  /// **'Moved down'**
  String get movedDown;

  /// Screen reader action on a subproject in the project tree: it moves right after its parent, on the parent's level.
  ///
  /// In en, this message translates to:
  /// **'Move out of {project}'**
  String projectMoveOut(String project);

  /// No description provided for @projectMovedOut.
  ///
  /// In en, this message translates to:
  /// **'Moved out of {project}'**
  String projectMovedOut(String project);

  /// Screen reader action on a project in the project tree: it becomes the last subproject of the project right above it on its level.
  ///
  /// In en, this message translates to:
  /// **'Move into {project}'**
  String projectMoveInto(String project);

  /// Announced to screen readers once a project was moved under another one, by the action or by dragging it.
  ///
  /// In en, this message translates to:
  /// **'Moved into {project}'**
  String projectMovedInto(String project);

  /// Announced to screen readers once a subproject was dragged to the top level of the project tree.
  ///
  /// In en, this message translates to:
  /// **'Moved to the top level'**
  String get projectMovedToTopLevel;

  /// No description provided for @projectMoveNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Moving a project needs a connection to the server.'**
  String get projectMoveNeedsConnection;

  /// Announced to screen readers when a project is to be moved while the server has not yet confirmed the previous move; nothing moves.
  ///
  /// In en, this message translates to:
  /// **'A project is still being moved'**
  String get projectMoveWait;

  /// The server did not answer in time and may have moved the project anyway.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the move. Check your connection and pull down to refresh.'**
  String get projectMoveUnconfirmed;

  /// No description provided for @projectMoveAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only project admins can move a project under another one.'**
  String get projectMoveAdminOnly;

  /// No description provided for @projectMoveForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to move this project.'**
  String get projectMoveForbidden;

  /// No description provided for @projectMoveArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived projects can\'t be moved, and nothing can be moved into them.'**
  String get projectMoveArchived;

  /// The server refused the new parent: the project itself, one of its subprojects or a saved filter.
  ///
  /// In en, this message translates to:
  /// **'The project can\'t be moved there.'**
  String get projectMoveNotPossible;

  /// No description provided for @projectMoveGone.
  ///
  /// In en, this message translates to:
  /// **'The project or its new parent no longer exists.'**
  String get projectMoveGone;

  /// The server's own reason, untranslated, when the app has no words for it.
  ///
  /// In en, this message translates to:
  /// **'The server refused the move: {message}'**
  String projectMoveRefused(String message);

  /// No description provided for @projectMoveFailed.
  ///
  /// In en, this message translates to:
  /// **'The project couldn\'t be moved.'**
  String get projectMoveFailed;

  /// App bar title while the project of a task list is not in the local project list.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get projectUnknownTitle;

  /// Semantic label of the star shown on favourite projects and tasks.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get favouriteLabel;

  /// No description provided for @projectTasksLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading tasks…'**
  String get projectTasksLoading;

  /// No description provided for @projectTasksEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No open tasks'**
  String get projectTasksEmptyTitle;

  /// No description provided for @projectTasksEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Everything in this project is done. Turn on “Show done” to see them.'**
  String get projectTasksEmptyBody;

  /// No description provided for @projectTasksEmptyAllTitle.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get projectTasksEmptyAllTitle;

  /// No description provided for @projectTasksEmptyAllBody.
  ///
  /// In en, this message translates to:
  /// **'This project has no tasks yet.'**
  String get projectTasksEmptyAllBody;

  /// Tooltip of the overflow menu button.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;

  /// Tooltip of the refresh button in the app bar, the single-tap alternative to pull-to-refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @taskDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskDone;

  /// No description provided for @taskDueSemantics.
  ///
  /// In en, this message translates to:
  /// **'Due {when}'**
  String taskDueSemantics(String when);

  /// No description provided for @taskOverdueSemantics.
  ///
  /// In en, this message translates to:
  /// **'Overdue, due {when}'**
  String taskOverdueSemantics(String when);

  /// No description provided for @prioritySemantics.
  ///
  /// In en, this message translates to:
  /// **'Priority: {priority}'**
  String prioritySemantics(String priority);

  /// No description provided for @labelSemantics.
  ///
  /// In en, this message translates to:
  /// **'Label: {label}'**
  String labelSemantics(String label);

  /// No description provided for @priorityUnset.
  ///
  /// In en, this message translates to:
  /// **'Unset'**
  String get priorityUnset;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// No description provided for @priorityDoNow.
  ///
  /// In en, this message translates to:
  /// **'Do now'**
  String get priorityDoNow;

  /// No description provided for @relativeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get relativeNow;

  /// No description provided for @relativeInMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 minute} other{in {count} minutes}}'**
  String relativeInMinutes(int count);

  /// No description provided for @relativeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String relativeMinutesAgo(int count);

  /// No description provided for @relativeInHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 hour} other{in {count} hours}}'**
  String relativeInHours(int count);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String relativeHoursAgo(int count);

  /// No description provided for @relativeInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 day} other{in {count} days}}'**
  String relativeInDays(int count);

  /// No description provided for @relativeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String relativeDaysAgo(int count);

  /// No description provided for @relativeInMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 month} other{in {count} months}}'**
  String relativeInMonths(int count);

  /// No description provided for @relativeMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String relativeMonthsAgo(int count);

  /// No description provided for @relativeInYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 year} other{in {count} years}}'**
  String relativeInYears(int count);

  /// No description provided for @relativeYearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String relativeYearsAgo(int count);

  /// A moment less than a minute away, in either direction, once the user picked the relative date display on the web.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeJustNow;

  /// The web's long date displays: a written-out date and its time of day.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String momentDateAtTime(String date, String time);

  /// No description provided for @taskDetailDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get taskDetailDueDate;

  /// No description provided for @taskDetailStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get taskDetailStartDate;

  /// No description provided for @taskDetailEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get taskDetailEndDate;

  /// No description provided for @taskDetailPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskDetailPriority;

  /// No description provided for @taskDetailProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get taskDetailProgress;

  /// No description provided for @taskPercentDone.
  ///
  /// In en, this message translates to:
  /// **'{percent}% done'**
  String taskPercentDone(int percent);

  /// No description provided for @taskDetailLabels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get taskDetailLabels;

  /// No description provided for @taskDetailAssignees.
  ///
  /// In en, this message translates to:
  /// **'Assignees'**
  String get taskDetailAssignees;

  /// No description provided for @taskDetailReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get taskDetailReminders;

  /// No description provided for @taskDetailRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get taskDetailRepeat;

  /// No description provided for @taskDetailDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskDetailDescription;

  /// No description provided for @taskDetailNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get taskDetailNoDescription;

  /// No description provided for @taskDetailClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get taskDetailClose;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get repeatMonthly;

  /// No description provided for @repeatEverySeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every second} other{Every {count} seconds}}'**
  String repeatEverySeconds(int count);

  /// No description provided for @repeatEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every minute} other{Every {count} minutes}}'**
  String repeatEveryMinutes(int count);

  /// No description provided for @repeatEveryHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every hour} other{Every {count} hours}}'**
  String repeatEveryHours(int count);

  /// No description provided for @repeatEveryDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every day} other{Every {count} days}}'**
  String repeatEveryDays(int count);

  /// No description provided for @repeatEveryWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week} other{Every {count} weeks}}'**
  String repeatEveryWeeks(int count);

  /// No description provided for @repeatFromCompletion.
  ///
  /// In en, this message translates to:
  /// **'{repeat}, counted from completion'**
  String repeatFromCompletion(String repeat);

  /// No description provided for @periodSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String periodSeconds(int count);

  /// No description provided for @periodMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String periodMinutes(int count);

  /// No description provided for @periodHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String periodHours(int count);

  /// No description provided for @periodDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String periodDays(int count);

  /// No description provided for @periodWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String periodWeeks(int count);

  /// No description provided for @reminderBefore.
  ///
  /// In en, this message translates to:
  /// **'{period} before the {reference}'**
  String reminderBefore(String period, String reference);

  /// No description provided for @reminderAfter.
  ///
  /// In en, this message translates to:
  /// **'{period} after the {reference}'**
  String reminderAfter(String period, String reference);

  /// No description provided for @reminderAtReference.
  ///
  /// In en, this message translates to:
  /// **'At the {reference}'**
  String reminderAtReference(String reference);

  /// No description provided for @reminderReferenceDueDate.
  ///
  /// In en, this message translates to:
  /// **'due date'**
  String get reminderReferenceDueDate;

  /// No description provided for @reminderReferenceStartDate.
  ///
  /// In en, this message translates to:
  /// **'start date'**
  String get reminderReferenceStartDate;

  /// No description provided for @reminderReferenceEndDate.
  ///
  /// In en, this message translates to:
  /// **'end date'**
  String get reminderReferenceEndDate;

  /// No description provided for @dataFailureLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load from the server'**
  String get dataFailureLoadTitle;

  /// No description provided for @dataFailureRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t refresh'**
  String get dataFailureRefreshTitle;

  /// No description provided for @dataFailureStaleNote.
  ///
  /// In en, this message translates to:
  /// **'Showing what was loaded last.'**
  String get dataFailureStaleNote;

  /// No description provided for @dataFailureSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session on {host} has ended. Sign in again on the Account tab.'**
  String dataFailureSessionEnded(String host);

  /// No description provided for @dataFailureForbidden.
  ///
  /// In en, this message translates to:
  /// **'{host} refused the request. You may no longer have access to this.'**
  String dataFailureForbidden(String host);

  /// No description provided for @dataFailureNotFound.
  ///
  /// In en, this message translates to:
  /// **'{host} no longer has this. It may have been deleted.'**
  String dataFailureNotFound(String host);

  /// No description provided for @dataFailureRateLimited.
  ///
  /// In en, this message translates to:
  /// **'{host} is limiting requests from your network for now.'**
  String dataFailureRateLimited(String host);

  /// No description provided for @dataFailureUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while loading from {host}.'**
  String dataFailureUnexpected(String host);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @firstSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting your tasks'**
  String get firstSyncTitle;

  /// No description provided for @firstSyncBody.
  ///
  /// In en, this message translates to:
  /// **'Rurana is saving everything from {host} on this device, so it works offline too.'**
  String firstSyncBody(String host);

  /// No description provided for @firstSyncPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get firstSyncPreparing;

  /// No description provided for @firstSyncCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel and sign out'**
  String get firstSyncCancel;

  /// No description provided for @syncPhaseAccount.
  ///
  /// In en, this message translates to:
  /// **'Checking your account…'**
  String get syncPhaseAccount;

  /// No description provided for @syncPhaseProjects.
  ///
  /// In en, this message translates to:
  /// **'Loading projects…'**
  String get syncPhaseProjects;

  /// No description provided for @syncPhaseLabels.
  ///
  /// In en, this message translates to:
  /// **'Loading labels…'**
  String get syncPhaseLabels;

  /// No description provided for @syncPhaseTasks.
  ///
  /// In en, this message translates to:
  /// **'Loading tasks…'**
  String get syncPhaseTasks;

  /// No description provided for @syncPhaseArchivedTasks.
  ///
  /// In en, this message translates to:
  /// **'Loading archived projects…'**
  String get syncPhaseArchivedTasks;

  /// No description provided for @syncPhaseDelta.
  ///
  /// In en, this message translates to:
  /// **'Loading changes…'**
  String get syncPhaseDelta;

  /// No description provided for @syncPhaseReconcile.
  ///
  /// In en, this message translates to:
  /// **'Checking for deleted tasks…'**
  String get syncPhaseReconcile;

  /// No description provided for @syncPhaseFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing up…'**
  String get syncPhaseFinishing;

  /// No description provided for @syncProgressOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String syncProgressOfTotal(int done, int total);

  /// No description provided for @syncProgressCount.
  ///
  /// In en, this message translates to:
  /// **'{count} so far'**
  String syncProgressCount(int count);

  /// No description provided for @syncIndicatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Syncing with the server'**
  String get syncIndicatorLabel;

  /// No description provided for @offlineNotice.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing saved data'**
  String get offlineNotice;

  /// No description provided for @accountLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {when}'**
  String accountLastSynced(String when);

  /// No description provided for @accountLastSyncedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Synced just now'**
  String get accountLastSyncedJustNow;

  /// No description provided for @accountNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get accountNeverSynced;

  /// No description provided for @accountSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get accountSyncing;

  /// No description provided for @accountSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'The last sync failed.'**
  String get accountSyncFailed;

  /// No description provided for @accountSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get accountSyncNow;

  /// No description provided for @accountFullResync.
  ///
  /// In en, this message translates to:
  /// **'Full resync'**
  String get accountFullResync;

  /// When the background sync last ran for the account.
  ///
  /// In en, this message translates to:
  /// **'Background sync: {when}'**
  String accountBackgroundSync(String when);

  /// No description provided for @accountBackgroundSyncJustNow.
  ///
  /// In en, this message translates to:
  /// **'Background sync: just now'**
  String get accountBackgroundSyncJustNow;

  /// No description provided for @accountBackgroundSyncNever.
  ///
  /// In en, this message translates to:
  /// **'Background sync has not run yet'**
  String get accountBackgroundSyncNever;

  /// No description provided for @accountBackgroundSyncIosHint.
  ///
  /// In en, this message translates to:
  /// **'iOS decides when apps may sync in the background.'**
  String get accountBackgroundSyncIosHint;

  /// No description provided for @taskMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get taskMarkDone;

  /// No description provided for @taskMarkNotDone.
  ///
  /// In en, this message translates to:
  /// **'Mark not done'**
  String get taskMarkNotDone;

  /// No description provided for @taskMarkedDone.
  ///
  /// In en, this message translates to:
  /// **'Marked done'**
  String get taskMarkedDone;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @taskAddFavourite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get taskAddFavourite;

  /// No description provided for @taskRemoveFavourite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get taskRemoveFavourite;

  /// No description provided for @taskNotYetSynced.
  ///
  /// In en, this message translates to:
  /// **'Not yet synced'**
  String get taskNotYetSynced;

  /// No description provided for @taskDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get taskDelete;

  /// No description provided for @taskDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get taskDeleteDialogTitle;

  /// No description provided for @taskDeleteDialogBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be deleted on the server too. This cannot be undone.'**
  String taskDeleteDialogBody(String title);

  /// No description provided for @taskDeleteDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get taskDeleteDialogCancel;

  /// No description provided for @taskDeleteDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get taskDeleteDialogConfirm;

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// No description provided for @accountPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'Pending changes: {count}'**
  String accountPendingChanges(int count);

  /// No description provided for @accountSendNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get accountSendNow;

  /// No description provided for @accountSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get accountSending;

  /// No description provided for @accountSendNowFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent. {reason}'**
  String accountSendNowFailed(String reason);

  /// No description provided for @accountSyncProblems.
  ///
  /// In en, this message translates to:
  /// **'Sync problems'**
  String get accountSyncProblems;

  /// No description provided for @syncProblemUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'The change could not be saved.'**
  String get syncProblemUpdateFailed;

  /// No description provided for @syncProblemDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The task could not be deleted.'**
  String get syncProblemDeleteFailed;

  /// No description provided for @syncProblemForbidden.
  ///
  /// In en, this message translates to:
  /// **'You no longer have access to its project.'**
  String get syncProblemForbidden;

  /// No description provided for @syncProblemProjectMissing.
  ///
  /// In en, this message translates to:
  /// **'Its project no longer exists on the server.'**
  String get syncProblemProjectMissing;

  /// No description provided for @syncProblemTaskMissing.
  ///
  /// In en, this message translates to:
  /// **'The task no longer exists on the server.'**
  String get syncProblemTaskMissing;

  /// No description provided for @syncProblemLabelMissing.
  ///
  /// In en, this message translates to:
  /// **'One of its labels no longer exists on the server.'**
  String get syncProblemLabelMissing;

  /// No description provided for @syncProblemUserMissing.
  ///
  /// In en, this message translates to:
  /// **'One of its assignees no longer exists on the server.'**
  String get syncProblemUserMissing;

  /// No description provided for @syncProblemProjectArchived.
  ///
  /// In en, this message translates to:
  /// **'Its project is archived.'**
  String get syncProblemProjectArchived;

  /// No description provided for @syncProblemRelatedTaskMissing.
  ///
  /// In en, this message translates to:
  /// **'A task it is related to no longer exists on the server.'**
  String get syncProblemRelatedTaskMissing;

  /// No description provided for @syncProblemRelationCycle.
  ///
  /// In en, this message translates to:
  /// **'The relation would make the tasks depend on each other in a loop.'**
  String get syncProblemRelationCycle;

  /// No description provided for @syncProblemRelationToItself.
  ///
  /// In en, this message translates to:
  /// **'A task cannot be related to itself.'**
  String get syncProblemRelationToItself;

  /// No description provided for @syncProblemColumnFull.
  ///
  /// In en, this message translates to:
  /// **'This column is full.'**
  String get syncProblemColumnFull;

  /// No description provided for @syncProblemColumnMissing.
  ///
  /// In en, this message translates to:
  /// **'The column no longer exists.'**
  String get syncProblemColumnMissing;

  /// No description provided for @syncProblemListNotReorderable.
  ///
  /// In en, this message translates to:
  /// **'This list can\'t be reordered.'**
  String get syncProblemListNotReorderable;

  /// No description provided for @syncProblemListMissing.
  ///
  /// In en, this message translates to:
  /// **'The list no longer exists.'**
  String get syncProblemListMissing;

  /// No description provided for @syncProblemRejected.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the change.'**
  String get syncProblemRejected;

  /// No description provided for @syncProblemUnexpected.
  ///
  /// In en, this message translates to:
  /// **'The server answered in an unexpected way.'**
  String get syncProblemUnexpected;

  /// No description provided for @syncProblemFailedAt.
  ///
  /// In en, this message translates to:
  /// **'Failed {when}'**
  String syncProblemFailedAt(String when);

  /// No description provided for @syncProblemFailedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Failed just now'**
  String get syncProblemFailedJustNow;

  /// No description provided for @syncProblemDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get syncProblemDiscard;

  /// No description provided for @syncProblemCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'The task could not be created.'**
  String get syncProblemCreateFailed;

  /// No description provided for @taskEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get taskEdit;

  /// No description provided for @taskEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get taskEditTitle;

  /// No description provided for @taskEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get taskEditSave;

  /// No description provided for @taskEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get taskEditSaved;

  /// No description provided for @taskEditLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading task…'**
  String get taskEditLoading;

  /// No description provided for @taskEditGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Task not found'**
  String get taskEditGoneTitle;

  /// No description provided for @taskEditGoneBody.
  ///
  /// In en, this message translates to:
  /// **'This task is no longer on this device.'**
  String get taskEditGoneBody;

  /// No description provided for @taskEditTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taskEditTitleLabel;

  /// No description provided for @taskEditTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title.'**
  String get taskEditTitleRequired;

  /// No description provided for @taskEditProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get taskEditProject;

  /// No description provided for @taskEditProjectPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a project'**
  String get taskEditProjectPickerTitle;

  /// No description provided for @taskEditProjectSemantics.
  ///
  /// In en, this message translates to:
  /// **'Project: {project}'**
  String taskEditProjectSemantics(String project);

  /// No description provided for @taskEditDateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get taskEditDateNotSet;

  /// No description provided for @taskEditClearDueDate.
  ///
  /// In en, this message translates to:
  /// **'Clear due date'**
  String get taskEditClearDueDate;

  /// No description provided for @taskEditClearStartDate.
  ///
  /// In en, this message translates to:
  /// **'Clear start date'**
  String get taskEditClearStartDate;

  /// No description provided for @taskEditClearEndDate.
  ///
  /// In en, this message translates to:
  /// **'Clear end date'**
  String get taskEditClearEndDate;

  /// No description provided for @shortcutToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get shortcutToday;

  /// No description provided for @shortcutTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get shortcutTomorrow;

  /// No description provided for @shortcutNextMonday.
  ///
  /// In en, this message translates to:
  /// **'Next Monday'**
  String get shortcutNextMonday;

  /// No description provided for @shortcutThisWeekend.
  ///
  /// In en, this message translates to:
  /// **'This weekend'**
  String get shortcutThisWeekend;

  /// No description provided for @shortcutLaterThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Later this week'**
  String get shortcutLaterThisWeek;

  /// No description provided for @shortcutNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get shortcutNextWeek;

  /// No description provided for @shortcutNextWeekend.
  ///
  /// In en, this message translates to:
  /// **'Next weekend'**
  String get shortcutNextWeekend;

  /// No description provided for @shortcutEndOfMonth.
  ///
  /// In en, this message translates to:
  /// **'End of month'**
  String get shortcutEndOfMonth;

  /// No description provided for @shortcutInAMonth.
  ///
  /// In en, this message translates to:
  /// **'In a month'**
  String get shortcutInAMonth;

  /// A date shortcut chip read out with the day it stands for.
  ///
  /// In en, this message translates to:
  /// **'{label}, {date}'**
  String shortcutSemantics(String label, String date);

  /// No description provided for @taskEditColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get taskEditColour;

  /// No description provided for @taskEditNoColour.
  ///
  /// In en, this message translates to:
  /// **'No colour'**
  String get taskEditNoColour;

  /// No description provided for @taskEditColourSemantics.
  ///
  /// In en, this message translates to:
  /// **'Colour {hex}'**
  String taskEditColourSemantics(String hex);

  /// No description provided for @taskEditRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get taskEditRepeat;

  /// No description provided for @repeatModeNone.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get repeatModeNone;

  /// No description provided for @repeatModeEvery.
  ///
  /// In en, this message translates to:
  /// **'Every…'**
  String get repeatModeEvery;

  /// No description provided for @repeatModeMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatModeMonthly;

  /// No description provided for @repeatModeFromCompletion.
  ///
  /// In en, this message translates to:
  /// **'From completion'**
  String get repeatModeFromCompletion;

  /// No description provided for @repeatAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get repeatAmountLabel;

  /// No description provided for @repeatAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter more than 0.'**
  String get repeatAmountInvalid;

  /// No description provided for @repeatUnitHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get repeatUnitHours;

  /// No description provided for @repeatUnitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get repeatUnitDays;

  /// No description provided for @repeatUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get repeatUnitWeeks;

  /// No description provided for @repeatPresetDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatPresetDaily;

  /// No description provided for @repeatPresetWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeatPresetWeekly;

  /// No description provided for @repeatPresetThirtyDays.
  ///
  /// In en, this message translates to:
  /// **'Every 30 days'**
  String get repeatPresetThirtyDays;

  /// No description provided for @taskEditDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get taskEditDiscardTitle;

  /// No description provided for @taskEditDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits to this task will be lost.'**
  String get taskEditDiscardBody;

  /// No description provided for @taskEditKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get taskEditKeepEditing;

  /// No description provided for @taskEditDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get taskEditDiscard;

  /// No description provided for @pickerDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get pickerDone;

  /// No description provided for @pickerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get pickerCancel;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @newTaskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'What needs doing?'**
  String get newTaskTitleHint;

  /// No description provided for @newTaskAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get newTaskAdd;

  /// No description provided for @newTaskMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get newTaskMoreOptions;

  /// No description provided for @newTaskPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date…'**
  String get newTaskPickDate;

  /// No description provided for @newTaskNoProject.
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get newTaskNoProject;

  /// No description provided for @newTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Added “{title}”'**
  String newTaskCreated(String title);

  /// The Add button once several lines are pasted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 task} other{Add {count} tasks}}'**
  String newTaskAddMany(int count);

  /// No description provided for @newTaskCreatedMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 task} other{Added {count} tasks}}'**
  String newTaskCreatedMany(int count);

  /// No description provided for @newTaskLabelsNotCreated.
  ///
  /// In en, this message translates to:
  /// **'These labels could not be created and were not added: {labels}'**
  String newTaskLabelsNotCreated(String labels);

  /// No description provided for @newTaskNamesKept.
  ///
  /// In en, this message translates to:
  /// **'Nobody found for {names}, so they stay in the title.'**
  String newTaskNamesKept(String names);

  /// No description provided for @newTaskNoProjectError.
  ///
  /// In en, this message translates to:
  /// **'There\'s no project to add tasks to yet. Create one on the web first.'**
  String get newTaskNoProjectError;

  /// No description provided for @newTaskAddFailed.
  ///
  /// In en, this message translates to:
  /// **'The task could not be added: {reason}'**
  String newTaskAddFailed(String reason);

  /// No description provided for @newTaskAddFailedUnknown.
  ///
  /// In en, this message translates to:
  /// **'The task could not be added.'**
  String get newTaskAddFailedUnknown;

  /// Above the preview once several lines are pasted and the first line has nothing to preview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks, one per line}}'**
  String newTaskLineCountOnly(int count);

  /// Error under the field when adding several lines failed partway; the lines added are removed from the text.
  ///
  /// In en, this message translates to:
  /// **'{added} of {total} tasks were added; the others are still here.'**
  String newTaskAddedPartly(int added, int total);

  /// Above the preview of the first line once several lines are pasted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks, one per line}} · the first one:'**
  String newTaskLineCount(int count);

  /// No description provided for @quickAddMagicOnly.
  ///
  /// In en, this message translates to:
  /// **'Only magic words, so nothing is recognised: the task will be called “{title}”.'**
  String quickAddMagicOnly(String title);

  /// No description provided for @quickAddDueLabel.
  ///
  /// In en, this message translates to:
  /// **'{date} · {relative}'**
  String quickAddDueLabel(String date, String relative);

  /// No description provided for @quickAddDueSemantics.
  ///
  /// In en, this message translates to:
  /// **'Due {date}, {relative}'**
  String quickAddDueSemantics(String date, String relative);

  /// No description provided for @quickAddRepeatSemantics.
  ///
  /// In en, this message translates to:
  /// **'Repeats: {repeat}'**
  String quickAddRepeatSemantics(String repeat);

  /// Warning chip for a +project whose title several projects share and that nothing else tells apart; the first is used.
  ///
  /// In en, this message translates to:
  /// **'Several projects are called “{project}”. Remove it and choose the project below.'**
  String quickAddProjectAmbiguous(String project);

  /// Warning chip for a +project that matches no project; the text stays in the title.
  ///
  /// In en, this message translates to:
  /// **'Project “{project}” not found'**
  String quickAddProjectNotFound(String project);

  /// No description provided for @quickAddNewLabel.
  ///
  /// In en, this message translates to:
  /// **'{label} · new'**
  String quickAddNewLabel(String label);

  /// No description provided for @quickAddNewLabelSemantics.
  ///
  /// In en, this message translates to:
  /// **'New label {label}, created when you add the task'**
  String quickAddNewLabelSemantics(String label);

  /// No description provided for @quickAddAssigneeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Assigned to {name}'**
  String quickAddAssigneeSemantics(String name);

  /// A person not found on this device yet; the server is searched when the task is added.
  ///
  /// In en, this message translates to:
  /// **'{name} · will be looked up'**
  String quickAddLookedUp(String name);

  /// No description provided for @quickAddLookedUpSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, will be looked up when you add the task'**
  String quickAddLookedUpSemantics(String name);

  /// No description provided for @quickAddReminderSemantics.
  ///
  /// In en, this message translates to:
  /// **'Reminder: {reminder}'**
  String quickAddReminderSemantics(String reminder);

  /// Tooltip and screen reader name of the remove button on a quick-add preview chip; removes that part from the text.
  ///
  /// In en, this message translates to:
  /// **'Remove {part}'**
  String quickAddRemovePart(String part);

  /// No description provided for @quickAddSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get quickAddSuggestions;

  /// No description provided for @quickAddInsertLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a label ({prefix})'**
  String quickAddInsertLabel(String prefix);

  /// No description provided for @quickAddInsertProject.
  ///
  /// In en, this message translates to:
  /// **'Choose a project ({prefix})'**
  String quickAddInsertProject(String prefix);

  /// No description provided for @quickAddInsertAssignee.
  ///
  /// In en, this message translates to:
  /// **'Assign someone ({prefix})'**
  String quickAddInsertAssignee(String prefix);

  /// No description provided for @quickAddSetPriority.
  ///
  /// In en, this message translates to:
  /// **'Set priority ({prefix})'**
  String quickAddSetPriority(String prefix);

  /// No description provided for @quickAddHelp.
  ///
  /// In en, this message translates to:
  /// **'How Quick Add Magic works'**
  String get quickAddHelp;

  /// No description provided for @quickAddHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Add Magic'**
  String get quickAddHelpTitle;

  /// No description provided for @quickAddHelpIntro.
  ///
  /// In en, this message translates to:
  /// **'Write the whole task in one line. These parts are recognised, marked in colour and taken out of the title:'**
  String get quickAddHelpIntro;

  /// No description provided for @quickAddHelpLabelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get quickAddHelpLabelsTitle;

  /// No description provided for @quickAddHelpLabelsBody.
  ///
  /// In en, this message translates to:
  /// **'A word starting with {prefix}. Labels that don\'t exist yet are created when you add the task. Use quotes for spaces.'**
  String quickAddHelpLabelsBody(String prefix);

  /// No description provided for @quickAddHelpProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get quickAddHelpProjectTitle;

  /// No description provided for @quickAddHelpProjectBody.
  ///
  /// In en, this message translates to:
  /// **'{prefix} and a project\'s title or identifier. Without one, the task goes to the project shown below the field.'**
  String quickAddHelpProjectBody(String prefix);

  /// No description provided for @quickAddHelpPriorityTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get quickAddHelpPriorityTitle;

  /// No description provided for @quickAddHelpPriorityBody.
  ///
  /// In en, this message translates to:
  /// **'{prefix} and a number from 1 (low) to 5 (do now).'**
  String quickAddHelpPriorityBody(String prefix);

  /// No description provided for @quickAddHelpPeopleTitle.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get quickAddHelpPeopleTitle;

  /// No description provided for @quickAddHelpPeopleBody.
  ///
  /// In en, this message translates to:
  /// **'{prefix} and a username or name. Anyone who isn\'t found stays in the title.'**
  String quickAddHelpPeopleBody(String prefix);

  /// No description provided for @quickAddHelpDatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Dates and times'**
  String get quickAddHelpDatesTitle;

  /// No description provided for @quickAddHelpDatesBody.
  ///
  /// In en, this message translates to:
  /// **'For example:'**
  String get quickAddHelpDatesBody;

  /// No description provided for @quickAddHelpTimesBody.
  ///
  /// In en, this message translates to:
  /// **'Add a time with “at”:'**
  String get quickAddHelpTimesBody;

  /// No description provided for @quickAddHelpRepeatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get quickAddHelpRepeatsTitle;

  /// No description provided for @quickAddHelpRepeatsBody.
  ///
  /// In en, this message translates to:
  /// **'A repeat without a date makes the task due today.'**
  String get quickAddHelpRepeatsBody;

  /// No description provided for @quickAddHelpEnglish.
  ///
  /// In en, this message translates to:
  /// **'Date and repeat words are always English, as on the web.'**
  String get quickAddHelpEnglish;

  /// No description provided for @quickAddHelpMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get quickAddHelpMoreTitle;

  /// No description provided for @quickAddHelpQuotes.
  ///
  /// In en, this message translates to:
  /// **'Put the whole title in quotes to switch the magic off for one task.'**
  String get quickAddHelpQuotes;

  /// No description provided for @quickAddHelpLines.
  ///
  /// In en, this message translates to:
  /// **'Paste several lines to add one task per line.'**
  String get quickAddHelpLines;

  /// No description provided for @quickAddHelpExampleTitle.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get quickAddHelpExampleTitle;

  /// The title part of the example line in the quick-add help.
  ///
  /// In en, this message translates to:
  /// **'Change tyres'**
  String get quickAddHelpExampleTask;

  /// A label title in the example line; one word.
  ///
  /// In en, this message translates to:
  /// **'car'**
  String get quickAddHelpExampleLabel;

  /// A project title in the example line; one word.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get quickAddHelpExampleProject;

  /// No description provided for @quickAddHelpMode.
  ///
  /// In en, this message translates to:
  /// **'These are the {mode} prefixes, as set in your account settings.'**
  String quickAddHelpMode(String mode);

  /// No description provided for @taskEditAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add label'**
  String get taskEditAddLabel;

  /// No description provided for @taskEditRemoveLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove label {label}'**
  String taskEditRemoveLabel(String label);

  /// No description provided for @taskEditAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get taskEditAssign;

  /// No description provided for @taskEditUnassign.
  ///
  /// In en, this message translates to:
  /// **'Unassign {name}'**
  String taskEditUnassign(String name);

  /// No description provided for @taskEditAddReminder.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get taskEditAddReminder;

  /// No description provided for @taskEditEditReminder.
  ///
  /// In en, this message translates to:
  /// **'Edit reminder'**
  String get taskEditEditReminder;

  /// No description provided for @taskEditRemoveReminder.
  ///
  /// In en, this message translates to:
  /// **'Remove reminder: {reminder}'**
  String taskEditRemoveReminder(String reminder);

  /// No description provided for @taskEditReminderDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This reminder is already set.'**
  String get taskEditReminderDuplicate;

  /// No description provided for @reminderDueDateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Due date is not set'**
  String get reminderDueDateNotSet;

  /// No description provided for @reminderStartDateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Start date is not set'**
  String get reminderStartDateNotSet;

  /// No description provided for @reminderEndDateNotSet.
  ///
  /// In en, this message translates to:
  /// **'End date is not set'**
  String get reminderEndDateNotSet;

  /// No description provided for @taskEditRemindersCoincide.
  ///
  /// In en, this message translates to:
  /// **'Some reminders fall on the same moment. The server keeps only one of them.'**
  String get taskEditRemindersCoincide;

  /// No description provided for @labelPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose labels'**
  String get labelPickerTitle;

  /// No description provided for @labelPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search or create a label'**
  String get labelPickerSearch;

  /// No description provided for @labelPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No labels yet. Type a name to create one.'**
  String get labelPickerEmpty;

  /// No description provided for @labelPickerCreate.
  ///
  /// In en, this message translates to:
  /// **'Create label “{title}”'**
  String labelPickerCreate(String title);

  /// No description provided for @labelPickerCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating the label…'**
  String get labelPickerCreating;

  /// No description provided for @labelPickerCreateOffline.
  ///
  /// In en, this message translates to:
  /// **'Creating a label needs a connection to the server.'**
  String get labelPickerCreateOffline;

  /// No description provided for @labelPickerCreateUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm that the label was created. Check your connection and try again.'**
  String get labelPickerCreateUnconfirmed;

  /// No description provided for @labelPickerCreateRejected.
  ///
  /// In en, this message translates to:
  /// **'The server did not create the label: {message}'**
  String labelPickerCreateRejected(String message);

  /// No description provided for @labelPickerCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'The label could not be created.'**
  String get labelPickerCreateFailed;

  /// No description provided for @labelPickerTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'A label title can have at most {max} characters.'**
  String labelPickerTitleTooLong(int max);

  /// No description provided for @assigneePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign people'**
  String get assigneePickerTitle;

  /// No description provided for @assigneePickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get assigneePickerSearch;

  /// No description provided for @assigneePickerSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get assigneePickerSearching;

  /// No description provided for @assigneePickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nobody found.'**
  String get assigneePickerNoResults;

  /// No description provided for @assigneePickerOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing people from your synced tasks'**
  String get assigneePickerOffline;

  /// After a search that failed for another reason than a missing connection; the reason is the server's message or assigneePickerSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'{reason} — showing people from your synced tasks'**
  String assigneePickerFallback(String reason);

  /// No description provided for @assigneePickerSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get assigneePickerSearchFailed;

  /// No description provided for @assigneeUsername.
  ///
  /// In en, this message translates to:
  /// **'@{username}'**
  String assigneeUsername(String username);

  /// No description provided for @reminderPickerCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get reminderPickerCustom;

  /// No description provided for @reminderPickerDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date and time…'**
  String get reminderPickerDateTime;

  /// No description provided for @reminderPickerAlreadySet.
  ///
  /// In en, this message translates to:
  /// **'Already set'**
  String get reminderPickerAlreadySet;

  /// No description provided for @reminderPickerNoDateHint.
  ///
  /// In en, this message translates to:
  /// **'Set a due, start or end date to get quick choices here.'**
  String get reminderPickerNoDateHint;

  /// No description provided for @reminderPickerCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom reminder'**
  String get reminderPickerCustomTitle;

  /// No description provided for @reminderAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get reminderAmountLabel;

  /// No description provided for @reminderAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number, 0 or more.'**
  String get reminderAmountInvalid;

  /// No description provided for @reminderUnitCaption.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get reminderUnitCaption;

  /// No description provided for @reminderDirectionCaption.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get reminderDirectionCaption;

  /// No description provided for @reminderUnitMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get reminderUnitMinutes;

  /// No description provided for @reminderUnitHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get reminderUnitHours;

  /// No description provided for @reminderUnitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get reminderUnitDays;

  /// No description provided for @reminderUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get reminderUnitWeeks;

  /// No description provided for @reminderDirectionBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get reminderDirectionBefore;

  /// No description provided for @reminderDirectionAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get reminderDirectionAfter;

  /// No description provided for @reminderRelativeToLabel.
  ///
  /// In en, this message translates to:
  /// **'Relative to'**
  String get reminderRelativeToLabel;

  /// No description provided for @reminderRelativeToDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get reminderRelativeToDueDate;

  /// No description provided for @reminderRelativeToStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get reminderRelativeToStartDate;

  /// No description provided for @reminderRelativeToEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get reminderRelativeToEndDate;

  /// No description provided for @reminderRelativeToUnset.
  ///
  /// In en, this message translates to:
  /// **'{date} (not set)'**
  String reminderRelativeToUnset(String date);

  /// No description provided for @inboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get inboxTitle;

  /// Screen reader label of the bell on the Overview and of the notifications item in Upcoming's menu.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Notifications} =1{Notifications, 1 unread} other{Notifications, {count} unread}}'**
  String inboxButton(int count);

  /// No description provided for @inboxLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications…'**
  String get inboxLoading;

  /// No description provided for @inboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You’re all caught up'**
  String get inboxEmptyTitle;

  /// No description provided for @inboxEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Comments, assignments and mentions from your Vikunja server show up here.'**
  String get inboxEmptyBody;

  /// No description provided for @inboxMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get inboxMarkAllRead;

  /// No description provided for @inboxToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get inboxToday;

  /// No description provided for @inboxYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get inboxYesterday;

  /// No description provided for @inboxEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get inboxEarlier;

  /// Screen reader label of the dot on an unread notification.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get inboxUnread;

  /// No description provided for @inboxTaskNotLocal.
  ///
  /// In en, this message translates to:
  /// **'This task is not on this device'**
  String get inboxTaskNotLocal;

  /// No description provided for @inboxProjectNotLocal.
  ///
  /// In en, this message translates to:
  /// **'This project is not on this device'**
  String get inboxProjectNotLocal;

  /// Stands in for the person who did something when the server did not say who.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get inboxSomeone;

  /// Stands in for a task without an identifier or title, as in “Anna commented on a task”.
  ///
  /// In en, this message translates to:
  /// **'a task'**
  String get inboxATask;

  /// Stands in for a project or team without a name.
  ///
  /// In en, this message translates to:
  /// **'unnamed'**
  String get inboxUnnamed;

  /// A comment on a task, named by its identifier, e.g. #12 or PROJ-12.
  ///
  /// In en, this message translates to:
  /// **'{doer} commented on {task}'**
  String inboxCommented(String doer, String task);

  /// No description provided for @inboxAssignedYou.
  ///
  /// In en, this message translates to:
  /// **'{doer} assigned you to {task}'**
  String inboxAssignedYou(String doer, String task);

  /// No description provided for @inboxAssigned.
  ///
  /// In en, this message translates to:
  /// **'{doer} assigned {assignee} to {task}'**
  String inboxAssigned(String doer, String assignee, String task);

  /// Inbox row for an assignment whose assignee has no name in the server's payload.
  ///
  /// In en, this message translates to:
  /// **'{doer} assigned someone to {task}'**
  String inboxAssignedSomeone(String doer, String task);

  /// No description provided for @inboxMentioned.
  ///
  /// In en, this message translates to:
  /// **'{doer} mentioned you on {task}'**
  String inboxMentioned(String doer, String task);

  /// No description provided for @inboxTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'{doer} created {task}'**
  String inboxTaskCreated(String doer, String task);

  /// No description provided for @inboxTaskDeleted.
  ///
  /// In en, this message translates to:
  /// **'{doer} deleted {task}'**
  String inboxTaskDeleted(String doer, String task);

  /// No description provided for @inboxProjectCreated.
  ///
  /// In en, this message translates to:
  /// **'{doer} created {project}'**
  String inboxProjectCreated(String doer, String project);

  /// No description provided for @inboxAddedYouToTeam.
  ///
  /// In en, this message translates to:
  /// **'{doer} added you to the {team} team'**
  String inboxAddedYouToTeam(String doer, String team);

  /// No description provided for @inboxAddedToTeam.
  ///
  /// In en, this message translates to:
  /// **'{doer} added {member} to the {team} team'**
  String inboxAddedToTeam(String doer, String member, String team);

  /// Inbox row for a team membership whose member has no name in the server's payload.
  ///
  /// In en, this message translates to:
  /// **'{doer} added someone to the {team} team'**
  String inboxAddedSomeoneToTeam(String doer, String team);

  /// Snackbar after tapping an inbox row that says someone deleted a task.
  ///
  /// In en, this message translates to:
  /// **'This task was deleted'**
  String get inboxTaskWasDeleted;

  /// The server's own reminder notification.
  ///
  /// In en, this message translates to:
  /// **'Reminder for {task}'**
  String inboxReminder(String task);

  /// A server notification of a kind this app does not know.
  ///
  /// In en, this message translates to:
  /// **'New notification'**
  String get inboxOther;

  /// A comment's text in quotation marks.
  ///
  /// In en, this message translates to:
  /// **'“{text}”'**
  String inboxQuoted(String text);

  /// No description provided for @notificationSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay on top of your tasks'**
  String get notificationSetupTitle;

  /// No description provided for @notificationSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Rurana can notify you on this phone, without the server having to send anything:'**
  String get notificationSetupBody;

  /// No description provided for @notificationSetupReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders at their time'**
  String get notificationSetupReminders;

  /// No description provided for @notificationSetupDueDates.
  ///
  /// In en, this message translates to:
  /// **'Due dates at the exact time'**
  String get notificationSetupDueDates;

  /// No description provided for @notificationSetupOnlyYours.
  ///
  /// In en, this message translates to:
  /// **'Only for tasks you created or are assigned to'**
  String get notificationSetupOnlyYours;

  /// No description provided for @notificationSetupTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get notificationSetupTurnOn;

  /// No description provided for @notificationSetupNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notificationSetupNotNow;

  /// No description provided for @notificationSetupExactTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders right on time'**
  String get notificationSetupExactTitle;

  /// No description provided for @notificationSetupExactBody.
  ///
  /// In en, this message translates to:
  /// **'Without exact alarms, Android may show reminders minutes late. You can allow them in the system settings; the app works either way.'**
  String get notificationSetupExactBody;

  /// No description provided for @notificationSetupExactAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow exact alarms'**
  String get notificationSetupExactAllow;

  /// No description provided for @notificationSetupSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get notificationSetupSkip;

  /// No description provided for @notificationsHeading.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsHeading;

  /// No description provided for @notificationsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notificationsReminders;

  /// No description provided for @notificationsRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'At the time of each reminder'**
  String get notificationsRemindersSubtitle;

  /// No description provided for @notificationsDueDates.
  ///
  /// In en, this message translates to:
  /// **'Due dates'**
  String get notificationsDueDates;

  /// No description provided for @notificationsDueDatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'At the exact due time'**
  String get notificationsDueDatesSubtitle;

  /// No description provided for @notificationsActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get notificationsActivity;

  /// No description provided for @notificationsActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Comments, assignments and mentions'**
  String get notificationsActivitySubtitle;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get notificationsOff;

  /// No description provided for @notificationsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get notificationsOpenSettings;

  /// No description provided for @notificationsTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get notificationsTurnOn;

  /// No description provided for @notificationsMayBeLate.
  ///
  /// In en, this message translates to:
  /// **'Reminders may be late'**
  String get notificationsMayBeLate;

  /// No description provided for @notificationsAllowExactAlarms.
  ///
  /// In en, this message translates to:
  /// **'Allow exact alarms'**
  String get notificationsAllowExactAlarms;

  /// How many notifications the OS holds for this account.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing scheduled} =1{1 scheduled} other{{count} scheduled}}'**
  String notificationsScheduled(int count);

  /// No description provided for @notificationsSendTest.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get notificationsSendTest;

  /// No description provided for @notificationTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Test notification'**
  String get notificationTestTitle;

  /// No description provided for @notificationTestBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications from Rurana work on this phone.'**
  String get notificationTestBody;

  /// No description provided for @notificationTaskGone.
  ///
  /// In en, this message translates to:
  /// **'This task is gone'**
  String get notificationTaskGone;

  /// Snackbar after tapping the test notification while the Account tab, which sent it, is already open.
  ///
  /// In en, this message translates to:
  /// **'Notifications work'**
  String get notificationTestReceived;

  /// Name of the Android notification channel for task reminders and due dates.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notificationChannelReminders;

  /// No description provided for @notificationChannelRemindersDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders and due dates of your tasks'**
  String get notificationChannelRemindersDescription;

  /// Name of the Android notification channel for comments, assignments and mentions from the server.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get notificationChannelActivity;

  /// No description provided for @notificationChannelActivityDescription.
  ///
  /// In en, this message translates to:
  /// **'Comments, assignments and mentions from your Vikunja servers'**
  String get notificationChannelActivityDescription;

  /// Body of an OS notification for a new comment; the title is the task's title. The comment is cut to 80 characters.
  ///
  /// In en, this message translates to:
  /// **'{name} commented: {comment}'**
  String activityNotificationCommented(String name, String comment);

  /// No description provided for @activityNotificationCommentedNoText.
  ///
  /// In en, this message translates to:
  /// **'{name} commented'**
  String activityNotificationCommentedNoText(String name);

  /// Body of an OS notification: someone assigned the user to the task in the title.
  ///
  /// In en, this message translates to:
  /// **'{name} assigned you'**
  String activityNotificationAssignedYou(String name);

  /// No description provided for @activityNotificationAssignedOther.
  ///
  /// In en, this message translates to:
  /// **'{name} assigned {assignee}'**
  String activityNotificationAssignedOther(String name, String assignee);

  /// Body of an OS notification for an assignment whose assignee has no name in the server's payload.
  ///
  /// In en, this message translates to:
  /// **'{name} assigned someone to this task'**
  String activityNotificationAssignedSomeone(String name);

  /// No description provided for @activityNotificationMentioned.
  ///
  /// In en, this message translates to:
  /// **'{name} mentioned you'**
  String activityNotificationMentioned(String name);

  /// No description provided for @activityNotificationTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'{name} created this task in {project}'**
  String activityNotificationTaskCreated(String name, String project);

  /// No description provided for @activityNotificationTaskCreatedNoProject.
  ///
  /// In en, this message translates to:
  /// **'{name} created this task'**
  String activityNotificationTaskCreatedNoProject(String name);

  /// No description provided for @activityNotificationTaskDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted this task'**
  String activityNotificationTaskDeleted(String name);

  /// Body of an OS notification; the title is the project's title.
  ///
  /// In en, this message translates to:
  /// **'{name} created the project {project}'**
  String activityNotificationProjectCreated(String name, String project);

  /// Body of an OS notification; the title is the team's name.
  ///
  /// In en, this message translates to:
  /// **'{name} added you to the team {team}'**
  String activityNotificationTeamAddedYou(String name, String team);

  /// No description provided for @activityNotificationTeamAddedOther.
  ///
  /// In en, this message translates to:
  /// **'{name} added {member} to the team {team}'**
  String activityNotificationTeamAddedOther(
    String name,
    String member,
    String team,
  );

  /// Body of an OS notification for a team membership whose member has no name in the server's payload.
  ///
  /// In en, this message translates to:
  /// **'{name} added someone to the team {team}'**
  String activityNotificationTeamAddedSomeone(String name, String team);

  /// Title of the OS notification that stands for the new notifications of one sync beyond the few shown one by one.
  ///
  /// In en, this message translates to:
  /// **'More activity'**
  String get activityNotificationMoreTitle;

  /// No description provided for @activityNotificationMoreBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more new notification} other{{count} more new notifications}}'**
  String activityNotificationMoreBody(int count);

  /// Title of an activity notification whose task, project or team has no name.
  ///
  /// In en, this message translates to:
  /// **'Vikunja'**
  String get activityNotificationUntitled;

  /// Title of the OS notification when the server ended an account's session.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to {host}'**
  String sessionEndedNotificationTitle(String host);

  /// No description provided for @sessionEndedNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Your session as {username} has ended. Rurana cannot sync this account until you sign in again.'**
  String sessionEndedNotificationBody(String username);

  /// Notification action that marks the task done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get notificationActionDone;

  /// No description provided for @notificationActionSnooze10Minutes.
  ///
  /// In en, this message translates to:
  /// **'Snooze 10 min'**
  String get notificationActionSnooze10Minutes;

  /// No description provided for @notificationActionSnooze1Hour.
  ///
  /// In en, this message translates to:
  /// **'Snooze 1 h'**
  String get notificationActionSnooze1Hour;

  /// Body of a reminder notification; the title is the task's title.
  ///
  /// In en, this message translates to:
  /// **'Reminder · {project}'**
  String notificationReminderBody(String project);

  /// No description provided for @notificationReminderBodyNoProject.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get notificationReminderBodyNoProject;

  /// Body of a due-date notification, shown at the due time.
  ///
  /// In en, this message translates to:
  /// **'Due now · {project}'**
  String notificationDueBody(String project);

  /// No description provided for @notificationDueBodyNoProject.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get notificationDueBodyNoProject;

  /// A notification body followed by the task's identifier, when its project has a prefix.
  ///
  /// In en, this message translates to:
  /// **'{body} · {identifier}'**
  String notificationBodyWithIdentifier(String body, String identifier);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @taskDetailSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get taskDetailSubtasks;

  /// Next to the Subtasks heading.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String taskDetailSubtasksDone(int done, int total);

  /// Label of the inline field under the subtasks and tooltip of its add button.
  ///
  /// In en, this message translates to:
  /// **'Add subtask'**
  String get taskDetailAddSubtask;

  /// No description provided for @taskDetailAddSubtaskFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the subtask'**
  String get taskDetailAddSubtaskFailed;

  /// No description provided for @taskDetailSubtaskNotLinked.
  ///
  /// In en, this message translates to:
  /// **'The task was added, but not as a subtask'**
  String get taskDetailSubtaskNotLinked;

  /// No description provided for @taskDetailParentTask.
  ///
  /// In en, this message translates to:
  /// **'Parent task'**
  String get taskDetailParentTask;

  /// No description provided for @taskDetailRelatedTasks.
  ///
  /// In en, this message translates to:
  /// **'Related tasks'**
  String get taskDetailRelatedTasks;

  /// No description provided for @taskDetailAddRelation.
  ///
  /// In en, this message translates to:
  /// **'Add relation'**
  String get taskDetailAddRelation;

  /// Relation kind: the other task is a subtask of this one.
  ///
  /// In en, this message translates to:
  /// **'Subtask'**
  String get taskRelationSubtask;

  /// Relation kind: the other task is this one's parent.
  ///
  /// In en, this message translates to:
  /// **'Parent task'**
  String get taskRelationParentTask;

  /// No description provided for @taskRelationRelated.
  ///
  /// In en, this message translates to:
  /// **'Related to'**
  String get taskRelationRelated;

  /// Relation kind: this task blocks the other.
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get taskRelationBlocking;

  /// No description provided for @taskRelationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked by'**
  String get taskRelationBlocked;

  /// No description provided for @taskRelationPrecedes.
  ///
  /// In en, this message translates to:
  /// **'Precedes'**
  String get taskRelationPrecedes;

  /// No description provided for @taskRelationFollows.
  ///
  /// In en, this message translates to:
  /// **'Follows'**
  String get taskRelationFollows;

  /// No description provided for @taskRelationDuplicateOf.
  ///
  /// In en, this message translates to:
  /// **'Duplicate of'**
  String get taskRelationDuplicateOf;

  /// Relation kind: the other task is a duplicate of this one.
  ///
  /// In en, this message translates to:
  /// **'Duplicated by'**
  String get taskRelationDuplicates;

  /// No description provided for @taskRelationCopiedFrom.
  ///
  /// In en, this message translates to:
  /// **'Copied from'**
  String get taskRelationCopiedFrom;

  /// No description provided for @taskRelationCopiedTo.
  ///
  /// In en, this message translates to:
  /// **'Copied to'**
  String get taskRelationCopiedTo;

  /// Tooltip of the button that removes a relation; the task itself stays.
  ///
  /// In en, this message translates to:
  /// **'Remove relation'**
  String get taskRelationRemove;

  /// No description provided for @taskRelationRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove relation?'**
  String get taskRelationRemoveTitle;

  /// No description provided for @taskRelationRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The link to “{title}” will be removed on the server too. The task itself stays.'**
  String taskRelationRemoveBody(String title);

  /// No description provided for @taskRelationRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get taskRelationRemoveConfirm;

  /// Label of the relation kind picker in the Add relation sheet.
  ///
  /// In en, this message translates to:
  /// **'Relation'**
  String get addRelationKind;

  /// No description provided for @addRelationSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by title or identifier'**
  String get addRelationSearch;

  /// No description provided for @addRelationShowDone.
  ///
  /// In en, this message translates to:
  /// **'Show done tasks'**
  String get addRelationShowDone;

  /// No description provided for @addRelationNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks'**
  String get addRelationNoMatches;

  /// No description provided for @taskDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get taskDuplicate;

  /// No description provided for @taskDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Duplicated'**
  String get taskDuplicated;

  /// Snackbar action that opens the copy just made.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskDuplicateOpen;

  /// No description provided for @taskDuplicateNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Duplicating needs a connection to the server.'**
  String get taskDuplicateNeedsConnection;

  /// No description provided for @taskDuplicateNotSynced.
  ///
  /// In en, this message translates to:
  /// **'You can duplicate this task once its changes are synced.'**
  String get taskDuplicateNotSynced;

  /// No description provided for @taskDuplicateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t duplicate the task: {message}'**
  String taskDuplicateFailed(String message);

  /// No description provided for @taskDuplicateFailedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t duplicate the task.'**
  String get taskDuplicateFailedUnknown;

  /// No description provided for @followTask.
  ///
  /// In en, this message translates to:
  /// **'Follow task'**
  String get followTask;

  /// No description provided for @unfollowTask.
  ///
  /// In en, this message translates to:
  /// **'Unfollow task'**
  String get unfollowTask;

  /// No description provided for @followProject.
  ///
  /// In en, this message translates to:
  /// **'Follow project'**
  String get followProject;

  /// No description provided for @unfollowProject.
  ///
  /// In en, this message translates to:
  /// **'Unfollow project'**
  String get unfollowProject;

  /// No description provided for @followNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Following needs a connection to the server.'**
  String get followNeedsConnection;

  /// No description provided for @followFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change whether you follow this. Try again.'**
  String get followFailed;

  /// No description provided for @followTaskOnceSynced.
  ///
  /// In en, this message translates to:
  /// **'You can follow this task once it is synced.'**
  String get followTaskOnceSynced;

  /// Label of the follow bell while it is not known whether the user follows the task (offline, or the task is not synced yet).
  ///
  /// In en, this message translates to:
  /// **'Follow task (needs a connection)'**
  String get followTaskUnavailable;

  /// Label of the follow bell and of the project menu item while the follow state is being read from the server.
  ///
  /// In en, this message translates to:
  /// **'Checking whether you follow this…'**
  String get followChecking;

  /// Under the task title when the user follows the task through its project.
  ///
  /// In en, this message translates to:
  /// **'Following the project {project}'**
  String followingViaProject(String project);

  /// No description provided for @followingViaSomeProject.
  ///
  /// In en, this message translates to:
  /// **'Following through a project'**
  String get followingViaSomeProject;

  /// No description provided for @followInheritedTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop following this task?'**
  String get followInheritedTaskTitle;

  /// No description provided for @followInheritedTaskBody.
  ///
  /// In en, this message translates to:
  /// **'You follow the project “{project}”, which includes this task. You will stop getting notifications about this task only and keep following the project.'**
  String followInheritedTaskBody(String project);

  /// No description provided for @followInheritedProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop following this project?'**
  String get followInheritedProjectTitle;

  /// No description provided for @followInheritedProjectBody.
  ///
  /// In en, this message translates to:
  /// **'You follow the parent project “{project}”. You will stop getting notifications about this project only and keep following “{project}”.'**
  String followInheritedProjectBody(String project);

  /// No description provided for @followInheritedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop following'**
  String get followInheritedConfirm;

  /// No description provided for @projectFollowed.
  ///
  /// In en, this message translates to:
  /// **'You follow this project now'**
  String get projectFollowed;

  /// No description provided for @projectUnfollowed.
  ///
  /// In en, this message translates to:
  /// **'You no longer follow this project'**
  String get projectUnfollowed;

  /// Above the preview of the first line once indented lines are pasted: indented lines become subtasks of the line above.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}, {subtasks, plural, =1{1 as a subtask} other{{subtasks} as subtasks}} · the first one:'**
  String newTaskTreeCount(int count, int subtasks);

  /// Like newTaskTreeCount when the first line has nothing to preview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}, {subtasks, plural, =1{1 as a subtask} other{{subtasks} as subtasks}}'**
  String newTaskTreeCountOnly(int count, int subtasks);

  /// No description provided for @tabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tabUpcoming;

  /// No description provided for @upcomingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do — have a nice day!'**
  String get upcomingEmptyTitle;

  /// No description provided for @upcomingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No open task is due in this date range.'**
  String get upcomingEmptyBody;

  /// No description provided for @upcomingShowOverdue.
  ///
  /// In en, this message translates to:
  /// **'Show overdue tasks'**
  String get upcomingShowOverdue;

  /// No description provided for @upcomingShowWithoutDate.
  ///
  /// In en, this message translates to:
  /// **'Show tasks without date'**
  String get upcomingShowWithoutDate;

  /// No description provided for @upcomingSelectRange.
  ///
  /// In en, this message translates to:
  /// **'Select a date range'**
  String get upcomingSelectRange;

  /// No description provided for @upcomingRangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get upcomingRangeCustom;

  /// The last entry of the date range sheet; opens a date range picker.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get upcomingRangeCustomEntry;

  /// Under the date range's name: its first and last day, both included.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String upcomingRangeDates(String from, String to);

  /// No description provided for @upcomingRangeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Date range {name}, {dates}'**
  String upcomingRangeSemantics(String name, String dates);

  /// No description provided for @upcomingRangeFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get upcomingRangeFrom;

  /// No description provided for @upcomingRangeTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get upcomingRangeTo;

  /// No description provided for @rangeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get rangeToday;

  /// No description provided for @rangeTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get rangeTomorrow;

  /// No description provided for @rangeLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last Week'**
  String get rangeLastWeek;

  /// No description provided for @rangeThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get rangeThisWeek;

  /// No description provided for @rangeRestOfThisWeek.
  ///
  /// In en, this message translates to:
  /// **'The Rest of This Week'**
  String get rangeRestOfThisWeek;

  /// No description provided for @rangeNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next Week'**
  String get rangeNextWeek;

  /// No description provided for @rangeNext7Days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 Days'**
  String get rangeNext7Days;

  /// No description provided for @rangeLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get rangeLastMonth;

  /// No description provided for @rangeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get rangeThisMonth;

  /// No description provided for @rangeRestOfThisMonth.
  ///
  /// In en, this message translates to:
  /// **'The Rest of This Month'**
  String get rangeRestOfThisMonth;

  /// No description provided for @rangeNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next Month'**
  String get rangeNextMonth;

  /// No description provided for @rangeNext30Days.
  ///
  /// In en, this message translates to:
  /// **'Next 30 Days'**
  String get rangeNext30Days;

  /// No description provided for @rangeThisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get rangeThisYear;

  /// No description provided for @rangeRestOfThisYear.
  ///
  /// In en, this message translates to:
  /// **'The Rest of This Year'**
  String get rangeRestOfThisYear;

  /// No description provided for @sectionTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get sectionTomorrow;

  /// Under the Overview's title when it shows the saved filter picked for it on the web.
  ///
  /// In en, this message translates to:
  /// **'Filter: {title}'**
  String overviewFilterSubtitle(String title);

  /// No description provided for @overviewFilterNotLoadedTitle.
  ///
  /// In en, this message translates to:
  /// **'This filter loads once you\'re online'**
  String get overviewFilterNotLoadedTitle;

  /// No description provided for @overviewFilterNotLoadedBody.
  ///
  /// In en, this message translates to:
  /// **'Your Overview shows the saved filter “{title}”, picked in your account settings. Its tasks download with the next sync.'**
  String overviewFilterNotLoadedBody(String title);

  /// No description provided for @overviewFilterEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'The saved filter “{title}” has no open tasks.'**
  String overviewFilterEmptyBody(String title);

  /// A project view whose title is exactly "List", the server's default name.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get projectViewList;

  /// A project view whose title is exactly "Gantt", the server's default name.
  ///
  /// In en, this message translates to:
  /// **'Gantt'**
  String get projectViewGantt;

  /// A project view whose title is exactly "Table", the server's default name.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get projectViewTable;

  /// A project view whose title is exactly "Kanban", the server's default name.
  ///
  /// In en, this message translates to:
  /// **'Kanban'**
  String get projectViewKanban;

  /// No description provided for @projectViewSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch view'**
  String get projectViewSwitch;

  /// No description provided for @projectSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get projectSort;

  /// The sort button's tooltip.
  ///
  /// In en, this message translates to:
  /// **'Sorted: {sort}'**
  String projectSortCurrent(String sort);

  /// No description provided for @sortManual.
  ///
  /// In en, this message translates to:
  /// **'Manually'**
  String get sortManual;

  /// No description provided for @sortTitleAsc.
  ///
  /// In en, this message translates to:
  /// **'Title (A–Z)'**
  String get sortTitleAsc;

  /// No description provided for @sortTitleDesc.
  ///
  /// In en, this message translates to:
  /// **'Title (Z–A)'**
  String get sortTitleDesc;

  /// No description provided for @sortPriorityDesc.
  ///
  /// In en, this message translates to:
  /// **'Priority (Highest first)'**
  String get sortPriorityDesc;

  /// No description provided for @sortPriorityAsc.
  ///
  /// In en, this message translates to:
  /// **'Priority (Lowest first)'**
  String get sortPriorityAsc;

  /// No description provided for @sortDueDateAsc.
  ///
  /// In en, this message translates to:
  /// **'Due date (Earliest first)'**
  String get sortDueDateAsc;

  /// No description provided for @sortDueDateDesc.
  ///
  /// In en, this message translates to:
  /// **'Due date (Latest first)'**
  String get sortDueDateDesc;

  /// No description provided for @sortStartDateAsc.
  ///
  /// In en, this message translates to:
  /// **'Start date (Earliest first)'**
  String get sortStartDateAsc;

  /// No description provided for @sortStartDateDesc.
  ///
  /// In en, this message translates to:
  /// **'Start date (Latest first)'**
  String get sortStartDateDesc;

  /// No description provided for @sortEndDateAsc.
  ///
  /// In en, this message translates to:
  /// **'End date (Earliest first)'**
  String get sortEndDateAsc;

  /// No description provided for @sortEndDateDesc.
  ///
  /// In en, this message translates to:
  /// **'End date (Latest first)'**
  String get sortEndDateDesc;

  /// No description provided for @sortPercentDoneDesc.
  ///
  /// In en, this message translates to:
  /// **'% done (Most done first)'**
  String get sortPercentDoneDesc;

  /// No description provided for @sortPercentDoneAsc.
  ///
  /// In en, this message translates to:
  /// **'% done (Least done first)'**
  String get sortPercentDoneAsc;

  /// No description provided for @sortCreatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Created (Newest first)'**
  String get sortCreatedDesc;

  /// No description provided for @sortCreatedAsc.
  ///
  /// In en, this message translates to:
  /// **'Created (Oldest first)'**
  String get sortCreatedAsc;

  /// No description provided for @sortUpdatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Updated (Newest first)'**
  String get sortUpdatedDesc;

  /// No description provided for @sortUpdatedAsc.
  ///
  /// In en, this message translates to:
  /// **'Updated (Oldest first)'**
  String get sortUpdatedAsc;

  /// No description provided for @projectTasksDoneSection.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get projectTasksDoneSection;

  /// No description provided for @projectTasksEmptyDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No done tasks'**
  String get projectTasksEmptyDoneTitle;

  /// No description provided for @projectTasksEmptyDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this view is done yet.'**
  String get projectTasksEmptyDoneBody;

  /// No description provided for @projectViewFilterNotice.
  ///
  /// In en, this message translates to:
  /// **'The server applies this view\'s filter “{filter}”. Shown as of {when}; changes made elsewhere appear after the next download.'**
  String projectViewFilterNotice(String filter, String when);

  /// No description provided for @projectViewNotLoadedTitle.
  ///
  /// In en, this message translates to:
  /// **'This view loads once you\'re online'**
  String get projectViewNotLoadedTitle;

  /// No description provided for @projectViewNotLoadedBody.
  ///
  /// In en, this message translates to:
  /// **'The server applies this view\'s filter “{filter}”. Its tasks download when you open it online.'**
  String projectViewNotLoadedBody(String filter);

  /// No description provided for @projectViewEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks'**
  String get projectViewEmptyTitle;

  /// No description provided for @projectViewEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched this view\'s filter at the last download.'**
  String get projectViewEmptyBody;

  /// No description provided for @taskDoneSemantics.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskDoneSemantics;

  /// No description provided for @taskAssigneesSemantics.
  ///
  /// In en, this message translates to:
  /// **'Assigned to {names}'**
  String taskAssigneesSemantics(String names);

  /// After the first three assignee avatars of a task row.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String taskMoreAssignees(int count);

  /// The checkboxes in a task's description, some still open.
  ///
  /// In en, this message translates to:
  /// **'{checked} of {total} tasks'**
  String taskChecklistProgress(int checked, int total);

  /// The checkboxes in a task's description, all checked.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{1 task} other{{total} tasks}}'**
  String taskChecklistAllDone(int total);

  /// No description provided for @taskHasDescription.
  ///
  /// In en, this message translates to:
  /// **'Has a description'**
  String get taskHasDescription;

  /// No description provided for @taskRepeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get taskRepeats;

  /// The default saved filter every user gets, whose title the server sends as exactly "My Open Tasks".
  ///
  /// In en, this message translates to:
  /// **'My Open Tasks'**
  String get savedFilterMyOpenTasks;

  /// A project whose title is exactly "Inbox", the name the server gives every user's first project.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get projectInboxTitle;

  /// The list of the user's favourite tasks, which the server offers as a project of its own while any task is a favourite.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get projectFavouritesTitle;

  /// Above the Overview when it shows the last download of the saved filter picked for it on the web.
  ///
  /// In en, this message translates to:
  /// **'Filter: {title}, as of {when}. Tasks created here show after the next sync.'**
  String overviewFilterNotice(String title, String when);

  /// No description provided for @overviewFilterNotDownloadedTitle.
  ///
  /// In en, this message translates to:
  /// **'This filter hasn\'t downloaded yet'**
  String get overviewFilterNotDownloadedTitle;

  /// No description provided for @projectViewDownloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading this view…'**
  String get projectViewDownloadingTitle;

  /// No description provided for @projectViewDownloadingBody.
  ///
  /// In en, this message translates to:
  /// **'The server applies this view\'s filter “{filter}”. Its tasks are on their way.'**
  String projectViewDownloadingBody(String filter);

  /// No description provided for @projectViewDownloadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download this view'**
  String get projectViewDownloadFailedTitle;

  /// No description provided for @projectViewDownloadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The server applies this view\'s filter “{filter}”. Pull down to try again.'**
  String projectViewDownloadFailedBody(String filter);

  /// Below "This view loads once you're online" for a kanban board never downloaded.
  ///
  /// In en, this message translates to:
  /// **'Its columns and cards download when you open it online.'**
  String get boardNotLoadedBody;

  /// Below "Downloading this view…" for a kanban board never downloaded.
  ///
  /// In en, this message translates to:
  /// **'Its columns and cards are on their way.'**
  String get boardDownloadingBody;

  /// Below "Couldn't download this view" for a kanban board never downloaded.
  ///
  /// In en, this message translates to:
  /// **'Pull down to try again.'**
  String get boardDownloadFailedBody;

  /// No description provided for @boardNoColumnsTitle.
  ///
  /// In en, this message translates to:
  /// **'No columns'**
  String get boardNoColumnsTitle;

  /// No description provided for @boardNoColumnsBody.
  ///
  /// In en, this message translates to:
  /// **'This board had no columns at the last download.'**
  String get boardNoColumnsBody;

  /// Above a kanban board whose buckets are defined by filters; the server refuses moves there.
  ///
  /// In en, this message translates to:
  /// **'This board\'s columns come from filters, so its cards can\'t be moved here.'**
  String get boardFilterColumnsNote;

  /// Tooltip of the double check mark on the done bucket of a kanban board (the web's "done bucket").
  ///
  /// In en, this message translates to:
  /// **'All tasks moved into this column are marked as done automatically.'**
  String get boardDoneColumnHint;

  /// Read by screen readers after a kanban column's title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}'**
  String boardColumnTaskCount(int count);

  /// Read by screen readers after the title of a kanban column with a task limit.
  ///
  /// In en, this message translates to:
  /// **'{count} of at most {limit, plural, =1{1 task} other{{limit} tasks}}'**
  String boardColumnTaskCountOfLimit(int count, int limit);

  /// Read by screen readers for a kanban column that has reached its task limit.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get boardColumnFull;

  /// Why a full kanban column takes no new task and refuses a dropped card.
  ///
  /// In en, this message translates to:
  /// **'You have reached the column limit. Remove tasks or increase the limit to add new tasks.'**
  String get boardColumnLimitReached;

  /// After adding several tasks to a kanban column with a task limit: those beyond the limit stay in the board's default column, named by its title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task didn\'t fit into the column and went to {column}.} other{{count} tasks didn\'t fit into the column and went to {column}.}}'**
  String boardTasksLeftInDefaultColumn(int count, String column);

  /// At the bottom of an empty kanban column.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get boardAddTask;

  /// At the bottom of a kanban column that has cards.
  ///
  /// In en, this message translates to:
  /// **'Add another task'**
  String get boardAddAnotherTask;

  /// Below the cards of a kanban column whose other cards are still on the server.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get boardLoadMore;

  /// No description provided for @boardLoadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more tasks…'**
  String get boardLoadingMore;

  /// No description provided for @boardLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more tasks. Try again later.'**
  String get boardLoadMoreFailed;

  /// Screen reader action on a kanban card.
  ///
  /// In en, this message translates to:
  /// **'Move to {column}'**
  String boardMoveTo(String column);

  /// Announced to screen readers after a kanban card moved to another column.
  ///
  /// In en, this message translates to:
  /// **'Moved to {column}'**
  String boardMovedTo(String column);

  /// Tooltip, also read by screen readers, of the menu button in a kanban column's header (the web's "bucket options"); names the column so that the buttons of a board tell apart.
  ///
  /// In en, this message translates to:
  /// **'Options for “{column}”'**
  String boardColumnOptionsFor(String column);

  /// Read by screen readers for the progress indicator in a kanban column's header while a change to the column is sent.
  ///
  /// In en, this message translates to:
  /// **'Saving the column…'**
  String get boardColumnSaving;

  /// Item of a kanban column's menu.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get boardColumnRename;

  /// Item of a kanban column's menu, with the column's task limit or boardColumnLimitNotSet.
  ///
  /// In en, this message translates to:
  /// **'Limit: {limit}'**
  String boardColumnLimit(String limit);

  /// A kanban column without a task limit, as in "Limit: Not set".
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get boardColumnLimitNotSet;

  /// Checkable item of a kanban column's menu that makes it the board's done column (the web's "done bucket").
  ///
  /// In en, this message translates to:
  /// **'Done column'**
  String get boardDoneColumn;

  /// Under the "Done column" menu item.
  ///
  /// In en, this message translates to:
  /// **'All tasks moved into the done column are marked as done automatically. All tasks marked as done elsewhere move there as well.'**
  String get boardDoneColumnHintExtended;

  /// Checkable item of a kanban column's menu that makes it the board's default column (the web's "default bucket").
  ///
  /// In en, this message translates to:
  /// **'Default column'**
  String get boardDefaultColumn;

  /// Under the "Default column" menu item.
  ///
  /// In en, this message translates to:
  /// **'When creating tasks without specifying a column, they will be added to this column.'**
  String get boardDefaultColumnHint;

  /// Item of a kanban column's menu and screen reader action on its header: one place to the left on the board.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get boardColumnMoveLeft;

  /// Item of a kanban column's menu and screen reader action on its header: one place to the right on the board.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get boardColumnMoveRight;

  /// No description provided for @boardColumnMovedLeft.
  ///
  /// In en, this message translates to:
  /// **'Column moved left'**
  String get boardColumnMovedLeft;

  /// No description provided for @boardColumnMovedRight.
  ///
  /// In en, this message translates to:
  /// **'Column moved right'**
  String get boardColumnMovedRight;

  /// Item of a kanban column's menu.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get boardColumnDelete;

  /// Under the disabled "Delete" item of the only column of a kanban board.
  ///
  /// In en, this message translates to:
  /// **'You can\'t delete the last column.'**
  String get boardColumnDeleteLast;

  /// No description provided for @boardColumnRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename column'**
  String get boardColumnRenameTitle;

  /// Label of the text field for a kanban column's title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get boardColumnTitleLabel;

  /// No description provided for @boardColumnTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the new column title…'**
  String get boardColumnTitleHint;

  /// Under the title field of a kanban column when it is empty or only spaces.
  ///
  /// In en, this message translates to:
  /// **'Enter a title.'**
  String get boardColumnTitleEmpty;

  /// No description provided for @boardColumnSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get boardColumnSave;

  /// Title of the sheet that creates a kanban column.
  ///
  /// In en, this message translates to:
  /// **'New column'**
  String get boardNewColumn;

  /// Action of the sheet that creates a kanban column.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get boardNewColumnCreate;

  /// At the end of a kanban board, after its last column.
  ///
  /// In en, this message translates to:
  /// **'Create a column'**
  String get boardCreateColumn;

  /// No description provided for @boardColumnLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Column limit'**
  String get boardColumnLimitTitle;

  /// No description provided for @boardColumnLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get boardColumnLimitLabel;

  /// Under the limit field of a kanban column.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task is in this column now.} other{{count} tasks are in this column now.}} Leave it empty for no limit.'**
  String boardColumnLimitHelp(int count);

  /// Under the limit field of a kanban column when the limit typed is below the tasks in it, which the server accepts.
  ///
  /// In en, this message translates to:
  /// **'That\'s fewer than it holds now. It takes no new tasks until some move out.'**
  String get boardColumnLimitBelowCount;

  /// No description provided for @boardDeleteColumnTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the column'**
  String get boardDeleteColumnTitle;

  /// No description provided for @boardDeleteColumnBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the column “{column}”?'**
  String boardDeleteColumnBody(String column);

  /// Second line of the confirmation before deleting a kanban column that holds tasks; names the column the server moves them to.
  ///
  /// In en, this message translates to:
  /// **'Its tasks aren\'t deleted but move to “{column}”.'**
  String boardDeleteColumnTasksMove(String column);

  /// Line of the confirmation before deleting the kanban column new tasks go to while it holds tasks: the app first makes the named column the default for every member, so that the server doesn't lose the tasks.
  ///
  /// In en, this message translates to:
  /// **'“{column}” becomes the default column.'**
  String boardDeleteColumnBecomesDefault(String column);

  /// No description provided for @boardDeleteColumnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get boardDeleteColumnConfirm;

  /// Announced to screen readers once the server created a kanban column.
  ///
  /// In en, this message translates to:
  /// **'Column created'**
  String get boardColumnCreated;

  /// No description provided for @boardColumnRenamed.
  ///
  /// In en, this message translates to:
  /// **'Column renamed'**
  String get boardColumnRenamed;

  /// No description provided for @boardColumnLimitSaved.
  ///
  /// In en, this message translates to:
  /// **'Column limit saved'**
  String get boardColumnLimitSaved;

  /// No description provided for @boardDoneColumnSaved.
  ///
  /// In en, this message translates to:
  /// **'Done column saved'**
  String get boardDoneColumnSaved;

  /// No description provided for @boardDefaultColumnSaved.
  ///
  /// In en, this message translates to:
  /// **'Default column saved'**
  String get boardDefaultColumnSaved;

  /// No description provided for @boardColumnDeleted.
  ///
  /// In en, this message translates to:
  /// **'Column deleted'**
  String get boardColumnDeleted;

  /// No description provided for @boardColumnNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Changing columns needs a connection to the server.'**
  String get boardColumnNeedsConnection;

  /// A change to a kanban column timed out; the server may have made it.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the change. Check your connection and pull down to refresh the board.'**
  String get boardColumnUnconfirmed;

  /// No description provided for @boardColumnAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only project admins can choose the done or default column.'**
  String get boardColumnAdminOnly;

  /// Deleting the column the server puts new tasks into, while it has tasks, needs another default column first, which only project admins may choose.
  ///
  /// In en, this message translates to:
  /// **'Only project admins can delete the column new tasks go to while it holds tasks.'**
  String get boardColumnDeleteAdminOnly;

  /// Deleting a kanban column failed after the app had made another column the default for it, and putting the old default back failed too.
  ///
  /// In en, this message translates to:
  /// **'“{newDefault}” is now the default column; deleting “{column}” failed.'**
  String boardColumnDeleteFailedNewDefault(String newDefault, String column);

  /// No description provided for @boardColumnForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to change this board\'s columns.'**
  String get boardColumnForbidden;

  /// No description provided for @boardColumnLastOne.
  ///
  /// In en, this message translates to:
  /// **'A board needs at least one column.'**
  String get boardColumnLastOne;

  /// No description provided for @boardColumnArchived.
  ///
  /// In en, this message translates to:
  /// **'This project is archived, so its columns can\'t be changed.'**
  String get boardColumnArchived;

  /// No description provided for @boardColumnInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server didn\'t accept this title or limit.'**
  String get boardColumnInvalid;

  /// A change to a kanban column failed for another reason; the reason is the server's message.
  ///
  /// In en, this message translates to:
  /// **'The server refused the change: {message}'**
  String boardColumnChangeRefused(String message);

  /// No description provided for @boardColumnChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'The change couldn\'t be saved.'**
  String get boardColumnChangeFailed;

  /// Read by screen readers for a task nested under another in a project list.
  ///
  /// In en, this message translates to:
  /// **'Subtask of {parent}'**
  String taskSubtaskOfSemantics(String parent);

  /// A link in a task description that no app on the device can open.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open this link'**
  String get linkCannotOpen;

  /// Read by screen readers for an image in a description or comment without a description of its own.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get richTextImage;

  /// Stands in for an image on another website, which the app does not load by itself.
  ///
  /// In en, this message translates to:
  /// **'Image from {host}'**
  String richTextImageFrom(String host);

  /// No description provided for @richTextImageFailed.
  ///
  /// In en, this message translates to:
  /// **'The image couldn\'t be loaded'**
  String get richTextImageFailed;

  /// An attachment image in a format the app does not draw, such as SVG.
  ///
  /// In en, this message translates to:
  /// **'This image can\'t be shown here'**
  String get richTextImageUnsupported;

  /// Screen reader hint on an image that opens full screen.
  ///
  /// In en, this message translates to:
  /// **'Show full screen'**
  String get richTextShowImage;

  /// Screen reader hint on the stand-in for an image on another website.
  ///
  /// In en, this message translates to:
  /// **'Opens in the browser'**
  String get richTextOpensInBrowser;

  /// Above a quote of another comment inside a comment.
  ///
  /// In en, this message translates to:
  /// **'Reply to {author}'**
  String richTextReplyTo(String author);

  /// No description provided for @imageViewerClose.
  ///
  /// In en, this message translates to:
  /// **'Close image'**
  String get imageViewerClose;

  /// No description provided for @taskDetailDetailsOffline.
  ///
  /// In en, this message translates to:
  /// **'Attachments, comments and reactions need a connection'**
  String get taskDetailDetailsOffline;

  /// No description provided for @taskDetailDetailsFailed.
  ///
  /// In en, this message translates to:
  /// **'Attachments, comments and reactions couldn\'t be loaded'**
  String get taskDetailDetailsFailed;

  /// No description provided for @taskDetailAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get taskDetailAttachments;

  /// Badge on the attachment the task uses as its cover image.
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get taskDetailCoverImage;

  /// No description provided for @attachmentAdd.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get attachmentAdd;

  /// No description provided for @attachmentSourceFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get attachmentSourceFiles;

  /// No description provided for @attachmentSourcePhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get attachmentSourcePhotos;

  /// No description provided for @attachmentSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get attachmentSourceCamera;

  /// No description provided for @attachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is too large: attachments can be up to {limit}.'**
  String attachmentTooLarge(String name, String limit);

  /// After files were added to a task; they upload when there is a connection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file will be uploaded} other{{count} files will be uploaded}}'**
  String attachmentsQueued(int count);

  /// No description provided for @attachmentAddFailed.
  ///
  /// In en, this message translates to:
  /// **'“{name}” couldn\'t be added.'**
  String attachmentAddFailed(String name);

  /// No description provided for @attachmentPickFailed.
  ///
  /// In en, this message translates to:
  /// **'The files couldn\'t be opened.'**
  String get attachmentPickFailed;

  /// No description provided for @attachmentUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get attachmentUploading;

  /// A file added to a task that has not been uploaded yet, e.g. while offline.
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get attachmentWaiting;

  /// No description provided for @attachmentUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded: see Sync problems in the Account tab'**
  String get attachmentUploadFailed;

  /// No description provided for @attachmentUploadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded: too large'**
  String get attachmentUploadTooLarge;

  /// No description provided for @attachmentCancelUpload.
  ///
  /// In en, this message translates to:
  /// **'Cancel upload of {name}'**
  String attachmentCancelUpload(String name);

  /// No description provided for @attachmentOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for {name}'**
  String attachmentOptions(String name);

  /// No description provided for @attachmentOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get attachmentOpen;

  /// No description provided for @attachmentShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get attachmentShare;

  /// No description provided for @attachmentSaveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get attachmentSaveToDevice;

  /// No description provided for @attachmentMakeCover.
  ///
  /// In en, this message translates to:
  /// **'Make cover'**
  String get attachmentMakeCover;

  /// No description provided for @attachmentRemoveCover.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get attachmentRemoveCover;

  /// No description provided for @attachmentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete attachment'**
  String get attachmentDelete;

  /// No description provided for @attachmentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete attachment'**
  String get attachmentDeleteTitle;

  /// No description provided for @attachmentDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the attachment {name}? This cannot be undone!'**
  String attachmentDeleteBody(String name);

  /// No description provided for @attachmentDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get attachmentDeleteConfirm;

  /// No description provided for @attachmentDeleted.
  ///
  /// In en, this message translates to:
  /// **'The attachment was deleted.'**
  String get attachmentDeleted;

  /// No description provided for @attachmentCoverSet.
  ///
  /// In en, this message translates to:
  /// **'The cover image was changed.'**
  String get attachmentCoverSet;

  /// No description provided for @attachmentCoverRemoved.
  ///
  /// In en, this message translates to:
  /// **'The cover image was removed.'**
  String get attachmentCoverRemoved;

  /// No description provided for @attachmentSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get attachmentSaved;

  /// No description provided for @attachmentDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get attachmentDownloading;

  /// No description provided for @attachmentDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get attachmentDeleting;

  /// No description provided for @attachmentSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get attachmentSaving;

  /// No description provided for @attachmentCancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download of {name}'**
  String attachmentCancelDownload(String name);

  /// No description provided for @attachmentNoApp.
  ///
  /// In en, this message translates to:
  /// **'No app on this device can open this file.'**
  String get attachmentNoApp;

  /// No description provided for @attachmentNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'This needs a connection to the server.'**
  String get attachmentNeedsConnection;

  /// No description provided for @attachmentUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the change. Check your connection and try again.'**
  String get attachmentUnconfirmed;

  /// No description provided for @attachmentForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to change this task\'s attachments.'**
  String get attachmentForbidden;

  /// No description provided for @attachmentArchived.
  ///
  /// In en, this message translates to:
  /// **'This project is archived, so its attachments can\'t be changed.'**
  String get attachmentArchived;

  /// No description provided for @attachmentGone.
  ///
  /// In en, this message translates to:
  /// **'The attachment no longer exists.'**
  String get attachmentGone;

  /// No description provided for @attachmentsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Attachments are turned off on this server.'**
  String get attachmentsDisabled;

  /// No description provided for @attachmentFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large for the server.'**
  String get attachmentFileTooLarge;

  /// No description provided for @attachmentFileTooLargeLimit.
  ///
  /// In en, this message translates to:
  /// **'The file is too large: attachments can be up to {limit}.'**
  String attachmentFileTooLargeLimit(String limit);

  /// No description provided for @attachmentNotSynced.
  ///
  /// In en, this message translates to:
  /// **'This works once the task has been synced.'**
  String get attachmentNotSynced;

  /// No description provided for @attachmentRefused.
  ///
  /// In en, this message translates to:
  /// **'The server refused it: {message}'**
  String attachmentRefused(String message);

  /// No description provided for @attachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Try again later.'**
  String get attachmentFailed;

  /// No description provided for @editorImage.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get editorImage;

  /// No description provided for @editorImageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading the image…'**
  String get editorImageUploading;

  /// Announced to screen readers once an uploaded image is in the description.
  ///
  /// In en, this message translates to:
  /// **'Image inserted'**
  String get editorImageInserted;

  /// No description provided for @shareSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Rurana first, then share again.'**
  String get shareSignedOut;

  /// No description provided for @sharePickAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Share to which account?'**
  String get sharePickAccountTitle;

  /// No description provided for @sharePickAccountBody.
  ///
  /// In en, this message translates to:
  /// **'What you share goes to that account\'s server.'**
  String get sharePickAccountBody;

  /// No description provided for @shareSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share to Rurana'**
  String get shareSheetTitle;

  /// No description provided for @shareAddToTask.
  ///
  /// In en, this message translates to:
  /// **'Add to task'**
  String get shareAddToTask;

  /// No description provided for @shareFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get shareFiles;

  /// No description provided for @shareRemoveFile.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String shareRemoveFile(String name);

  /// No description provided for @shareFilePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get shareFilePreparing;

  /// No description provided for @shareFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Too large: attachments can be up to {limit}'**
  String shareFileTooLarge(String limit);

  /// No description provided for @shareFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t be read'**
  String get shareFileUnreadable;

  /// No description provided for @shareFilesLeftOut.
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t take attachments, so the files are left out.'**
  String get shareFilesLeftOut;

  /// No description provided for @shareTooManyFiles.
  ///
  /// In en, this message translates to:
  /// **'Only the first {count} files are added.'**
  String shareTooManyFiles(int count);

  /// No description provided for @shareAppendHint.
  ///
  /// In en, this message translates to:
  /// **'The text goes at the end of the task\'s description.'**
  String get shareAppendHint;

  /// No description provided for @sharePickTask.
  ///
  /// In en, this message translates to:
  /// **'Choose a task.'**
  String get sharePickTask;

  /// No description provided for @shareCreate.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get shareCreate;

  /// No description provided for @shareAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get shareAdd;

  /// No description provided for @shareTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Task created} =1{Task created, 1 file will be uploaded} other{Task created, {count} files will be uploaded}}'**
  String shareTaskCreated(int count);

  /// No description provided for @shareAddedToTask.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Added to the task} =1{Added to the task, 1 file will be uploaded} other{Added to the task, {count} files will be uploaded}}'**
  String shareAddedToTask(int count);

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'What was shared couldn\'t be added.'**
  String get shareFailed;

  /// No description provided for @syncProblemUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'“{name}” could not be uploaded.'**
  String syncProblemUploadFailed(String name);

  /// No description provided for @syncProblemUploadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large.'**
  String get syncProblemUploadTooLarge;

  /// No description provided for @syncProblemUploadTimedOut.
  ///
  /// In en, this message translates to:
  /// **'It timed out several times; try again on a faster connection.'**
  String get syncProblemUploadTimedOut;

  /// No description provided for @syncProblemUploadForbidden.
  ///
  /// In en, this message translates to:
  /// **'You may not add attachments to this task.'**
  String get syncProblemUploadForbidden;

  /// No description provided for @syncProblemAttachmentsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Attachments are turned off on the server.'**
  String get syncProblemAttachmentsDisabled;

  /// No description provided for @syncProblemUploadFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The copy kept on this device is gone; discard it.'**
  String get syncProblemUploadFileMissing;

  /// No description provided for @taskDetailComments.
  ///
  /// In en, this message translates to:
  /// **'Comments ({count})'**
  String taskDetailComments(int count);

  /// No description provided for @taskDetailShowComments.
  ///
  /// In en, this message translates to:
  /// **'Show comments'**
  String get taskDetailShowComments;

  /// No description provided for @taskDetailMoreComments.
  ///
  /// In en, this message translates to:
  /// **'Load more comments'**
  String get taskDetailMoreComments;

  /// No description provided for @commentsOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get commentsOldestFirst;

  /// No description provided for @commentsNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get commentsNewestFirst;

  /// Screen reader hint on the button that shows the comments' order.
  ///
  /// In en, this message translates to:
  /// **'Change the order'**
  String get commentsChangeOrder;

  /// No description provided for @commentsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading comments…'**
  String get commentsLoading;

  /// No description provided for @commentsNeedConnection.
  ///
  /// In en, this message translates to:
  /// **'Comments need a connection'**
  String get commentsNeedConnection;

  /// No description provided for @commentsFailed.
  ///
  /// In en, this message translates to:
  /// **'Comments couldn\'t be loaded'**
  String get commentsFailed;

  /// After a comment's time when it was changed later.
  ///
  /// In en, this message translates to:
  /// **'edited {when}'**
  String commentEdited(String when);

  /// No description provided for @reactionByOne.
  ///
  /// In en, this message translates to:
  /// **'{user} reacted with {reaction}'**
  String reactionByOne(String user, String reaction);

  /// No description provided for @reactionBySeveral.
  ///
  /// In en, this message translates to:
  /// **'{users} and {lastUser} reacted with {reaction}'**
  String reactionBySeveral(String users, String lastUser, String reaction);

  /// The first ten people who reacted, then how many more did.
  ///
  /// In en, this message translates to:
  /// **'{users} and {count} more reacted with {reaction}'**
  String reactionByMany(String users, int count, String reaction);

  /// No description provided for @taskDetailCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created {when} by {name}'**
  String taskDetailCreatedBy(String when, String name);

  /// No description provided for @taskDetailCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {when}'**
  String taskDetailCreated(String when);

  /// No description provided for @taskDetailUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {when}'**
  String taskDetailUpdated(String when);

  /// No description provided for @taskDetailDoneWhen.
  ///
  /// In en, this message translates to:
  /// **'Done {when}'**
  String taskDetailDoneWhen(String when);

  /// Screen reader hint on a project in the task's project path.
  ///
  /// In en, this message translates to:
  /// **'Opens the project'**
  String get taskDetailOpenProjectHint;

  /// No description provided for @taskOpenNotFound.
  ///
  /// In en, this message translates to:
  /// **'This task wasn\'t found'**
  String get taskOpenNotFound;

  /// No description provided for @taskOpenForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this task'**
  String get taskOpenForbidden;

  /// No description provided for @taskOpenOffline.
  ///
  /// In en, this message translates to:
  /// **'This task isn\'t on this device. Connect to open it.'**
  String get taskOpenOffline;

  /// No description provided for @taskOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'This task couldn\'t be opened'**
  String get taskOpenFailed;

  /// No description provided for @deepLinkPickAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Open in which account?'**
  String get deepLinkPickAccountTitle;

  /// No description provided for @deepLinkPickAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This task is in more than one of your accounts.'**
  String get deepLinkPickAccountBody;

  /// An attachment image in a description or comment that could not load without a connection; a tap tries again.
  ///
  /// In en, this message translates to:
  /// **'The image needs a connection'**
  String get richTextImageOffline;

  /// Read by screen readers once a page of comments the user asked for has arrived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No more comments} =1{1 comment loaded} other{{count} comments loaded}}'**
  String commentsLoaded(int count);

  /// While a task that is not on this device is read from the server, e.g. after tapping a link to it.
  ///
  /// In en, this message translates to:
  /// **'Opening the task…'**
  String get taskOpening;

  /// No description provided for @deepLinkSwitchAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch accounts?'**
  String get deepLinkSwitchAccountTitle;

  /// No description provided for @deepLinkSwitchAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This task is in another of your accounts. Choose it to switch and open the task.'**
  String get deepLinkSwitchAccountBody;

  /// Add button in the Projects tab's app bar and empty state, and the title of the sheet that creates a project.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get projectNew;

  /// Confirms the new project or view form.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get projectCreate;

  /// The disabled confirm button while the server creates the project.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get projectCreating;

  /// No description provided for @projectCreated.
  ///
  /// In en, this message translates to:
  /// **'Project created'**
  String get projectCreated;

  /// Title field of the project and view forms.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get projectTitleLabel;

  /// No description provided for @projectTitleHint.
  ///
  /// In en, this message translates to:
  /// **'The project\'s title goes here…'**
  String get projectTitleHint;

  /// No description provided for @projectTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify a title.'**
  String get projectTitleRequired;

  /// Row of the project forms that picks the parent, and the title of the picker.
  ///
  /// In en, this message translates to:
  /// **'Parent project'**
  String get projectParentLabel;

  /// Parent choice that puts the project at the top level.
  ///
  /// In en, this message translates to:
  /// **'None (top level)'**
  String get projectParentTopLevel;

  /// Project menu item that opens the edit page; also a view's option.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get projectEdit;

  /// No description provided for @projectEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit project'**
  String get projectEditTitle;

  /// No description provided for @projectSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get projectSave;

  /// While a project or view change is on its way to the server.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get projectSaving;

  /// No description provided for @projectEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Project saved'**
  String get projectEditSaved;

  /// No description provided for @projectEditDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits to this project will be lost.'**
  String get projectEditDiscardBody;

  /// No description provided for @projectIdentifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Project identifier'**
  String get projectIdentifierLabel;

  /// No description provided for @projectIdentifierHelp.
  ///
  /// In en, this message translates to:
  /// **'Up to 10 characters, unique on the server. The identifiers of this project\'s tasks start with it and change with it. Leave it empty for none.'**
  String get projectIdentifierHelp;

  /// No description provided for @projectIdentifierTaken.
  ///
  /// In en, this message translates to:
  /// **'This identifier is already in use. Identifiers are unique on the whole server.'**
  String get projectIdentifierTaken;

  /// No description provided for @projectGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This project no longer exists'**
  String get projectGoneTitle;

  /// No description provided for @projectGoneBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted, here or on the web.'**
  String get projectGoneBody;

  /// Project menu item and title of the page that manages the project's views.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get projectViews;

  /// No description provided for @projectDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get projectDuplicate;

  /// No description provided for @projectDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Duplicate project'**
  String get projectDuplicateTitle;

  /// No description provided for @projectDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'The copy gets this project\'s tasks, views and columns, but not its subprojects. Choose the project it goes into:'**
  String get projectDuplicateBody;

  /// No description provided for @projectDuplicateShares.
  ///
  /// In en, this message translates to:
  /// **'Also copy its shares'**
  String get projectDuplicateShares;

  /// No description provided for @projectDuplicateSharesHint.
  ///
  /// In en, this message translates to:
  /// **'People, teams and link shares. Each link share becomes a new public link to the copy.'**
  String get projectDuplicateSharesHint;

  /// The disabled confirm button while the server copies the project and the app syncs the copy.
  ///
  /// In en, this message translates to:
  /// **'Duplicating…'**
  String get projectDuplicating;

  /// No description provided for @projectDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Project duplicated'**
  String get projectDuplicated;

  /// No description provided for @projectArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get projectArchive;

  /// No description provided for @projectUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get projectUnarchive;

  /// No description provided for @projectArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this project?'**
  String get projectArchiveTitle;

  /// No description provided for @projectUnarchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Unarchive this project?'**
  String get projectUnarchiveTitle;

  /// No description provided for @projectArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be able to edit this project or create tasks until you unarchive it. Its subprojects are archived too.'**
  String get projectArchiveBody;

  /// No description provided for @projectUnarchiveBody.
  ///
  /// In en, this message translates to:
  /// **'You will be able to create tasks or edit it. Its subprojects are unarchived too.'**
  String get projectUnarchiveBody;

  /// No description provided for @projectArchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Project archived'**
  String get projectArchivedDone;

  /// No description provided for @projectUnarchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Project unarchived'**
  String get projectUnarchivedDone;

  /// No description provided for @projectArchiveDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'You can\'t archive this because it\'s your default project.'**
  String get projectArchiveDefaultHint;

  /// No description provided for @projectNewSubproject.
  ///
  /// In en, this message translates to:
  /// **'New subproject'**
  String get projectNewSubproject;

  /// No description provided for @projectAddToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get projectAddToFavourites;

  /// No description provided for @projectRemoveFromFavourites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get projectRemoveFromFavourites;

  /// No description provided for @projectFavourited.
  ///
  /// In en, this message translates to:
  /// **'Added to favourites'**
  String get projectFavourited;

  /// No description provided for @projectUnfavourited.
  ///
  /// In en, this message translates to:
  /// **'Removed from favourites'**
  String get projectUnfavourited;

  /// No description provided for @projectDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get projectDelete;

  /// No description provided for @projectDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{project}”?'**
  String projectDeleteTitle(String project);

  /// What deleting a project without subprojects removes; counts done tasks too.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{It has no tasks. It is deleted for everyone.} =1{This deletes 1 task, for everyone.} other{This deletes {count} tasks, for everyone.}}'**
  String projectDeleteTasks(int count);

  /// What deleting a project removes: the tasks of the project and of all its subprojects, and the subprojects at every level.
  ///
  /// In en, this message translates to:
  /// **'This deletes {tasks, plural, =0{no tasks} =1{1 task} other{{tasks} tasks}} and {subprojects, plural, =1{1 subproject} other{{subprojects} subprojects}}, for everyone.'**
  String projectDeleteTasksAndSubprojects(int tasks, int subprojects);

  /// No description provided for @projectDeleteCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get projectDeleteCannotBeUndone;

  /// Added to the delete and archive confirmations when the user's default project is in the project's subtree.
  ///
  /// In en, this message translates to:
  /// **'This includes your default project “{project}”.'**
  String projectIncludesDefault(String project);

  /// No description provided for @projectDeleted.
  ///
  /// In en, this message translates to:
  /// **'Project deleted'**
  String get projectDeleted;

  /// No description provided for @projectChangeNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Managing projects needs a connection to the server.'**
  String get projectChangeNeedsConnection;

  /// The request timed out; the server may have made the change.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the change. Check your connection and pull down to refresh.'**
  String get projectChangeUnconfirmed;

  /// A form's request (new project, duplicate, edit, view) timed out; the server may have made the change, and trying again could make it twice.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the change. It may have gone through, so check before trying again.'**
  String get projectFormUnconfirmed;

  /// No description provided for @projectChangeForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to change this project.'**
  String get projectChangeForbidden;

  /// No description provided for @projectCreateForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to add a project there.'**
  String get projectCreateForbidden;

  /// No description provided for @projectDeleteAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only project admins can delete a project.'**
  String get projectDeleteAdminOnly;

  /// No description provided for @projectViewsAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only project admins can change views.'**
  String get projectViewsAdminOnly;

  /// No description provided for @projectDeleteDefault.
  ///
  /// In en, this message translates to:
  /// **'This is a user\'s default project. Only its owner can delete it.'**
  String get projectDeleteDefault;

  /// No description provided for @projectArchiveDefault.
  ///
  /// In en, this message translates to:
  /// **'This is a user\'s default project, so it can\'t be archived.'**
  String get projectArchiveDefault;

  /// No description provided for @projectUnarchiveParentFirst.
  ///
  /// In en, this message translates to:
  /// **'The parent project is archived. Unarchive the parent project first.'**
  String get projectUnarchiveParentFirst;

  /// No description provided for @projectChangeArchived.
  ///
  /// In en, this message translates to:
  /// **'This project is archived. Unarchive it to change it.'**
  String get projectChangeArchived;

  /// No description provided for @projectParentArchived.
  ///
  /// In en, this message translates to:
  /// **'The parent project is archived, so nothing can be added to it.'**
  String get projectParentArchived;

  /// No description provided for @projectGone.
  ///
  /// In en, this message translates to:
  /// **'The project no longer exists.'**
  String get projectGone;

  /// No description provided for @projectChangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server didn\'t accept this title or identifier.'**
  String get projectChangeInvalid;

  /// Error of the project edit page's title field when the title is longer than the server accepts, as a duplicate's title can be.
  ///
  /// In en, this message translates to:
  /// **'A title can be up to 250 characters long, and an emoji can count as several. Shorten this one to save.'**
  String get projectTitleTooLong;

  /// A change from the project menu was refused because the stored title is too long: the server checks it on every change.
  ///
  /// In en, this message translates to:
  /// **'This project\'s title is longer than the server accepts. Shorten it under Edit first.'**
  String get projectTitleTooLongToChange;

  /// No description provided for @projectChangeRefused.
  ///
  /// In en, this message translates to:
  /// **'The server refused the change: {message}'**
  String projectChangeRefused(String message);

  /// No description provided for @projectChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'The change couldn\'t be saved.'**
  String get projectChangeFailed;

  /// No description provided for @projectViewNew.
  ///
  /// In en, this message translates to:
  /// **'New view'**
  String get projectViewNew;

  /// No description provided for @projectViewEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit view'**
  String get projectViewEditTitle;

  /// No description provided for @projectViewOptionsFor.
  ///
  /// In en, this message translates to:
  /// **'Options for {view}'**
  String projectViewOptionsFor(String view);

  /// No description provided for @projectViewDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get projectViewDelete;

  /// No description provided for @projectViewDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{view}”?'**
  String projectViewDeleteTitle(String view);

  /// No description provided for @projectViewDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Nobody can use it to look at this project\'s tasks any more. No task is deleted. This can\'t be undone.'**
  String get projectViewDeleteBody;

  /// No description provided for @projectViewLastOne.
  ///
  /// In en, this message translates to:
  /// **'A project needs at least one view.'**
  String get projectViewLastOne;

  /// No description provided for @projectViewCreated.
  ///
  /// In en, this message translates to:
  /// **'View created'**
  String get projectViewCreated;

  /// No description provided for @projectViewSaved.
  ///
  /// In en, this message translates to:
  /// **'View saved'**
  String get projectViewSaved;

  /// No description provided for @projectViewDeleted.
  ///
  /// In en, this message translates to:
  /// **'View deleted'**
  String get projectViewDeleted;

  /// No description provided for @projectViewKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get projectViewKindLabel;

  /// No description provided for @projectViewShowDone.
  ///
  /// In en, this message translates to:
  /// **'Show done tasks'**
  String get projectViewShowDone;

  /// No description provided for @projectViewShowDoneHint.
  ///
  /// In en, this message translates to:
  /// **'Off adds “done = false” to the filter, like the web\'s List view.'**
  String get projectViewShowDoneHint;

  /// The server's own explanation follows, in English.
  ///
  /// In en, this message translates to:
  /// **'This filter isn\'t valid: {message}'**
  String projectViewFilterInvalid(String message);

  /// Whether a Kanban view's columns are its own or come from filters.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get projectViewColumnsLabel;

  /// No description provided for @projectViewColumnsManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get projectViewColumnsManual;

  /// No description provided for @projectViewColumnsFilter.
  ///
  /// In en, this message translates to:
  /// **'From filters'**
  String get projectViewColumnsFilter;

  /// No description provided for @projectViewFilterColumnsOnWeb.
  ///
  /// In en, this message translates to:
  /// **'The filters of these columns are set up on the web.'**
  String get projectViewFilterColumnsOnWeb;

  /// No description provided for @projectViewGone.
  ///
  /// In en, this message translates to:
  /// **'The view no longer exists.'**
  String get projectViewGone;

  /// No description provided for @projectViewInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server didn\'t accept this view.'**
  String get projectViewInvalid;

  /// What deleting a project removes, when its tasks could not be counted.
  ///
  /// In en, this message translates to:
  /// **'This deletes its tasks and subprojects, for everyone.'**
  String get projectDeleteEverything;

  /// No description provided for @filterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterLabel;

  /// Example in the web's filter syntax; keep the syntax untranslated.
  ///
  /// In en, this message translates to:
  /// **'done = false && labels in Work'**
  String get filterHint;

  /// No description provided for @filterHelp.
  ///
  /// In en, this message translates to:
  /// **'In the web\'s filter syntax, with label and project titles. Suggestions follow what you type.'**
  String get filterHelp;

  /// Live count under the filter field, from the tasks stored on the device.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No task matches on this device} =1{1 task matches on this device} other{{count} tasks match on this device}}'**
  String filterMatchCount(int count);

  /// Under the filter field when it is valid but names bucket_id, which only the server evaluates.
  ///
  /// In en, this message translates to:
  /// **'The server applies this filter; the app can\'t count it here.'**
  String get filterNotCountable;

  /// No description provided for @filterErrorUnknownField.
  ///
  /// In en, this message translates to:
  /// **'A field in this filter doesn\'t exist. Fields are written like dueDate or labels.'**
  String get filterErrorUnknownField;

  /// No description provided for @filterErrorUnknownFieldNamed.
  ///
  /// In en, this message translates to:
  /// **'“{field}” isn\'t a field. Fields are written like dueDate or labels.'**
  String filterErrorUnknownFieldNamed(String field);

  /// No description provided for @filterErrorLabelValue.
  ///
  /// In en, this message translates to:
  /// **'No label is called “{value}”.'**
  String filterErrorLabelValue(String value);

  /// No description provided for @filterErrorProjectValue.
  ///
  /// In en, this message translates to:
  /// **'No project is called “{value}”.'**
  String filterErrorProjectValue(String value);

  /// The field stays as the filter names it, like due_date.
  ///
  /// In en, this message translates to:
  /// **'“{value}” isn\'t a valid value for {field}.'**
  String filterErrorFieldValue(String value, String field);

  /// No description provided for @filterErrorOperator.
  ///
  /// In en, this message translates to:
  /// **'This filter uses an operator that doesn\'t exist.'**
  String get filterErrorOperator;

  /// No description provided for @filterErrorValue.
  ///
  /// In en, this message translates to:
  /// **'A value doesn\'t fit its field, or no label or project has that title.'**
  String get filterErrorValue;

  /// No description provided for @filterErrorSyntax.
  ///
  /// In en, this message translates to:
  /// **'This filter is incomplete. Join conditions with && or ||, close every bracket, and don\'t put & | ( ) in a value.'**
  String get filterErrorSyntax;

  /// No description provided for @filterErrorTooComplex.
  ///
  /// In en, this message translates to:
  /// **'This filter is too long or nested too deeply.'**
  String get filterErrorTooComplex;

  /// No description provided for @filterErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'This filter isn\'t valid.'**
  String get filterErrorInvalid;

  /// No description provided for @filterSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Filter suggestions'**
  String get filterSuggestions;

  /// Screen-reader name of the && suggestion.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get filterSuggestionAnd;

  /// Screen-reader name of the || suggestion.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get filterSuggestionOr;

  /// Name of the date suggestion now in the filter builder, spoken and shown as its tooltip.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get filterDateNow;

  /// Name of the date suggestion now/d in the filter builder.
  ///
  /// In en, this message translates to:
  /// **'Start of today'**
  String get filterDateStartOfToday;

  /// Name of the date suggestion now/d+1d in the filter builder.
  ///
  /// In en, this message translates to:
  /// **'Start of tomorrow'**
  String get filterDateStartOfTomorrow;

  /// Name of the date suggestion now+7d in the filter builder.
  ///
  /// In en, this message translates to:
  /// **'In 7 days'**
  String get filterDateInSevenDays;

  /// Name of the date suggestion now/w in the filter builder.
  ///
  /// In en, this message translates to:
  /// **'Start of this week'**
  String get filterDateStartOfWeek;

  /// Name of the date suggestion now/w+1w in the filter builder.
  ///
  /// In en, this message translates to:
  /// **'Start of next week'**
  String get filterDateStartOfNextWeek;

  /// Name of the date suggestion now/M in the filter builder.
  ///
  /// In en, this message translates to:
  /// **'Start of this month'**
  String get filterDateStartOfMonth;

  /// Name of the date suggestion now-7d in the filter builder.
  ///
  /// In en, this message translates to:
  /// **'7 days ago'**
  String get filterDateSevenDaysAgo;

  /// No description provided for @savedFilterNew.
  ///
  /// In en, this message translates to:
  /// **'New saved filter'**
  String get savedFilterNew;

  /// No description provided for @savedFilterEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit saved filter'**
  String get savedFilterEditTitle;

  /// No description provided for @savedFilterDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get savedFilterDescriptionLabel;

  /// No description provided for @savedFilterIncludeNulls.
  ///
  /// In en, this message translates to:
  /// **'Include tasks which don\'t have a value set'**
  String get savedFilterIncludeNulls;

  /// No description provided for @savedFilterIncludeNullsHint.
  ///
  /// In en, this message translates to:
  /// **'Also lists tasks that have no value where the filter compares one, such as tasks without a due date.'**
  String get savedFilterIncludeNullsHint;

  /// No description provided for @savedFilterFavourite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get savedFilterFavourite;

  /// No description provided for @savedFilterFavouriteHint.
  ///
  /// In en, this message translates to:
  /// **'Shows it among the favourites in the Projects tab.'**
  String get savedFilterFavouriteHint;

  /// No description provided for @savedFilterFilterRequired.
  ///
  /// In en, this message translates to:
  /// **'A saved filter needs a filter.'**
  String get savedFilterFilterRequired;

  /// No description provided for @savedFilterCreated.
  ///
  /// In en, this message translates to:
  /// **'Saved filter created'**
  String get savedFilterCreated;

  /// No description provided for @savedFilterSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved filter saved'**
  String get savedFilterSaved;

  /// No description provided for @savedFilterDeleted.
  ///
  /// In en, this message translates to:
  /// **'Saved filter deleted'**
  String get savedFilterDeleted;

  /// No description provided for @savedFilterDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String savedFilterDeleteTitle(String title);

  /// No description provided for @savedFilterDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'No task is deleted, only the filter and its views. This can\'t be undone.'**
  String get savedFilterDeleteBody;

  /// No description provided for @savedFilterEditDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits to this saved filter will be lost.'**
  String get savedFilterEditDiscardBody;

  /// No description provided for @savedFilterLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the saved filter…'**
  String get savedFilterLoading;

  /// No description provided for @savedFilterLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The saved filter couldn\'t be loaded.'**
  String get savedFilterLoadFailed;

  /// No description provided for @savedFilterChangeNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Managing saved filters needs a connection to the server.'**
  String get savedFilterChangeNeedsConnection;

  /// No description provided for @savedFilterChangeForbidden.
  ///
  /// In en, this message translates to:
  /// **'Only the person who made this saved filter can change it.'**
  String get savedFilterChangeForbidden;

  /// No description provided for @savedFilterGone.
  ///
  /// In en, this message translates to:
  /// **'The saved filter no longer exists.'**
  String get savedFilterGone;

  /// No description provided for @savedFilterChangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server didn\'t accept this saved filter.'**
  String get savedFilterChangeInvalid;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Screen-reader label of the progress bar while the search reads this device's data for the first time.
  ///
  /// In en, this message translates to:
  /// **'Preparing the search'**
  String get searchPreparing;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Tasks, projects, filters, labels'**
  String get searchHint;

  /// No description provided for @searchTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get searchTasks;

  /// No description provided for @searchProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get searchProjects;

  /// No description provided for @searchLabels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get searchLabels;

  /// No description provided for @searchStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Search this device'**
  String get searchStartTitle;

  /// No description provided for @searchStartBody.
  ///
  /// In en, this message translates to:
  /// **'Tasks by title, description, #12 or PROJ-12; projects, saved filters and labels by name. Works offline.'**
  String get searchStartBody;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this device matches “{query}”.'**
  String searchNoResultsBody(String query);

  /// No description provided for @searchMoreTasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more task matches. Type more to narrow it down.} other{{count} more tasks match. Type more to narrow it down.}}'**
  String searchMoreTasks(int count);

  /// Announced to screen readers as the results change.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No results} =1{1 result} other{{count} results}}'**
  String searchResultCount(int count);

  /// No description provided for @labelTasksEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No open tasks'**
  String get labelTasksEmptyTitle;

  /// No description provided for @labelTasksEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Open tasks with the label “{label}” show here.'**
  String labelTasksEmptyBody(String label);

  /// No description provided for @labelTasksGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This label is gone'**
  String get labelTasksGoneTitle;

  /// No description provided for @labelTasksGoneBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted, here or on the web.'**
  String get labelTasksGoneBody;

  /// No description provided for @projectViewEmptyMatchingBody.
  ///
  /// In en, this message translates to:
  /// **'No task matches this view\'s filter.'**
  String get projectViewEmptyMatchingBody;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @descriptionEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionEditorTitle;

  /// Shown in the empty editor.
  ///
  /// In en, this message translates to:
  /// **'Write a description…'**
  String get descriptionEditorPlaceholder;

  /// No description provided for @descriptionEditorLoading.
  ///
  /// In en, this message translates to:
  /// **'Opening the editor…'**
  String get descriptionEditorLoading;

  /// No description provided for @descriptionEditorFailed.
  ///
  /// In en, this message translates to:
  /// **'The editor could not be opened.'**
  String get descriptionEditorFailed;

  /// No description provided for @descriptionEditorSaved.
  ///
  /// In en, this message translates to:
  /// **'Description saved'**
  String get descriptionEditorSaved;

  /// No description provided for @descriptionEditorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The description could not be saved. Try again.'**
  String get descriptionEditorSaveFailed;

  /// No description provided for @descriptionEditorLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save the description?'**
  String get descriptionEditorLeaveTitle;

  /// No description provided for @descriptionEditorLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your changes to the description are not saved yet.'**
  String get descriptionEditorLeaveBody;

  /// No description provided for @descriptionEditorChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'The description changed meanwhile'**
  String get descriptionEditorChangedTitle;

  /// No description provided for @descriptionEditorChangedBody.
  ///
  /// In en, this message translates to:
  /// **'It was changed on the web since you started editing. Overwrite that change with yours, or reload it and lose your edits?'**
  String get descriptionEditorChangedBody;

  /// No description provided for @descriptionEditorOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get descriptionEditorOverwrite;

  /// No description provided for @descriptionEditorReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get descriptionEditorReload;

  /// The system ended the editor's web view, for example while the app was in the background; a copy of the edit is kept.
  ///
  /// In en, this message translates to:
  /// **'The editor stopped. Reload it to go on with your changes.'**
  String get descriptionEditorStoppedKept;

  /// No description provided for @descriptionEditorStoppedLost.
  ///
  /// In en, this message translates to:
  /// **'The editor stopped, and your latest changes are lost. Reload it to go on.'**
  String get descriptionEditorStoppedLost;

  /// Stands in for an image in the editor, which does not load images.
  ///
  /// In en, this message translates to:
  /// **'Image (not shown while editing)'**
  String get descriptionEditorImage;

  /// No description provided for @descriptionEditorRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore unsaved changes?'**
  String get descriptionEditorRestoreTitle;

  /// No description provided for @descriptionEditorRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'You left this description with changes that were not saved.'**
  String get descriptionEditorRestoreBody;

  /// No description provided for @descriptionEditorRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get descriptionEditorRestore;

  /// No description provided for @editorToolbar.
  ///
  /// In en, this message translates to:
  /// **'Text formatting'**
  String get editorToolbar;

  /// No description provided for @editorBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get editorBold;

  /// No description provided for @editorItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get editorItalic;

  /// No description provided for @editorUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get editorUnderline;

  /// No description provided for @editorStrike.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get editorStrike;

  /// No description provided for @editorCode.
  ///
  /// In en, this message translates to:
  /// **'Inline code'**
  String get editorCode;

  /// No description provided for @editorTextStyle.
  ///
  /// In en, this message translates to:
  /// **'Text style'**
  String get editorTextStyle;

  /// No description provided for @editorParagraph.
  ///
  /// In en, this message translates to:
  /// **'Paragraph'**
  String get editorParagraph;

  /// No description provided for @editorHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading {level}'**
  String editorHeading(int level);

  /// No description provided for @editorBulletList.
  ///
  /// In en, this message translates to:
  /// **'Bulleted list'**
  String get editorBulletList;

  /// No description provided for @editorOrderedList.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get editorOrderedList;

  /// No description provided for @editorTaskList.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get editorTaskList;

  /// No description provided for @editorQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get editorQuote;

  /// No description provided for @editorCodeBlock.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get editorCodeBlock;

  /// No description provided for @editorLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get editorLink;

  /// No description provided for @editorTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get editorTable;

  /// No description provided for @editorInsertTable.
  ///
  /// In en, this message translates to:
  /// **'Insert table'**
  String get editorInsertTable;

  /// No description provided for @editorAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get editorAddRow;

  /// No description provided for @editorAddColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get editorAddColumn;

  /// No description provided for @editorDeleteRow.
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get editorDeleteRow;

  /// No description provided for @editorDeleteColumn.
  ///
  /// In en, this message translates to:
  /// **'Delete column'**
  String get editorDeleteColumn;

  /// No description provided for @editorDeleteTable.
  ///
  /// In en, this message translates to:
  /// **'Delete table'**
  String get editorDeleteTable;

  /// No description provided for @editorDivider.
  ///
  /// In en, this message translates to:
  /// **'Divider'**
  String get editorDivider;

  /// No description provided for @editorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get editorUndo;

  /// No description provided for @editorRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get editorRedo;

  /// No description provided for @editorClearFormatting.
  ///
  /// In en, this message translates to:
  /// **'Clear formatting'**
  String get editorClearFormatting;

  /// No description provided for @editorLinkAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get editorLinkAddTitle;

  /// No description provided for @editorLinkEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit link'**
  String get editorLinkEditTitle;

  /// No description provided for @editorLinkAddress.
  ///
  /// In en, this message translates to:
  /// **'Web address'**
  String get editorLinkAddress;

  /// No description provided for @editorLinkApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get editorLinkApply;

  /// No description provided for @editorLinkRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get editorLinkRemove;

  /// No description provided for @editorMentions.
  ///
  /// In en, this message translates to:
  /// **'People to mention'**
  String get editorMentions;

  /// No description provided for @editorMentionsSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get editorMentionsSearching;

  /// No description provided for @editorMentionsNone.
  ///
  /// In en, this message translates to:
  /// **'No one found'**
  String get editorMentionsNone;

  /// Above the suggestions when the server could not be searched.
  ///
  /// In en, this message translates to:
  /// **'No connection: people this device knows'**
  String get editorMentionsFromDevice;

  /// No description provided for @taskDetailEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Edit description'**
  String get taskDetailEditDescription;

  /// No description provided for @taskDetailAddDescription.
  ///
  /// In en, this message translates to:
  /// **'Add description'**
  String get taskDetailAddDescription;

  /// Announced after a checkbox in a description was ticked.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get checklistItemChecked;

  /// Announced after a checkbox in a description was unticked.
  ///
  /// In en, this message translates to:
  /// **'Unchecked'**
  String get checklistItemUnchecked;

  /// No description provided for @projectEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get projectEditDescription;

  /// No description provided for @projectEditNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get projectEditNoDescription;

  /// No description provided for @syncProblemDescriptionConflict.
  ///
  /// In en, this message translates to:
  /// **'The description was changed on the web too.'**
  String get syncProblemDescriptionConflict;

  /// Sends the phone's description, overwriting the web's.
  ///
  /// In en, this message translates to:
  /// **'Keep my version'**
  String get syncProblemKeepMine;

  /// Drops the phone's description and takes the one on the server.
  ///
  /// In en, this message translates to:
  /// **'Use the web version'**
  String get syncProblemUseWebs;

  /// Announced to screen readers when mention suggestions arrive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person found} other{{count} people found}}'**
  String editorMentionsFound(int count);

  /// Opens both descriptions of a conflict, to keep one of them.
  ///
  /// In en, this message translates to:
  /// **'Compare versions'**
  String get syncProblemCompare;

  /// No description provided for @syncProblemCompareTitle.
  ///
  /// In en, this message translates to:
  /// **'Which description should stay?'**
  String get syncProblemCompareTitle;

  /// No description provided for @syncProblemYourVersion.
  ///
  /// In en, this message translates to:
  /// **'Your version'**
  String get syncProblemYourVersion;

  /// No description provided for @syncProblemWebVersion.
  ///
  /// In en, this message translates to:
  /// **'Web version'**
  String get syncProblemWebVersion;

  /// No description provided for @syncProblemWebTaskGone.
  ///
  /// In en, this message translates to:
  /// **'This task is no longer on the server.'**
  String get syncProblemWebTaskGone;

  /// No description provided for @syncProblemNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get syncProblemNoDescription;

  /// No description provided for @accountSettingsEntry.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettingsEntry;

  /// No description provided for @accountSettingsEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name, avatar, colour scheme and preferences, saved on the server for all your devices'**
  String get accountSettingsEntrySubtitle;

  /// Screen readers say it after 'Double tap to' on the profile header.
  ///
  /// In en, this message translates to:
  /// **'open the account settings'**
  String get accountHeaderTapHint;

  /// Heads the Account tab's settings that stay on the phone (notifications, colours).
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get onThisDeviceHeading;

  /// No description provided for @onThisDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'These settings stay on this device and are not saved to your account.'**
  String get onThisDeviceSubtitle;

  /// No description provided for @accountSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettingsTitle;

  /// No description provided for @accountSettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Saved to your account on {host}: they apply on the web and on all your devices.'**
  String accountSettingsIntro(String host);

  /// No description provided for @accountSettingsOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline: account settings can be changed once the server can be reached again.'**
  String get accountSettingsOffline;

  /// No description provided for @accountSettingsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading account settings…'**
  String get accountSettingsLoading;

  /// Announced to screen readers after a setting was saved on the server.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get accountSettingsSaved;

  /// Screen readers' name for the progress bar while a change is sent to the server.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get accountSettingsSaving;

  /// No description provided for @accountSettingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountSettingsProfile;

  /// No description provided for @accountSettingsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountSettingsName;

  /// No description provided for @accountSettingsNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Shown instead of your username. Leave it empty to show @{username}.'**
  String accountSettingsNameHelp(String username);

  /// No description provided for @accountSettingsNameManaged.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in provider ({provider}) sets your name at every sign-in. Change it there.'**
  String accountSettingsNameManaged(String provider);

  /// No description provided for @accountSettingsNameSave.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get accountSettingsNameSave;

  /// No description provided for @accountSettingsNameDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The name you typed has not been saved.'**
  String get accountSettingsNameDiscardBody;

  /// No description provided for @accountSettingsNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Name saved'**
  String get accountSettingsNameSaved;

  /// No description provided for @accountSettingsAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get accountSettingsAvatar;

  /// No description provided for @accountSettingsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Password and email'**
  String get accountSettingsSignIn;

  /// No description provided for @accountSettingsWaitingForProfile.
  ///
  /// In en, this message translates to:
  /// **'Available once the server has said how you sign in.'**
  String get accountSettingsWaitingForProfile;

  /// No description provided for @accountSettingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountSettingsChangePassword;

  /// No description provided for @accountSettingsChangePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Opens the web in your browser. Afterwards, sign in here again; changes not sent yet are kept.'**
  String get accountSettingsChangePasswordHint;

  /// No description provided for @accountSettingsChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email address'**
  String get accountSettingsChangeEmail;

  /// No description provided for @accountSettingsOpensWeb.
  ///
  /// In en, this message translates to:
  /// **'Opens the web in your browser'**
  String get accountSettingsOpensWeb;

  /// No description provided for @accountSettingsPendingEmail.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation of {email}'**
  String accountSettingsPendingEmail(String email);

  /// No description provided for @accountSettingsManagedBySignInNamed.
  ///
  /// In en, this message translates to:
  /// **'Managed by your sign-in provider ({provider})'**
  String accountSettingsManagedBySignInNamed(String provider);

  /// No description provided for @accountSettingsWebNotOpened.
  ///
  /// In en, this message translates to:
  /// **'The browser could not be opened.'**
  String get accountSettingsWebNotOpened;

  /// No description provided for @accountSettingsDefaults.
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get accountSettingsDefaults;

  /// No description provided for @accountSettingsDefaultProject.
  ///
  /// In en, this message translates to:
  /// **'Default project'**
  String get accountSettingsDefaultProject;

  /// No description provided for @accountSettingsDefaultProjectNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get accountSettingsDefaultProjectNone;

  /// No description provided for @accountSettingsDefaultProjectUnknown.
  ///
  /// In en, this message translates to:
  /// **'A project not on this device'**
  String get accountSettingsDefaultProjectUnknown;

  /// No description provided for @accountSettingsDefaultProjectInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose a project you can add tasks to that is not archived.'**
  String get accountSettingsDefaultProjectInvalid;

  /// No description provided for @accountSettingsDefaultView.
  ///
  /// In en, this message translates to:
  /// **'Default view'**
  String get accountSettingsDefaultView;

  /// No description provided for @accountSettingsDefaultViewFirst.
  ///
  /// In en, this message translates to:
  /// **'First view'**
  String get accountSettingsDefaultViewFirst;

  /// No description provided for @accountSettingsQuickAddMagic.
  ///
  /// In en, this message translates to:
  /// **'Quick Add Magic'**
  String get accountSettingsQuickAddMagic;

  /// No description provided for @accountSettingsQuickAddMagicDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get accountSettingsQuickAddMagicDisabled;

  /// No description provided for @accountSettingsQuickAddMagicVikunja.
  ///
  /// In en, this message translates to:
  /// **'Vikunja'**
  String get accountSettingsQuickAddMagicVikunja;

  /// No description provided for @accountSettingsQuickAddMagicTodoist.
  ///
  /// In en, this message translates to:
  /// **'Todoist'**
  String get accountSettingsQuickAddMagicTodoist;

  /// The lowest priority task rows show, the web's minimum visible task priority.
  ///
  /// In en, this message translates to:
  /// **'Priorities shown from'**
  String get accountSettingsMinimumPriority;

  /// What the Overview tab lists: all open tasks or a saved filter.
  ///
  /// In en, this message translates to:
  /// **'Overview shows'**
  String get accountSettingsOverviewFilter;

  /// No description provided for @accountSettingsOverviewFilterNone.
  ///
  /// In en, this message translates to:
  /// **'All open tasks'**
  String get accountSettingsOverviewFilterNone;

  /// No description provided for @accountSettingsOverviewFilterUnknown.
  ///
  /// In en, this message translates to:
  /// **'A saved filter not on this device'**
  String get accountSettingsOverviewFilterUnknown;

  /// No description provided for @accountSettingsWeekStart.
  ///
  /// In en, this message translates to:
  /// **'First day of the week'**
  String get accountSettingsWeekStart;

  /// No description provided for @accountSettingsTimeAndLanguage.
  ///
  /// In en, this message translates to:
  /// **'Time and language'**
  String get accountSettingsTimeAndLanguage;

  /// No description provided for @accountSettingsTimezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get accountSettingsTimezone;

  /// No description provided for @accountSettingsTimezoneServerDefault.
  ///
  /// In en, this message translates to:
  /// **'The server\'s default'**
  String get accountSettingsTimezoneServerDefault;

  /// No description provided for @accountSettingsTimezoneHelp.
  ///
  /// In en, this message translates to:
  /// **'For saved filters, emails and reminders sent by the server. The app shows times in this device\'s zone.'**
  String get accountSettingsTimezoneHelp;

  /// No description provided for @accountSettingsTimezoneSearch.
  ///
  /// In en, this message translates to:
  /// **'Search time zones'**
  String get accountSettingsTimezoneSearch;

  /// No description provided for @accountSettingsTimezoneDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get accountSettingsTimezoneDevice;

  /// Heads the time zones whose clocks match this device's over the coming year.
  ///
  /// In en, this message translates to:
  /// **'Same time as this device'**
  String get accountSettingsTimezoneSameAsDevice;

  /// No description provided for @accountSettingsTimezoneAll.
  ///
  /// In en, this message translates to:
  /// **'All time zones'**
  String get accountSettingsTimezoneAll;

  /// No description provided for @accountSettingsTimezoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server does not know the time zone {zone}. Choose another one.'**
  String accountSettingsTimezoneInvalid(String zone);

  /// No description provided for @accountSettingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountSettingsLanguage;

  /// No description provided for @accountSettingsLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'For emails and the web. The app follows your device\'s language.'**
  String get accountSettingsLanguageHelp;

  /// No description provided for @accountSettingsLanguageNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get accountSettingsLanguageNotSet;

  /// No description provided for @accountSettingsLanguageSearch.
  ///
  /// In en, this message translates to:
  /// **'Search languages'**
  String get accountSettingsLanguageSearch;

  /// No description provided for @accountSettingsDateDisplay.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get accountSettingsDateDisplay;

  /// No description provided for @accountSettingsDateDisplayDevice.
  ///
  /// In en, this message translates to:
  /// **'As on this device'**
  String get accountSettingsDateDisplayDevice;

  /// No description provided for @accountSettingsDateDisplayRelative.
  ///
  /// In en, this message translates to:
  /// **'Relative, e.g. in 3 days'**
  String get accountSettingsDateDisplayRelative;

  /// No description provided for @accountSettingsDateMonthDayYearDashed.
  ///
  /// In en, this message translates to:
  /// **'MM-DD-YYYY'**
  String get accountSettingsDateMonthDayYearDashed;

  /// No description provided for @accountSettingsDateDayMonthYearDashed.
  ///
  /// In en, this message translates to:
  /// **'DD-MM-YYYY'**
  String get accountSettingsDateDayMonthYearDashed;

  /// No description provided for @accountSettingsDateYearMonthDayDashed.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get accountSettingsDateYearMonthDayDashed;

  /// No description provided for @accountSettingsDateMonthDayYearSlashed.
  ///
  /// In en, this message translates to:
  /// **'MM/DD/YYYY'**
  String get accountSettingsDateMonthDayYearSlashed;

  /// No description provided for @accountSettingsDateDayMonthYearSlashed.
  ///
  /// In en, this message translates to:
  /// **'DD/MM/YYYY'**
  String get accountSettingsDateDayMonthYearSlashed;

  /// No description provided for @accountSettingsDateYearMonthDaySlashed.
  ///
  /// In en, this message translates to:
  /// **'YYYY/MM/DD'**
  String get accountSettingsDateYearMonthDaySlashed;

  /// No description provided for @accountSettingsDateExample.
  ///
  /// In en, this message translates to:
  /// **'Example: {example}'**
  String accountSettingsDateExample(String example);

  /// No description provided for @accountSettingsTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get accountSettingsTimeFormat;

  /// No description provided for @accountSettingsTimeFormatDevice.
  ///
  /// In en, this message translates to:
  /// **'As on this device'**
  String get accountSettingsTimeFormatDevice;

  /// No description provided for @accountSettingsTimeFormat12.
  ///
  /// In en, this message translates to:
  /// **'12-hour'**
  String get accountSettingsTimeFormat12;

  /// No description provided for @accountSettingsTimeFormat24.
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get accountSettingsTimeFormat24;

  /// No description provided for @accountSettingsEmailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get accountSettingsEmailNotifications;

  /// No description provided for @accountSettingsEmailsOff.
  ///
  /// In en, this message translates to:
  /// **'This server does not send reminder emails at the moment. The settings are kept for when it does.'**
  String get accountSettingsEmailsOff;

  /// No description provided for @accountSettingsEmailReminders.
  ///
  /// In en, this message translates to:
  /// **'Task reminders by email'**
  String get accountSettingsEmailReminders;

  /// No description provided for @accountSettingsEmailRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An email for each reminder, besides this device\'s notifications'**
  String get accountSettingsEmailRemindersSubtitle;

  /// No description provided for @accountSettingsOverdueReminders.
  ///
  /// In en, this message translates to:
  /// **'Daily overdue summary'**
  String get accountSettingsOverdueReminders;

  /// No description provided for @accountSettingsOverdueRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An email listing your overdue tasks that are not done'**
  String get accountSettingsOverdueRemindersSubtitle;

  /// No description provided for @accountSettingsOverdueTime.
  ///
  /// In en, this message translates to:
  /// **'Time of the summary'**
  String get accountSettingsOverdueTime;

  /// No description provided for @accountSettingsOverdueTimeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server refused this time.'**
  String get accountSettingsOverdueTimeInvalid;

  /// No description provided for @accountSettingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get accountSettingsPrivacy;

  /// No description provided for @accountSettingsDiscoverableByName.
  ///
  /// In en, this message translates to:
  /// **'Findable by name'**
  String get accountSettingsDiscoverableByName;

  /// No description provided for @accountSettingsDiscoverableByNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Others can add you to teams and projects by searching for your name'**
  String get accountSettingsDiscoverableByNameSubtitle;

  /// No description provided for @accountSettingsDiscoverableByEmail.
  ///
  /// In en, this message translates to:
  /// **'Findable by email'**
  String get accountSettingsDiscoverableByEmail;

  /// No description provided for @accountSettingsDiscoverableByEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Others can add you to teams and projects by searching for your full email address'**
  String get accountSettingsDiscoverableByEmailSubtitle;

  /// No description provided for @accountSettingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountSettingsAppearance;

  /// No description provided for @accountSettingsColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Colour scheme'**
  String get accountSettingsColorScheme;

  /// No description provided for @accountSettingsColorSchemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get accountSettingsColorSchemeLight;

  /// No description provided for @accountSettingsColorSchemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get accountSettingsColorSchemeSystem;

  /// No description provided for @accountSettingsColorSchemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get accountSettingsColorSchemeDark;

  /// No description provided for @accountSettingsNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get accountSettingsNothingFound;

  /// No description provided for @accountSettingsNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Changing account settings needs a connection to the server.'**
  String get accountSettingsNeedsConnection;

  /// No description provided for @accountSettingsUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The change could not be confirmed. Check it again once the connection is back.'**
  String get accountSettingsUnconfirmed;

  /// No description provided for @accountSettingsSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to change account settings.'**
  String get accountSettingsSignInAgain;

  /// No description provided for @accountSettingsRefused.
  ///
  /// In en, this message translates to:
  /// **'The server refused the change: {message}'**
  String accountSettingsRefused(String message);

  /// No description provided for @accountSettingsInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server refused this value.'**
  String get accountSettingsInvalid;

  /// No description provided for @accountSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'The change could not be saved. Try again later.'**
  String get accountSettingsFailed;

  /// No description provided for @avatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get avatarTitle;

  /// No description provided for @avatarCurrent.
  ///
  /// In en, this message translates to:
  /// **'Your avatar'**
  String get avatarCurrent;

  /// No description provided for @avatarProviderDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get avatarProviderDefault;

  /// No description provided for @avatarProviderDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A plain picture'**
  String get avatarProviderDefaultSubtitle;

  /// No description provided for @avatarProviderInitials.
  ///
  /// In en, this message translates to:
  /// **'Initials'**
  String get avatarProviderInitials;

  /// No description provided for @avatarProviderInitialsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your initials'**
  String get avatarProviderInitialsSubtitle;

  /// No description provided for @avatarProviderGravatar.
  ///
  /// In en, this message translates to:
  /// **'Gravatar'**
  String get avatarProviderGravatar;

  /// No description provided for @avatarProviderGravatarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The picture for your email address at gravatar.com'**
  String get avatarProviderGravatarSubtitle;

  /// No description provided for @avatarProviderMarble.
  ///
  /// In en, this message translates to:
  /// **'Marble'**
  String get avatarProviderMarble;

  /// No description provided for @avatarProviderMarbleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A colourful pattern made from your username'**
  String get avatarProviderMarbleSubtitle;

  /// No description provided for @avatarProviderUpload.
  ///
  /// In en, this message translates to:
  /// **'Your photo'**
  String get avatarProviderUpload;

  /// No description provided for @avatarProviderUploadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A photo from this device'**
  String get avatarProviderUploadSubtitle;

  /// No description provided for @avatarProviderUploadReplace.
  ///
  /// In en, this message translates to:
  /// **'Choose another photo'**
  String get avatarProviderUploadReplace;

  /// No description provided for @avatarProviderLdap.
  ///
  /// In en, this message translates to:
  /// **'From your directory'**
  String get avatarProviderLdap;

  /// No description provided for @avatarProviderOpenId.
  ///
  /// In en, this message translates to:
  /// **'From your sign-in provider'**
  String get avatarProviderOpenId;

  /// No description provided for @avatarAppShowsInitials.
  ///
  /// In en, this message translates to:
  /// **'This app shows your initials for the default, initials and marble avatars; the web draws them.'**
  String get avatarAppShowsInitials;

  /// No description provided for @avatarManagedLdap.
  ///
  /// In en, this message translates to:
  /// **'Your avatar comes from your organisation\'s directory (LDAP). Ask your IT team how to change it.'**
  String get avatarManagedLdap;

  /// No description provided for @avatarManagedOpenId.
  ///
  /// In en, this message translates to:
  /// **'Your avatar comes from your sign-in provider ({provider}). Change it there.'**
  String avatarManagedOpenId(String provider);

  /// No description provided for @avatarChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get avatarChoosePhoto;

  /// No description provided for @avatarTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get avatarTakePhoto;

  /// No description provided for @avatarChanged.
  ///
  /// In en, this message translates to:
  /// **'Avatar changed'**
  String get avatarChanged;

  /// No description provided for @avatarUploaded.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded'**
  String get avatarUploaded;

  /// No description provided for @avatarCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Your new avatar'**
  String get avatarCropTitle;

  /// No description provided for @avatarCropHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to move the photo and pinch to zoom. The square becomes your avatar.'**
  String get avatarCropHint;

  /// No description provided for @avatarCropUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get avatarCropUpload;

  /// No description provided for @avatarUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get avatarUploading;

  /// No description provided for @avatarImageUnusable.
  ///
  /// In en, this message translates to:
  /// **'This picture cannot be used. Choose a PNG or JPEG photo.'**
  String get avatarImageUnusable;

  /// No description provided for @avatarImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This picture is too large for the server.'**
  String get avatarImageTooLarge;

  /// No description provided for @avatarPickFailed.
  ///
  /// In en, this message translates to:
  /// **'The photos could not be opened.'**
  String get avatarPickFailed;

  /// No description provided for @accountSettingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get accountSettingsSecurity;

  /// No description provided for @accountSettingsTotp.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get accountSettingsTotp;

  /// No description provided for @accountSettingsTotpOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get accountSettingsTotpOn;

  /// No description provided for @accountSettingsTotpOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get accountSettingsTotpOff;

  /// No description provided for @accountSettingsTotpSetupStarted.
  ///
  /// In en, this message translates to:
  /// **'Setup not finished'**
  String get accountSettingsTotpSetupStarted;

  /// No description provided for @accountSettingsTotpChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get accountSettingsTotpChecking;

  /// No description provided for @accountSettingsTotpUnknown.
  ///
  /// In en, this message translates to:
  /// **'Could not be checked'**
  String get accountSettingsTotpUnknown;

  /// No description provided for @accountSettingsTotpNotOffered.
  ///
  /// In en, this message translates to:
  /// **'Not offered by this server'**
  String get accountSettingsTotpNotOffered;

  /// No description provided for @accountSettingsTotpNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available for this account'**
  String get accountSettingsTotpNotAvailable;

  /// No description provided for @accountSettingsTotpNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked over an unencrypted connection'**
  String get accountSettingsTotpNotChecked;

  /// No description provided for @accountSettingsTotpTurnOnNote.
  ///
  /// In en, this message translates to:
  /// **'Opens the web in your browser. Turning it on signs you out everywhere, this app included. Then sign in here again; your browser asks for the code.'**
  String get accountSettingsTotpTurnOnNote;

  /// No description provided for @accountSettingsTotpOnNote.
  ///
  /// In en, this message translates to:
  /// **'Opens the web in your browser. Turning it off needs your password.'**
  String get accountSettingsTotpOnNote;

  /// No description provided for @accountSettingsSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get accountSettingsSessions;

  /// No description provided for @accountSettingsSessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 signed-in device or browser} other{{count} signed-in devices and browsers}}'**
  String accountSettingsSessionsCount(int count);

  /// No description provided for @accountSettingsSessionsHint.
  ///
  /// In en, this message translates to:
  /// **'Where you are signed in'**
  String get accountSettingsSessionsHint;

  /// No description provided for @accountSettingsIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get accountSettingsIntegrations;

  /// No description provided for @accountSettingsApiTokens.
  ///
  /// In en, this message translates to:
  /// **'API tokens'**
  String get accountSettingsApiTokens;

  /// No description provided for @accountSettingsApiTokensCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tokens} =1{1 token} other{{count} tokens}}'**
  String accountSettingsApiTokensCount(int count);

  /// No description provided for @accountSettingsApiTokensHint.
  ///
  /// In en, this message translates to:
  /// **'For scripts and other apps'**
  String get accountSettingsApiTokensHint;

  /// The protocol's name; not translated.
  ///
  /// In en, this message translates to:
  /// **'CalDAV'**
  String get accountSettingsCaldav;

  /// No description provided for @accountSettingsCaldavHint.
  ///
  /// In en, this message translates to:
  /// **'Your tasks in calendar and task apps'**
  String get accountSettingsCaldavHint;

  /// No description provided for @accountSettingsYourData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get accountSettingsYourData;

  /// No description provided for @accountSettingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export your data'**
  String get accountSettingsExport;

  /// No description provided for @accountSettingsExportReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to download until {date}'**
  String accountSettingsExportReady(String date);

  /// No description provided for @accountSettingsExportNone.
  ///
  /// In en, this message translates to:
  /// **'No export yet'**
  String get accountSettingsExportNone;

  /// No description provided for @accountSettingsExportHint.
  ///
  /// In en, this message translates to:
  /// **'A copy of your projects and tasks'**
  String get accountSettingsExportHint;

  /// No description provided for @accountSettingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountSettingsDeleteAccount;

  /// No description provided for @accountSettingsWebAsksPassword.
  ///
  /// In en, this message translates to:
  /// **'The web asks for your password.'**
  String get accountSettingsWebAsksPassword;

  /// No description provided for @accountDeletionScheduled.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted on {date}.'**
  String accountDeletionScheduled(String date);

  /// No description provided for @accountDeletionOverdue.
  ///
  /// In en, this message translates to:
  /// **'Your account has been due for deletion since {date}.'**
  String accountDeletionOverdue(String date);

  /// No description provided for @accountDeletionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel deletion'**
  String get accountDeletionCancel;

  /// No description provided for @accountDeletionScheduledRow.
  ///
  /// In en, this message translates to:
  /// **'Deletion on {date}. Cancel it on the web.'**
  String accountDeletionScheduledRow(String date);

  /// No description provided for @accountDeletionOverdueRow.
  ///
  /// In en, this message translates to:
  /// **'Deletion due since {date}. Cancel it on the web.'**
  String accountDeletionOverdueRow(String date);

  /// No description provided for @accountDeletionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeletionDialogTitle;

  /// No description provided for @accountDeletionDialogPermanent.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account is permanent. All projects and tasks you own are deleted with it; what you shared with others passes to them.'**
  String get accountDeletionDialogPermanent;

  /// No description provided for @accountDeletionDialogEmail.
  ///
  /// In en, this message translates to:
  /// **'The server emails you a link to confirm. Once you confirm, your account is deleted after three days; until then you can change your mind.'**
  String get accountDeletionDialogEmail;

  /// No description provided for @accountDeletionDialogNoEmail.
  ///
  /// In en, this message translates to:
  /// **'If your server does not send emails, ask its administrator to delete your account.'**
  String get accountDeletionDialogNoEmail;

  /// No description provided for @accountDeletionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue in the browser'**
  String get accountDeletionContinue;

  /// No description provided for @accountSecurityNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'This needs a connection to the server.'**
  String get accountSecurityNeedsConnection;

  /// No description provided for @accountSecurityUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The server\'s answer did not arrive. Refresh to see whether it worked.'**
  String get accountSecurityUnconfirmed;

  /// No description provided for @accountSecuritySignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again first.'**
  String get accountSecuritySignInAgain;

  /// No description provided for @accountSecurityNotOffered.
  ///
  /// In en, this message translates to:
  /// **'This server does not offer this.'**
  String get accountSecurityNotOffered;

  /// No description provided for @accountSecurityRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The server is busy. Try again in a minute.'**
  String get accountSecurityRateLimited;

  /// No description provided for @accountSecurityRefused.
  ///
  /// In en, this message translates to:
  /// **'The server refused: {message}'**
  String accountSecurityRefused(String message);

  /// No description provided for @accountSecurityFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Try again later.'**
  String get accountSecurityFailed;

  /// Screen readers say it for a spinner on a row while it is changed.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get accountSecurityWorking;

  /// No description provided for @accountSecurityCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String accountSecurityCreated(String date);

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsIntro.
  ///
  /// In en, this message translates to:
  /// **'These devices and browsers are signed in to your account. Ending a session signs that device or browser out; it can take up to 10 minutes.'**
  String get sessionsIntro;

  /// No description provided for @sessionsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading sessions…'**
  String get sessionsLoading;

  /// No description provided for @sessionsThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get sessionsThisDevice;

  /// No description provided for @sessionsThisDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'To end this session, sign out of the account in this app.'**
  String get sessionsThisDeviceHint;

  /// No description provided for @sessionsLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {when}'**
  String sessionsLastActive(String when);

  /// No description provided for @sessionsLastActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Last active'**
  String get sessionsLastActiveLabel;

  /// No description provided for @sessionsSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get sessionsSignedIn;

  /// No description provided for @sessionsDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get sessionsDevice;

  /// No description provided for @sessionsIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get sessionsIpAddress;

  /// No description provided for @sessionsUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get sessionsUnknownDevice;

  /// No description provided for @sessionsBrowserOn.
  ///
  /// In en, this message translates to:
  /// **'{browser} on {system}'**
  String sessionsBrowserOn(String browser, String system);

  /// A session whose User-Agent is only the Dart runtime, e.g. a script.
  ///
  /// In en, this message translates to:
  /// **'An app without a name'**
  String get sessionsDartClient;

  /// No description provided for @sessionsEnd.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get sessionsEnd;

  /// No description provided for @sessionsEndTitle.
  ///
  /// In en, this message translates to:
  /// **'End this session?'**
  String get sessionsEndTitle;

  /// No description provided for @sessionsEndBody.
  ///
  /// In en, this message translates to:
  /// **'{device} will be signed out. It can take up to 10 minutes.'**
  String sessionsEndBody(String device);

  /// No description provided for @sessionsEnded.
  ///
  /// In en, this message translates to:
  /// **'Session ended. It can take up to 10 minutes to take effect.'**
  String get sessionsEnded;

  /// No description provided for @sessionsEndOthers.
  ///
  /// In en, this message translates to:
  /// **'End all other sessions'**
  String get sessionsEndOthers;

  /// No description provided for @sessionsEndOthersTitle.
  ///
  /// In en, this message translates to:
  /// **'End all other sessions?'**
  String get sessionsEndOthersTitle;

  /// No description provided for @sessionsEndOthersBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The other device or browser is signed out} other{All {count} other devices and browsers are signed out}} within 10 minutes. This device stays signed in.'**
  String sessionsEndOthersBody(int count);

  /// No description provided for @sessionsEndedOthers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No other session to end.} =1{1 session ended. It can take up to 10 minutes to take effect.} other{{count} sessions ended. It can take up to 10 minutes to take effect.}}'**
  String sessionsEndedOthers(int count);

  /// No description provided for @sessionsNotAllEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended: {ended}. Still signed in: {notEnded}.'**
  String sessionsNotAllEnded(int ended, int notEnded);

  /// No description provided for @sessionsNoOthers.
  ///
  /// In en, this message translates to:
  /// **'No other sessions'**
  String get sessionsNoOthers;

  /// No description provided for @sessionsNoOthersBody.
  ///
  /// In en, this message translates to:
  /// **'Only this device is signed in to your account.'**
  String get sessionsNoOthersBody;

  /// No description provided for @sessionsOptionsFor.
  ///
  /// In en, this message translates to:
  /// **'Options for {device}'**
  String sessionsOptionsFor(String device);

  /// No description provided for @apiTokensTitle.
  ///
  /// In en, this message translates to:
  /// **'API tokens'**
  String get apiTokensTitle;

  /// No description provided for @apiTokensIntro.
  ///
  /// In en, this message translates to:
  /// **'API tokens let scripts and other apps use Vikunja\'s API without your password. A token can only do what its permissions allow.'**
  String get apiTokensIntro;

  /// No description provided for @apiTokensDocs.
  ///
  /// In en, this message translates to:
  /// **'API documentation'**
  String get apiTokensDocs;

  /// No description provided for @apiTokensLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading API tokens…'**
  String get apiTokensLoading;

  /// No description provided for @apiTokensEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No API tokens'**
  String get apiTokensEmptyTitle;

  /// No description provided for @apiTokensEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create one for a script or another app.'**
  String get apiTokensEmptyBody;

  /// No description provided for @apiTokensNew.
  ///
  /// In en, this message translates to:
  /// **'New token'**
  String get apiTokensNew;

  /// No description provided for @apiTokensExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String apiTokensExpires(String date);

  /// No description provided for @apiTokensExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired {when}'**
  String apiTokensExpired(String when);

  /// No description provided for @apiTokensPermissionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 permission} other{{count} permissions}}'**
  String apiTokensPermissionCount(int count);

  /// No description provided for @apiTokensPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get apiTokensPermissions;

  /// No description provided for @apiTokensDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete token'**
  String get apiTokensDelete;

  /// No description provided for @apiTokensDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the token “{title}”?'**
  String apiTokensDeleteTitle(String title);

  /// No description provided for @apiTokensDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Apps and scripts using it stop working. This cannot be undone.'**
  String get apiTokensDeleteBody;

  /// No description provided for @apiTokensDeleted.
  ///
  /// In en, this message translates to:
  /// **'Token deleted'**
  String get apiTokensDeleted;

  /// No description provided for @apiTokenFormTitle.
  ///
  /// In en, this message translates to:
  /// **'New API token'**
  String get apiTokenFormTitle;

  /// No description provided for @apiTokenFormCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get apiTokenFormCreate;

  /// No description provided for @apiTokenFormCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get apiTokenFormCreating;

  /// No description provided for @apiTokenFormLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading permissions…'**
  String get apiTokenFormLoading;

  /// No description provided for @apiTokenFormName.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get apiTokenFormName;

  /// No description provided for @apiTokenFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'A title you will recognise later'**
  String get apiTokenFormNameHint;

  /// No description provided for @apiTokenFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title.'**
  String get apiTokenFormNameRequired;

  /// No description provided for @apiTokenFormExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get apiTokenFormExpiry;

  /// No description provided for @apiTokenFormExpiryDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{In 1 day} other{In {days} days}}'**
  String apiTokenFormExpiryDays(int days);

  /// No description provided for @apiTokenFormExpiryCustom.
  ///
  /// In en, this message translates to:
  /// **'Pick a day…'**
  String get apiTokenFormExpiryCustom;

  /// No description provided for @apiTokenFormExpiryPick.
  ///
  /// In en, this message translates to:
  /// **'Valid through'**
  String get apiTokenFormExpiryPick;

  /// No description provided for @apiTokenFormExpiryThrough.
  ///
  /// In en, this message translates to:
  /// **'Through {date}'**
  String apiTokenFormExpiryThrough(String date);

  /// No description provided for @apiTokenFormExpiryPast.
  ///
  /// In en, this message translates to:
  /// **'Pick a day that has not passed yet.'**
  String get apiTokenFormExpiryPast;

  /// No description provided for @apiTokenFormPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get apiTokenFormPermissions;

  /// No description provided for @apiTokenFormPermissionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose what the token may do. The names come from the server and are not translated.'**
  String get apiTokenFormPermissionsHelp;

  /// No description provided for @apiTokenFormPermissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one permission.'**
  String get apiTokenFormPermissionsRequired;

  /// No description provided for @apiTokenFormNoPermissions.
  ///
  /// In en, this message translates to:
  /// **'This server offers no permissions for tokens.'**
  String get apiTokenFormNoPermissions;

  /// No description provided for @apiTokenFormPresets.
  ///
  /// In en, this message translates to:
  /// **'Quick presets'**
  String get apiTokenFormPresets;

  /// No description provided for @apiTokenPresetReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get apiTokenPresetReadOnly;

  /// No description provided for @apiTokenPresetTasks.
  ///
  /// In en, this message translates to:
  /// **'Task management'**
  String get apiTokenPresetTasks;

  /// No description provided for @apiTokenPresetProjects.
  ///
  /// In en, this message translates to:
  /// **'Project management'**
  String get apiTokenPresetProjects;

  /// No description provided for @apiTokenPresetFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Full access'**
  String get apiTokenPresetFullAccess;

  /// No description provided for @apiTokenFormGroupSelected.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total}'**
  String apiTokenFormGroupSelected(int selected, int total);

  /// No description provided for @apiTokenFormShowGroup.
  ///
  /// In en, this message translates to:
  /// **'Show the permissions of {group}'**
  String apiTokenFormShowGroup(String group);

  /// No description provided for @apiTokenFormHideGroup.
  ///
  /// In en, this message translates to:
  /// **'Hide the permissions of {group}'**
  String apiTokenFormHideGroup(String group);

  /// No description provided for @apiTokenFormDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The token has not been created.'**
  String get apiTokenFormDiscardBody;

  /// No description provided for @oneTimeSecretApiTitle.
  ///
  /// In en, this message translates to:
  /// **'Your new API token'**
  String get oneTimeSecretApiTitle;

  /// No description provided for @oneTimeSecretCaldavTitle.
  ///
  /// In en, this message translates to:
  /// **'Your new CalDAV token'**
  String get oneTimeSecretCaldavTitle;

  /// No description provided for @oneTimeSecretLabel.
  ///
  /// In en, this message translates to:
  /// **'The new token'**
  String get oneTimeSecretLabel;

  /// No description provided for @oneTimeSecretCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get oneTimeSecretCopy;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copiedToClipboard;

  /// No description provided for @copyToClipboardFailed.
  ///
  /// In en, this message translates to:
  /// **'Copying did not work. Try again.'**
  String get copyToClipboardFailed;

  /// No description provided for @oneTimeSecretOnce.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see it again. Store it somewhere safe, such as a password manager.'**
  String get oneTimeSecretOnce;

  /// No description provided for @oneTimeSecretApiUsage.
  ///
  /// In en, this message translates to:
  /// **'Scripts and apps send it as a bearer token in the Authorization header.'**
  String get oneTimeSecretApiUsage;

  /// No description provided for @oneTimeSecretCaldavUsage.
  ///
  /// In en, this message translates to:
  /// **'Enter it as the password in your CalDAV app, with the username {username}.'**
  String oneTimeSecretCaldavUsage(String username);

  /// No description provided for @oneTimeSecretDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get oneTimeSecretDone;

  /// No description provided for @oneTimeSecretLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without copying?'**
  String get oneTimeSecretLeaveTitle;

  /// No description provided for @oneTimeSecretLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'The token is shown only now. Without it, you will have to create a new one.'**
  String get oneTimeSecretLeaveBody;

  /// No description provided for @oneTimeSecretStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get oneTimeSecretStay;

  /// No description provided for @oneTimeSecretLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get oneTimeSecretLeave;

  /// No description provided for @caldavTitle.
  ///
  /// In en, this message translates to:
  /// **'CalDAV'**
  String get caldavTitle;

  /// No description provided for @caldavIntro.
  ///
  /// In en, this message translates to:
  /// **'Connect calendar and task apps that speak CalDAV to see and change your tasks there. Enter this address in the app:'**
  String get caldavIntro;

  /// No description provided for @caldavAddress.
  ///
  /// In en, this message translates to:
  /// **'CalDAV address'**
  String get caldavAddress;

  /// No description provided for @caldavUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get caldavUsername;

  /// No description provided for @caldavCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy the address'**
  String get caldavCopyAddress;

  /// No description provided for @caldavCopyUsername.
  ///
  /// In en, this message translates to:
  /// **'Copy the username'**
  String get caldavCopyUsername;

  /// No description provided for @caldavPasswordOrToken.
  ///
  /// In en, this message translates to:
  /// **'As the password, use a CalDAV token or your account password.'**
  String get caldavPasswordOrToken;

  /// No description provided for @caldavTokenTotp.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication is on, so your account password does not work here. Use a CalDAV token as the password.'**
  String get caldavTokenTotp;

  /// No description provided for @caldavTokenProvider.
  ///
  /// In en, this message translates to:
  /// **'You sign in through {provider}, so use a CalDAV token as the password.'**
  String caldavTokenProvider(String provider);

  /// No description provided for @caldavTokenUnknown.
  ///
  /// In en, this message translates to:
  /// **'Use a CalDAV token as the password. Your account password works too, unless two-factor authentication is on.'**
  String get caldavTokenUnknown;

  /// No description provided for @caldavApiTokenHint.
  ///
  /// In en, this message translates to:
  /// **'An API token with the CalDAV permission works as the password too.'**
  String get caldavApiTokenHint;

  /// No description provided for @caldavDocs.
  ///
  /// In en, this message translates to:
  /// **'More about CalDAV in Vikunja'**
  String get caldavDocs;

  /// No description provided for @caldavTokens.
  ///
  /// In en, this message translates to:
  /// **'CalDAV tokens'**
  String get caldavTokens;

  /// No description provided for @caldavTokensLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading CalDAV tokens…'**
  String get caldavTokensLoading;

  /// No description provided for @caldavTokensEmpty.
  ///
  /// In en, this message translates to:
  /// **'No CalDAV tokens yet.'**
  String get caldavTokensEmpty;

  /// No description provided for @caldavTokenName.
  ///
  /// In en, this message translates to:
  /// **'Token {id}'**
  String caldavTokenName(int id);

  /// No description provided for @caldavNewToken.
  ///
  /// In en, this message translates to:
  /// **'New CalDAV token'**
  String get caldavNewToken;

  /// No description provided for @caldavDeleteToken.
  ///
  /// In en, this message translates to:
  /// **'Delete token {id}'**
  String caldavDeleteToken(int id);

  /// No description provided for @caldavDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete token {id}?'**
  String caldavDeleteTitle(int id);

  /// No description provided for @caldavDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'CalDAV apps using it can no longer sign in. This cannot be undone.'**
  String get caldavDeleteBody;

  /// No description provided for @caldavDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get caldavDelete;

  /// No description provided for @caldavTokenDeleted.
  ///
  /// In en, this message translates to:
  /// **'CalDAV token deleted'**
  String get caldavTokenDeleted;

  /// No description provided for @dataExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export your data'**
  String get dataExportTitle;

  /// No description provided for @dataExportIntro.
  ///
  /// In en, this message translates to:
  /// **'The export holds your projects, tasks, comments, attachments and saved filters. You can import it into any Vikunja server.'**
  String get dataExportIntro;

  /// No description provided for @dataExportLoading.
  ///
  /// In en, this message translates to:
  /// **'Looking for an export…'**
  String get dataExportLoading;

  /// No description provided for @dataExportReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to download'**
  String get dataExportReadyTitle;

  /// No description provided for @dataExportReadyBody.
  ///
  /// In en, this message translates to:
  /// **'{size}, available until {date}'**
  String dataExportReadyBody(String size, String date);

  /// No description provided for @dataExportNoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No export yet'**
  String get dataExportNoneTitle;

  /// No description provided for @dataExportNoneBody.
  ///
  /// In en, this message translates to:
  /// **'Request one below. An export is kept for seven days.'**
  String get dataExportNoneBody;

  /// No description provided for @dataExportRequest.
  ///
  /// In en, this message translates to:
  /// **'Request a new export'**
  String get dataExportRequest;

  /// No description provided for @dataExportRequestNote.
  ///
  /// In en, this message translates to:
  /// **'Opens the web in your browser. The server emails you when the export is ready, and this page shows it too.'**
  String get dataExportRequestNote;

  /// No description provided for @dataExportDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get dataExportDownload;

  /// Headline of the Overview before noon.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String overviewGreetingMorning(String name);

  /// Headline of the Overview from noon to 6 pm.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String overviewGreetingAfternoon(String name);

  /// Headline of the Overview from 6 pm to 5 am.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String overviewGreetingEvening(String name);

  /// Under the Overview's greeting: the open tasks it shows that are due today or overdue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing left for today} =1{1 task left for today} other{{count} tasks left for today}}'**
  String overviewTasksLeftToday(int count);

  /// Under Upcoming's app bar: the date range's name, its days and how many open tasks are due in it.
  ///
  /// In en, this message translates to:
  /// **'{range}, {dates} · {count, plural, =0{nothing open} =1{1 open} other{{count} open}}'**
  String upcomingSubtitle(String range, String dates, int count);

  /// Screen reader label of a day in Upcoming's day strip.
  ///
  /// In en, this message translates to:
  /// **'{day}, {count, plural, =0{nothing open} =1{1 open} other{{count} open}}'**
  String upcomingDaySemantics(String day, int count);

  /// Screen reader hint of a day in Upcoming's day strip that is not selected.
  ///
  /// In en, this message translates to:
  /// **'Show only this day'**
  String get upcomingShowDayHint;

  /// Screen reader hint of the selected day in Upcoming's day strip: another tap shows every day again.
  ///
  /// In en, this message translates to:
  /// **'Show the whole range'**
  String get upcomingShowRangeHint;

  /// Upcoming with one day picked in the day strip that has no open tasks.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get upcomingNothingPlanned;

  /// The detail sheet's full-width button that marks an open task done.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get taskDetailMarkDone;

  /// The detail sheet's full-width button that reopens a done task.
  ///
  /// In en, this message translates to:
  /// **'Mark as not done'**
  String get taskDetailMarkNotDone;

  /// The status of a task that is not done, beside its project in the detail sheet.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskDetailStatusOpen;

  /// Filter chip under a project's view tabs that adds the done tasks to a list view.
  ///
  /// In en, this message translates to:
  /// **'Show done'**
  String get projectShowDoneChip;

  /// Under a project's title: how many of the project's own tasks are done.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String projectProgressDone(int done, int total);

  /// What screen readers say for the progress line under a project's title.
  ///
  /// In en, this message translates to:
  /// **'Project progress: {done} of {total} tasks done'**
  String projectProgressSemantics(int done, int total);

  /// Outlined button in the Account tab's profile header; opens the account settings.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get accountHeaderEdit;

  /// Account tab section with the server's version, the sync status and the changes waiting for the server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get accountServerHeading;

  /// The app's version line at the end of the Account tab.
  ///
  /// In en, this message translates to:
  /// **'Rurana {version} ({build})'**
  String accountAppVersion(String version, String build);

  /// The app's version line when the build number is unknown.
  ///
  /// In en, this message translates to:
  /// **'Rurana {version}'**
  String accountAppVersionWithoutBuild(String version);

  /// Heading of a task's comments while it has none.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsHeading;

  /// No description provided for @commentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get commentsEmpty;

  /// No description provided for @commentComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get commentComposerHint;

  /// No description provided for @commentSend.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get commentSend;

  /// No description provided for @commentSending.
  ///
  /// In en, this message translates to:
  /// **'Sending the comment…'**
  String get commentSending;

  /// Read by screen readers once a comment written in the app is on the server.
  ///
  /// In en, this message translates to:
  /// **'Comment sent'**
  String get commentPosted;

  /// No description provided for @commentComposerOffline.
  ///
  /// In en, this message translates to:
  /// **'Needs a connection. What you wrote stays here.'**
  String get commentComposerOffline;

  /// No description provided for @commentReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String commentReplyingTo(String name);

  /// Tooltip of the button that drops the quote above the comment field.
  ///
  /// In en, this message translates to:
  /// **'Don\'t reply'**
  String get commentReplyCancel;

  /// No description provided for @commentOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for the comment by {name}'**
  String commentOptions(String name);

  /// No description provided for @commentReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get commentReply;

  /// No description provided for @commentCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get commentCopyLink;

  /// No description provided for @commentLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get commentLinkCopied;

  /// No description provided for @commentEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commentEdit;

  /// No description provided for @commentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commentDelete;

  /// No description provided for @commentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get commentDeleteTitle;

  /// No description provided for @commentDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get commentDeleteBody;

  /// No description provided for @commentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get commentDeleted;

  /// No description provided for @commentSaved.
  ///
  /// In en, this message translates to:
  /// **'Comment saved'**
  String get commentSaved;

  /// Screen reader text of a comment while its edit or deletion is on the way.
  ///
  /// In en, this message translates to:
  /// **'Saving the change…'**
  String get commentWorking;

  /// No description provided for @commentEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get commentEditorTitle;

  /// No description provided for @commentEmptyRefused.
  ///
  /// In en, this message translates to:
  /// **'A comment can\'t be empty'**
  String get commentEmptyRefused;

  /// No description provided for @commentsArchivedNote.
  ///
  /// In en, this message translates to:
  /// **'This project is archived, so its comments can\'t be changed.'**
  String get commentsArchivedNote;

  /// No description provided for @commentsReadOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'You can only read this task.'**
  String get commentsReadOnlyNote;

  /// No description provided for @commentFailedNotAuthor.
  ///
  /// In en, this message translates to:
  /// **'Only the author can change a comment.'**
  String get commentFailedNotAuthor;

  /// No description provided for @commentFailedGone.
  ///
  /// In en, this message translates to:
  /// **'The comment no longer exists.'**
  String get commentFailedGone;

  /// No description provided for @commentFailedNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'This needs a connection to the server.'**
  String get commentFailedNeedsConnection;

  /// No description provided for @commentFailedTooLong.
  ///
  /// In en, this message translates to:
  /// **'This comment is too long.'**
  String get commentFailedTooLong;

  /// A comment write timed out: it may have arrived.
  ///
  /// In en, this message translates to:
  /// **'The server didn\'t answer. Check the comments before sending again.'**
  String get commentFailedUnconfirmed;

  /// No description provided for @commentFailedSend.
  ///
  /// In en, this message translates to:
  /// **'The comment couldn\'t be sent. Try again later.'**
  String get commentFailedSend;

  /// No description provided for @commentFailedSave.
  ///
  /// In en, this message translates to:
  /// **'The comment couldn\'t be saved. Try again later.'**
  String get commentFailedSave;

  /// No description provided for @commentFailedDelete.
  ///
  /// In en, this message translates to:
  /// **'The comment couldn\'t be deleted. Try again later.'**
  String get commentFailedDelete;

  /// No description provided for @reactionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add reaction'**
  String get reactionAdd;

  /// No description provided for @reactionOther.
  ///
  /// In en, this message translates to:
  /// **'Another emoji'**
  String get reactionOther;

  /// Hint in the field for any emoji in the add-reaction sheet; the system keyboard offers them.
  ///
  /// In en, this message translates to:
  /// **'Type an emoji'**
  String get reactionOtherHint;

  /// No description provided for @reactionOtherAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get reactionOtherAdd;

  /// No description provided for @reactionTooLong.
  ///
  /// In en, this message translates to:
  /// **'At most 20 characters'**
  String get reactionTooLong;

  /// Screen reader hint for a tap on a reaction chip the user has not reacted with.
  ///
  /// In en, this message translates to:
  /// **'add your reaction'**
  String get reactionAddMine;

  /// Screen reader hint for a tap on a reaction chip the user reacted with.
  ///
  /// In en, this message translates to:
  /// **'remove your reaction'**
  String get reactionRemoveMine;

  /// No description provided for @reactionFailed.
  ///
  /// In en, this message translates to:
  /// **'The reaction couldn\'t be saved. Try again later.'**
  String get reactionFailed;

  /// Read by screen readers for a task row's comment count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment} other{{count} comments}}'**
  String taskCommentCount(int count);

  /// Read by screen readers for a task row whose comments include one the user has not seen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 comment, unread} other{{count} comments, unread}}'**
  String taskCommentCountUnread(int count);

  /// Announced to screen readers when the quote above the comment field is dropped.
  ///
  /// In en, this message translates to:
  /// **'No longer replying'**
  String get commentReplyDropped;

  /// Project menu item that opens the project's sharing page.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareMenuItem;

  /// Title of a project's sharing page.
  ///
  /// In en, this message translates to:
  /// **'Share {project}'**
  String sharePageTitle(String project);

  /// No description provided for @sharePageLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading who has access…'**
  String get sharePageLoading;

  /// Section of the users a project is shared with.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get sharePeopleSection;

  /// Section of the teams a project is shared with.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get shareTeamsSection;

  /// Section of a project's link shares.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get shareLinksSection;

  /// No description provided for @sharePeopleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not shared with anyone yet'**
  String get sharePeopleEmpty;

  /// No description provided for @shareTeamsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not shared with any team yet'**
  String get shareTeamsEmpty;

  /// No description provided for @shareLinksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No links yet'**
  String get shareLinksEmpty;

  /// No description provided for @shareLinksIntro.
  ///
  /// In en, this message translates to:
  /// **'Anyone with a link can open this project without an account, with the link\'s permission.'**
  String get shareLinksIntro;

  /// The signed-in user's own row in a share list.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String shareUserIsYou(String name);

  /// Share permission 0.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get sharePermissionRead;

  /// Share permission 1.
  ///
  /// In en, this message translates to:
  /// **'Read & write'**
  String get sharePermissionWrite;

  /// Share permission 2.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get sharePermissionAdmin;

  /// No description provided for @shareAddPerson.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get shareAddPerson;

  /// No description provided for @shareAddTeam.
  ///
  /// In en, this message translates to:
  /// **'Add team'**
  String get shareAddTeam;

  /// A team share whose name the server hides because the user is not in the team.
  ///
  /// In en, this message translates to:
  /// **'Hidden team'**
  String get shareHiddenTeam;

  /// No description provided for @shareTeamMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String shareTeamMemberCount(int count);

  /// No description provided for @shareReadOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Only project admins can change who has access'**
  String get shareReadOnlyNote;

  /// Title of the sheet that changes or removes a share.
  ///
  /// In en, this message translates to:
  /// **'Access for {name}'**
  String shareAccessFor(String name);

  /// Title of the permission choice when adding a person or team.
  ///
  /// In en, this message translates to:
  /// **'Permission for {name}'**
  String sharePermissionFor(String name);

  /// No description provided for @shareRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get shareRemove;

  /// No description provided for @shareRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String shareRemoveTitle(String name);

  /// No description provided for @shareRemovePersonBody.
  ///
  /// In en, this message translates to:
  /// **'{name} loses access to this project and the projects under it at once.'**
  String shareRemovePersonBody(String name);

  /// No description provided for @shareRemoveSelfBody.
  ///
  /// In en, this message translates to:
  /// **'You lose access to this project and the projects under it at once, unless you have it in another way.'**
  String get shareRemoveSelfBody;

  /// No description provided for @shareRemoveTeamBody.
  ///
  /// In en, this message translates to:
  /// **'The members of {name} lose access to this project and the projects under it at once, unless they have it in another way.'**
  String shareRemoveTeamBody(String name);

  /// No description provided for @shareCleanupOthersIntro.
  ///
  /// In en, this message translates to:
  /// **'In the projects they can no longer reach, the server also deletes:'**
  String get shareCleanupOthersIntro;

  /// No description provided for @shareCleanupOthersAssignments.
  ///
  /// In en, this message translates to:
  /// **'their task assignments'**
  String get shareCleanupOthersAssignments;

  /// No description provided for @shareCleanupOthersSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'their subscriptions to tasks and projects'**
  String get shareCleanupOthersSubscriptions;

  /// No description provided for @shareCleanupOthersWebhooks.
  ///
  /// In en, this message translates to:
  /// **'webhooks they created'**
  String get shareCleanupOthersWebhooks;

  /// No description provided for @shareCleanupSelfIntro.
  ///
  /// In en, this message translates to:
  /// **'In the projects you can no longer reach, the server also deletes:'**
  String get shareCleanupSelfIntro;

  /// No description provided for @shareCleanupSelfAssignments.
  ///
  /// In en, this message translates to:
  /// **'your task assignments'**
  String get shareCleanupSelfAssignments;

  /// No description provided for @shareCleanupSelfSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'your subscriptions to tasks and projects'**
  String get shareCleanupSelfSubscriptions;

  /// No description provided for @shareCleanupSelfWebhooks.
  ///
  /// In en, this message translates to:
  /// **'webhooks you created'**
  String get shareCleanupSelfWebhooks;

  /// No description provided for @shareAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} has access now'**
  String shareAdded(String name);

  /// No description provided for @sharePermissionChanged.
  ///
  /// In en, this message translates to:
  /// **'Access for {name} changed'**
  String sharePermissionChanged(String name);

  /// No description provided for @shareRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String shareRemoved(String name);

  /// No description provided for @shareSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get shareSaving;

  /// No description provided for @sharePeopleSearchField.
  ///
  /// In en, this message translates to:
  /// **'Username, name or email'**
  String get sharePeopleSearchField;

  /// No description provided for @sharePeopleSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by exact username, or by name or email if the person allows it'**
  String get sharePeopleSearchHint;

  /// No description provided for @sharePeopleSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get sharePeopleSearching;

  /// No description provided for @sharePeopleNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nobody found who could be added'**
  String get sharePeopleNoResults;

  /// No description provided for @sharePeopleSearchOffline.
  ///
  /// In en, this message translates to:
  /// **'Searching for people needs a connection.'**
  String get sharePeopleSearchOffline;

  /// No description provided for @sharePeopleSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Searching did not work. Try again.'**
  String get sharePeopleSearchFailed;

  /// No description provided for @shareTeamsFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter teams'**
  String get shareTeamsFilter;

  /// No description provided for @shareTeamsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading teams…'**
  String get shareTeamsLoading;

  /// No description provided for @shareTeamsNoneToAdd.
  ///
  /// In en, this message translates to:
  /// **'No other team to add. You can add the teams you are a member of.'**
  String get shareTeamsNoneToAdd;

  /// No description provided for @shareTeamsNoneToAddPublic.
  ///
  /// In en, this message translates to:
  /// **'No other team to add. You can add the teams you are a member of and public teams.'**
  String get shareTeamsNoneToAddPublic;

  /// No description provided for @shareTeamPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get shareTeamPublic;

  /// No description provided for @linkShareUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Link without a name'**
  String get linkShareUnnamed;

  /// No description provided for @linkSharePasswordProtected.
  ///
  /// In en, this message translates to:
  /// **'Password protected'**
  String get linkSharePasswordProtected;

  /// No description provided for @linkShareCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String linkShareCreatedBy(String name);

  /// No description provided for @linkShareShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get linkShareShare;

  /// No description provided for @linkShareCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get linkShareCopy;

  /// No description provided for @linkShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkShareCopied;

  /// No description provided for @linkShareQr.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get linkShareQr;

  /// The project view a link share opens; tapping it picks another.
  ///
  /// In en, this message translates to:
  /// **'Opens {view}'**
  String linkShareView(String view);

  /// No description provided for @linkShareViewTitle.
  ///
  /// In en, this message translates to:
  /// **'The link opens'**
  String get linkShareViewTitle;

  /// No description provided for @linkShareDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get linkShareDelete;

  /// No description provided for @linkShareDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the link “{name}”?'**
  String linkShareDeleteTitle(String name);

  /// No description provided for @linkShareDeleteUnnamedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this link?'**
  String get linkShareDeleteUnnamedTitle;

  /// No description provided for @linkShareDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone using this link loses access at once. This can\'t be undone.'**
  String get linkShareDeleteBody;

  /// No description provided for @linkShareDeleted.
  ///
  /// In en, this message translates to:
  /// **'Link deleted'**
  String get linkShareDeleted;

  /// Subject of a shared link, e.g. in an email.
  ///
  /// In en, this message translates to:
  /// **'Link to {project}'**
  String linkShareSubject(String project);

  /// No description provided for @linkShareCreate.
  ///
  /// In en, this message translates to:
  /// **'Create link'**
  String get linkShareCreate;

  /// No description provided for @linkShareFormTitle.
  ///
  /// In en, this message translates to:
  /// **'New link'**
  String get linkShareFormTitle;

  /// No description provided for @linkShareFormPermission.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get linkShareFormPermission;

  /// No description provided for @linkShareFormName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get linkShareFormName;

  /// No description provided for @linkShareFormNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Changes made through the link show this name'**
  String get linkShareFormNameHelper;

  /// No description provided for @linkShareFormPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get linkShareFormPassword;

  /// No description provided for @linkShareFormPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Whoever opens the link has to enter it'**
  String get linkShareFormPasswordHelper;

  /// No description provided for @linkShareFormShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get linkShareFormShowPassword;

  /// No description provided for @linkShareFormHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get linkShareFormHidePassword;

  /// No description provided for @linkShareFormSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get linkShareFormSubmit;

  /// No description provided for @linkShareCreated.
  ///
  /// In en, this message translates to:
  /// **'Link created'**
  String get linkShareCreated;

  /// No description provided for @linkShareCreatedBody.
  ///
  /// In en, this message translates to:
  /// **'Share it with the people who should open this project.'**
  String get linkShareCreatedBody;

  /// No description provided for @linkShareQrSemantics.
  ///
  /// In en, this message translates to:
  /// **'QR code for the link'**
  String get linkShareQrSemantics;

  /// No description provided for @linkShareQrTooLong.
  ///
  /// In en, this message translates to:
  /// **'This link is too long for a QR code'**
  String get linkShareQrTooLong;

  /// No description provided for @linkShareQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan it with a phone\'s camera to open the project.'**
  String get linkShareQrHint;

  /// No description provided for @shareFailureOffline.
  ///
  /// In en, this message translates to:
  /// **'This needs a connection.'**
  String get shareFailureOffline;

  /// No description provided for @shareFailureUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The server did not answer in time. Check the list before trying again.'**
  String get shareFailureUnconfirmed;

  /// No description provided for @shareFailureForbidden.
  ///
  /// In en, this message translates to:
  /// **'Only project admins can change who has access.'**
  String get shareFailureForbidden;

  /// No description provided for @shareFailureAlreadyShared.
  ///
  /// In en, this message translates to:
  /// **'This person already has access or owns the project.'**
  String get shareFailureAlreadyShared;

  /// No description provided for @shareFailureUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'There is no user with this username.'**
  String get shareFailureUnknownUser;

  /// No description provided for @shareFailureGone.
  ///
  /// In en, this message translates to:
  /// **'This access was already removed.'**
  String get shareFailureGone;

  /// No description provided for @shareFailureTeamAlreadyShared.
  ///
  /// In en, this message translates to:
  /// **'This team already has access.'**
  String get shareFailureTeamAlreadyShared;

  /// No description provided for @shareFailureUnknownTeam.
  ///
  /// In en, this message translates to:
  /// **'This team no longer exists.'**
  String get shareFailureUnknownTeam;

  /// No description provided for @shareFailureLinkSharingOff.
  ///
  /// In en, this message translates to:
  /// **'Link sharing is turned off on this server.'**
  String get shareFailureLinkSharingOff;

  /// No description provided for @shareFailureInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept this.'**
  String get shareFailureInvalid;

  /// No description provided for @shareFailureGeneric.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Try again.'**
  String get shareFailureGeneric;

  /// No description provided for @shareReadOnlyProjectNote.
  ///
  /// In en, this message translates to:
  /// **'Read only: you can see this project but not change it.'**
  String get shareReadOnlyProjectNote;

  /// Spoken for a task's done checkbox in a project the user may only read.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get shareTaskReadOnly;

  /// Account tab section with the labels and teams pages.
  ///
  /// In en, this message translates to:
  /// **'Organise'**
  String get accountOrganiseHeading;

  /// No description provided for @accountLabelsEntry.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get accountLabelsEntry;

  /// No description provided for @accountTeamsEntry.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get accountTeamsEntry;

  /// How many labels are on this device, read out for the count next to the Labels entry.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 label} other{{count} labels}}'**
  String labelsCount(int count);

  /// Title of the labels page.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labelsTitle;

  /// No description provided for @labelsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading labels…'**
  String get labelsLoading;

  /// Section of the labels the user created.
  ///
  /// In en, this message translates to:
  /// **'Your labels'**
  String get labelsOwnSection;

  /// Section of other people's labels the user sees on shared tasks.
  ///
  /// In en, this message translates to:
  /// **'From others'**
  String get labelsOthersSection;

  /// Who created another person's label.
  ///
  /// In en, this message translates to:
  /// **'By {name}'**
  String labelsCreatedBy(String name);

  /// No description provided for @labelsOptionsFor.
  ///
  /// In en, this message translates to:
  /// **'Options for {label}'**
  String labelsOptionsFor(String label);

  /// No description provided for @labelsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get labelsEdit;

  /// No description provided for @labelsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get labelsDelete;

  /// No description provided for @labelsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search labels'**
  String get labelsSearch;

  /// No description provided for @labelsSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No label matches “{query}”.'**
  String labelsSearchEmpty(String query);

  /// No description provided for @labelsNew.
  ///
  /// In en, this message translates to:
  /// **'New label'**
  String get labelsNew;

  /// No description provided for @labelsNewOffline.
  ///
  /// In en, this message translates to:
  /// **'Creating a label needs a connection to the server.'**
  String get labelsNewOffline;

  /// No description provided for @labelsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No labels yet'**
  String get labelsEmptyTitle;

  /// No description provided for @labelsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Labels mark tasks across all projects. Create one here or while editing a task.'**
  String get labelsEmptyBody;

  /// Screen reader hint of a label that opens its tasks.
  ///
  /// In en, this message translates to:
  /// **'Show tasks with label {title}'**
  String labelsShowTasks(String title);

  /// No description provided for @labelsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete label “{title}”?'**
  String labelsDeleteTitle(String title);

  /// No description provided for @labelsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It is removed from every task that has it. This can\'t be undone.'**
  String get labelsDeleteBody;

  /// No description provided for @labelsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Label deleted'**
  String get labelsDeleted;

  /// No description provided for @labelsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit label'**
  String get labelsEditTitle;

  /// No description provided for @labelsTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get labelsTitleLabel;

  /// No description provided for @labelsTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify a title.'**
  String get labelsTitleRequired;

  /// Read out with the counter of a label title near its limit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 character left} other{{count} characters left}}'**
  String labelsTitleRemaining(int count);

  /// No description provided for @labelsColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get labelsColour;

  /// No description provided for @labelsCustomColour.
  ///
  /// In en, this message translates to:
  /// **'Custom colour'**
  String get labelsCustomColour;

  /// No description provided for @labelsCustomColourHelper.
  ///
  /// In en, this message translates to:
  /// **'Six hex digits, like 1973ff'**
  String get labelsCustomColourHelper;

  /// No description provided for @labelsCustomColourInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter three or six hex digits.'**
  String get labelsCustomColourInvalid;

  /// No description provided for @labelsDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get labelsDescription;

  /// No description provided for @labelsNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get labelsNoDescription;

  /// No description provided for @labelsEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Edit description'**
  String get labelsEditDescription;

  /// No description provided for @labelsAddDescription.
  ///
  /// In en, this message translates to:
  /// **'Add description'**
  String get labelsAddDescription;

  /// No description provided for @labelsDescriptionAfterCreate.
  ///
  /// In en, this message translates to:
  /// **'You can add a description once the label exists.'**
  String get labelsDescriptionAfterCreate;

  /// No description provided for @labelsDescriptionCreatorOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the person who created this label can change it.'**
  String get labelsDescriptionCreatorOnly;

  /// No description provided for @labelsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get labelsCreate;

  /// No description provided for @labelsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get labelsSave;

  /// No description provided for @labelsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get labelsSaving;

  /// No description provided for @labelsCreated.
  ///
  /// In en, this message translates to:
  /// **'Label created'**
  String get labelsCreated;

  /// No description provided for @labelsSaved.
  ///
  /// In en, this message translates to:
  /// **'Label saved'**
  String get labelsSaved;

  /// No description provided for @labelsDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits to this label will be lost.'**
  String get labelsDiscardBody;

  /// No description provided for @labelsGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This label no longer exists'**
  String get labelsGoneTitle;

  /// No description provided for @labelsGoneBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted, here or on the web.'**
  String get labelsGoneBody;

  /// No description provided for @labelsNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Changing a label needs a connection to the server.'**
  String get labelsNeedsConnection;

  /// No description provided for @labelsUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the change. Check your connection and pull down to refresh.'**
  String get labelsUnconfirmed;

  /// No description provided for @labelsNotCreator.
  ///
  /// In en, this message translates to:
  /// **'Only the person who created this label can change it.'**
  String get labelsNotCreator;

  /// No description provided for @labelsGone.
  ///
  /// In en, this message translates to:
  /// **'This label no longer exists.'**
  String get labelsGone;

  /// No description provided for @labelsInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept this label. Check its title and colour.'**
  String get labelsInvalid;

  /// No description provided for @labelsRefused.
  ///
  /// In en, this message translates to:
  /// **'The server refused: {message}'**
  String labelsRefused(String message);

  /// No description provided for @labelsFailed.
  ///
  /// In en, this message translates to:
  /// **'The label could not be changed.'**
  String get labelsFailed;

  /// Title of the teams page.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get teamsTitle;

  /// No description provided for @teamsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading teams…'**
  String get teamsLoading;

  /// No description provided for @teamsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No teams yet'**
  String get teamsEmptyTitle;

  /// No description provided for @teamsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'With a team you share projects with several people at once.'**
  String get teamsEmptyBody;

  /// No description provided for @teamsNew.
  ///
  /// In en, this message translates to:
  /// **'New team'**
  String get teamsNew;

  /// No description provided for @teamsNewOffline.
  ///
  /// In en, this message translates to:
  /// **'Creating a team needs a connection to the server.'**
  String get teamsNewOffline;

  /// No description provided for @teamMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String teamMemberCount(int count);

  /// Chip on a team the user administers.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get teamAdminBadge;

  /// Chip on a public team.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get teamPublicBadge;

  /// Chip on a team synced from a sign-in provider.
  ///
  /// In en, this message translates to:
  /// **'Managed by {provider}'**
  String teamManagedBy(String provider);

  /// Chip on a team synced from a sign-in provider whose name is unknown.
  ///
  /// In en, this message translates to:
  /// **'Managed externally'**
  String get teamManagedExternally;

  /// No description provided for @teamNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New team'**
  String get teamNewTitle;

  /// No description provided for @teamNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get teamNameLabel;

  /// No description provided for @teamNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify a name.'**
  String get teamNameRequired;

  /// No description provided for @teamPublicLabel.
  ///
  /// In en, this message translates to:
  /// **'Public team'**
  String get teamPublicLabel;

  /// No description provided for @teamPublicHelp.
  ///
  /// In en, this message translates to:
  /// **'Everyone on this server can find it and share projects with it.'**
  String get teamPublicHelp;

  /// No description provided for @teamCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get teamCreate;

  /// No description provided for @teamCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating the team…'**
  String get teamCreating;

  /// No description provided for @teamCreated.
  ///
  /// In en, this message translates to:
  /// **'Team created'**
  String get teamCreated;

  /// No description provided for @teamLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the team…'**
  String get teamLoading;

  /// No description provided for @teamGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This team is not available'**
  String get teamGoneTitle;

  /// No description provided for @teamGoneBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted, or you are no longer a member.'**
  String get teamGoneBody;

  /// No description provided for @teamEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit team'**
  String get teamEdit;

  /// No description provided for @teamEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Edit description'**
  String get teamEditDescription;

  /// No description provided for @teamAddDescription.
  ///
  /// In en, this message translates to:
  /// **'Add description'**
  String get teamAddDescription;

  /// No description provided for @teamSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get teamSave;

  /// No description provided for @teamSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get teamSaving;

  /// No description provided for @teamSaved.
  ///
  /// In en, this message translates to:
  /// **'Team saved'**
  String get teamSaved;

  /// No description provided for @teamExternalNote.
  ///
  /// In en, this message translates to:
  /// **'This team is managed by {provider}. Its members change there.'**
  String teamExternalNote(String provider);

  /// No description provided for @teamExternalNoteGeneric.
  ///
  /// In en, this message translates to:
  /// **'This team is managed by your organisation\'s sign-in. Its members change there.'**
  String get teamExternalNoteGeneric;

  /// No description provided for @teamMembersSection.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get teamMembersSection;

  /// The signed-in user's own row among a team's members.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String teamMemberYou(String name);

  /// No description provided for @teamRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get teamRoleAdmin;

  /// No description provided for @teamRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get teamRoleMember;

  /// No description provided for @teamMemberOptionsFor.
  ///
  /// In en, this message translates to:
  /// **'Options for {name}'**
  String teamMemberOptionsFor(String name);

  /// No description provided for @teamMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get teamMakeAdmin;

  /// No description provided for @teamMakeMember.
  ///
  /// In en, this message translates to:
  /// **'Make member'**
  String get teamMakeMember;

  /// No description provided for @teamRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from team'**
  String get teamRemoveMember;

  /// No description provided for @teamMadeAdmin.
  ///
  /// In en, this message translates to:
  /// **'{name} is an admin now'**
  String teamMadeAdmin(String name);

  /// No description provided for @teamMadeMember.
  ///
  /// In en, this message translates to:
  /// **'{name} is a member now'**
  String teamMadeMember(String name);

  /// No description provided for @teamAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get teamAddMember;

  /// No description provided for @teamMemberAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added to the team'**
  String teamMemberAdded(String name);

  /// No description provided for @teamMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed from the team'**
  String teamMemberRemoved(String name);

  /// No description provided for @teamRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the team?'**
  String teamRemoveTitle(String name);

  /// No description provided for @teamRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{name} loses access to every project shared with this team.'**
  String teamRemoveBody(String name);

  /// No description provided for @teamRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get teamRemoveConfirm;

  /// No description provided for @teamLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave team'**
  String get teamLeave;

  /// No description provided for @teamLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave “{team}”?'**
  String teamLeaveTitle(String team);

  /// No description provided for @teamLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You lose access to every project shared with this team. A team admin would have to add you again.'**
  String get teamLeaveBody;

  /// No description provided for @teamLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get teamLeaveConfirm;

  /// No description provided for @teamLeft.
  ///
  /// In en, this message translates to:
  /// **'You left the team'**
  String get teamLeft;

  /// No description provided for @teamOnlyAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Make someone else admin first'**
  String get teamOnlyAdminTitle;

  /// No description provided for @teamOnlyAdminBody.
  ///
  /// In en, this message translates to:
  /// **'Nobody but you is an admin of this team. Without an admin, nobody could change it any more.'**
  String get teamOnlyAdminBody;

  /// No description provided for @teamLastMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'You are the last member'**
  String get teamLastMemberTitle;

  /// No description provided for @teamLastMemberBody.
  ///
  /// In en, this message translates to:
  /// **'The last member can\'t leave a team. Delete the team instead?'**
  String get teamLastMemberBody;

  /// No description provided for @teamDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete team'**
  String get teamDelete;

  /// No description provided for @teamDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{team}”?'**
  String teamDeleteTitle(String team);

  /// No description provided for @teamDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'All members lose access to every project shared with this team. This can\'t be undone.'**
  String get teamDeleteBody;

  /// No description provided for @teamDeleted.
  ///
  /// In en, this message translates to:
  /// **'Team deleted'**
  String get teamDeleted;

  /// No description provided for @teamAddMemberOffline.
  ///
  /// In en, this message translates to:
  /// **'Adding members needs a connection to the server.'**
  String get teamAddMemberOffline;

  /// No description provided for @teamNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Changing a team needs a connection to the server.'**
  String get teamNeedsConnection;

  /// No description provided for @teamUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the change. Check your connection and pull down to refresh.'**
  String get teamUnconfirmed;

  /// No description provided for @teamForbidden.
  ///
  /// In en, this message translates to:
  /// **'Only team admins can do this.'**
  String get teamForbidden;

  /// No description provided for @teamAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'This person is already a member of the team.'**
  String get teamAlreadyMember;

  /// No description provided for @teamLastMemberRefused.
  ///
  /// In en, this message translates to:
  /// **'The last member can\'t leave a team. Delete the team instead.'**
  String get teamLastMemberRefused;

  /// No description provided for @teamExternalRefused.
  ///
  /// In en, this message translates to:
  /// **'Members can\'t be removed from a team managed by your organisation\'s sign-in.'**
  String get teamExternalRefused;

  /// No description provided for @teamUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'There is no such user on this server.'**
  String get teamUnknownUser;

  /// No description provided for @teamNotMember.
  ///
  /// In en, this message translates to:
  /// **'This person is no longer in the team.'**
  String get teamNotMember;

  /// No description provided for @teamInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept this. A name needs 1 to 250 characters.'**
  String get teamInvalid;

  /// No description provided for @teamGone.
  ///
  /// In en, this message translates to:
  /// **'This team no longer exists, or you are no longer in it.'**
  String get teamGone;

  /// No description provided for @teamRefused.
  ///
  /// In en, this message translates to:
  /// **'The server refused: {message}'**
  String teamRefused(String message);

  /// No description provided for @teamFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Try again.'**
  String get teamFailed;

  /// No description provided for @teamOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get teamOk;

  /// Confirmation title when admins choose a lower permission on their own share row.
  ///
  /// In en, this message translates to:
  /// **'Lower your own access?'**
  String get shareLowerOwnAccessTitle;

  /// Body of the confirmation when users lower their own share from admin.
  ///
  /// In en, this message translates to:
  /// **'You may no longer be able to change who has access to this project, nor undo this yourself.'**
  String get shareLowerOwnAccessAdminBody;

  /// Body of the confirmation when users lower their own share from read & write to read only.
  ///
  /// In en, this message translates to:
  /// **'You may no longer be able to change this project or its tasks.'**
  String get shareLowerOwnAccessWriteBody;

  /// Confirm button of the dialog that lowers the user's own share.
  ///
  /// In en, this message translates to:
  /// **'Lower access'**
  String get shareLowerOwnAccessConfirm;

  /// Snackbar after users removed their own share of a project.
  ///
  /// In en, this message translates to:
  /// **'You removed yourself'**
  String get shareRemovedSelf;

  /// Share page title text once the project is gone from the device after users removed their own share.
  ///
  /// In en, this message translates to:
  /// **'You no longer have access to this project'**
  String get shareNoAccessTitle;

  /// Body below shareNoAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'It is gone from this device. Someone with access can share it with you again.'**
  String get shareNoAccessBody;

  /// Screen readers say it after 'Double tap to' on a person or team row of the share page that admins can change.
  ///
  /// In en, this message translates to:
  /// **'change access'**
  String get shareChangeAccessHint;

  /// Screen readers say it after 'Double tap to' on a link row of the share page.
  ///
  /// In en, this message translates to:
  /// **'share, copy or delete the link'**
  String get linkShareRowHint;

  /// Tooltip and screen reader label of a link row's share button; name is the link's name or 'Link without a name'.
  ///
  /// In en, this message translates to:
  /// **'Share {name}'**
  String linkShareShareNamed(String name);

  /// Title of the timeline's date range sheet.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get projectTimelineRangeTitle;

  /// Tooltip and screen reader label of the timeline's range chip.
  ///
  /// In en, this message translates to:
  /// **'Date range: {dates}'**
  String projectTimelineRangeCurrent(String dates);

  /// The timeline's default range in its range sheet, which follows today.
  ///
  /// In en, this message translates to:
  /// **'Default (15 days back, 55 ahead)'**
  String get projectTimelineRangeDefault;

  /// Opens the date pickers for a custom timeline range.
  ///
  /// In en, this message translates to:
  /// **'Custom range…'**
  String get projectTimelineRangeCustom;

  /// In the timeline's range sheet, shown when the range, the tasks without dates or the zoom differ from the defaults: sets all three back.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get projectTimelineReset;

  /// Widens the timeline's days.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get projectTimelineZoomIn;

  /// Narrows the timeline's days.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get projectTimelineZoomOut;

  /// Scrolls the timeline to today.
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get projectTimelineGoToToday;

  /// Read by screen readers for a timeline bar: its first and last day.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String projectTimelineSpanSemantics(String from, String to);

  /// Read by screen readers for a timeline bar of a task with a start date only.
  ///
  /// In en, this message translates to:
  /// **'starts {date}, open end'**
  String projectTimelineStartOnlySemantics(String date);

  /// Read by screen readers for a timeline bar of a task with an end date and no start date.
  ///
  /// In en, this message translates to:
  /// **'ends {date}, open start'**
  String projectTimelineEndOnlySemantics(String date);

  /// Read by screen readers for a timeline bar of a task with a due date and no start or end date.
  ///
  /// In en, this message translates to:
  /// **'due {date}, open start'**
  String projectTimelineDueOnlySemantics(String date);

  /// Read by screen readers for a timeline bar of a task without dates, drawn from today for a week.
  ///
  /// In en, this message translates to:
  /// **'no dates, estimated'**
  String get projectTimelineEstimatedSemantics;

  /// Read by screen readers for a timeline bar of a task without dates of its own, drawn over its subtasks' dates.
  ///
  /// In en, this message translates to:
  /// **'dates from its subtasks'**
  String get projectTimelineDerivedSemantics;

  /// Tooltip and screen reader action of a collapsed timeline row.
  ///
  /// In en, this message translates to:
  /// **'Show subtasks of {title}'**
  String projectTimelineExpand(String title);

  /// Tooltip and screen reader action of an expanded timeline row.
  ///
  /// In en, this message translates to:
  /// **'Hide subtasks of {title}'**
  String projectTimelineCollapse(String title);

  /// Empty timeline: no task in its date range.
  ///
  /// In en, this message translates to:
  /// **'No tasks between {from} and {to}'**
  String projectTimelineEmptyTitle(String from, String to);

  /// Below the empty timeline's title while tasks without dates are hidden.
  ///
  /// In en, this message translates to:
  /// **'Choose another date range or show tasks without dates.'**
  String get projectTimelineEmptyBody;

  /// Below the empty timeline's title while tasks without dates are shown.
  ///
  /// In en, this message translates to:
  /// **'Choose another date range.'**
  String get projectTimelineEmptyRangeBody;

  /// A table view's button and sheet that pick what each row shows.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get projectTableColumns;

  /// No description provided for @projectTableColumnsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose what each row shows. The choice applies to every table view.'**
  String get projectTableColumnsHint;

  /// Resets the table's columns to the web's six.
  ///
  /// In en, this message translates to:
  /// **'Default columns'**
  String get projectTableColumnsReset;

  /// Below the Title column, which cannot be turned off.
  ///
  /// In en, this message translates to:
  /// **'Every row shows it'**
  String get projectTableColumnTitleAlways;

  /// The table column of a task's number or identifier, # on the web.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get projectTableColumnNumber;

  /// The table column of a task's comment count.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get projectTableColumnComments;

  /// No description provided for @projectTableColumnDoneAt.
  ///
  /// In en, this message translates to:
  /// **'Done at'**
  String get projectTableColumnDoneAt;

  /// No description provided for @projectTableColumnCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get projectTableColumnCreated;

  /// No description provided for @projectTableColumnUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get projectTableColumnUpdated;

  /// No description provided for @projectTableColumnCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get projectTableColumnCreatedBy;

  /// The table's default sort, by number, highest first.
  ///
  /// In en, this message translates to:
  /// **'Default (Highest number first)'**
  String get projectTableSortDefault;

  /// No description provided for @projectTableSortNumberDesc.
  ///
  /// In en, this message translates to:
  /// **'Number (Highest first)'**
  String get projectTableSortNumberDesc;

  /// No description provided for @projectTableSortNumberAsc.
  ///
  /// In en, this message translates to:
  /// **'Number (Lowest first)'**
  String get projectTableSortNumberAsc;

  /// No description provided for @projectTableSortDoneAsc.
  ///
  /// In en, this message translates to:
  /// **'Done (Open first)'**
  String get projectTableSortDoneAsc;

  /// No description provided for @projectTableSortDoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Done (Done first)'**
  String get projectTableSortDoneDesc;

  /// No description provided for @projectTableSortDoneAtDesc.
  ///
  /// In en, this message translates to:
  /// **'Done at (Newest first)'**
  String get projectTableSortDoneAtDesc;

  /// No description provided for @projectTableSortDoneAtAsc.
  ///
  /// In en, this message translates to:
  /// **'Done at (Oldest first)'**
  String get projectTableSortDoneAtAsc;

  /// No description provided for @projectTableStartsSemantics.
  ///
  /// In en, this message translates to:
  /// **'Starts {when}'**
  String projectTableStartsSemantics(String when);

  /// No description provided for @projectTableEndsSemantics.
  ///
  /// In en, this message translates to:
  /// **'Ends {when}'**
  String projectTableEndsSemantics(String when);

  /// No description provided for @projectTableCreatedBySemantics.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String projectTableCreatedBySemantics(String name);

  /// A task's percent done in a table row, rounded to a whole percent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String projectTableCellPercent(int percent);

  /// No description provided for @projectViewsIntro.
  ///
  /// In en, this message translates to:
  /// **'The views of {project}, in the order the app and the web show them.'**
  String projectViewsIntro(String project);

  /// Filter chip above a Gantt view's timeline that adds the tasks without any date, as estimated bars from today. Phrased as an action like 'Show done'.
  ///
  /// In en, this message translates to:
  /// **'Show undated'**
  String get projectTimelineShowUndated;

  /// Server overview button under Continue to sign-in; opens the browser sign-in, whose page offers registration.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get overviewCreateAccount;

  /// Shown before the browser sign-in opens for Create account. The label is the web login page's link (German web: Account erstellen).
  ///
  /// In en, this message translates to:
  /// **'On the sign-in page, choose Create account. You come back here afterwards.'**
  String get overviewCreateAccountHint;

  /// Server overview button; opens the web's password reset page in the browser.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get overviewForgotPassword;

  /// Server overview note when public registration is off but the server has invite links.
  ///
  /// In en, this message translates to:
  /// **'Registration needs an invitation.'**
  String get overviewRegistrationNeedsInvitation;

  /// No description provided for @overviewSignInPageOffersBoth.
  ///
  /// In en, this message translates to:
  /// **'The sign-in page also lets you create an account and reset your password.'**
  String get overviewSignInPageOffersBoth;

  /// No description provided for @overviewSignInPageOffersRegistration.
  ///
  /// In en, this message translates to:
  /// **'The sign-in page also lets you create an account.'**
  String get overviewSignInPageOffersRegistration;

  /// No description provided for @overviewSignInPageOffersPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'The sign-in page also lets you reset your password.'**
  String get overviewSignInPageOffersPasswordReset;

  /// Account tab, Server section, when the server reports demo mode.
  ///
  /// In en, this message translates to:
  /// **'This is a demo server. Its data may be deleted at any time.'**
  String get overviewDemoNote;

  /// Second line of a link-share guest in the account list, the switcher and the Account tab's header.
  ///
  /// In en, this message translates to:
  /// **'Guest · {host}'**
  String guestAccountSubtitle(String host);

  /// Badge of a guest access the server ended, and the action of its banner on the Account tab.
  ///
  /// In en, this message translates to:
  /// **'Open the link again'**
  String get guestOpenLinkAgain;

  /// Title of the Account tab's banner when the server no longer accepts a link-share guest.
  ///
  /// In en, this message translates to:
  /// **'Guest access ended'**
  String get guestReauthTitle;

  /// No description provided for @guestReauthBody.
  ///
  /// In en, this message translates to:
  /// **'{host} ended this guest access. Open the shared link again to keep the project in sync: a link with a password asks for it, and a deleted link needs a new one from whoever shared it. Nothing on this device is lost.'**
  String guestReauthBody(String host);

  /// Screen reader label of the avatar button that opens the account switcher while a link-share guest is active.
  ///
  /// In en, this message translates to:
  /// **'Accounts, guest in {name} on {host}'**
  String guestSwitcherButton(String name, String host);

  /// First line of the guest note on the Account tab; the permission is sharePermissionRead, sharePermissionWrite or sharePermissionAdmin.
  ///
  /// In en, this message translates to:
  /// **'Shared link: {permission}'**
  String guestNotePermission(String permission);

  /// No description provided for @guestNoteCanView.
  ///
  /// In en, this message translates to:
  /// **'You can view this project\'s tasks, comments and attachments.'**
  String get guestNoteCanView;

  /// No description provided for @guestNoteCanChange.
  ///
  /// In en, this message translates to:
  /// **'You can view and change this project\'s tasks, comment and add attachments.'**
  String get guestNoteCanChange;

  /// No description provided for @guestNoteNeedsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account settings, labels, teams, favourites, reactions and the server\'s notifications need an account of your own.'**
  String get guestNoteNeedsAccount;

  /// The Account tab's sign-out button while a link-share guest is active.
  ///
  /// In en, this message translates to:
  /// **'Remove guest access'**
  String get guestRemove;

  /// No description provided for @guestRemoveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove guest access?'**
  String get guestRemoveDialogTitle;

  /// No description provided for @guestRemoveDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Rurana will remove the guest access to {name} on {host} and delete its tasks saved on this device. You can open the shared link again at any time.'**
  String guestRemoveDialogBody(String name, String host);

  /// No description provided for @guestRemoveDialogPendingChangesOpenLinkFirst.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One change has not been sent to the server yet and will be lost; switch to this guest access, open the link again and tap Send now first to keep it.} other{{count} changes have not been sent to the server yet and will be lost; switch to this guest access, open the link again and tap Send now first to keep them.}}'**
  String guestRemoveDialogPendingChangesOpenLinkFirst(int count);

  /// No description provided for @guestRemoved.
  ///
  /// In en, this message translates to:
  /// **'Guest access to {name} removed'**
  String guestRemoved(String name);

  /// Connect screen: text button and sheet title to open a project someone shared as a link, as a guest
  ///
  /// In en, this message translates to:
  /// **'Open a shared link'**
  String get guestOpenSharedLink;

  /// Open a shared link sheet: what the sheet is for
  ///
  /// In en, this message translates to:
  /// **'Got a link to a project someone shared? Open it here as a guest, without an account of your own.'**
  String get guestLinkExplanation;

  /// Open a shared link sheet: label of the link field
  ///
  /// In en, this message translates to:
  /// **'Shared link'**
  String get guestLinkLabel;

  /// Open a shared link sheet: example of a shared link in the empty field
  ///
  /// In en, this message translates to:
  /// **'https://vikunja.example.com/share/…/auth'**
  String get guestLinkHint;

  /// Open a shared link sheet: puts the clipboard's text into the field
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get guestLinkPaste;

  /// Open a shared link sheet and password sheet: opens the shared project
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get guestLinkOpen;

  /// Open a shared link sheet: the text is neither a shared link nor an invitation
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a link to a shared project. Such a link ends in /share/…/auth.'**
  String get guestLinkInvalid;

  /// Open a shared link sheet: Paste found nothing to paste
  ///
  /// In en, this message translates to:
  /// **'There\'s no text on the clipboard.'**
  String get guestLinkClipboardEmpty;

  /// Connect screen while a shared link is being opened; the link's secret is cut short
  ///
  /// In en, this message translates to:
  /// **'Opening the shared link {link} …'**
  String guestConnectingTo(String link);

  /// Password sheet title for a shared project protected by a password
  ///
  /// In en, this message translates to:
  /// **'Password needed'**
  String get guestPasswordTitle;

  /// Password sheet: what to enter
  ///
  /// In en, this message translates to:
  /// **'This shared project is protected by a password. Enter the one you got with the link.'**
  String get guestPasswordBody;

  /// Password sheet: label of the password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get guestPasswordLabel;

  /// Password sheet: the server refused the password
  ///
  /// In en, this message translates to:
  /// **'Wrong password. Check it and try again.'**
  String get guestPasswordWrong;

  /// Password sheet: helper under the field
  ///
  /// In en, this message translates to:
  /// **'Rurana doesn\'t save this password. If the link has to be opened again later, it asks for it again.'**
  String get guestPasswordNotStored;

  /// Sheet when another app shares a link to a shared project into Rurana
  ///
  /// In en, this message translates to:
  /// **'Open the shared project?'**
  String get guestShareTitle;

  /// Shared link sheet: what opening the link does
  ///
  /// In en, this message translates to:
  /// **'This is a link to a project on {host}. Open it as a guest, without an account of your own.'**
  String guestShareBody(String host);

  /// Shared link sheet: opens the shared project as a guest
  ///
  /// In en, this message translates to:
  /// **'Open as guest'**
  String get guestShareOpen;

  /// Shared link sheet, signed in: makes a task of the shared text as with any other share
  ///
  /// In en, this message translates to:
  /// **'Make it a new task instead'**
  String get guestShareNewTask;

  /// Connect screen error title: the shared link is unknown or deleted
  ///
  /// In en, this message translates to:
  /// **'This link doesn\'t work'**
  String get guestLinkGoneTitle;

  /// Connect screen error: the shared link is unknown or deleted, or link sharing is off
  ///
  /// In en, this message translates to:
  /// **'{host} doesn\'t accept this shared link. It was deleted or is incomplete, or the server no longer allows shared links.'**
  String guestLinkGoneExplanation(String host);

  /// Connect screen error: what to do about a shared link that doesn't work
  ///
  /// In en, this message translates to:
  /// **'Ask whoever shared the project for a new link.'**
  String get guestLinkGoneSuggestion;

  /// Connect screen while an invitation link is checked
  ///
  /// In en, this message translates to:
  /// **'Checking the invitation to {host} …'**
  String inviteConnectingTo(String host);

  /// Connect screen: card title for a registration invitation an admin sent
  ///
  /// In en, this message translates to:
  /// **'Invitation to {host}'**
  String inviteHeading(String host);

  /// Invitation card: the teams the new account joins, comma separated
  ///
  /// In en, this message translates to:
  /// **'You\'ll join: {teams}'**
  String inviteTeams(String teams);

  /// Invitation card: the invitation skips the email confirmation
  ///
  /// In en, this message translates to:
  /// **'Your account works right away, without confirming your email address.'**
  String get inviteNoEmailConfirmation;

  /// Invitation card: the invitation does not skip the email confirmation
  ///
  /// In en, this message translates to:
  /// **'You may have to confirm your email address before you can sign in.'**
  String get inviteEmailConfirmation;

  /// Invitation card: the two steps
  ///
  /// In en, this message translates to:
  /// **'Create your account in the browser, then come back here and continue to sign-in.'**
  String get inviteSteps;

  /// Invitation card: opens the invitation in the browser to register
  ///
  /// In en, this message translates to:
  /// **'Create account in the browser'**
  String get inviteCreateAccount;

  /// Invitation card: the server is older than 2.7.0 or has no /api/v2
  ///
  /// In en, this message translates to:
  /// **'This server can\'t check invitations from the app. Open the invitation in the browser to create your account.'**
  String get inviteUnchecked;

  /// Invitation card: checking the invitation failed for another reason
  ///
  /// In en, this message translates to:
  /// **'The invitation couldn\'t be checked just now. You can still open it in the browser.'**
  String get inviteCheckFailed;

  /// Connect screen error title: the invitation was refused
  ///
  /// In en, this message translates to:
  /// **'Invitation not valid'**
  String get inviteInvalidTitle;

  /// Connect screen error: the server answered 404 code 2005
  ///
  /// In en, this message translates to:
  /// **'This invitation is invalid, expired or used up.'**
  String get inviteInvalidExplanation;

  /// Connect screen error: what to do about an invitation that was refused
  ///
  /// In en, this message translates to:
  /// **'Ask whoever invited you for a new link. With an account of your own, enter the server\'s address instead.'**
  String get inviteInvalidSuggestion;

  /// Under the label picker's search field for a link-share guest.
  ///
  /// In en, this message translates to:
  /// **'A shared link can\'t create labels; only the labels already used in this project can be added.'**
  String get guestLabelPickerNote;

  /// Connect screen error: the server has link sharing turned off
  ///
  /// In en, this message translates to:
  /// **'{host} doesn\'t allow opening projects through shared links.'**
  String guestSharingOffExplanation(String host);

  /// Connect screen error: what to do when the server has link sharing off
  ///
  /// In en, this message translates to:
  /// **'Ask whoever shared the project to share it with an account of yours instead.'**
  String get guestSharingOffSuggestion;

  /// Connect screen card: the shared link's address is not the Vikunja server itself
  ///
  /// In en, this message translates to:
  /// **'Which server is it?'**
  String get guestServerNeededTitle;

  /// Connect screen card: why the server's address is needed
  ///
  /// In en, this message translates to:
  /// **'The link points to {host}, but no Vikunja server answers there. The server may have an address of its own.'**
  String guestServerNeededExplanation(String host);

  /// Connect screen card: what to do to open the shared link
  ///
  /// In en, this message translates to:
  /// **'Enter the server\'s address above and tap Continue to open the link.'**
  String get guestServerNeededSuggestion;

  /// Snackbar after opening a shared link whose guest access was already on the device
  ///
  /// In en, this message translates to:
  /// **'This shared project was already on this device. Switched to it.'**
  String get guestAlreadyAdded;

  /// Title of the OS notification when the server ended a link-share guest's access; name is the share's name or the shared project's title.
  ///
  /// In en, this message translates to:
  /// **'Guest access to {name} ended'**
  String guestAccessEndedNotificationTitle(String name);

  /// No description provided for @guestAccessEndedNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'{host} ended this guest access. Rurana can\'t sync the project until you open the shared link again.'**
  String guestAccessEndedNotificationBody(String host);

  /// A load or refresh of a link-share guest failed because the server ended its access.
  ///
  /// In en, this message translates to:
  /// **'Your guest access on {host} has ended. Open the link again on the Account tab.'**
  String guestDataFailureAccessEnded(String host);

  /// Headline of the Overview before noon for a link-share guest, who has no name of its own.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get overviewGreetingMorningGuest;

  /// Headline of the Overview from noon to 6 pm for a link-share guest.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get overviewGreetingAfternoonGuest;

  /// Headline of the Overview from 6 pm to 5 am for a link-share guest.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get overviewGreetingEveningGuest;

  /// A task's due date on a home-screen widget: a day word (Today, Tomorrow, Yesterday) or a short weekday, then the time.
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String widgetDueAt(String day, String time);

  /// Below the rows of a home-screen widget: how many matching tasks do not fit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 more} other{+{count} more}}'**
  String widgetMoreTasks(int count);

  /// Screen reader text of the task count in a home-screen widget's header.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tasks} =1{1 task} other{{count} tasks}}'**
  String widgetTaskCount(int count);

  /// Screen reader text of the done control of a task row on a home-screen widget.
  ///
  /// In en, this message translates to:
  /// **'Mark “{title}” done'**
  String widgetMarkDone(String title);

  /// Title of a home-screen widget with the tasks due in the next days.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Next day} other{Next {days} days}}'**
  String widgetUpcomingTitle(int days);

  /// A home-screen widget whose account was signed out or removed.
  ///
  /// In en, this message translates to:
  /// **'Account removed'**
  String get widgetAccountRemovedTitle;

  /// On a home-screen widget whose account or list is gone.
  ///
  /// In en, this message translates to:
  /// **'Choose another list for this widget.'**
  String get widgetChooseAnotherList;

  /// An empty Today widget on the home screen, below the title All done.
  ///
  /// In en, this message translates to:
  /// **'Nothing is due today.'**
  String get widgetTodayEmptyBody;

  /// An empty Overdue widget on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing overdue'**
  String get widgetOverdueEmptyTitle;

  /// The account line of a home-screen widget while more than one account is signed in.
  ///
  /// In en, this message translates to:
  /// **'{name} · {host}'**
  String widgetAccountSubtitle(String name, String host);

  /// The Account tab entry and the title of the page that explains the home-screen widgets.
  ///
  /// In en, this message translates to:
  /// **'Home-screen widgets'**
  String get widgetsTitle;

  /// Subtitle of the Account tab entry to the widgets page.
  ///
  /// In en, this message translates to:
  /// **'Your tasks on the home screen, ticked off right there'**
  String get widgetsEntrySubtitle;

  /// The widgets page's introduction.
  ///
  /// In en, this message translates to:
  /// **'A widget shows one list of an account: today\'s tasks, the next days, the overdue ones, your favourites, a project, a label or a saved filter. Tick a task off right there, or tap it to open it here.'**
  String get widgetsIntro;

  /// Heading above the platform's steps to place a widget.
  ///
  /// In en, this message translates to:
  /// **'How to add one'**
  String get widgetsHowToHeading;

  /// iOS steps to place and set up a widget.
  ///
  /// In en, this message translates to:
  /// **'Touch and hold an empty spot on your Home Screen, tap Edit, then Add Widget, and look for Rurana. To choose the account and the list, touch and hold the widget and tap Edit Widget.'**
  String get widgetsHowToIos;

  /// Heading of the Android widget kinds that can be placed from the app.
  ///
  /// In en, this message translates to:
  /// **'Add a widget'**
  String get widgetsAddHeading;

  /// Under the Add widget heading: which account a widget added from here shows.
  ///
  /// In en, this message translates to:
  /// **'It shows the active account; you can change that in its settings.'**
  String get widgetsAddHint;

  /// Button that asks the launcher to place a widget of that kind.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get widgetsAdd;

  /// Snackbar when the launcher cannot place a widget requested by the app.
  ///
  /// In en, this message translates to:
  /// **'Your home screen can\'t add widgets from here. Add it on the home screen instead.'**
  String get widgetsPinUnsupported;

  /// Heading of the widgets already placed (Android); a tap sets one up.
  ///
  /// In en, this message translates to:
  /// **'On your home screen'**
  String get widgetsPlacedHeading;

  /// A placed widget whose account was signed out.
  ///
  /// In en, this message translates to:
  /// **'Account removed – choose another'**
  String get widgetsPlacedAccountRemoved;

  /// Privacy note on the widgets page.
  ///
  /// In en, this message translates to:
  /// **'Widgets show your task titles on the home screen, where anyone who sees your phone can read them.'**
  String get widgetsPrivacyNote;

  /// Widget kind: overdue tasks and those due today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get widgetKindToday;

  /// What the Today widget shows.
  ///
  /// In en, this message translates to:
  /// **'Overdue and due today'**
  String get widgetKindTodayHint;

  /// Widget kind: tasks due in the next days.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get widgetKindUpcoming;

  /// What the Upcoming widget shows.
  ///
  /// In en, this message translates to:
  /// **'Due in the next days'**
  String get widgetKindUpcomingHint;

  /// Widget kind: tasks past their due date.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get widgetKindOverdue;

  /// What the Overdue widget shows.
  ///
  /// In en, this message translates to:
  /// **'Past their due date'**
  String get widgetKindOverdueHint;

  /// Widget kind: the favourite tasks.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get widgetKindFavorites;

  /// What the Favourites widget shows.
  ///
  /// In en, this message translates to:
  /// **'Your favourite tasks'**
  String get widgetKindFavoritesHint;

  /// Widget kind: a project's open tasks.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get widgetKindProject;

  /// Widget kind: a label's open tasks.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get widgetKindLabel;

  /// Widget kind: a saved filter's tasks.
  ///
  /// In en, this message translates to:
  /// **'Saved filter'**
  String get widgetKindSavedFilter;

  /// Widget kind: a button that opens the New task sheet.
  ///
  /// In en, this message translates to:
  /// **'New task button'**
  String get widgetKindQuickAdd;

  /// What the New task button widget does.
  ///
  /// In en, this message translates to:
  /// **'One tap to a new task'**
  String get widgetKindQuickAddHint;

  /// How many days ahead an Upcoming widget shows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String widgetUpcomingDays(int count);

  /// Title of the page that sets up a placed widget (Android).
  ///
  /// In en, this message translates to:
  /// **'Set up widget'**
  String get widgetConfigureTitle;

  /// Heading of the account choice on the widget setup page.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get widgetConfigureAccountHeading;

  /// Heading of the list choice on the widget setup page.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get widgetConfigureListHeading;

  /// Label of the Upcoming widget's day count choice.
  ///
  /// In en, this message translates to:
  /// **'Days ahead'**
  String get widgetConfigureDaysLabel;

  /// Trailing text of a project, label or saved filter choice not picked yet.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get widgetConfigureChoose;

  /// Project picker without projects.
  ///
  /// In en, this message translates to:
  /// **'This account has no projects to show.'**
  String get widgetConfigureNoProjects;

  /// Label picker without labels.
  ///
  /// In en, this message translates to:
  /// **'This account has no labels yet.'**
  String get widgetConfigureNoLabels;

  /// Saved filter picker without saved filters.
  ///
  /// In en, this message translates to:
  /// **'This account has no saved filters yet.'**
  String get widgetConfigureNoSavedFilters;

  /// Heading of the widget preview on the setup page.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get widgetConfigurePreviewHeading;

  /// When the widget's preview cannot be built.
  ///
  /// In en, this message translates to:
  /// **'No preview yet'**
  String get widgetConfigurePreviewNone;

  /// Saves the widget's setup.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get widgetConfigureSave;

  /// The Save button while the setup is written.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get widgetConfigureSaving;

  /// Snackbar after saving a widget's setup.
  ///
  /// In en, this message translates to:
  /// **'Widget set up'**
  String get widgetConfigureSaved;

  /// Snackbar when saving a widget's setup failed.
  ///
  /// In en, this message translates to:
  /// **'The widget couldn\'t be saved. Try again.'**
  String get widgetConfigureSaveFailed;

  /// Account tab section heading with the way to the home-screen widgets.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get widgetsHeading;

  /// Account tab entry to the home-screen widgets page.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get widgetsEntryTitle;

  /// Android steps to place and set up a widget. Below Android 12 and on some launchers the widgets page is the only way to set one up.
  ///
  /// In en, this message translates to:
  /// **'Touch and hold an empty spot on your home screen, tap Widgets and look for Rurana. To choose the account and the list, tap the widget under “On your home screen” below. Some home screens also offer this in the widget\'s settings when you touch and hold it.'**
  String get widgetsHowToAndroid;

  /// A placed list widget that was never set up; it shows Today of the active account. Tapping opens its setup.
  ///
  /// In en, this message translates to:
  /// **'Not set up yet – shows the active account'**
  String get widgetsPlacedNotSetUp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
