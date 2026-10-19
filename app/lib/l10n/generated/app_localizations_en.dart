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
  String homeUsername(String username) {
    return '@$username';
  }

  @override
  String get homeSignOut => 'Sign out';

  @override
  String get homeSignOutOfThisAccount => 'Sign out of this account';

  @override
  String get homeSigningOut => 'Signing out…';

  @override
  String get signOutDialogTitle => 'Sign out?';

  @override
  String signOutDialogBody(String account, String host) {
    return 'Rurana will sign $account out of $host and delete this account’s tasks saved on this device. You can sign in again at any time.';
  }

  @override
  String signOutDialogAccount(String name, String username) {
    return '$name (@$username)';
  }

  @override
  String signOutDialogSwitchesTo(String name) {
    return 'Rurana then switches to $name.';
  }

  @override
  String signOutDialogPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes have not been sent to the server yet and will be lost; tap Send now first to keep them.',
      one: 'One change has not been sent to the server yet and will be lost; tap Send now first to keep it.',
    );
    return '$_temp0';
  }

  @override
  String get signOutDialogCancel => 'Cancel';

  @override
  String get signOutDialogConfirm => 'Sign out';

  @override
  String get removeAccountDialogTitle => 'Remove account?';

  @override
  String get removeAccountDialogConfirm => 'Remove';

  @override
  String removeAccountDialogPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes have not been sent to the server yet and will be lost; switch to this account and tap Send now first to keep them.',
      one: 'One change has not been sent to the server yet and will be lost; switch to this account and tap Send now first to keep it.',
    );
    return '$_temp0';
  }

  @override
  String removeAccountDialogPendingChangesSignInFirst(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes have not been sent to the server yet and will be lost; switch to this account, sign in again and tap Send now first to keep them.',
      one: 'One change has not been sent to the server yet and will be lost; switch to this account, sign in again and tap Send now first to keep it.',
    );
    return '$_temp0';
  }

  @override
  String get reauthTitle => 'Signed out by the server';

  @override
  String reauthBody(String host) {
    return '$host ended your session. Sign in again to keep your tasks in sync. Nothing on this device is lost.';
  }

  @override
  String get reauthAction => 'Sign in again';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabProjects => 'Projects';

  @override
  String get tabAccount => 'Account';

  @override
  String get accountsHeading => 'Accounts';

  @override
  String accountSwitcherButton(String name, String host) {
    return 'Accounts, signed in as $name on $host';
  }

  @override
  String get accountCurrent => 'Current';

  @override
  String accountSubtitle(String username, String host) {
    return '@$username · $host';
  }

  @override
  String get accountBadgeSignInAgain => 'Sign in again';

  @override
  String accountBadgeUnsent(int count) {
    return '$count unsent';
  }

  @override
  String get accountAdd => 'Add account';

  @override
  String get accountManage => 'Manage accounts';

  @override
  String accountMoreActions(String name) {
    return 'More for $name';
  }

  @override
  String get accountRemove => 'Remove…';

  @override
  String accountSwitchedTo(String name) {
    return 'Switched to $name';
  }

  @override
  String accountSignedOutOf(String name) {
    return 'Signed out of $name';
  }

  @override
  String get addAccountTagline =>
      'Sign in with another account, on one of your servers or a new one.';

  @override
  String get addAccountYourServers => 'Your servers';

  @override
  String get addAccountAlreadyAdded =>
      'You’re already signed in to this account — switched to it';

  @override
  String get addAccountAlreadyActive =>
      'You’re already signed in to this account';

  @override
  String get overviewLoading => 'Loading your tasks…';

  @override
  String get overviewEmptyTitle => 'All done';

  @override
  String get overviewEmptyBody =>
      'No open tasks right now. Enjoy the quiet, or add one with New task.';

  @override
  String get sectionOverdue => 'Overdue';

  @override
  String get sectionToday => 'Today';

  @override
  String get sectionNextSevenDays => 'Next 7 days';

  @override
  String get sectionLater => 'Later';

  @override
  String get sectionNoDueDate => 'No due date';

  @override
  String get projectsLoading => 'Loading your projects…';

  @override
  String get projectsEmptyTitle => 'No projects yet';

  @override
  String get projectsEmptyBody =>
      'Create your first project on the web and it will show up here.';

  @override
  String get projectsFavouritesHeading => 'Favourites';

  @override
  String get projectsFavouriteTasks => 'Favourite tasks';

  @override
  String get projectsAllHeading => 'All projects';

  @override
  String get projectsShowArchived => 'Show archived projects';

  @override
  String get projectArchived => 'Archived';

  @override
  String get projectArchivedNote =>
      'This project is archived. It is not possible to create new or edit tasks for it.';

  @override
  String get savedFiltersHeading => 'Saved filters';

  @override
  String get savedFilterUnknownTitle => 'Saved filter';

  @override
  String smartListOpenTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open tasks',
      one: '1 open task',
    );
    return '$_temp0';
  }

  @override
  String smartListFilterNotice(String when) {
    return 'The server applies this filter. Shown as of $when; new tasks and changes made elsewhere appear after the next download.';
  }

  @override
  String smartListFilterNotLoadedBody(String title) {
    return 'The server applies the saved filter “$title”. Its tasks download when you open it online.';
  }

  @override
  String get smartListFilterDownloadingTitle => 'Downloading this filter…';

  @override
  String smartListFilterDownloadingBody(String title) {
    return 'The server applies the saved filter “$title”. Its tasks are on their way.';
  }

  @override
  String get smartListFilterGoneTitle => 'This saved filter is gone';

  @override
  String get smartListFilterGoneBody =>
      'The last sync no longer found it. It may have been deleted on the web.';

  @override
  String get smartListFilterDownloadFailedTitle =>
      'Couldn\'t download this filter';

  @override
  String smartListFilterDownloadFailedBody(String title) {
    return 'The server applies the saved filter “$title”. Pull down to try again.';
  }

  @override
  String get favoritesEmptyTitle => 'No favourite tasks';

  @override
  String get favoritesEmptyBody =>
      'Mark a task as a favourite with its star to find it here.';

  @override
  String get appearanceHeading => 'Appearance';

  @override
  String get appearanceSystemColors => 'Use system colours';

  @override
  String get appearanceSystemColorsSubtitle =>
      'The colours of your wallpaper instead of the app\'s blue';

  @override
  String projectChildCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subprojects',
      one: '1 subproject',
    );
    return '$_temp0';
  }

  @override
  String projectExpand(String title) {
    return 'Show subprojects of $title';
  }

  @override
  String projectCollapse(String title) {
    return 'Hide subprojects of $title';
  }

  @override
  String get projectUnknownTitle => 'Project';

  @override
  String get favouriteLabel => 'Favourite';

  @override
  String get projectTasksShowDone => 'Show done tasks';

  @override
  String get projectTasksLoading => 'Loading tasks…';

  @override
  String get projectTasksEmptyTitle => 'No open tasks';

  @override
  String get projectTasksEmptyBody =>
      'Everything in this project is done. Turn on “Show done tasks” to see them.';

  @override
  String get projectTasksEmptyAllTitle => 'No tasks';

  @override
  String get projectTasksEmptyAllBody => 'This project has no tasks yet.';

  @override
  String get moreActions => 'More';

  @override
  String get refresh => 'Refresh';

  @override
  String get taskDone => 'Done';

  @override
  String taskDueSemantics(String when) {
    return 'Due $when';
  }

  @override
  String taskOverdueSemantics(String when) {
    return 'Overdue, due $when';
  }

  @override
  String prioritySemantics(String priority) {
    return 'Priority: $priority';
  }

  @override
  String labelSemantics(String label) {
    return 'Label: $label';
  }

  @override
  String get priorityUnset => 'Unset';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get priorityDoNow => 'Do now';

  @override
  String get relativeNow => 'now';

  @override
  String relativeInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count minutes',
      one: 'in 1 minute',
    );
    return '$_temp0';
  }

  @override
  String relativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String relativeInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count hours',
      one: 'in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String relativeInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String relativeInMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count months',
      one: 'in 1 month',
    );
    return '$_temp0';
  }

  @override
  String relativeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String relativeInYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count years',
      one: 'in 1 year',
    );
    return '$_temp0';
  }

  @override
  String relativeYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get relativeJustNow => 'just now';

  @override
  String momentDateAtTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String get taskDetailDueDate => 'Due date';

  @override
  String get taskDetailStartDate => 'Start date';

  @override
  String get taskDetailEndDate => 'End date';

  @override
  String get taskDetailPriority => 'Priority';

  @override
  String get taskDetailProgress => 'Progress';

  @override
  String taskPercentDone(int percent) {
    return '$percent% done';
  }

  @override
  String get taskDetailLabels => 'Labels';

  @override
  String get taskDetailAssignees => 'Assignees';

  @override
  String get taskDetailReminders => 'Reminders';

  @override
  String get taskDetailRepeat => 'Repeats';

  @override
  String get taskDetailDescription => 'Description';

  @override
  String get taskDetailNoDescription => 'No description';

  @override
  String get taskDetailClose => 'Close';

  @override
  String get repeatMonthly => 'Every month';

  @override
  String repeatEverySeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count seconds',
      one: 'Every second',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count minutes',
      one: 'Every minute',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count hours',
      one: 'Every hour',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String repeatFromCompletion(String repeat) {
    return '$repeat, counted from completion';
  }

  @override
  String periodSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String periodMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String periodHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String periodDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String periodWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String reminderBefore(String period, String reference) {
    return '$period before the $reference';
  }

  @override
  String reminderAfter(String period, String reference) {
    return '$period after the $reference';
  }

  @override
  String reminderAtReference(String reference) {
    return 'At the $reference';
  }

  @override
  String get reminderReferenceDueDate => 'due date';

  @override
  String get reminderReferenceStartDate => 'start date';

  @override
  String get reminderReferenceEndDate => 'end date';

  @override
  String get dataFailureLoadTitle => 'Couldn’t load from the server';

  @override
  String get dataFailureRefreshTitle => 'Couldn’t refresh';

  @override
  String get dataFailureStaleNote => 'Showing what was loaded last.';

  @override
  String dataFailureSessionEnded(String host) {
    return 'Your session on $host has ended. Sign in again on the Account tab.';
  }

  @override
  String dataFailureForbidden(String host) {
    return '$host refused the request. You may no longer have access to this.';
  }

  @override
  String dataFailureNotFound(String host) {
    return '$host no longer has this. It may have been deleted.';
  }

  @override
  String dataFailureRateLimited(String host) {
    return '$host is limiting requests from your network for now.';
  }

  @override
  String dataFailureUnexpected(String host) {
    return 'An unexpected error occurred while loading from $host.';
  }

  @override
  String get retry => 'Try again';

  @override
  String get firstSyncTitle => 'Getting your tasks';

  @override
  String firstSyncBody(String host) {
    return 'Rurana is saving everything from $host on this device, so it works offline too.';
  }

  @override
  String get firstSyncPreparing => 'Preparing…';

  @override
  String get firstSyncCancel => 'Cancel and sign out';

  @override
  String get syncPhaseAccount => 'Checking your account…';

  @override
  String get syncPhaseProjects => 'Loading projects…';

  @override
  String get syncPhaseLabels => 'Loading labels…';

  @override
  String get syncPhaseTasks => 'Loading tasks…';

  @override
  String get syncPhaseArchivedTasks => 'Loading archived projects…';

  @override
  String get syncPhaseDelta => 'Loading changes…';

  @override
  String get syncPhaseReconcile => 'Checking for deleted tasks…';

  @override
  String get syncPhaseFinishing => 'Finishing up…';

  @override
  String syncProgressOfTotal(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString of $totalString';
  }

  @override
  String syncProgressCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString so far';
  }

  @override
  String get syncIndicatorLabel => 'Syncing with the server';

  @override
  String get offlineNotice => 'Offline — showing saved data';

  @override
  String accountLastSynced(String when) {
    return 'Last synced $when';
  }

  @override
  String get accountLastSyncedJustNow => 'Synced just now';

  @override
  String get accountNeverSynced => 'Not synced yet';

  @override
  String get accountSyncing => 'Syncing…';

  @override
  String get accountSyncFailed => 'The last sync failed.';

  @override
  String get accountSyncNow => 'Sync now';

  @override
  String get accountFullResync => 'Full resync';

  @override
  String accountBackgroundSync(String when) {
    return 'Background sync: $when';
  }

  @override
  String get accountBackgroundSyncJustNow => 'Background sync: just now';

  @override
  String get accountBackgroundSyncNever => 'Background sync has not run yet';

  @override
  String get accountBackgroundSyncIosHint =>
      'iOS decides when apps may sync in the background.';

  @override
  String get taskMarkDone => 'Mark done';

  @override
  String get taskMarkNotDone => 'Mark not done';

  @override
  String get taskMarkedDone => 'Marked done';

  @override
  String get undo => 'Undo';

  @override
  String get taskAddFavourite => 'Add to favourites';

  @override
  String get taskRemoveFavourite => 'Remove from favourites';

  @override
  String get taskNotYetSynced => 'Not yet synced';

  @override
  String get taskDelete => 'Delete task';

  @override
  String get taskDeleteDialogTitle => 'Delete task?';

  @override
  String taskDeleteDialogBody(String title) {
    return '“$title” will be deleted on the server too. This cannot be undone.';
  }

  @override
  String get taskDeleteDialogCancel => 'Cancel';

  @override
  String get taskDeleteDialogConfirm => 'Delete';

  @override
  String get taskDeleted => 'Task deleted';

  @override
  String accountPendingChanges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Pending changes: $countString';
  }

  @override
  String get accountSendNow => 'Send now';

  @override
  String get accountSending => 'Sending…';

  @override
  String accountSendNowFailed(String reason) {
    return 'Not sent. $reason';
  }

  @override
  String get accountSyncProblems => 'Sync problems';

  @override
  String get syncProblemUpdateFailed => 'The change could not be saved.';

  @override
  String get syncProblemDeleteFailed => 'The task could not be deleted.';

  @override
  String get syncProblemForbidden =>
      'You no longer have access to its project.';

  @override
  String get syncProblemProjectMissing =>
      'Its project no longer exists on the server.';

  @override
  String get syncProblemTaskMissing =>
      'The task no longer exists on the server.';

  @override
  String get syncProblemLabelMissing =>
      'One of its labels no longer exists on the server.';

  @override
  String get syncProblemUserMissing =>
      'One of its assignees no longer exists on the server.';

  @override
  String get syncProblemProjectArchived => 'Its project is archived.';

  @override
  String get syncProblemRelatedTaskMissing =>
      'A task it is related to no longer exists on the server.';

  @override
  String get syncProblemRelationCycle =>
      'The relation would make the tasks depend on each other in a loop.';

  @override
  String get syncProblemRelationToItself =>
      'A task cannot be related to itself.';

  @override
  String get syncProblemColumnFull => 'This column is full.';

  @override
  String get syncProblemColumnMissing => 'The column no longer exists.';

  @override
  String get syncProblemRejected => 'The server rejected the change.';

  @override
  String get syncProblemUnexpected =>
      'The server answered in an unexpected way.';

  @override
  String syncProblemFailedAt(String when) {
    return 'Failed $when';
  }

  @override
  String get syncProblemFailedJustNow => 'Failed just now';

  @override
  String get syncProblemDiscard => 'Discard';

  @override
  String get syncProblemCreateFailed => 'The task could not be created.';

  @override
  String get taskEdit => 'Edit';

  @override
  String get taskEditTitle => 'Edit task';

  @override
  String get taskEditSave => 'Save';

  @override
  String get taskEditSaved => 'Saved';

  @override
  String get taskEditLoading => 'Loading task…';

  @override
  String get taskEditGoneTitle => 'Task not found';

  @override
  String get taskEditGoneBody => 'This task is no longer on this device.';

  @override
  String get taskEditTitleLabel => 'Title';

  @override
  String get taskEditTitleRequired => 'Enter a title.';

  @override
  String get taskEditProject => 'Project';

  @override
  String get taskEditProjectPickerTitle => 'Choose a project';

  @override
  String taskEditProjectSemantics(String project) {
    return 'Project: $project';
  }

  @override
  String get taskEditDateNotSet => 'Not set';

  @override
  String get taskEditClearDueDate => 'Clear due date';

  @override
  String get taskEditClearStartDate => 'Clear start date';

  @override
  String get taskEditClearEndDate => 'Clear end date';

  @override
  String get shortcutToday => 'Today';

  @override
  String get shortcutTomorrow => 'Tomorrow';

  @override
  String get shortcutNextMonday => 'Next Monday';

  @override
  String get shortcutThisWeekend => 'This weekend';

  @override
  String get shortcutLaterThisWeek => 'Later this week';

  @override
  String get shortcutNextWeek => 'Next week';

  @override
  String get shortcutNextWeekend => 'Next weekend';

  @override
  String get shortcutEndOfMonth => 'End of month';

  @override
  String get shortcutInAMonth => 'In a month';

  @override
  String shortcutSemantics(String label, String date) {
    return '$label, $date';
  }

  @override
  String get taskEditColour => 'Colour';

  @override
  String get taskEditNoColour => 'No colour';

  @override
  String taskEditColourSemantics(String hex) {
    return 'Colour $hex';
  }

  @override
  String get taskEditRepeat => 'Repeat';

  @override
  String get repeatModeNone => 'Never';

  @override
  String get repeatModeEvery => 'Every…';

  @override
  String get repeatModeMonthly => 'Monthly';

  @override
  String get repeatModeFromCompletion => 'From completion';

  @override
  String get repeatAmountLabel => 'Every';

  @override
  String get repeatAmountInvalid => 'Enter more than 0.';

  @override
  String get repeatUnitHours => 'Hours';

  @override
  String get repeatUnitDays => 'Days';

  @override
  String get repeatUnitWeeks => 'Weeks';

  @override
  String get repeatPresetDaily => 'Every day';

  @override
  String get repeatPresetWeekly => 'Every week';

  @override
  String get repeatPresetThirtyDays => 'Every 30 days';

  @override
  String get taskEditDiscardTitle => 'Discard changes?';

  @override
  String get taskEditDiscardBody => 'Your edits to this task will be lost.';

  @override
  String get taskEditKeepEditing => 'Keep editing';

  @override
  String get taskEditDiscard => 'Discard';

  @override
  String get pickerDone => 'Done';

  @override
  String get pickerCancel => 'Cancel';

  @override
  String get newTask => 'New task';

  @override
  String get newTaskTitleHint => 'What needs doing?';

  @override
  String get newTaskAdd => 'Add';

  @override
  String get newTaskMoreOptions => 'More options';

  @override
  String get newTaskPickDate => 'Pick date…';

  @override
  String get newTaskNoProject => 'No project';

  @override
  String newTaskCreated(String title) {
    return 'Added “$title”';
  }

  @override
  String newTaskAddMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count tasks',
      one: 'Add 1 task',
    );
    return '$_temp0';
  }

  @override
  String newTaskCreatedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count tasks',
      one: 'Added 1 task',
    );
    return '$_temp0';
  }

  @override
  String newTaskLabelsNotCreated(String labels) {
    return 'These labels could not be created and were not added: $labels';
  }

  @override
  String newTaskNamesKept(String names) {
    return 'Nobody found for $names, so they stay in the title.';
  }

  @override
  String get newTaskNoProjectError =>
      'There\'s no project to add tasks to yet. Create one on the web first.';

  @override
  String newTaskAddFailed(String reason) {
    return 'The task could not be added: $reason';
  }

  @override
  String get newTaskAddFailedUnknown => 'The task could not be added.';

  @override
  String newTaskLineCountOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks, one per line',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String newTaskAddedPartly(int added, int total) {
    return '$added of $total tasks were added; the others are still here.';
  }

  @override
  String newTaskLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks, one per line',
      one: '1 task',
    );
    return '$_temp0 · the first one:';
  }

  @override
  String quickAddMagicOnly(String title) {
    return 'Only magic words, so nothing is recognised: the task will be called “$title”.';
  }

  @override
  String quickAddDueLabel(String date, String relative) {
    return '$date · $relative';
  }

  @override
  String quickAddDueSemantics(String date, String relative) {
    return 'Due $date, $relative';
  }

  @override
  String quickAddRepeatSemantics(String repeat) {
    return 'Repeats: $repeat';
  }

  @override
  String quickAddProjectAmbiguous(String project) {
    return 'Several projects are called “$project”. Remove it and choose the project below.';
  }

  @override
  String quickAddProjectNotFound(String project) {
    return 'Project “$project” not found';
  }

  @override
  String quickAddNewLabel(String label) {
    return '$label · new';
  }

  @override
  String quickAddNewLabelSemantics(String label) {
    return 'New label $label, created when you add the task';
  }

  @override
  String quickAddAssigneeSemantics(String name) {
    return 'Assigned to $name';
  }

  @override
  String quickAddLookedUp(String name) {
    return '$name · will be looked up';
  }

  @override
  String quickAddLookedUpSemantics(String name) {
    return '$name, will be looked up when you add the task';
  }

  @override
  String quickAddReminderSemantics(String reminder) {
    return 'Reminder: $reminder';
  }

  @override
  String quickAddRemovePart(String part) {
    return 'Remove $part';
  }

  @override
  String get quickAddSuggestions => 'Suggestions';

  @override
  String quickAddInsertLabel(String prefix) {
    return 'Add a label ($prefix)';
  }

  @override
  String quickAddInsertProject(String prefix) {
    return 'Choose a project ($prefix)';
  }

  @override
  String quickAddInsertAssignee(String prefix) {
    return 'Assign someone ($prefix)';
  }

  @override
  String quickAddSetPriority(String prefix) {
    return 'Set priority ($prefix)';
  }

  @override
  String get quickAddHelp => 'How Quick Add Magic works';

  @override
  String get quickAddHelpTitle => 'Quick Add Magic';

  @override
  String get quickAddHelpIntro =>
      'Write the whole task in one line. These parts are recognised, marked in colour and taken out of the title:';

  @override
  String get quickAddHelpLabelsTitle => 'Labels';

  @override
  String quickAddHelpLabelsBody(String prefix) {
    return 'A word starting with $prefix. Labels that don\'t exist yet are created when you add the task. Use quotes for spaces.';
  }

  @override
  String get quickAddHelpProjectTitle => 'Project';

  @override
  String quickAddHelpProjectBody(String prefix) {
    return '$prefix and a project\'s title or identifier. Without one, the task goes to the project shown below the field.';
  }

  @override
  String get quickAddHelpPriorityTitle => 'Priority';

  @override
  String quickAddHelpPriorityBody(String prefix) {
    return '$prefix and a number from 1 (low) to 5 (do now).';
  }

  @override
  String get quickAddHelpPeopleTitle => 'People';

  @override
  String quickAddHelpPeopleBody(String prefix) {
    return '$prefix and a username or name. Anyone who isn\'t found stays in the title.';
  }

  @override
  String get quickAddHelpDatesTitle => 'Dates and times';

  @override
  String get quickAddHelpDatesBody => 'For example:';

  @override
  String get quickAddHelpTimesBody => 'Add a time with “at”:';

  @override
  String get quickAddHelpRepeatsTitle => 'Repeats';

  @override
  String get quickAddHelpRepeatsBody =>
      'A repeat without a date makes the task due today.';

  @override
  String get quickAddHelpEnglish =>
      'Date and repeat words are always English, as on the web.';

  @override
  String get quickAddHelpMoreTitle => 'Good to know';

  @override
  String get quickAddHelpQuotes =>
      'Put the whole title in quotes to switch the magic off for one task.';

  @override
  String get quickAddHelpLines =>
      'Paste several lines to add one task per line.';

  @override
  String get quickAddHelpExampleTitle => 'Example';

  @override
  String get quickAddHelpExampleTask => 'Change tyres';

  @override
  String get quickAddHelpExampleLabel => 'car';

  @override
  String get quickAddHelpExampleProject => 'Home';

  @override
  String quickAddHelpMode(String mode) {
    return 'These are the $mode prefixes, as set in your Vikunja settings on the web.';
  }

  @override
  String get taskEditAddLabel => 'Add label';

  @override
  String taskEditRemoveLabel(String label) {
    return 'Remove label $label';
  }

  @override
  String get taskEditAssign => 'Assign';

  @override
  String taskEditUnassign(String name) {
    return 'Unassign $name';
  }

  @override
  String get taskEditAddReminder => 'Add reminder';

  @override
  String get taskEditEditReminder => 'Edit reminder';

  @override
  String taskEditRemoveReminder(String reminder) {
    return 'Remove reminder: $reminder';
  }

  @override
  String get taskEditReminderDuplicate => 'This reminder is already set.';

  @override
  String get reminderDueDateNotSet => 'Due date is not set';

  @override
  String get reminderStartDateNotSet => 'Start date is not set';

  @override
  String get reminderEndDateNotSet => 'End date is not set';

  @override
  String get taskEditRemindersCoincide =>
      'Some reminders fall on the same moment. The server keeps only one of them.';

  @override
  String get labelPickerTitle => 'Choose labels';

  @override
  String get labelPickerSearch => 'Search or create a label';

  @override
  String get labelPickerEmpty => 'No labels yet. Type a name to create one.';

  @override
  String labelPickerCreate(String title) {
    return 'Create label “$title”';
  }

  @override
  String get labelPickerCreating => 'Creating the label…';

  @override
  String get labelPickerCreateOffline =>
      'Creating a label needs a connection to the server.';

  @override
  String get labelPickerCreateUnconfirmed =>
      'Couldn\'t confirm that the label was created. Check your connection and try again.';

  @override
  String labelPickerCreateRejected(String message) {
    return 'The server did not create the label: $message';
  }

  @override
  String get labelPickerCreateFailed => 'The label could not be created.';

  @override
  String labelPickerTitleTooLong(int max) {
    return 'A label title can have at most $max characters.';
  }

  @override
  String get assigneePickerTitle => 'Assign people';

  @override
  String get assigneePickerSearch => 'Search people';

  @override
  String get assigneePickerSearching => 'Searching…';

  @override
  String get assigneePickerNoResults => 'Nobody found.';

  @override
  String get assigneePickerOffline =>
      'Offline — showing people from your synced tasks';

  @override
  String assigneePickerFallback(String reason) {
    return '$reason — showing people from your synced tasks';
  }

  @override
  String get assigneePickerSearchFailed => 'Search failed';

  @override
  String assigneeUsername(String username) {
    return '@$username';
  }

  @override
  String get reminderPickerCustom => 'Custom…';

  @override
  String get reminderPickerDateTime => 'Date and time…';

  @override
  String get reminderPickerAlreadySet => 'Already set';

  @override
  String get reminderPickerNoDateHint =>
      'Set a due, start or end date to get quick choices here.';

  @override
  String get reminderPickerCustomTitle => 'Custom reminder';

  @override
  String get reminderAmountLabel => 'Amount';

  @override
  String get reminderAmountInvalid => 'Enter a whole number, 0 or more.';

  @override
  String get reminderUnitCaption => 'Unit';

  @override
  String get reminderDirectionCaption => 'When';

  @override
  String get reminderUnitMinutes => 'Minutes';

  @override
  String get reminderUnitHours => 'Hours';

  @override
  String get reminderUnitDays => 'Days';

  @override
  String get reminderUnitWeeks => 'Weeks';

  @override
  String get reminderDirectionBefore => 'Before';

  @override
  String get reminderDirectionAfter => 'After';

  @override
  String get reminderRelativeToLabel => 'Relative to';

  @override
  String get reminderRelativeToDueDate => 'Due date';

  @override
  String get reminderRelativeToStartDate => 'Start date';

  @override
  String get reminderRelativeToEndDate => 'End date';

  @override
  String reminderRelativeToUnset(String date) {
    return '$date (not set)';
  }

  @override
  String get inboxTitle => 'Notifications';

  @override
  String inboxButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notifications, $countString unread',
      one: 'Notifications, 1 unread',
      zero: 'Notifications',
    );
    return '$_temp0';
  }

  @override
  String get inboxLoading => 'Loading notifications…';

  @override
  String get inboxEmptyTitle => 'You’re all caught up';

  @override
  String get inboxEmptyBody =>
      'Comments, assignments and mentions from your Vikunja server show up here.';

  @override
  String get inboxMarkAllRead => 'Mark all as read';

  @override
  String get inboxToday => 'Today';

  @override
  String get inboxYesterday => 'Yesterday';

  @override
  String get inboxEarlier => 'Earlier';

  @override
  String get inboxUnread => 'Unread';

  @override
  String get inboxTaskNotLocal => 'This task is not on this device';

  @override
  String get inboxProjectNotLocal => 'This project is not on this device';

  @override
  String get inboxSomeone => 'Someone';

  @override
  String get inboxATask => 'a task';

  @override
  String get inboxUnnamed => 'unnamed';

  @override
  String inboxCommented(String doer, String task) {
    return '$doer commented on $task';
  }

  @override
  String inboxAssignedYou(String doer, String task) {
    return '$doer assigned you to $task';
  }

  @override
  String inboxAssigned(String doer, String assignee, String task) {
    return '$doer assigned $assignee to $task';
  }

  @override
  String inboxAssignedSomeone(String doer, String task) {
    return '$doer assigned someone to $task';
  }

  @override
  String inboxMentioned(String doer, String task) {
    return '$doer mentioned you on $task';
  }

  @override
  String inboxTaskCreated(String doer, String task) {
    return '$doer created $task';
  }

  @override
  String inboxTaskDeleted(String doer, String task) {
    return '$doer deleted $task';
  }

  @override
  String inboxProjectCreated(String doer, String project) {
    return '$doer created $project';
  }

  @override
  String inboxAddedYouToTeam(String doer, String team) {
    return '$doer added you to the $team team';
  }

  @override
  String inboxAddedToTeam(String doer, String member, String team) {
    return '$doer added $member to the $team team';
  }

  @override
  String inboxAddedSomeoneToTeam(String doer, String team) {
    return '$doer added someone to the $team team';
  }

  @override
  String get inboxTaskWasDeleted => 'This task was deleted';

  @override
  String inboxReminder(String task) {
    return 'Reminder for $task';
  }

  @override
  String get inboxOther => 'New notification';

  @override
  String inboxQuoted(String text) {
    return '“$text”';
  }

  @override
  String get notificationSetupTitle => 'Stay on top of your tasks';

  @override
  String get notificationSetupBody =>
      'Rurana can notify you on this phone, without the server having to send anything:';

  @override
  String get notificationSetupReminders => 'Reminders at their time';

  @override
  String get notificationSetupDueDates => 'Due dates at the exact time';

  @override
  String get notificationSetupOnlyYours =>
      'Only for tasks you created or are assigned to';

  @override
  String get notificationSetupTurnOn => 'Turn on notifications';

  @override
  String get notificationSetupNotNow => 'Not now';

  @override
  String get notificationSetupExactTitle => 'Reminders right on time';

  @override
  String get notificationSetupExactBody =>
      'Without exact alarms, Android may show reminders minutes late. You can allow them in the system settings; the app works either way.';

  @override
  String get notificationSetupExactAllow => 'Allow exact alarms';

  @override
  String get notificationSetupSkip => 'Skip';

  @override
  String get notificationsHeading => 'Notifications';

  @override
  String get notificationsReminders => 'Reminders';

  @override
  String get notificationsRemindersSubtitle => 'At the time of each reminder';

  @override
  String get notificationsDueDates => 'Due dates';

  @override
  String get notificationsDueDatesSubtitle => 'At the exact due time';

  @override
  String get notificationsActivity => 'Activity';

  @override
  String get notificationsActivitySubtitle =>
      'Comments, assignments and mentions';

  @override
  String get notificationsOff => 'Notifications are off';

  @override
  String get notificationsOpenSettings => 'Open settings';

  @override
  String get notificationsTurnOn => 'Turn on';

  @override
  String get notificationsMayBeLate => 'Reminders may be late';

  @override
  String get notificationsAllowExactAlarms => 'Allow exact alarms';

  @override
  String notificationsScheduled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scheduled',
      one: '1 scheduled',
      zero: 'Nothing scheduled',
    );
    return '$_temp0';
  }

  @override
  String get notificationsSendTest => 'Send a test notification';

  @override
  String get notificationTestTitle => 'Test notification';

  @override
  String get notificationTestBody =>
      'Notifications from Rurana work on this phone.';

  @override
  String get notificationTaskGone => 'This task is gone';

  @override
  String get notificationTestReceived => 'Notifications work';

  @override
  String get notificationChannelReminders => 'Reminders';

  @override
  String get notificationChannelRemindersDescription =>
      'Reminders and due dates of your tasks';

  @override
  String get notificationChannelActivity => 'Activity';

  @override
  String get notificationChannelActivityDescription =>
      'Comments, assignments and mentions from your Vikunja servers';

  @override
  String activityNotificationCommented(String name, String comment) {
    return '$name commented: $comment';
  }

  @override
  String activityNotificationCommentedNoText(String name) {
    return '$name commented';
  }

  @override
  String activityNotificationAssignedYou(String name) {
    return '$name assigned you';
  }

  @override
  String activityNotificationAssignedOther(String name, String assignee) {
    return '$name assigned $assignee';
  }

  @override
  String activityNotificationAssignedSomeone(String name) {
    return '$name assigned someone to this task';
  }

  @override
  String activityNotificationMentioned(String name) {
    return '$name mentioned you';
  }

  @override
  String activityNotificationTaskCreated(String name, String project) {
    return '$name created this task in $project';
  }

  @override
  String activityNotificationTaskCreatedNoProject(String name) {
    return '$name created this task';
  }

  @override
  String activityNotificationTaskDeleted(String name) {
    return '$name deleted this task';
  }

  @override
  String activityNotificationProjectCreated(String name, String project) {
    return '$name created the project $project';
  }

  @override
  String activityNotificationTeamAddedYou(String name, String team) {
    return '$name added you to the team $team';
  }

  @override
  String activityNotificationTeamAddedOther(
    String name,
    String member,
    String team,
  ) {
    return '$name added $member to the team $team';
  }

  @override
  String activityNotificationTeamAddedSomeone(String name, String team) {
    return '$name added someone to the team $team';
  }

  @override
  String get activityNotificationMoreTitle => 'More activity';

  @override
  String activityNotificationMoreBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more new notifications',
      one: '1 more new notification',
    );
    return '$_temp0';
  }

  @override
  String get activityNotificationUntitled => 'Vikunja';

  @override
  String sessionEndedNotificationTitle(String host) {
    return 'Sign in again to $host';
  }

  @override
  String sessionEndedNotificationBody(String username) {
    return 'Your session as $username has ended. Rurana cannot sync this account until you sign in again.';
  }

  @override
  String get notificationActionDone => 'Done';

  @override
  String get notificationActionSnooze10Minutes => 'Snooze 10 min';

  @override
  String get notificationActionSnooze1Hour => 'Snooze 1 h';

  @override
  String notificationReminderBody(String project) {
    return 'Reminder · $project';
  }

  @override
  String get notificationReminderBodyNoProject => 'Reminder';

  @override
  String notificationDueBody(String project) {
    return 'Due now · $project';
  }

  @override
  String get notificationDueBodyNoProject => 'Due now';

  @override
  String notificationBodyWithIdentifier(String body, String identifier) {
    return '$body · $identifier';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get taskDetailSubtasks => 'Subtasks';

  @override
  String taskDetailSubtasksDone(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get taskDetailAddSubtask => 'Add subtask';

  @override
  String get taskDetailAddSubtaskFailed => 'Couldn\'t add the subtask';

  @override
  String get taskDetailSubtaskNotLinked =>
      'The task was added, but not as a subtask';

  @override
  String get taskDetailParentTask => 'Parent task';

  @override
  String get taskDetailRelatedTasks => 'Related tasks';

  @override
  String get taskDetailAddRelation => 'Add relation';

  @override
  String get taskRelationSubtask => 'Subtask';

  @override
  String get taskRelationParentTask => 'Parent task';

  @override
  String get taskRelationRelated => 'Related to';

  @override
  String get taskRelationBlocking => 'Blocks';

  @override
  String get taskRelationBlocked => 'Blocked by';

  @override
  String get taskRelationPrecedes => 'Precedes';

  @override
  String get taskRelationFollows => 'Follows';

  @override
  String get taskRelationDuplicateOf => 'Duplicate of';

  @override
  String get taskRelationDuplicates => 'Duplicated by';

  @override
  String get taskRelationCopiedFrom => 'Copied from';

  @override
  String get taskRelationCopiedTo => 'Copied to';

  @override
  String get taskRelationRemove => 'Remove relation';

  @override
  String get taskRelationRemoveTitle => 'Remove relation?';

  @override
  String taskRelationRemoveBody(String title) {
    return 'The link to “$title” will be removed on the server too. The task itself stays.';
  }

  @override
  String get taskRelationRemoveConfirm => 'Remove';

  @override
  String get addRelationKind => 'Relation';

  @override
  String get addRelationSearch => 'Search by title or identifier';

  @override
  String get addRelationShowDone => 'Show done tasks';

  @override
  String get addRelationNoMatches => 'No matching tasks';

  @override
  String get taskDuplicate => 'Duplicate';

  @override
  String get taskDuplicated => 'Duplicated';

  @override
  String get taskDuplicateOpen => 'Open';

  @override
  String get taskDuplicateNeedsConnection =>
      'Duplicating needs a connection to the server.';

  @override
  String get taskDuplicateNotSynced =>
      'You can duplicate this task once its changes are synced.';

  @override
  String taskDuplicateFailed(String message) {
    return 'Couldn\'t duplicate the task: $message';
  }

  @override
  String get taskDuplicateFailedUnknown => 'Couldn\'t duplicate the task.';

  @override
  String get followTask => 'Follow task';

  @override
  String get unfollowTask => 'Unfollow task';

  @override
  String get followProject => 'Follow project';

  @override
  String get unfollowProject => 'Unfollow project';

  @override
  String get followNeedsConnection =>
      'Following needs a connection to the server.';

  @override
  String get followFailed =>
      'Couldn\'t change whether you follow this. Try again.';

  @override
  String get followTaskOnceSynced =>
      'You can follow this task once it is synced.';

  @override
  String get followTaskUnavailable => 'Follow task (needs a connection)';

  @override
  String get followChecking => 'Checking whether you follow this…';

  @override
  String followingViaProject(String project) {
    return 'Following the project $project';
  }

  @override
  String get followingViaSomeProject => 'Following through a project';

  @override
  String get followInheritedTaskTitle => 'Stop following this task?';

  @override
  String followInheritedTaskBody(String project) {
    return 'You follow the project “$project”, which includes this task. You will stop getting notifications about this task only and keep following the project.';
  }

  @override
  String get followInheritedProjectTitle => 'Stop following this project?';

  @override
  String followInheritedProjectBody(String project) {
    return 'You follow the parent project “$project”. You will stop getting notifications about this project only and keep following “$project”.';
  }

  @override
  String get followInheritedConfirm => 'Stop following';

  @override
  String get projectFollowed => 'You follow this project now';

  @override
  String get projectUnfollowed => 'You no longer follow this project';

  @override
  String newTaskTreeCount(int count, int subtasks) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subtasks,
      locale: localeName,
      other: '$subtasks as subtasks',
      one: '1 as a subtask',
    );
    return '$_temp0, $_temp1 · the first one:';
  }

  @override
  String newTaskTreeCountOnly(int count, int subtasks) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subtasks,
      locale: localeName,
      other: '$subtasks as subtasks',
      one: '1 as a subtask',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get tabUpcoming => 'Upcoming';

  @override
  String get upcomingEmptyTitle => 'Nothing to do — have a nice day!';

  @override
  String get upcomingEmptyBody => 'No open task is due in this date range.';

  @override
  String get upcomingShowOverdue => 'Show overdue tasks';

  @override
  String get upcomingShowWithoutDate => 'Show tasks without date';

  @override
  String get upcomingSelectRange => 'Select a date range';

  @override
  String get upcomingRangeCustom => 'Custom';

  @override
  String get upcomingRangeCustomEntry => 'Custom…';

  @override
  String upcomingRangeDates(String from, String to) {
    return '$from – $to';
  }

  @override
  String upcomingRangeSemantics(String name, String dates) {
    return 'Date range $name, $dates';
  }

  @override
  String get upcomingRangeFrom => 'From';

  @override
  String get upcomingRangeTo => 'To';

  @override
  String get rangeToday => 'Today';

  @override
  String get rangeTomorrow => 'Tomorrow';

  @override
  String get rangeLastWeek => 'Last Week';

  @override
  String get rangeThisWeek => 'This Week';

  @override
  String get rangeRestOfThisWeek => 'The Rest of This Week';

  @override
  String get rangeNextWeek => 'Next Week';

  @override
  String get rangeNext7Days => 'Next 7 Days';

  @override
  String get rangeLastMonth => 'Last Month';

  @override
  String get rangeThisMonth => 'This Month';

  @override
  String get rangeRestOfThisMonth => 'The Rest of This Month';

  @override
  String get rangeNextMonth => 'Next Month';

  @override
  String get rangeNext30Days => 'Next 30 Days';

  @override
  String get rangeThisYear => 'This Year';

  @override
  String get rangeRestOfThisYear => 'The Rest of This Year';

  @override
  String get sectionTomorrow => 'Tomorrow';

  @override
  String overviewFilterSubtitle(String title) {
    return 'Filter: $title';
  }

  @override
  String get overviewFilterNotLoadedTitle =>
      'This filter loads once you\'re online';

  @override
  String overviewFilterNotLoadedBody(String title) {
    return 'Your Overview shows the saved filter “$title”, picked on the web. Its tasks download with the next sync.';
  }

  @override
  String overviewFilterEmptyBody(String title) {
    return 'The saved filter “$title” has no open tasks.';
  }

  @override
  String get projectViewList => 'List';

  @override
  String get projectViewGantt => 'Gantt';

  @override
  String get projectViewTable => 'Table';

  @override
  String get projectViewKanban => 'Kanban';

  @override
  String get projectViewSwitch => 'Switch view';

  @override
  String get projectSort => 'Sort';

  @override
  String projectSortCurrent(String sort) {
    return 'Sorted: $sort';
  }

  @override
  String get sortManual => 'Manually';

  @override
  String get sortTitleAsc => 'Title (A–Z)';

  @override
  String get sortTitleDesc => 'Title (Z–A)';

  @override
  String get sortPriorityDesc => 'Priority (Highest first)';

  @override
  String get sortPriorityAsc => 'Priority (Lowest first)';

  @override
  String get sortDueDateAsc => 'Due date (Earliest first)';

  @override
  String get sortDueDateDesc => 'Due date (Latest first)';

  @override
  String get sortStartDateAsc => 'Start date (Earliest first)';

  @override
  String get sortStartDateDesc => 'Start date (Latest first)';

  @override
  String get sortEndDateAsc => 'End date (Earliest first)';

  @override
  String get sortEndDateDesc => 'End date (Latest first)';

  @override
  String get sortPercentDoneDesc => '% done (Most done first)';

  @override
  String get sortPercentDoneAsc => '% done (Least done first)';

  @override
  String get sortCreatedDesc => 'Created (Newest first)';

  @override
  String get sortCreatedAsc => 'Created (Oldest first)';

  @override
  String get sortUpdatedDesc => 'Updated (Newest first)';

  @override
  String get sortUpdatedAsc => 'Updated (Oldest first)';

  @override
  String get projectTasksDoneSection => 'Done';

  @override
  String get projectTasksEmptyDoneTitle => 'No done tasks';

  @override
  String get projectTasksEmptyDoneBody => 'Nothing in this view is done yet.';

  @override
  String projectViewFilterNotice(String filter, String when) {
    return 'The server applies this view\'s filter “$filter”. Shown as of $when; changes made elsewhere appear after the next download.';
  }

  @override
  String get projectViewNotLoadedTitle => 'This view loads once you\'re online';

  @override
  String projectViewNotLoadedBody(String filter) {
    return 'The server applies this view\'s filter “$filter”. Its tasks download when you open it online.';
  }

  @override
  String get projectViewEmptyTitle => 'No matching tasks';

  @override
  String get projectViewEmptyBody =>
      'Nothing matched this view\'s filter at the last download.';

  @override
  String get taskDoneSemantics => 'Done';

  @override
  String taskAssigneesSemantics(String names) {
    return 'Assigned to $names';
  }

  @override
  String taskMoreAssignees(int count) {
    return '+$count';
  }

  @override
  String taskChecklistProgress(int checked, int total) {
    return '$checked of $total tasks';
  }

  @override
  String taskChecklistAllDone(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total tasks',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String get taskHasDescription => 'Has a description';

  @override
  String get taskRepeats => 'Repeats';

  @override
  String get savedFilterMyOpenTasks => 'My Open Tasks';

  @override
  String get projectInboxTitle => 'Inbox';

  @override
  String get projectFavouritesTitle => 'Favourites';

  @override
  String overviewFilterNotice(String title, String when) {
    return 'Filter: $title, as of $when. Tasks created here show after the next sync.';
  }

  @override
  String get overviewFilterNotDownloadedTitle =>
      'This filter hasn\'t downloaded yet';

  @override
  String get projectViewDownloadingTitle => 'Downloading this view…';

  @override
  String projectViewDownloadingBody(String filter) {
    return 'The server applies this view\'s filter “$filter”. Its tasks are on their way.';
  }

  @override
  String get projectViewDownloadFailedTitle => 'Couldn\'t download this view';

  @override
  String projectViewDownloadFailedBody(String filter) {
    return 'The server applies this view\'s filter “$filter”. Pull down to try again.';
  }

  @override
  String get boardNotLoadedBody =>
      'Its columns and cards download when you open it online.';

  @override
  String get boardDownloadingBody => 'Its columns and cards are on their way.';

  @override
  String get boardDownloadFailedBody => 'Pull down to try again.';

  @override
  String get boardNoColumnsTitle => 'No columns';

  @override
  String get boardNoColumnsBody =>
      'This board had no columns at the last download.';

  @override
  String get boardFilterColumnsNote =>
      'This board\'s columns come from filters, so its cards can\'t be moved here.';

  @override
  String get boardDoneColumnHint =>
      'All tasks moved into this column are marked as done automatically.';

  @override
  String boardColumnTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String boardColumnTaskCountOfLimit(int count, int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: '$limit tasks',
      one: '1 task',
    );
    return '$count of at most $_temp0';
  }

  @override
  String get boardColumnFull => 'Full';

  @override
  String get boardColumnLimitReached =>
      'You have reached the column limit. Remove tasks or increase the limit to add new tasks.';

  @override
  String boardTasksLeftInDefaultColumn(int count, String column) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks didn\'t fit into the column and went to $column.',
      one: '1 task didn\'t fit into the column and went to $column.',
    );
    return '$_temp0';
  }

  @override
  String get boardAddTask => 'Add a task';

  @override
  String get boardAddAnotherTask => 'Add another task';

  @override
  String get boardLoadMore => 'Load more';

  @override
  String get boardLoadingMore => 'Loading more tasks…';

  @override
  String get boardLoadMoreFailed =>
      'Couldn\'t load more tasks. Try again later.';

  @override
  String boardMoveTo(String column) {
    return 'Move to $column';
  }

  @override
  String boardMovedTo(String column) {
    return 'Moved to $column';
  }

  @override
  String get boardMoveUp => 'Move up';

  @override
  String get boardMovedUp => 'Moved up';

  @override
  String get boardMoveDown => 'Move down';

  @override
  String get boardMovedDown => 'Moved down';

  @override
  String boardColumnOptionsFor(String column) {
    return 'Options for “$column”';
  }

  @override
  String get boardColumnSaving => 'Saving the column…';

  @override
  String get boardColumnRename => 'Rename';

  @override
  String boardColumnLimit(String limit) {
    return 'Limit: $limit';
  }

  @override
  String get boardColumnLimitNotSet => 'Not set';

  @override
  String get boardDoneColumn => 'Done column';

  @override
  String get boardDoneColumnHintExtended =>
      'All tasks moved into the done column are marked as done automatically. All tasks marked as done elsewhere move there as well.';

  @override
  String get boardDefaultColumn => 'Default column';

  @override
  String get boardDefaultColumnHint =>
      'When creating tasks without specifying a column, they will be added to this column.';

  @override
  String get boardColumnMoveLeft => 'Move left';

  @override
  String get boardColumnMoveRight => 'Move right';

  @override
  String get boardColumnMovedLeft => 'Column moved left';

  @override
  String get boardColumnMovedRight => 'Column moved right';

  @override
  String get boardColumnDelete => 'Delete';

  @override
  String get boardColumnDeleteLast => 'You can\'t delete the last column.';

  @override
  String get boardColumnRenameTitle => 'Rename column';

  @override
  String get boardColumnTitleLabel => 'Title';

  @override
  String get boardColumnTitleHint => 'Enter the new column title…';

  @override
  String get boardColumnTitleEmpty => 'Enter a title.';

  @override
  String get boardColumnSave => 'Save';

  @override
  String get boardNewColumn => 'New column';

  @override
  String get boardNewColumnCreate => 'Create';

  @override
  String get boardCreateColumn => 'Create a column';

  @override
  String get boardColumnLimitTitle => 'Column limit';

  @override
  String get boardColumnLimitLabel => 'Limit';

  @override
  String boardColumnLimitHelp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks are in this column now.',
      one: '1 task is in this column now.',
    );
    return '$_temp0 Leave it empty for no limit.';
  }

  @override
  String get boardColumnLimitBelowCount =>
      'That\'s fewer than it holds now. It takes no new tasks until some move out.';

  @override
  String get boardDeleteColumnTitle => 'Delete the column';

  @override
  String boardDeleteColumnBody(String column) {
    return 'Are you sure you want to delete the column “$column”?';
  }

  @override
  String boardDeleteColumnTasksMove(String column) {
    return 'Its tasks aren\'t deleted but move to “$column”.';
  }

  @override
  String boardDeleteColumnBecomesDefault(String column) {
    return '“$column” becomes the default column.';
  }

  @override
  String get boardDeleteColumnConfirm => 'Delete';

  @override
  String get boardColumnCreated => 'Column created';

  @override
  String get boardColumnRenamed => 'Column renamed';

  @override
  String get boardColumnLimitSaved => 'Column limit saved';

  @override
  String get boardDoneColumnSaved => 'Done column saved';

  @override
  String get boardDefaultColumnSaved => 'Default column saved';

  @override
  String get boardColumnDeleted => 'Column deleted';

  @override
  String get boardColumnNeedsConnection =>
      'Changing columns needs a connection to the server.';

  @override
  String get boardColumnUnconfirmed =>
      'Couldn\'t confirm the change. Check your connection and pull down to refresh the board.';

  @override
  String get boardColumnAdminOnly =>
      'Only project admins can choose the done or default column.';

  @override
  String get boardColumnDeleteAdminOnly =>
      'Only project admins can delete the column new tasks go to while it holds tasks.';

  @override
  String boardColumnDeleteFailedNewDefault(String newDefault, String column) {
    return '“$newDefault” is now the default column; deleting “$column” failed.';
  }

  @override
  String get boardColumnForbidden =>
      'You don\'t have permission to change this board\'s columns.';

  @override
  String get boardColumnLastOne => 'A board needs at least one column.';

  @override
  String get boardColumnArchived =>
      'This project is archived, so its columns can\'t be changed.';

  @override
  String get boardColumnInvalid =>
      'The server didn\'t accept this title or limit.';

  @override
  String boardColumnChangeRefused(String message) {
    return 'The server refused the change: $message';
  }

  @override
  String get boardColumnChangeFailed => 'The change couldn\'t be saved.';

  @override
  String taskSubtaskOfSemantics(String parent) {
    return 'Subtask of $parent';
  }

  @override
  String get linkCannotOpen => 'Can\'t open this link';

  @override
  String get richTextImage => 'Image';

  @override
  String richTextImageFrom(String host) {
    return 'Image from $host';
  }

  @override
  String get richTextImageFailed => 'The image couldn\'t be loaded';

  @override
  String get richTextImageUnsupported => 'This image can\'t be shown here';

  @override
  String get richTextShowImage => 'Show full screen';

  @override
  String get richTextOpensInBrowser => 'Opens in the browser';

  @override
  String richTextReplyTo(String author) {
    return 'Reply to $author';
  }

  @override
  String get imageViewerClose => 'Close image';

  @override
  String get taskDetailDetailsOffline =>
      'Attachments, comments and reactions need a connection';

  @override
  String get taskDetailDetailsFailed =>
      'Attachments, comments and reactions couldn\'t be loaded';

  @override
  String get taskDetailAttachments => 'Attachments';

  @override
  String get taskDetailCoverImage => 'Cover image';

  @override
  String taskDetailComments(int count) {
    return 'Comments ($count)';
  }

  @override
  String get taskDetailShowComments => 'Show comments';

  @override
  String get taskDetailMoreComments => 'Load more comments';

  @override
  String get commentsOldestFirst => 'Oldest first';

  @override
  String get commentsNewestFirst => 'Newest first';

  @override
  String get commentsChangeOrder => 'Change the order';

  @override
  String get commentsLoading => 'Loading comments…';

  @override
  String get commentsNeedConnection => 'Comments need a connection';

  @override
  String get commentsFailed => 'Comments couldn\'t be loaded';

  @override
  String commentEdited(String when) {
    return 'edited $when';
  }

  @override
  String reactionByOne(String user, String reaction) {
    return '$user reacted with $reaction';
  }

  @override
  String reactionBySeveral(String users, String lastUser, String reaction) {
    return '$users and $lastUser reacted with $reaction';
  }

  @override
  String reactionByMany(String users, int count, String reaction) {
    return '$users and $count more reacted with $reaction';
  }

  @override
  String taskDetailCreatedBy(String when, String name) {
    return 'Created $when by $name';
  }

  @override
  String taskDetailCreated(String when) {
    return 'Created $when';
  }

  @override
  String taskDetailUpdated(String when) {
    return 'Updated $when';
  }

  @override
  String taskDetailDoneWhen(String when) {
    return 'Done $when';
  }

  @override
  String get taskDetailOpenProjectHint => 'Opens the project';

  @override
  String get taskOpenNotFound => 'This task wasn\'t found';

  @override
  String get taskOpenForbidden => 'You don\'t have access to this task';

  @override
  String get taskOpenOffline =>
      'This task isn\'t on this device. Connect to open it.';

  @override
  String get taskOpenFailed => 'This task couldn\'t be opened';

  @override
  String get deepLinkPickAccountTitle => 'Open in which account?';

  @override
  String get deepLinkPickAccountBody =>
      'This task is in more than one of your accounts.';

  @override
  String get richTextImageOffline => 'The image needs a connection';

  @override
  String commentsLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments loaded',
      one: '1 comment loaded',
      zero: 'No more comments',
    );
    return '$_temp0';
  }

  @override
  String get taskOpening => 'Opening the task…';

  @override
  String get deepLinkSwitchAccountTitle => 'Switch accounts?';

  @override
  String get deepLinkSwitchAccountBody =>
      'This task is in another of your accounts. Choose it to switch and open the task.';
}
