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
  /// **'Taskuna'**
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
  /// **'Taskuna needs Vikunja {minimum} or newer. This server runs {found}.'**
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
  /// **'Taskuna needs Vikunja {minimum} or newer. This server reports a version the app does not recognize.'**
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
  /// **'Sign in with browser'**
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

  /// No description provided for @signInComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Sign-in isn’t available in this version yet.'**
  String get signInComingSoon;
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
