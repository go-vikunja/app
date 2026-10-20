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
  /// **'These are the {mode} prefixes, as set in your Vikunja settings on the web.'**
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

  /// Screen reader label of the bell in the Overview's app bar.
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
  /// **'Your Overview shows the saved filter “{title}”, picked on the web. Its tasks download with the next sync.'**
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

  /// No description provided for @projectViewsIntro.
  ///
  /// In en, this message translates to:
  /// **'The views of {project}, in the order the app and the web show them. Table and Gantt views show on the web only for now.'**
  String projectViewsIntro(String project);

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

  /// A view kind the app does not show yet (Table, Gantt).
  ///
  /// In en, this message translates to:
  /// **'{kind} – shown on the web only for now'**
  String projectViewKindWebOnly(String kind);

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
