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

  /// No description provided for @homeUsername.
  ///
  /// In en, this message translates to:
  /// **'@{username}'**
  String homeUsername(String username);

  /// No description provided for @homeSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get homeSignOut;

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
  /// **'Rurana will sign you out of {host}. You can sign in again at any time.'**
  String signOutDialogBody(String host);

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
  /// **'No open tasks right now. Enjoy the quiet, or add some on the web.'**
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
  /// **'Create your first project on the web and it will show up here.'**
  String get projectsEmptyBody;

  /// No description provided for @projectsFavouritesHeading.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get projectsFavouritesHeading;

  /// No description provided for @projectsAllHeading.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get projectsAllHeading;

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

  /// No description provided for @projectTasksShowDone.
  ///
  /// In en, this message translates to:
  /// **'Show done tasks'**
  String get projectTasksShowDone;

  /// No description provided for @projectTasksLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading tasks…'**
  String get projectTasksLoading;

  /// No description provided for @projectTasksLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get projectTasksLoadMore;

  /// No description provided for @projectTasksLoadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more tasks…'**
  String get projectTasksLoadingMore;

  /// No description provided for @projectTasksEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No open tasks'**
  String get projectTasksEmptyTitle;

  /// No description provided for @projectTasksEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Everything in this project is done. Turn on “Show done tasks” to see them.'**
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

  /// No description provided for @taskNotDone.
  ///
  /// In en, this message translates to:
  /// **'Not done'**
  String get taskNotDone;

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

  /// No description provided for @taskDetailStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskDetailStatusDone;

  /// No description provided for @taskDetailStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskDetailStatusOpen;

  /// No description provided for @taskDetailIdentifierInProject.
  ///
  /// In en, this message translates to:
  /// **'{identifier} in {project}'**
  String taskDetailIdentifierInProject(String identifier, String project);

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

  /// No description provided for @taskDetailDoneAt.
  ///
  /// In en, this message translates to:
  /// **'Done at'**
  String get taskDetailDoneAt;

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
