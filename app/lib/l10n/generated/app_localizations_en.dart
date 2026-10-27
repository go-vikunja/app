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
      'Create your first project to start adding tasks.';

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
  String get appearanceLightDarkHint =>
      'Light or dark is your account\'s colour scheme, in Account settings.';

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
  String get moveUp => 'Move up';

  @override
  String get movedUp => 'Moved up';

  @override
  String get moveDown => 'Move down';

  @override
  String get movedDown => 'Moved down';

  @override
  String projectMoveOut(String project) {
    return 'Move out of $project';
  }

  @override
  String projectMovedOut(String project) {
    return 'Moved out of $project';
  }

  @override
  String projectMoveInto(String project) {
    return 'Move into $project';
  }

  @override
  String projectMovedInto(String project) {
    return 'Moved into $project';
  }

  @override
  String get projectMovedToTopLevel => 'Moved to the top level';

  @override
  String get projectMoveNeedsConnection =>
      'Moving a project needs a connection to the server.';

  @override
  String get projectMoveWait => 'A project is still being moved';

  @override
  String get projectMoveUnconfirmed =>
      'Couldn\'t confirm the move. Check your connection and pull down to refresh.';

  @override
  String get projectMoveAdminOnly =>
      'Only project admins can move a project under another one.';

  @override
  String get projectMoveForbidden =>
      'You don\'t have permission to move this project.';

  @override
  String get projectMoveArchived =>
      'Archived projects can\'t be moved, and nothing can be moved into them.';

  @override
  String get projectMoveNotPossible => 'The project can\'t be moved there.';

  @override
  String get projectMoveGone =>
      'The project or its new parent no longer exists.';

  @override
  String projectMoveRefused(String message) {
    return 'The server refused the move: $message';
  }

  @override
  String get projectMoveFailed => 'The project couldn\'t be moved.';

  @override
  String get projectUnknownTitle => 'Project';

  @override
  String get favouriteLabel => 'Favourite';

  @override
  String get projectTasksLoading => 'Loading tasks…';

  @override
  String get projectTasksEmptyTitle => 'No open tasks';

  @override
  String get projectTasksEmptyBody =>
      'Everything in this project is done. Turn on “Show done” to see them.';

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
  String get syncProblemListNotReorderable => 'This list can\'t be reordered.';

  @override
  String get syncProblemListMissing => 'The list no longer exists.';

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
    return 'These are the $mode prefixes, as set in your account settings.';
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
    return 'Your Overview shows the saved filter “$title”, picked in your account settings. Its tasks download with the next sync.';
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
  String get attachmentAdd => 'Add attachment';

  @override
  String get attachmentSourceFiles => 'Files';

  @override
  String get attachmentSourcePhotos => 'Photos';

  @override
  String get attachmentSourceCamera => 'Take a photo';

  @override
  String attachmentTooLarge(String name, String limit) {
    return '“$name” is too large: attachments can be up to $limit.';
  }

  @override
  String attachmentsQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files will be uploaded',
      one: '1 file will be uploaded',
    );
    return '$_temp0';
  }

  @override
  String attachmentAddFailed(String name) {
    return '“$name” couldn\'t be added.';
  }

  @override
  String get attachmentPickFailed => 'The files couldn\'t be opened.';

  @override
  String get attachmentUploading => 'Uploading…';

  @override
  String get attachmentWaiting => 'Waiting to upload';

  @override
  String get attachmentUploadFailed =>
      'Not uploaded: see Sync problems in the Account tab';

  @override
  String get attachmentUploadTooLarge => 'Not uploaded: too large';

  @override
  String attachmentCancelUpload(String name) {
    return 'Cancel upload of $name';
  }

  @override
  String attachmentOptions(String name) {
    return 'Options for $name';
  }

  @override
  String get attachmentOpen => 'Open';

  @override
  String get attachmentShare => 'Share';

  @override
  String get attachmentSaveToDevice => 'Save to device';

  @override
  String get attachmentMakeCover => 'Make cover';

  @override
  String get attachmentRemoveCover => 'Remove cover';

  @override
  String get attachmentDelete => 'Delete attachment';

  @override
  String get attachmentDeleteTitle => 'Delete attachment';

  @override
  String attachmentDeleteBody(String name) {
    return 'Are you sure you want to delete the attachment $name? This cannot be undone!';
  }

  @override
  String get attachmentDeleteConfirm => 'Delete';

  @override
  String get attachmentDeleted => 'The attachment was deleted.';

  @override
  String get attachmentCoverSet => 'The cover image was changed.';

  @override
  String get attachmentCoverRemoved => 'The cover image was removed.';

  @override
  String get attachmentSaved => 'Saved.';

  @override
  String get attachmentDownloading => 'Downloading…';

  @override
  String get attachmentDeleting => 'Deleting…';

  @override
  String get attachmentSaving => 'Saving…';

  @override
  String attachmentCancelDownload(String name) {
    return 'Cancel download of $name';
  }

  @override
  String get attachmentNoApp => 'No app on this device can open this file.';

  @override
  String get attachmentNeedsConnection =>
      'This needs a connection to the server.';

  @override
  String get attachmentUnconfirmed =>
      'Couldn\'t confirm the change. Check your connection and try again.';

  @override
  String get attachmentForbidden =>
      'You don\'t have permission to change this task\'s attachments.';

  @override
  String get attachmentArchived =>
      'This project is archived, so its attachments can\'t be changed.';

  @override
  String get attachmentGone => 'The attachment no longer exists.';

  @override
  String get attachmentsDisabled =>
      'Attachments are turned off on this server.';

  @override
  String get attachmentFileTooLarge => 'The file is too large for the server.';

  @override
  String attachmentFileTooLargeLimit(String limit) {
    return 'The file is too large: attachments can be up to $limit.';
  }

  @override
  String get attachmentNotSynced => 'This works once the task has been synced.';

  @override
  String attachmentRefused(String message) {
    return 'The server refused it: $message';
  }

  @override
  String get attachmentFailed => 'That didn\'t work. Try again later.';

  @override
  String get editorImage => 'Insert image';

  @override
  String get editorImageUploading => 'Uploading the image…';

  @override
  String get editorImageInserted => 'Image inserted';

  @override
  String get shareSignedOut => 'Sign in to Rurana first, then share again.';

  @override
  String get sharePickAccountTitle => 'Share to which account?';

  @override
  String get sharePickAccountBody =>
      'What you share goes to that account\'s server.';

  @override
  String get shareSheetTitle => 'Share to Rurana';

  @override
  String get shareAddToTask => 'Add to task';

  @override
  String get shareFiles => 'Files';

  @override
  String shareRemoveFile(String name) {
    return 'Remove $name';
  }

  @override
  String get shareFilePreparing => 'Preparing…';

  @override
  String shareFileTooLarge(String limit) {
    return 'Too large: attachments can be up to $limit';
  }

  @override
  String get shareFileUnreadable => 'Couldn\'t be read';

  @override
  String get shareFilesLeftOut =>
      'This server doesn\'t take attachments, so the files are left out.';

  @override
  String shareTooManyFiles(int count) {
    return 'Only the first $count files are added.';
  }

  @override
  String get shareAppendHint =>
      'The text goes at the end of the task\'s description.';

  @override
  String get sharePickTask => 'Choose a task.';

  @override
  String get shareCreate => 'Create task';

  @override
  String get shareAdd => 'Add';

  @override
  String shareTaskCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Task created, $count files will be uploaded',
      one: 'Task created, 1 file will be uploaded',
      zero: 'Task created',
    );
    return '$_temp0';
  }

  @override
  String shareAddedToTask(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added to the task, $count files will be uploaded',
      one: 'Added to the task, 1 file will be uploaded',
      zero: 'Added to the task',
    );
    return '$_temp0';
  }

  @override
  String get shareFailed => 'What was shared couldn\'t be added.';

  @override
  String syncProblemUploadFailed(String name) {
    return '“$name” could not be uploaded.';
  }

  @override
  String get syncProblemUploadTooLarge => 'The file is too large.';

  @override
  String get syncProblemUploadTimedOut =>
      'It timed out several times; try again on a faster connection.';

  @override
  String get syncProblemUploadForbidden =>
      'You may not add attachments to this task.';

  @override
  String get syncProblemAttachmentsDisabled =>
      'Attachments are turned off on the server.';

  @override
  String get syncProblemUploadFileMissing =>
      'The copy kept on this device is gone; discard it.';

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

  @override
  String get projectNew => 'New project';

  @override
  String get projectCreate => 'Create';

  @override
  String get projectCreating => 'Creating…';

  @override
  String get projectCreated => 'Project created';

  @override
  String get projectTitleLabel => 'Title';

  @override
  String get projectTitleHint => 'The project\'s title goes here…';

  @override
  String get projectTitleRequired => 'Please specify a title.';

  @override
  String get projectParentLabel => 'Parent project';

  @override
  String get projectParentTopLevel => 'None (top level)';

  @override
  String get projectEdit => 'Edit';

  @override
  String get projectEditTitle => 'Edit project';

  @override
  String get projectSave => 'Save';

  @override
  String get projectSaving => 'Saving…';

  @override
  String get projectEditSaved => 'Project saved';

  @override
  String get projectEditDiscardBody =>
      'Your edits to this project will be lost.';

  @override
  String get projectIdentifierLabel => 'Project identifier';

  @override
  String get projectIdentifierHelp =>
      'Up to 10 characters, unique on the server. The identifiers of this project\'s tasks start with it and change with it. Leave it empty for none.';

  @override
  String get projectIdentifierTaken =>
      'This identifier is already in use. Identifiers are unique on the whole server.';

  @override
  String get projectGoneTitle => 'This project no longer exists';

  @override
  String get projectGoneBody => 'It may have been deleted, here or on the web.';

  @override
  String get projectViews => 'Views';

  @override
  String get projectDuplicate => 'Duplicate';

  @override
  String get projectDuplicateTitle => 'Duplicate project';

  @override
  String get projectDuplicateBody =>
      'The copy gets this project\'s tasks, views and columns, but not its subprojects. Choose the project it goes into:';

  @override
  String get projectDuplicateShares => 'Also copy its shares';

  @override
  String get projectDuplicateSharesHint =>
      'People, teams and link shares. Each link share becomes a new public link to the copy.';

  @override
  String get projectDuplicating => 'Duplicating…';

  @override
  String get projectDuplicated => 'Project duplicated';

  @override
  String get projectArchive => 'Archive';

  @override
  String get projectUnarchive => 'Unarchive';

  @override
  String get projectArchiveTitle => 'Archive this project?';

  @override
  String get projectUnarchiveTitle => 'Unarchive this project?';

  @override
  String get projectArchiveBody =>
      'You won\'t be able to edit this project or create tasks until you unarchive it. Its subprojects are archived too.';

  @override
  String get projectUnarchiveBody =>
      'You will be able to create tasks or edit it. Its subprojects are unarchived too.';

  @override
  String get projectArchivedDone => 'Project archived';

  @override
  String get projectUnarchivedDone => 'Project unarchived';

  @override
  String get projectArchiveDefaultHint =>
      'You can\'t archive this because it\'s your default project.';

  @override
  String get projectNewSubproject => 'New subproject';

  @override
  String get projectAddToFavourites => 'Add to favourites';

  @override
  String get projectRemoveFromFavourites => 'Remove from favourites';

  @override
  String get projectFavourited => 'Added to favourites';

  @override
  String get projectUnfavourited => 'Removed from favourites';

  @override
  String get projectDelete => 'Delete';

  @override
  String projectDeleteTitle(String project) {
    return 'Delete “$project”?';
  }

  @override
  String projectDeleteTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This deletes $count tasks, for everyone.',
      one: 'This deletes 1 task, for everyone.',
      zero: 'It has no tasks. It is deleted for everyone.',
    );
    return '$_temp0';
  }

  @override
  String projectDeleteTasksAndSubprojects(int tasks, int subprojects) {
    String _temp0 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks tasks',
      one: '1 task',
      zero: 'no tasks',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subprojects,
      locale: localeName,
      other: '$subprojects subprojects',
      one: '1 subproject',
    );
    return 'This deletes $_temp0 and $_temp1, for everyone.';
  }

  @override
  String get projectDeleteCannotBeUndone => 'This can\'t be undone.';

  @override
  String projectIncludesDefault(String project) {
    return 'This includes your default project “$project”.';
  }

  @override
  String get projectDeleted => 'Project deleted';

  @override
  String get projectChangeNeedsConnection =>
      'Managing projects needs a connection to the server.';

  @override
  String get projectChangeUnconfirmed =>
      'Couldn\'t confirm the change. Check your connection and pull down to refresh.';

  @override
  String get projectFormUnconfirmed =>
      'Couldn\'t confirm the change. It may have gone through, so check before trying again.';

  @override
  String get projectChangeForbidden =>
      'You don\'t have permission to change this project.';

  @override
  String get projectCreateForbidden =>
      'You don\'t have permission to add a project there.';

  @override
  String get projectDeleteAdminOnly =>
      'Only project admins can delete a project.';

  @override
  String get projectViewsAdminOnly => 'Only project admins can change views.';

  @override
  String get projectDeleteDefault =>
      'This is a user\'s default project. Only its owner can delete it.';

  @override
  String get projectArchiveDefault =>
      'This is a user\'s default project, so it can\'t be archived.';

  @override
  String get projectUnarchiveParentFirst =>
      'The parent project is archived. Unarchive the parent project first.';

  @override
  String get projectChangeArchived =>
      'This project is archived. Unarchive it to change it.';

  @override
  String get projectParentArchived =>
      'The parent project is archived, so nothing can be added to it.';

  @override
  String get projectGone => 'The project no longer exists.';

  @override
  String get projectChangeInvalid =>
      'The server didn\'t accept this title or identifier.';

  @override
  String get projectTitleTooLong =>
      'A title can be up to 250 characters long, and an emoji can count as several. Shorten this one to save.';

  @override
  String get projectTitleTooLongToChange =>
      'This project\'s title is longer than the server accepts. Shorten it under Edit first.';

  @override
  String projectChangeRefused(String message) {
    return 'The server refused the change: $message';
  }

  @override
  String get projectChangeFailed => 'The change couldn\'t be saved.';

  @override
  String get projectViewNew => 'New view';

  @override
  String get projectViewEditTitle => 'Edit view';

  @override
  String projectViewOptionsFor(String view) {
    return 'Options for $view';
  }

  @override
  String get projectViewDelete => 'Delete';

  @override
  String projectViewDeleteTitle(String view) {
    return 'Delete “$view”?';
  }

  @override
  String get projectViewDeleteBody =>
      'Nobody can use it to look at this project\'s tasks any more. No task is deleted. This can\'t be undone.';

  @override
  String get projectViewLastOne => 'A project needs at least one view.';

  @override
  String get projectViewCreated => 'View created';

  @override
  String get projectViewSaved => 'View saved';

  @override
  String get projectViewDeleted => 'View deleted';

  @override
  String get projectViewKindLabel => 'Kind';

  @override
  String get projectViewShowDone => 'Show done tasks';

  @override
  String get projectViewShowDoneHint =>
      'Off adds “done = false” to the filter, like the web\'s List view.';

  @override
  String projectViewFilterInvalid(String message) {
    return 'This filter isn\'t valid: $message';
  }

  @override
  String get projectViewColumnsLabel => 'Columns';

  @override
  String get projectViewColumnsManual => 'Manual';

  @override
  String get projectViewColumnsFilter => 'From filters';

  @override
  String get projectViewFilterColumnsOnWeb =>
      'The filters of these columns are set up on the web.';

  @override
  String get projectViewGone => 'The view no longer exists.';

  @override
  String get projectViewInvalid => 'The server didn\'t accept this view.';

  @override
  String get projectDeleteEverything =>
      'This deletes its tasks and subprojects, for everyone.';

  @override
  String get filterLabel => 'Filter';

  @override
  String get filterHint => 'done = false && labels in Work';

  @override
  String get filterHelp =>
      'In the web\'s filter syntax, with label and project titles. Suggestions follow what you type.';

  @override
  String filterMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks match on this device',
      one: '1 task matches on this device',
      zero: 'No task matches on this device',
    );
    return '$_temp0';
  }

  @override
  String get filterNotCountable =>
      'The server applies this filter; the app can\'t count it here.';

  @override
  String get filterErrorUnknownField =>
      'A field in this filter doesn\'t exist. Fields are written like dueDate or labels.';

  @override
  String filterErrorUnknownFieldNamed(String field) {
    return '“$field” isn\'t a field. Fields are written like dueDate or labels.';
  }

  @override
  String filterErrorLabelValue(String value) {
    return 'No label is called “$value”.';
  }

  @override
  String filterErrorProjectValue(String value) {
    return 'No project is called “$value”.';
  }

  @override
  String filterErrorFieldValue(String value, String field) {
    return '“$value” isn\'t a valid value for $field.';
  }

  @override
  String get filterErrorOperator =>
      'This filter uses an operator that doesn\'t exist.';

  @override
  String get filterErrorValue =>
      'A value doesn\'t fit its field, or no label or project has that title.';

  @override
  String get filterErrorSyntax =>
      'This filter is incomplete. Join conditions with && or ||, close every bracket, and don\'t put & | ( ) in a value.';

  @override
  String get filterErrorTooComplex =>
      'This filter is too long or nested too deeply.';

  @override
  String get filterErrorInvalid => 'This filter isn\'t valid.';

  @override
  String get filterSuggestions => 'Filter suggestions';

  @override
  String get filterSuggestionAnd => 'and';

  @override
  String get filterSuggestionOr => 'or';

  @override
  String get filterDateNow => 'Now';

  @override
  String get filterDateStartOfToday => 'Start of today';

  @override
  String get filterDateStartOfTomorrow => 'Start of tomorrow';

  @override
  String get filterDateInSevenDays => 'In 7 days';

  @override
  String get filterDateStartOfWeek => 'Start of this week';

  @override
  String get filterDateStartOfNextWeek => 'Start of next week';

  @override
  String get filterDateStartOfMonth => 'Start of this month';

  @override
  String get filterDateSevenDaysAgo => '7 days ago';

  @override
  String get savedFilterNew => 'New saved filter';

  @override
  String get savedFilterEditTitle => 'Edit saved filter';

  @override
  String get savedFilterDescriptionLabel => 'Description';

  @override
  String get savedFilterIncludeNulls =>
      'Include tasks which don\'t have a value set';

  @override
  String get savedFilterIncludeNullsHint =>
      'Also lists tasks that have no value where the filter compares one, such as tasks without a due date.';

  @override
  String get savedFilterFavourite => 'Favourite';

  @override
  String get savedFilterFavouriteHint =>
      'Shows it among the favourites in the Projects tab.';

  @override
  String get savedFilterFilterRequired => 'A saved filter needs a filter.';

  @override
  String get savedFilterCreated => 'Saved filter created';

  @override
  String get savedFilterSaved => 'Saved filter saved';

  @override
  String get savedFilterDeleted => 'Saved filter deleted';

  @override
  String savedFilterDeleteTitle(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get savedFilterDeleteBody =>
      'No task is deleted, only the filter and its views. This can\'t be undone.';

  @override
  String get savedFilterEditDiscardBody =>
      'Your edits to this saved filter will be lost.';

  @override
  String get savedFilterLoading => 'Loading the saved filter…';

  @override
  String get savedFilterLoadFailed => 'The saved filter couldn\'t be loaded.';

  @override
  String get savedFilterChangeNeedsConnection =>
      'Managing saved filters needs a connection to the server.';

  @override
  String get savedFilterChangeForbidden =>
      'Only the person who made this saved filter can change it.';

  @override
  String get savedFilterGone => 'The saved filter no longer exists.';

  @override
  String get savedFilterChangeInvalid =>
      'The server didn\'t accept this saved filter.';

  @override
  String get search => 'Search';

  @override
  String get searchPreparing => 'Preparing the search';

  @override
  String get searchHint => 'Tasks, projects, filters, labels';

  @override
  String get searchTasks => 'Tasks';

  @override
  String get searchProjects => 'Projects';

  @override
  String get searchLabels => 'Labels';

  @override
  String get searchStartTitle => 'Search this device';

  @override
  String get searchStartBody =>
      'Tasks by title, description, #12 or PROJ-12; projects, saved filters and labels by name. Works offline.';

  @override
  String get searchNoResultsTitle => 'Nothing found';

  @override
  String searchNoResultsBody(String query) {
    return 'Nothing on this device matches “$query”.';
  }

  @override
  String searchMoreTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more tasks match. Type more to narrow it down.',
      one: '1 more task matches. Type more to narrow it down.',
    );
    return '$_temp0';
  }

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String get labelTasksEmptyTitle => 'No open tasks';

  @override
  String labelTasksEmptyBody(String label) {
    return 'Open tasks with the label “$label” show here.';
  }

  @override
  String get labelTasksGoneTitle => 'This label is gone';

  @override
  String get labelTasksGoneBody =>
      'It may have been deleted, here or on the web.';

  @override
  String get projectViewEmptyMatchingBody =>
      'No task matches this view\'s filter.';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get descriptionEditorTitle => 'Description';

  @override
  String get descriptionEditorPlaceholder => 'Write a description…';

  @override
  String get descriptionEditorLoading => 'Opening the editor…';

  @override
  String get descriptionEditorFailed => 'The editor could not be opened.';

  @override
  String get descriptionEditorSaved => 'Description saved';

  @override
  String get descriptionEditorSaveFailed =>
      'The description could not be saved. Try again.';

  @override
  String get descriptionEditorLeaveTitle => 'Save the description?';

  @override
  String get descriptionEditorLeaveBody =>
      'Your changes to the description are not saved yet.';

  @override
  String get descriptionEditorChangedTitle =>
      'The description changed meanwhile';

  @override
  String get descriptionEditorChangedBody =>
      'It was changed on the web since you started editing. Overwrite that change with yours, or reload it and lose your edits?';

  @override
  String get descriptionEditorOverwrite => 'Overwrite';

  @override
  String get descriptionEditorReload => 'Reload';

  @override
  String get descriptionEditorStoppedKept =>
      'The editor stopped. Reload it to go on with your changes.';

  @override
  String get descriptionEditorStoppedLost =>
      'The editor stopped, and your latest changes are lost. Reload it to go on.';

  @override
  String get descriptionEditorImage => 'Image (not shown while editing)';

  @override
  String get descriptionEditorRestoreTitle => 'Restore unsaved changes?';

  @override
  String get descriptionEditorRestoreBody =>
      'You left this description with changes that were not saved.';

  @override
  String get descriptionEditorRestore => 'Restore';

  @override
  String get editorToolbar => 'Text formatting';

  @override
  String get editorBold => 'Bold';

  @override
  String get editorItalic => 'Italic';

  @override
  String get editorUnderline => 'Underline';

  @override
  String get editorStrike => 'Strikethrough';

  @override
  String get editorCode => 'Inline code';

  @override
  String get editorTextStyle => 'Text style';

  @override
  String get editorParagraph => 'Paragraph';

  @override
  String editorHeading(int level) {
    return 'Heading $level';
  }

  @override
  String get editorBulletList => 'Bulleted list';

  @override
  String get editorOrderedList => 'Numbered list';

  @override
  String get editorTaskList => 'Checklist';

  @override
  String get editorQuote => 'Quote';

  @override
  String get editorCodeBlock => 'Code block';

  @override
  String get editorLink => 'Link';

  @override
  String get editorTable => 'Table';

  @override
  String get editorInsertTable => 'Insert table';

  @override
  String get editorAddRow => 'Add row';

  @override
  String get editorAddColumn => 'Add column';

  @override
  String get editorDeleteRow => 'Delete row';

  @override
  String get editorDeleteColumn => 'Delete column';

  @override
  String get editorDeleteTable => 'Delete table';

  @override
  String get editorDivider => 'Divider';

  @override
  String get editorUndo => 'Undo';

  @override
  String get editorRedo => 'Redo';

  @override
  String get editorClearFormatting => 'Clear formatting';

  @override
  String get editorLinkAddTitle => 'Add link';

  @override
  String get editorLinkEditTitle => 'Edit link';

  @override
  String get editorLinkAddress => 'Web address';

  @override
  String get editorLinkApply => 'Apply';

  @override
  String get editorLinkRemove => 'Remove link';

  @override
  String get editorMentions => 'People to mention';

  @override
  String get editorMentionsSearching => 'Searching…';

  @override
  String get editorMentionsNone => 'No one found';

  @override
  String get editorMentionsFromDevice =>
      'No connection: people this device knows';

  @override
  String get taskDetailEditDescription => 'Edit description';

  @override
  String get taskDetailAddDescription => 'Add description';

  @override
  String get checklistItemChecked => 'Checked';

  @override
  String get checklistItemUnchecked => 'Unchecked';

  @override
  String get projectEditDescription => 'Description';

  @override
  String get projectEditNoDescription => 'No description';

  @override
  String get syncProblemDescriptionConflict =>
      'The description was changed on the web too.';

  @override
  String get syncProblemKeepMine => 'Keep my version';

  @override
  String get syncProblemUseWebs => 'Use the web version';

  @override
  String editorMentionsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people found',
      one: '1 person found',
    );
    return '$_temp0';
  }

  @override
  String get syncProblemCompare => 'Compare versions';

  @override
  String get syncProblemCompareTitle => 'Which description should stay?';

  @override
  String get syncProblemYourVersion => 'Your version';

  @override
  String get syncProblemWebVersion => 'Web version';

  @override
  String get syncProblemWebTaskGone => 'This task is no longer on the server.';

  @override
  String get syncProblemNoDescription => 'No description';

  @override
  String get accountSettingsEntry => 'Account settings';

  @override
  String get accountSettingsEntrySubtitle =>
      'Name, avatar, colour scheme and preferences, saved on the server for all your devices';

  @override
  String get accountHeaderTapHint => 'open the account settings';

  @override
  String get onThisDeviceHeading => 'On this device';

  @override
  String get onThisDeviceSubtitle =>
      'These settings stay on this device and are not saved to your account.';

  @override
  String get accountSettingsTitle => 'Account settings';

  @override
  String accountSettingsIntro(String host) {
    return 'Saved to your account on $host: they apply on the web and on all your devices.';
  }

  @override
  String get accountSettingsOffline =>
      'Offline: account settings can be changed once the server can be reached again.';

  @override
  String get accountSettingsLoading => 'Loading account settings…';

  @override
  String get accountSettingsSaved => 'Saved';

  @override
  String get accountSettingsSaving => 'Saving';

  @override
  String get accountSettingsProfile => 'Profile';

  @override
  String get accountSettingsName => 'Name';

  @override
  String accountSettingsNameHelp(String username) {
    return 'Shown instead of your username. Leave it empty to show @$username.';
  }

  @override
  String accountSettingsNameManaged(String provider) {
    return 'Your sign-in provider ($provider) sets your name at every sign-in. Change it there.';
  }

  @override
  String get accountSettingsNameSave => 'Save name';

  @override
  String get accountSettingsNameDiscardBody =>
      'The name you typed has not been saved.';

  @override
  String get accountSettingsNameSaved => 'Name saved';

  @override
  String get accountSettingsAvatar => 'Avatar';

  @override
  String get accountSettingsSignIn => 'Password and email';

  @override
  String get accountSettingsWaitingForProfile =>
      'Available once the server has said how you sign in.';

  @override
  String get accountSettingsChangePassword => 'Change password';

  @override
  String get accountSettingsChangePasswordHint =>
      'Opens the web in your browser. Afterwards, sign in here again; changes not sent yet are kept.';

  @override
  String get accountSettingsChangeEmail => 'Change email address';

  @override
  String get accountSettingsOpensWeb => 'Opens the web in your browser';

  @override
  String accountSettingsPendingEmail(String email) {
    return 'Waiting for confirmation of $email';
  }

  @override
  String accountSettingsManagedBySignInNamed(String provider) {
    return 'Managed by your sign-in provider ($provider)';
  }

  @override
  String get accountSettingsWebNotOpened => 'The browser could not be opened.';

  @override
  String get accountSettingsDefaults => 'Defaults';

  @override
  String get accountSettingsDefaultProject => 'Default project';

  @override
  String get accountSettingsDefaultProjectNone => 'None';

  @override
  String get accountSettingsDefaultProjectUnknown =>
      'A project not on this device';

  @override
  String get accountSettingsDefaultProjectInvalid =>
      'Choose a project you can add tasks to that is not archived.';

  @override
  String get accountSettingsDefaultView => 'Default view';

  @override
  String get accountSettingsDefaultViewFirst => 'First view';

  @override
  String get accountSettingsQuickAddMagic => 'Quick Add Magic';

  @override
  String get accountSettingsQuickAddMagicDisabled => 'Off';

  @override
  String get accountSettingsQuickAddMagicVikunja => 'Vikunja';

  @override
  String get accountSettingsQuickAddMagicTodoist => 'Todoist';

  @override
  String get accountSettingsMinimumPriority => 'Priorities shown from';

  @override
  String get accountSettingsOverviewFilter => 'Overview shows';

  @override
  String get accountSettingsOverviewFilterNone => 'All open tasks';

  @override
  String get accountSettingsOverviewFilterUnknown =>
      'A saved filter not on this device';

  @override
  String get accountSettingsWeekStart => 'First day of the week';

  @override
  String get accountSettingsTimeAndLanguage => 'Time and language';

  @override
  String get accountSettingsTimezone => 'Time zone';

  @override
  String get accountSettingsTimezoneServerDefault => 'The server\'s default';

  @override
  String get accountSettingsTimezoneHelp =>
      'For saved filters, emails and reminders sent by the server. The app shows times in this device\'s zone.';

  @override
  String get accountSettingsTimezoneSearch => 'Search time zones';

  @override
  String get accountSettingsTimezoneDevice => 'This device';

  @override
  String get accountSettingsTimezoneSameAsDevice => 'Same time as this device';

  @override
  String get accountSettingsTimezoneAll => 'All time zones';

  @override
  String accountSettingsTimezoneInvalid(String zone) {
    return 'The server does not know the time zone $zone. Choose another one.';
  }

  @override
  String get accountSettingsLanguage => 'Language';

  @override
  String get accountSettingsLanguageHelp =>
      'For emails and the web. The app follows your device\'s language.';

  @override
  String get accountSettingsLanguageNotSet => 'Not set';

  @override
  String get accountSettingsLanguageSearch => 'Search languages';

  @override
  String get accountSettingsDateDisplay => 'Date format';

  @override
  String get accountSettingsDateDisplayDevice => 'As on this device';

  @override
  String get accountSettingsDateDisplayRelative => 'Relative, e.g. in 3 days';

  @override
  String get accountSettingsDateMonthDayYearDashed => 'MM-DD-YYYY';

  @override
  String get accountSettingsDateDayMonthYearDashed => 'DD-MM-YYYY';

  @override
  String get accountSettingsDateYearMonthDayDashed => 'YYYY-MM-DD';

  @override
  String get accountSettingsDateMonthDayYearSlashed => 'MM/DD/YYYY';

  @override
  String get accountSettingsDateDayMonthYearSlashed => 'DD/MM/YYYY';

  @override
  String get accountSettingsDateYearMonthDaySlashed => 'YYYY/MM/DD';

  @override
  String accountSettingsDateExample(String example) {
    return 'Example: $example';
  }

  @override
  String get accountSettingsTimeFormat => 'Time format';

  @override
  String get accountSettingsTimeFormatDevice => 'As on this device';

  @override
  String get accountSettingsTimeFormat12 => '12-hour';

  @override
  String get accountSettingsTimeFormat24 => '24-hour';

  @override
  String get accountSettingsEmailNotifications => 'Email notifications';

  @override
  String get accountSettingsEmailsOff =>
      'This server does not send reminder emails at the moment. The settings are kept for when it does.';

  @override
  String get accountSettingsEmailReminders => 'Task reminders by email';

  @override
  String get accountSettingsEmailRemindersSubtitle =>
      'An email for each reminder, besides this device\'s notifications';

  @override
  String get accountSettingsOverdueReminders => 'Daily overdue summary';

  @override
  String get accountSettingsOverdueRemindersSubtitle =>
      'An email listing your overdue tasks that are not done';

  @override
  String get accountSettingsOverdueTime => 'Time of the summary';

  @override
  String get accountSettingsOverdueTimeInvalid =>
      'The server refused this time.';

  @override
  String get accountSettingsPrivacy => 'Privacy';

  @override
  String get accountSettingsDiscoverableByName => 'Findable by name';

  @override
  String get accountSettingsDiscoverableByNameSubtitle =>
      'Others can add you to teams and projects by searching for your name';

  @override
  String get accountSettingsDiscoverableByEmail => 'Findable by email';

  @override
  String get accountSettingsDiscoverableByEmailSubtitle =>
      'Others can add you to teams and projects by searching for your full email address';

  @override
  String get accountSettingsAppearance => 'Appearance';

  @override
  String get accountSettingsColorScheme => 'Colour scheme';

  @override
  String get accountSettingsColorSchemeLight => 'Light';

  @override
  String get accountSettingsColorSchemeSystem => 'System';

  @override
  String get accountSettingsColorSchemeDark => 'Dark';

  @override
  String get accountSettingsNothingFound => 'Nothing found';

  @override
  String get accountSettingsNeedsConnection =>
      'Changing account settings needs a connection to the server.';

  @override
  String get accountSettingsUnconfirmed =>
      'The change could not be confirmed. Check it again once the connection is back.';

  @override
  String get accountSettingsSignInAgain =>
      'Sign in again to change account settings.';

  @override
  String accountSettingsRefused(String message) {
    return 'The server refused the change: $message';
  }

  @override
  String get accountSettingsInvalid => 'The server refused this value.';

  @override
  String get accountSettingsFailed =>
      'The change could not be saved. Try again later.';

  @override
  String get avatarTitle => 'Avatar';

  @override
  String get avatarCurrent => 'Your avatar';

  @override
  String get avatarProviderDefault => 'Default';

  @override
  String get avatarProviderDefaultSubtitle => 'A plain picture';

  @override
  String get avatarProviderInitials => 'Initials';

  @override
  String get avatarProviderInitialsSubtitle => 'Your initials';

  @override
  String get avatarProviderGravatar => 'Gravatar';

  @override
  String get avatarProviderGravatarSubtitle =>
      'The picture for your email address at gravatar.com';

  @override
  String get avatarProviderMarble => 'Marble';

  @override
  String get avatarProviderMarbleSubtitle =>
      'A colourful pattern made from your username';

  @override
  String get avatarProviderUpload => 'Your photo';

  @override
  String get avatarProviderUploadSubtitle => 'A photo from this device';

  @override
  String get avatarProviderUploadReplace => 'Choose another photo';

  @override
  String get avatarProviderLdap => 'From your directory';

  @override
  String get avatarProviderOpenId => 'From your sign-in provider';

  @override
  String get avatarAppShowsInitials =>
      'This app shows your initials for the default, initials and marble avatars; the web draws them.';

  @override
  String get avatarManagedLdap =>
      'Your avatar comes from your organisation\'s directory (LDAP). Ask your IT team how to change it.';

  @override
  String avatarManagedOpenId(String provider) {
    return 'Your avatar comes from your sign-in provider ($provider). Change it there.';
  }

  @override
  String get avatarChoosePhoto => 'Choose a photo';

  @override
  String get avatarTakePhoto => 'Take a photo';

  @override
  String get avatarChanged => 'Avatar changed';

  @override
  String get avatarUploaded => 'Photo uploaded';

  @override
  String get avatarCropTitle => 'Your new avatar';

  @override
  String get avatarCropHint =>
      'Drag to move the photo and pinch to zoom. The square becomes your avatar.';

  @override
  String get avatarCropUpload => 'Upload';

  @override
  String get avatarUploading => 'Uploading…';

  @override
  String get avatarImageUnusable =>
      'This picture cannot be used. Choose a PNG or JPEG photo.';

  @override
  String get avatarImageTooLarge => 'This picture is too large for the server.';

  @override
  String get avatarPickFailed => 'The photos could not be opened.';

  @override
  String get accountSettingsSecurity => 'Security';

  @override
  String get accountSettingsTotp => 'Two-factor authentication';

  @override
  String get accountSettingsTotpOn => 'On';

  @override
  String get accountSettingsTotpOff => 'Off';

  @override
  String get accountSettingsTotpSetupStarted => 'Setup not finished';

  @override
  String get accountSettingsTotpChecking => 'Checking…';

  @override
  String get accountSettingsTotpUnknown => 'Could not be checked';

  @override
  String get accountSettingsTotpNotOffered => 'Not offered by this server';

  @override
  String get accountSettingsTotpNotAvailable =>
      'Not available for this account';

  @override
  String get accountSettingsTotpNotChecked =>
      'Not checked over an unencrypted connection';

  @override
  String get accountSettingsTotpTurnOnNote =>
      'Opens the web in your browser. Turning it on signs you out everywhere, this app included. Then sign in here again; your browser asks for the code.';

  @override
  String get accountSettingsTotpOnNote =>
      'Opens the web in your browser. Turning it off needs your password.';

  @override
  String get accountSettingsSessions => 'Sessions';

  @override
  String accountSettingsSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signed-in devices and browsers',
      one: '1 signed-in device or browser',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsSessionsHint => 'Where you are signed in';

  @override
  String get accountSettingsIntegrations => 'Integrations';

  @override
  String get accountSettingsApiTokens => 'API tokens';

  @override
  String accountSettingsApiTokensCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens',
      one: '1 token',
      zero: 'No tokens',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsApiTokensHint => 'For scripts and other apps';

  @override
  String get accountSettingsCaldav => 'CalDAV';

  @override
  String get accountSettingsCaldavHint =>
      'Your tasks in calendar and task apps';

  @override
  String get accountSettingsYourData => 'Your data';

  @override
  String get accountSettingsExport => 'Export your data';

  @override
  String accountSettingsExportReady(String date) {
    return 'Ready to download until $date';
  }

  @override
  String get accountSettingsExportNone => 'No export yet';

  @override
  String get accountSettingsExportHint => 'A copy of your projects and tasks';

  @override
  String get accountSettingsDeleteAccount => 'Delete account';

  @override
  String get accountSettingsWebAsksPassword =>
      'The web asks for your password.';

  @override
  String accountDeletionScheduled(String date) {
    return 'Your account will be deleted on $date.';
  }

  @override
  String accountDeletionOverdue(String date) {
    return 'Your account has been due for deletion since $date.';
  }

  @override
  String get accountDeletionCancel => 'Cancel deletion';

  @override
  String accountDeletionScheduledRow(String date) {
    return 'Deletion on $date. Cancel it on the web.';
  }

  @override
  String accountDeletionOverdueRow(String date) {
    return 'Deletion due since $date. Cancel it on the web.';
  }

  @override
  String get accountDeletionDialogTitle => 'Delete your account?';

  @override
  String get accountDeletionDialogPermanent =>
      'Deleting your account is permanent. All projects and tasks you own are deleted with it; what you shared with others passes to them.';

  @override
  String get accountDeletionDialogEmail =>
      'The server emails you a link to confirm. Once you confirm, your account is deleted after three days; until then you can change your mind.';

  @override
  String get accountDeletionDialogNoEmail =>
      'If your server does not send emails, ask its administrator to delete your account.';

  @override
  String get accountDeletionContinue => 'Continue in the browser';

  @override
  String get accountSecurityNeedsConnection =>
      'This needs a connection to the server.';

  @override
  String get accountSecurityUnconfirmed =>
      'The server\'s answer did not arrive. Refresh to see whether it worked.';

  @override
  String get accountSecuritySignInAgain => 'Sign in again first.';

  @override
  String get accountSecurityNotOffered => 'This server does not offer this.';

  @override
  String get accountSecurityRateLimited =>
      'The server is busy. Try again in a minute.';

  @override
  String accountSecurityRefused(String message) {
    return 'The server refused: $message';
  }

  @override
  String get accountSecurityFailed => 'That did not work. Try again later.';

  @override
  String get accountSecurityWorking => 'Working';

  @override
  String accountSecurityCreated(String date) {
    return 'Created $date';
  }

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsIntro =>
      'These devices and browsers are signed in to your account. Ending a session signs that device or browser out; it can take up to 10 minutes.';

  @override
  String get sessionsLoading => 'Loading sessions…';

  @override
  String get sessionsThisDevice => 'This device';

  @override
  String get sessionsThisDeviceHint =>
      'To end this session, sign out of the account in this app.';

  @override
  String sessionsLastActive(String when) {
    return 'Last active $when';
  }

  @override
  String get sessionsLastActiveLabel => 'Last active';

  @override
  String get sessionsSignedIn => 'Signed in';

  @override
  String get sessionsDevice => 'Device';

  @override
  String get sessionsIpAddress => 'IP address';

  @override
  String get sessionsUnknownDevice => 'Unknown device';

  @override
  String sessionsBrowserOn(String browser, String system) {
    return '$browser on $system';
  }

  @override
  String get sessionsDartClient => 'An app without a name';

  @override
  String get sessionsEnd => 'End session';

  @override
  String get sessionsEndTitle => 'End this session?';

  @override
  String sessionsEndBody(String device) {
    return '$device will be signed out. It can take up to 10 minutes.';
  }

  @override
  String get sessionsEnded =>
      'Session ended. It can take up to 10 minutes to take effect.';

  @override
  String get sessionsEndOthers => 'End all other sessions';

  @override
  String get sessionsEndOthersTitle => 'End all other sessions?';

  @override
  String sessionsEndOthersBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count other devices and browsers are signed out',
      one: 'The other device or browser is signed out',
    );
    return '$_temp0 within 10 minutes. This device stays signed in.';
  }

  @override
  String sessionsEndedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sessions ended. It can take up to 10 minutes to take effect.',
      one: '1 session ended. It can take up to 10 minutes to take effect.',
      zero: 'No other session to end.',
    );
    return '$_temp0';
  }

  @override
  String sessionsNotAllEnded(int ended, int notEnded) {
    return 'Ended: $ended. Still signed in: $notEnded.';
  }

  @override
  String get sessionsNoOthers => 'No other sessions';

  @override
  String get sessionsNoOthersBody =>
      'Only this device is signed in to your account.';

  @override
  String sessionsOptionsFor(String device) {
    return 'Options for $device';
  }

  @override
  String get apiTokensTitle => 'API tokens';

  @override
  String get apiTokensIntro =>
      'API tokens let scripts and other apps use Vikunja\'s API without your password. A token can only do what its permissions allow.';

  @override
  String get apiTokensDocs => 'API documentation';

  @override
  String get apiTokensLoading => 'Loading API tokens…';

  @override
  String get apiTokensEmptyTitle => 'No API tokens';

  @override
  String get apiTokensEmptyBody => 'Create one for a script or another app.';

  @override
  String get apiTokensNew => 'New token';

  @override
  String apiTokensExpires(String date) {
    return 'Expires $date';
  }

  @override
  String apiTokensExpired(String when) {
    return 'Expired $when';
  }

  @override
  String apiTokensPermissionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      one: '1 permission',
    );
    return '$_temp0';
  }

  @override
  String get apiTokensPermissions => 'Permissions';

  @override
  String get apiTokensDelete => 'Delete token';

  @override
  String apiTokensDeleteTitle(String title) {
    return 'Delete the token “$title”?';
  }

  @override
  String get apiTokensDeleteBody =>
      'Apps and scripts using it stop working. This cannot be undone.';

  @override
  String get apiTokensDeleted => 'Token deleted';

  @override
  String get apiTokenFormTitle => 'New API token';

  @override
  String get apiTokenFormCreate => 'Create';

  @override
  String get apiTokenFormCreating => 'Creating…';

  @override
  String get apiTokenFormLoading => 'Loading permissions…';

  @override
  String get apiTokenFormName => 'Title';

  @override
  String get apiTokenFormNameHint => 'A title you will recognise later';

  @override
  String get apiTokenFormNameRequired => 'Enter a title.';

  @override
  String get apiTokenFormExpiry => 'Expires';

  @override
  String apiTokenFormExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String get apiTokenFormExpiryCustom => 'Pick a day…';

  @override
  String get apiTokenFormExpiryPick => 'Valid through';

  @override
  String apiTokenFormExpiryThrough(String date) {
    return 'Through $date';
  }

  @override
  String get apiTokenFormExpiryPast => 'Pick a day that has not passed yet.';

  @override
  String get apiTokenFormPermissions => 'Permissions';

  @override
  String get apiTokenFormPermissionsHelp =>
      'Choose what the token may do. The names come from the server and are not translated.';

  @override
  String get apiTokenFormPermissionsRequired =>
      'Choose at least one permission.';

  @override
  String get apiTokenFormNoPermissions =>
      'This server offers no permissions for tokens.';

  @override
  String get apiTokenFormPresets => 'Quick presets';

  @override
  String get apiTokenPresetReadOnly => 'Read only';

  @override
  String get apiTokenPresetTasks => 'Task management';

  @override
  String get apiTokenPresetProjects => 'Project management';

  @override
  String get apiTokenPresetFullAccess => 'Full access';

  @override
  String apiTokenFormGroupSelected(int selected, int total) {
    return '$selected of $total';
  }

  @override
  String apiTokenFormShowGroup(String group) {
    return 'Show the permissions of $group';
  }

  @override
  String apiTokenFormHideGroup(String group) {
    return 'Hide the permissions of $group';
  }

  @override
  String get apiTokenFormDiscardBody => 'The token has not been created.';

  @override
  String get oneTimeSecretApiTitle => 'Your new API token';

  @override
  String get oneTimeSecretCaldavTitle => 'Your new CalDAV token';

  @override
  String get oneTimeSecretLabel => 'The new token';

  @override
  String get oneTimeSecretCopy => 'Copy';

  @override
  String get copiedToClipboard => 'Copied';

  @override
  String get copyToClipboardFailed => 'Copying did not work. Try again.';

  @override
  String get oneTimeSecretOnce =>
      'You won\'t see it again. Store it somewhere safe, such as a password manager.';

  @override
  String get oneTimeSecretApiUsage =>
      'Scripts and apps send it as a bearer token in the Authorization header.';

  @override
  String oneTimeSecretCaldavUsage(String username) {
    return 'Enter it as the password in your CalDAV app, with the username $username.';
  }

  @override
  String get oneTimeSecretDone => 'Done';

  @override
  String get oneTimeSecretLeaveTitle => 'Leave without copying?';

  @override
  String get oneTimeSecretLeaveBody =>
      'The token is shown only now. Without it, you will have to create a new one.';

  @override
  String get oneTimeSecretStay => 'Stay';

  @override
  String get oneTimeSecretLeave => 'Leave';

  @override
  String get caldavTitle => 'CalDAV';

  @override
  String get caldavIntro =>
      'Connect calendar and task apps that speak CalDAV to see and change your tasks there. Enter this address in the app:';

  @override
  String get caldavAddress => 'CalDAV address';

  @override
  String get caldavUsername => 'Username';

  @override
  String get caldavCopyAddress => 'Copy the address';

  @override
  String get caldavCopyUsername => 'Copy the username';

  @override
  String get caldavPasswordOrToken =>
      'As the password, use a CalDAV token or your account password.';

  @override
  String get caldavTokenTotp =>
      'Two-factor authentication is on, so your account password does not work here. Use a CalDAV token as the password.';

  @override
  String caldavTokenProvider(String provider) {
    return 'You sign in through $provider, so use a CalDAV token as the password.';
  }

  @override
  String get caldavTokenUnknown =>
      'Use a CalDAV token as the password. Your account password works too, unless two-factor authentication is on.';

  @override
  String get caldavApiTokenHint =>
      'An API token with the CalDAV permission works as the password too.';

  @override
  String get caldavDocs => 'More about CalDAV in Vikunja';

  @override
  String get caldavTokens => 'CalDAV tokens';

  @override
  String get caldavTokensLoading => 'Loading CalDAV tokens…';

  @override
  String get caldavTokensEmpty => 'No CalDAV tokens yet.';

  @override
  String caldavTokenName(int id) {
    return 'Token $id';
  }

  @override
  String get caldavNewToken => 'New CalDAV token';

  @override
  String caldavDeleteToken(int id) {
    return 'Delete token $id';
  }

  @override
  String caldavDeleteTitle(int id) {
    return 'Delete token $id?';
  }

  @override
  String get caldavDeleteBody =>
      'CalDAV apps using it can no longer sign in. This cannot be undone.';

  @override
  String get caldavDelete => 'Delete';

  @override
  String get caldavTokenDeleted => 'CalDAV token deleted';

  @override
  String get dataExportTitle => 'Export your data';

  @override
  String get dataExportIntro =>
      'The export holds your projects, tasks, comments, attachments and saved filters. You can import it into any Vikunja server.';

  @override
  String get dataExportLoading => 'Looking for an export…';

  @override
  String get dataExportReadyTitle => 'Ready to download';

  @override
  String dataExportReadyBody(String size, String date) {
    return '$size, available until $date';
  }

  @override
  String get dataExportNoneTitle => 'No export yet';

  @override
  String get dataExportNoneBody =>
      'Request one below. An export is kept for seven days.';

  @override
  String get dataExportRequest => 'Request a new export';

  @override
  String get dataExportRequestNote =>
      'Opens the web in your browser. The server emails you when the export is ready, and this page shows it too.';

  @override
  String get dataExportDownload => 'Download';

  @override
  String overviewGreetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String overviewGreetingAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String overviewGreetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String overviewTasksLeftToday(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString tasks left for today',
      one: '1 task left for today',
      zero: 'Nothing left for today',
    );
    return '$_temp0';
  }

  @override
  String upcomingSubtitle(String range, String dates, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString open',
      one: '1 open',
      zero: 'nothing open',
    );
    return '$range, $dates · $_temp0';
  }

  @override
  String upcomingDaySemantics(String day, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString open',
      one: '1 open',
      zero: 'nothing open',
    );
    return '$day, $_temp0';
  }

  @override
  String get upcomingShowDayHint => 'Show only this day';

  @override
  String get upcomingShowRangeHint => 'Show the whole range';

  @override
  String get upcomingNothingPlanned => 'Nothing planned';

  @override
  String get taskDetailMarkDone => 'Mark as done';

  @override
  String get taskDetailMarkNotDone => 'Mark as not done';

  @override
  String get taskDetailStatusOpen => 'Open';

  @override
  String get projectShowDoneChip => 'Show done';

  @override
  String projectProgressDone(int done, int total) {
    return '$done of $total done';
  }

  @override
  String projectProgressSemantics(int done, int total) {
    return 'Project progress: $done of $total tasks done';
  }

  @override
  String get accountHeaderEdit => 'Edit';

  @override
  String get accountServerHeading => 'Server';

  @override
  String accountAppVersion(String version, String build) {
    return 'Rurana $version ($build)';
  }

  @override
  String accountAppVersionWithoutBuild(String version) {
    return 'Rurana $version';
  }

  @override
  String get commentsHeading => 'Comments';

  @override
  String get commentsEmpty => 'No comments yet';

  @override
  String get commentComposerHint => 'Write a comment…';

  @override
  String get commentSend => 'Send comment';

  @override
  String get commentSending => 'Sending the comment…';

  @override
  String get commentPosted => 'Comment sent';

  @override
  String get commentComposerOffline =>
      'Needs a connection. What you wrote stays here.';

  @override
  String commentReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get commentReplyCancel => 'Don\'t reply';

  @override
  String commentOptions(String name) {
    return 'Options for the comment by $name';
  }

  @override
  String get commentReply => 'Reply';

  @override
  String get commentCopyLink => 'Copy link';

  @override
  String get commentLinkCopied => 'Link copied';

  @override
  String get commentEdit => 'Edit';

  @override
  String get commentDelete => 'Delete';

  @override
  String get commentDeleteTitle => 'Delete this comment?';

  @override
  String get commentDeleteBody => 'This can\'t be undone.';

  @override
  String get commentDeleted => 'Comment deleted';

  @override
  String get commentSaved => 'Comment saved';

  @override
  String get commentWorking => 'Saving the change…';

  @override
  String get commentEditorTitle => 'Edit comment';

  @override
  String get commentEmptyRefused => 'A comment can\'t be empty';

  @override
  String get commentsArchivedNote =>
      'This project is archived, so its comments can\'t be changed.';

  @override
  String get commentsReadOnlyNote => 'You can only read this task.';

  @override
  String get commentFailedNotAuthor => 'Only the author can change a comment.';

  @override
  String get commentFailedGone => 'The comment no longer exists.';

  @override
  String get commentFailedNeedsConnection =>
      'This needs a connection to the server.';

  @override
  String get commentFailedTooLong => 'This comment is too long.';

  @override
  String get commentFailedUnconfirmed =>
      'The server didn\'t answer. Check the comments before sending again.';

  @override
  String get commentFailedSend =>
      'The comment couldn\'t be sent. Try again later.';

  @override
  String get commentFailedSave =>
      'The comment couldn\'t be saved. Try again later.';

  @override
  String get commentFailedDelete =>
      'The comment couldn\'t be deleted. Try again later.';

  @override
  String get reactionAdd => 'Add reaction';

  @override
  String get reactionOther => 'Another emoji';

  @override
  String get reactionOtherHint => 'Type an emoji';

  @override
  String get reactionOtherAdd => 'Add';

  @override
  String get reactionTooLong => 'At most 20 characters';

  @override
  String get reactionAddMine => 'add your reaction';

  @override
  String get reactionRemoveMine => 'remove your reaction';

  @override
  String get reactionFailed =>
      'The reaction couldn\'t be saved. Try again later.';

  @override
  String taskCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
    );
    return '$_temp0';
  }

  @override
  String taskCommentCountUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments, unread',
      one: '1 comment, unread',
    );
    return '$_temp0';
  }

  @override
  String get commentReplyDropped => 'No longer replying';

  @override
  String get shareMenuItem => 'Share';

  @override
  String sharePageTitle(String project) {
    return 'Share $project';
  }

  @override
  String get sharePageLoading => 'Loading who has access…';

  @override
  String get sharePeopleSection => 'People';

  @override
  String get shareTeamsSection => 'Teams';

  @override
  String get shareLinksSection => 'Links';

  @override
  String get sharePeopleEmpty => 'Not shared with anyone yet';

  @override
  String get shareTeamsEmpty => 'Not shared with any team yet';

  @override
  String get shareLinksEmpty => 'No links yet';

  @override
  String get shareLinksIntro =>
      'Anyone with a link can open this project without an account, with the link\'s permission.';

  @override
  String shareUserIsYou(String name) {
    return '$name (you)';
  }

  @override
  String get sharePermissionRead => 'Read only';

  @override
  String get sharePermissionWrite => 'Read & write';

  @override
  String get sharePermissionAdmin => 'Admin';

  @override
  String get shareAddPerson => 'Add person';

  @override
  String get shareAddTeam => 'Add team';

  @override
  String get shareHiddenTeam => 'Hidden team';

  @override
  String shareTeamMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get shareReadOnlyNote =>
      'Only project admins can change who has access';

  @override
  String shareAccessFor(String name) {
    return 'Access for $name';
  }

  @override
  String sharePermissionFor(String name) {
    return 'Permission for $name';
  }

  @override
  String get shareRemove => 'Remove';

  @override
  String shareRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String shareRemovePersonBody(String name) {
    return '$name loses access to this project and the projects under it at once.';
  }

  @override
  String get shareRemoveSelfBody =>
      'You lose access to this project and the projects under it at once, unless you have it in another way.';

  @override
  String shareRemoveTeamBody(String name) {
    return 'The members of $name lose access to this project and the projects under it at once, unless they have it in another way.';
  }

  @override
  String get shareCleanupOthersIntro =>
      'In the projects they can no longer reach, the server also deletes:';

  @override
  String get shareCleanupOthersAssignments => 'their task assignments';

  @override
  String get shareCleanupOthersSubscriptions =>
      'their subscriptions to tasks and projects';

  @override
  String get shareCleanupOthersWebhooks => 'webhooks they created';

  @override
  String get shareCleanupSelfIntro =>
      'In the projects you can no longer reach, the server also deletes:';

  @override
  String get shareCleanupSelfAssignments => 'your task assignments';

  @override
  String get shareCleanupSelfSubscriptions =>
      'your subscriptions to tasks and projects';

  @override
  String get shareCleanupSelfWebhooks => 'webhooks you created';

  @override
  String shareAdded(String name) {
    return '$name has access now';
  }

  @override
  String sharePermissionChanged(String name) {
    return 'Access for $name changed';
  }

  @override
  String shareRemoved(String name) {
    return '$name removed';
  }

  @override
  String get shareSaving => 'Saving…';

  @override
  String get sharePeopleSearchField => 'Username, name or email';

  @override
  String get sharePeopleSearchHint =>
      'Search by exact username, or by name or email if the person allows it';

  @override
  String get sharePeopleSearching => 'Searching…';

  @override
  String get sharePeopleNoResults => 'Nobody found who could be added';

  @override
  String get sharePeopleSearchOffline =>
      'Searching for people needs a connection.';

  @override
  String get sharePeopleSearchFailed => 'Searching did not work. Try again.';

  @override
  String get shareTeamsFilter => 'Filter teams';

  @override
  String get shareTeamsLoading => 'Loading teams…';

  @override
  String get shareTeamsNoneToAdd =>
      'No other team to add. You can add the teams you are a member of.';

  @override
  String get shareTeamsNoneToAddPublic =>
      'No other team to add. You can add the teams you are a member of and public teams.';

  @override
  String get shareTeamPublic => 'Public';

  @override
  String get linkShareUnnamed => 'Link without a name';

  @override
  String get linkSharePasswordProtected => 'Password protected';

  @override
  String linkShareCreatedBy(String name) {
    return 'Created by $name';
  }

  @override
  String get linkShareShare => 'Share';

  @override
  String get linkShareCopy => 'Copy link';

  @override
  String get linkShareCopied => 'Link copied';

  @override
  String get linkShareQr => 'QR code';

  @override
  String linkShareView(String view) {
    return 'Opens $view';
  }

  @override
  String get linkShareViewTitle => 'The link opens';

  @override
  String get linkShareDelete => 'Delete';

  @override
  String linkShareDeleteTitle(String name) {
    return 'Delete the link “$name”?';
  }

  @override
  String get linkShareDeleteUnnamedTitle => 'Delete this link?';

  @override
  String get linkShareDeleteBody =>
      'Anyone using this link loses access at once. This can\'t be undone.';

  @override
  String get linkShareDeleted => 'Link deleted';

  @override
  String linkShareSubject(String project) {
    return 'Link to $project';
  }

  @override
  String get linkShareCreate => 'Create link';

  @override
  String get linkShareFormTitle => 'New link';

  @override
  String get linkShareFormPermission => 'Permission';

  @override
  String get linkShareFormName => 'Name (optional)';

  @override
  String get linkShareFormNameHelper =>
      'Changes made through the link show this name';

  @override
  String get linkShareFormPassword => 'Password (optional)';

  @override
  String get linkShareFormPasswordHelper =>
      'Whoever opens the link has to enter it';

  @override
  String get linkShareFormShowPassword => 'Show password';

  @override
  String get linkShareFormHidePassword => 'Hide password';

  @override
  String get linkShareFormSubmit => 'Create';

  @override
  String get linkShareCreated => 'Link created';

  @override
  String get linkShareCreatedBody =>
      'Share it with the people who should open this project.';

  @override
  String get linkShareQrSemantics => 'QR code for the link';

  @override
  String get linkShareQrTooLong => 'This link is too long for a QR code';

  @override
  String get linkShareQrHint =>
      'Scan it with a phone\'s camera to open the project.';

  @override
  String get shareFailureOffline => 'This needs a connection.';

  @override
  String get shareFailureUnconfirmed =>
      'The server did not answer in time. Check the list before trying again.';

  @override
  String get shareFailureForbidden =>
      'Only project admins can change who has access.';

  @override
  String get shareFailureAlreadyShared =>
      'This person already has access or owns the project.';

  @override
  String get shareFailureUnknownUser => 'There is no user with this username.';

  @override
  String get shareFailureGone => 'This access was already removed.';

  @override
  String get shareFailureTeamAlreadyShared => 'This team already has access.';

  @override
  String get shareFailureUnknownTeam => 'This team no longer exists.';

  @override
  String get shareFailureLinkSharingOff =>
      'Link sharing is turned off on this server.';

  @override
  String get shareFailureInvalid => 'The server did not accept this.';

  @override
  String get shareFailureGeneric => 'That did not work. Try again.';

  @override
  String get shareReadOnlyProjectNote =>
      'Read only: you can see this project but not change it.';

  @override
  String get shareTaskReadOnly => 'Read only';

  @override
  String get accountOrganiseHeading => 'Organise';

  @override
  String get accountLabelsEntry => 'Labels';

  @override
  String get accountTeamsEntry => 'Teams';

  @override
  String labelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count labels',
      one: '1 label',
    );
    return '$_temp0';
  }

  @override
  String get labelsTitle => 'Labels';

  @override
  String get labelsLoading => 'Loading labels…';

  @override
  String get labelsOwnSection => 'Your labels';

  @override
  String get labelsOthersSection => 'From others';

  @override
  String labelsCreatedBy(String name) {
    return 'By $name';
  }

  @override
  String labelsOptionsFor(String label) {
    return 'Options for $label';
  }

  @override
  String get labelsEdit => 'Edit';

  @override
  String get labelsDelete => 'Delete';

  @override
  String get labelsSearch => 'Search labels';

  @override
  String labelsSearchEmpty(String query) {
    return 'No label matches “$query”.';
  }

  @override
  String get labelsNew => 'New label';

  @override
  String get labelsNewOffline =>
      'Creating a label needs a connection to the server.';

  @override
  String get labelsEmptyTitle => 'No labels yet';

  @override
  String get labelsEmptyBody =>
      'Labels mark tasks across all projects. Create one here or while editing a task.';

  @override
  String labelsShowTasks(String title) {
    return 'Show tasks with label $title';
  }

  @override
  String labelsDeleteTitle(String title) {
    return 'Delete label “$title”?';
  }

  @override
  String get labelsDeleteBody =>
      'It is removed from every task that has it. This can\'t be undone.';

  @override
  String get labelsDeleted => 'Label deleted';

  @override
  String get labelsEditTitle => 'Edit label';

  @override
  String get labelsTitleLabel => 'Title';

  @override
  String get labelsTitleRequired => 'Please specify a title.';

  @override
  String labelsTitleRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters left',
      one: '1 character left',
    );
    return '$_temp0';
  }

  @override
  String get labelsColour => 'Colour';

  @override
  String get labelsCustomColour => 'Custom colour';

  @override
  String get labelsCustomColourHelper => 'Six hex digits, like 1973ff';

  @override
  String get labelsCustomColourInvalid => 'Enter three or six hex digits.';

  @override
  String get labelsDescription => 'Description';

  @override
  String get labelsNoDescription => 'No description';

  @override
  String get labelsEditDescription => 'Edit description';

  @override
  String get labelsAddDescription => 'Add description';

  @override
  String get labelsDescriptionAfterCreate =>
      'You can add a description once the label exists.';

  @override
  String get labelsDescriptionCreatorOnly =>
      'Only the person who created this label can change it.';

  @override
  String get labelsCreate => 'Create';

  @override
  String get labelsSave => 'Save';

  @override
  String get labelsSaving => 'Saving…';

  @override
  String get labelsCreated => 'Label created';

  @override
  String get labelsSaved => 'Label saved';

  @override
  String get labelsDiscardBody => 'Your edits to this label will be lost.';

  @override
  String get labelsGoneTitle => 'This label no longer exists';

  @override
  String get labelsGoneBody => 'It may have been deleted, here or on the web.';

  @override
  String get labelsNeedsConnection =>
      'Changing a label needs a connection to the server.';

  @override
  String get labelsUnconfirmed =>
      'Couldn\'t confirm the change. Check your connection and pull down to refresh.';

  @override
  String get labelsNotCreator =>
      'Only the person who created this label can change it.';

  @override
  String get labelsGone => 'This label no longer exists.';

  @override
  String get labelsInvalid =>
      'The server did not accept this label. Check its title and colour.';

  @override
  String labelsRefused(String message) {
    return 'The server refused: $message';
  }

  @override
  String get labelsFailed => 'The label could not be changed.';

  @override
  String get teamsTitle => 'Teams';

  @override
  String get teamsLoading => 'Loading teams…';

  @override
  String get teamsEmptyTitle => 'No teams yet';

  @override
  String get teamsEmptyBody =>
      'With a team you share projects with several people at once.';

  @override
  String get teamsNew => 'New team';

  @override
  String get teamsNewOffline =>
      'Creating a team needs a connection to the server.';

  @override
  String teamMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get teamAdminBadge => 'Admin';

  @override
  String get teamPublicBadge => 'Public';

  @override
  String teamManagedBy(String provider) {
    return 'Managed by $provider';
  }

  @override
  String get teamManagedExternally => 'Managed externally';

  @override
  String get teamNewTitle => 'New team';

  @override
  String get teamNameLabel => 'Name';

  @override
  String get teamNameRequired => 'Please specify a name.';

  @override
  String get teamPublicLabel => 'Public team';

  @override
  String get teamPublicHelp =>
      'Everyone on this server can find it and share projects with it.';

  @override
  String get teamCreate => 'Create';

  @override
  String get teamCreating => 'Creating the team…';

  @override
  String get teamCreated => 'Team created';

  @override
  String get teamLoading => 'Loading the team…';

  @override
  String get teamGoneTitle => 'This team is not available';

  @override
  String get teamGoneBody =>
      'It may have been deleted, or you are no longer a member.';

  @override
  String get teamEdit => 'Edit team';

  @override
  String get teamEditDescription => 'Edit description';

  @override
  String get teamAddDescription => 'Add description';

  @override
  String get teamSave => 'Save';

  @override
  String get teamSaving => 'Saving…';

  @override
  String get teamSaved => 'Team saved';

  @override
  String teamExternalNote(String provider) {
    return 'This team is managed by $provider. Its members change there.';
  }

  @override
  String get teamExternalNoteGeneric =>
      'This team is managed by your organisation\'s sign-in. Its members change there.';

  @override
  String get teamMembersSection => 'Members';

  @override
  String teamMemberYou(String name) {
    return '$name (you)';
  }

  @override
  String get teamRoleAdmin => 'Admin';

  @override
  String get teamRoleMember => 'Member';

  @override
  String teamMemberOptionsFor(String name) {
    return 'Options for $name';
  }

  @override
  String get teamMakeAdmin => 'Make admin';

  @override
  String get teamMakeMember => 'Make member';

  @override
  String get teamRemoveMember => 'Remove from team';

  @override
  String teamMadeAdmin(String name) {
    return '$name is an admin now';
  }

  @override
  String teamMadeMember(String name) {
    return '$name is a member now';
  }

  @override
  String get teamAddMember => 'Add member';

  @override
  String teamMemberAdded(String name) {
    return '$name added to the team';
  }

  @override
  String teamMemberRemoved(String name) {
    return '$name removed from the team';
  }

  @override
  String teamRemoveTitle(String name) {
    return 'Remove $name from the team?';
  }

  @override
  String teamRemoveBody(String name) {
    return '$name loses access to every project shared with this team.';
  }

  @override
  String get teamRemoveConfirm => 'Remove';

  @override
  String get teamLeave => 'Leave team';

  @override
  String teamLeaveTitle(String team) {
    return 'Leave “$team”?';
  }

  @override
  String get teamLeaveBody =>
      'You lose access to every project shared with this team. A team admin would have to add you again.';

  @override
  String get teamLeaveConfirm => 'Leave';

  @override
  String get teamLeft => 'You left the team';

  @override
  String get teamOnlyAdminTitle => 'Make someone else admin first';

  @override
  String get teamOnlyAdminBody =>
      'Nobody but you is an admin of this team. Without an admin, nobody could change it any more.';

  @override
  String get teamLastMemberTitle => 'You are the last member';

  @override
  String get teamLastMemberBody =>
      'The last member can\'t leave a team. Delete the team instead?';

  @override
  String get teamDelete => 'Delete team';

  @override
  String teamDeleteTitle(String team) {
    return 'Delete “$team”?';
  }

  @override
  String get teamDeleteBody =>
      'All members lose access to every project shared with this team. This can\'t be undone.';

  @override
  String get teamDeleted => 'Team deleted';

  @override
  String get teamAddMemberOffline =>
      'Adding members needs a connection to the server.';

  @override
  String get teamNeedsConnection =>
      'Changing a team needs a connection to the server.';

  @override
  String get teamUnconfirmed =>
      'Couldn\'t confirm the change. Check your connection and pull down to refresh.';

  @override
  String get teamForbidden => 'Only team admins can do this.';

  @override
  String get teamAlreadyMember =>
      'This person is already a member of the team.';

  @override
  String get teamLastMemberRefused =>
      'The last member can\'t leave a team. Delete the team instead.';

  @override
  String get teamExternalRefused =>
      'Members can\'t be removed from a team managed by your organisation\'s sign-in.';

  @override
  String get teamUnknownUser => 'There is no such user on this server.';

  @override
  String get teamNotMember => 'This person is no longer in the team.';

  @override
  String get teamInvalid =>
      'The server did not accept this. A name needs 1 to 250 characters.';

  @override
  String get teamGone =>
      'This team no longer exists, or you are no longer in it.';

  @override
  String teamRefused(String message) {
    return 'The server refused: $message';
  }

  @override
  String get teamFailed => 'That didn\'t work. Try again.';

  @override
  String get teamOk => 'OK';

  @override
  String get shareLowerOwnAccessTitle => 'Lower your own access?';

  @override
  String get shareLowerOwnAccessAdminBody =>
      'You may no longer be able to change who has access to this project, nor undo this yourself.';

  @override
  String get shareLowerOwnAccessWriteBody =>
      'You may no longer be able to change this project or its tasks.';

  @override
  String get shareLowerOwnAccessConfirm => 'Lower access';

  @override
  String get shareRemovedSelf => 'You removed yourself';

  @override
  String get shareNoAccessTitle => 'You no longer have access to this project';

  @override
  String get shareNoAccessBody =>
      'It is gone from this device. Someone with access can share it with you again.';

  @override
  String get shareChangeAccessHint => 'change access';

  @override
  String get linkShareRowHint => 'share, copy or delete the link';

  @override
  String linkShareShareNamed(String name) {
    return 'Share $name';
  }

  @override
  String get projectTimelineRangeTitle => 'Date range';

  @override
  String projectTimelineRangeCurrent(String dates) {
    return 'Date range: $dates';
  }

  @override
  String get projectTimelineRangeDefault => 'Default (15 days back, 55 ahead)';

  @override
  String get projectTimelineRangeCustom => 'Custom range…';

  @override
  String get projectTimelineReset => 'Reset to defaults';

  @override
  String get projectTimelineZoomIn => 'Zoom in';

  @override
  String get projectTimelineZoomOut => 'Zoom out';

  @override
  String get projectTimelineGoToToday => 'Go to today';

  @override
  String projectTimelineSpanSemantics(String from, String to) {
    return '$from to $to';
  }

  @override
  String projectTimelineStartOnlySemantics(String date) {
    return 'starts $date, open end';
  }

  @override
  String projectTimelineEndOnlySemantics(String date) {
    return 'ends $date, open start';
  }

  @override
  String projectTimelineDueOnlySemantics(String date) {
    return 'due $date, open start';
  }

  @override
  String get projectTimelineEstimatedSemantics => 'no dates, estimated';

  @override
  String get projectTimelineDerivedSemantics => 'dates from its subtasks';

  @override
  String projectTimelineExpand(String title) {
    return 'Show subtasks of $title';
  }

  @override
  String projectTimelineCollapse(String title) {
    return 'Hide subtasks of $title';
  }

  @override
  String projectTimelineEmptyTitle(String from, String to) {
    return 'No tasks between $from and $to';
  }

  @override
  String get projectTimelineEmptyBody =>
      'Choose another date range or show tasks without dates.';

  @override
  String get projectTimelineEmptyRangeBody => 'Choose another date range.';

  @override
  String get projectTableColumns => 'Columns';

  @override
  String get projectTableColumnsHint =>
      'Choose what each row shows. The choice applies to every table view.';

  @override
  String get projectTableColumnsReset => 'Default columns';

  @override
  String get projectTableColumnTitleAlways => 'Every row shows it';

  @override
  String get projectTableColumnNumber => 'Number';

  @override
  String get projectTableColumnComments => 'Comments';

  @override
  String get projectTableColumnDoneAt => 'Done at';

  @override
  String get projectTableColumnCreated => 'Created';

  @override
  String get projectTableColumnUpdated => 'Updated';

  @override
  String get projectTableColumnCreatedBy => 'Created by';

  @override
  String get projectTableSortDefault => 'Default (Highest number first)';

  @override
  String get projectTableSortNumberDesc => 'Number (Highest first)';

  @override
  String get projectTableSortNumberAsc => 'Number (Lowest first)';

  @override
  String get projectTableSortDoneAsc => 'Done (Open first)';

  @override
  String get projectTableSortDoneDesc => 'Done (Done first)';

  @override
  String get projectTableSortDoneAtDesc => 'Done at (Newest first)';

  @override
  String get projectTableSortDoneAtAsc => 'Done at (Oldest first)';

  @override
  String projectTableStartsSemantics(String when) {
    return 'Starts $when';
  }

  @override
  String projectTableEndsSemantics(String when) {
    return 'Ends $when';
  }

  @override
  String projectTableCreatedBySemantics(String name) {
    return 'Created by $name';
  }

  @override
  String projectTableCellPercent(int percent) {
    return '$percent%';
  }

  @override
  String projectViewsIntro(String project) {
    return 'The views of $project, in the order the app and the web show them.';
  }

  @override
  String get projectTimelineShowUndated => 'Show undated';

  @override
  String get overviewCreateAccount => 'Create account';

  @override
  String get overviewCreateAccountHint =>
      'On the sign-in page, choose Create account. You come back here afterwards.';

  @override
  String get overviewForgotPassword => 'Forgot password?';

  @override
  String get overviewRegistrationNeedsInvitation =>
      'Registration needs an invitation.';

  @override
  String get overviewSignInPageOffersBoth =>
      'The sign-in page also lets you create an account and reset your password.';

  @override
  String get overviewSignInPageOffersRegistration =>
      'The sign-in page also lets you create an account.';

  @override
  String get overviewSignInPageOffersPasswordReset =>
      'The sign-in page also lets you reset your password.';

  @override
  String get overviewDemoNote =>
      'This is a demo server. Its data may be deleted at any time.';

  @override
  String guestAccountSubtitle(String host) {
    return 'Guest · $host';
  }

  @override
  String get guestOpenLinkAgain => 'Open the link again';

  @override
  String get guestReauthTitle => 'Guest access ended';

  @override
  String guestReauthBody(String host) {
    return '$host ended this guest access. Open the shared link again to keep the project in sync: a link with a password asks for it, and a deleted link needs a new one from whoever shared it. Nothing on this device is lost.';
  }

  @override
  String guestSwitcherButton(String name, String host) {
    return 'Accounts, guest in $name on $host';
  }

  @override
  String guestNotePermission(String permission) {
    return 'Shared link: $permission';
  }

  @override
  String get guestNoteCanView =>
      'You can view this project\'s tasks, comments and attachments.';

  @override
  String get guestNoteCanChange =>
      'You can view and change this project\'s tasks, comment and add attachments.';

  @override
  String get guestNoteNeedsAccount =>
      'Account settings, labels, teams, favourites, reactions and the server\'s notifications need an account of your own.';

  @override
  String get guestRemove => 'Remove guest access';

  @override
  String get guestRemoveDialogTitle => 'Remove guest access?';

  @override
  String guestRemoveDialogBody(String name, String host) {
    return 'Rurana will remove the guest access to $name on $host and delete its tasks saved on this device. You can open the shared link again at any time.';
  }

  @override
  String guestRemoveDialogPendingChangesOpenLinkFirst(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes have not been sent to the server yet and will be lost; switch to this guest access, open the link again and tap Send now first to keep them.',
      one: 'One change has not been sent to the server yet and will be lost; switch to this guest access, open the link again and tap Send now first to keep it.',
    );
    return '$_temp0';
  }

  @override
  String guestRemoved(String name) {
    return 'Guest access to $name removed';
  }

  @override
  String get guestOpenSharedLink => 'Open a shared link';

  @override
  String get guestLinkExplanation =>
      'Got a link to a project someone shared? Open it here as a guest, without an account of your own.';

  @override
  String get guestLinkLabel => 'Shared link';

  @override
  String get guestLinkHint => 'https://vikunja.example.com/share/…/auth';

  @override
  String get guestLinkPaste => 'Paste';

  @override
  String get guestLinkOpen => 'Open';

  @override
  String get guestLinkInvalid =>
      'This isn\'t a link to a shared project. Such a link ends in /share/…/auth.';

  @override
  String get guestLinkClipboardEmpty => 'There\'s no text on the clipboard.';

  @override
  String guestConnectingTo(String link) {
    return 'Opening the shared link $link …';
  }

  @override
  String get guestPasswordTitle => 'Password needed';

  @override
  String get guestPasswordBody =>
      'This shared project is protected by a password. Enter the one you got with the link.';

  @override
  String get guestPasswordLabel => 'Password';

  @override
  String get guestPasswordWrong => 'Wrong password. Check it and try again.';

  @override
  String get guestPasswordNotStored =>
      'Rurana doesn\'t save this password. If the link has to be opened again later, it asks for it again.';

  @override
  String get guestShareTitle => 'Open the shared project?';

  @override
  String guestShareBody(String host) {
    return 'This is a link to a project on $host. Open it as a guest, without an account of your own.';
  }

  @override
  String get guestShareOpen => 'Open as guest';

  @override
  String get guestShareNewTask => 'Make it a new task instead';

  @override
  String get guestLinkGoneTitle => 'This link doesn\'t work';

  @override
  String guestLinkGoneExplanation(String host) {
    return '$host doesn\'t accept this shared link. It was deleted or is incomplete, or the server no longer allows shared links.';
  }

  @override
  String get guestLinkGoneSuggestion =>
      'Ask whoever shared the project for a new link.';

  @override
  String inviteConnectingTo(String host) {
    return 'Checking the invitation to $host …';
  }

  @override
  String inviteHeading(String host) {
    return 'Invitation to $host';
  }

  @override
  String inviteTeams(String teams) {
    return 'You\'ll join: $teams';
  }

  @override
  String get inviteNoEmailConfirmation =>
      'Your account works right away, without confirming your email address.';

  @override
  String get inviteEmailConfirmation =>
      'You may have to confirm your email address before you can sign in.';

  @override
  String get inviteSteps =>
      'Create your account in the browser, then come back here and continue to sign-in.';

  @override
  String get inviteCreateAccount => 'Create account in the browser';

  @override
  String get inviteUnchecked =>
      'This server can\'t check invitations from the app. Open the invitation in the browser to create your account.';

  @override
  String get inviteCheckFailed =>
      'The invitation couldn\'t be checked just now. You can still open it in the browser.';

  @override
  String get inviteInvalidTitle => 'Invitation not valid';

  @override
  String get inviteInvalidExplanation =>
      'This invitation is invalid, expired or used up.';

  @override
  String get inviteInvalidSuggestion =>
      'Ask whoever invited you for a new link. With an account of your own, enter the server\'s address instead.';

  @override
  String get guestLabelPickerNote =>
      'A shared link can\'t create labels; only the labels already used in this project can be added.';

  @override
  String guestSharingOffExplanation(String host) {
    return '$host doesn\'t allow opening projects through shared links.';
  }

  @override
  String get guestSharingOffSuggestion =>
      'Ask whoever shared the project to share it with an account of yours instead.';

  @override
  String get guestServerNeededTitle => 'Which server is it?';

  @override
  String guestServerNeededExplanation(String host) {
    return 'The link points to $host, but no Vikunja server answers there. The server may have an address of its own.';
  }

  @override
  String get guestServerNeededSuggestion =>
      'Enter the server\'s address above and tap Continue to open the link.';

  @override
  String get guestAlreadyAdded =>
      'This shared project was already on this device. Switched to it.';

  @override
  String guestAccessEndedNotificationTitle(String name) {
    return 'Guest access to $name ended';
  }

  @override
  String guestAccessEndedNotificationBody(String host) {
    return '$host ended this guest access. Rurana can\'t sync the project until you open the shared link again.';
  }

  @override
  String guestDataFailureAccessEnded(String host) {
    return 'Your guest access on $host has ended. Open the link again on the Account tab.';
  }

  @override
  String get overviewGreetingMorningGuest => 'Good morning';

  @override
  String get overviewGreetingAfternoonGuest => 'Good afternoon';

  @override
  String get overviewGreetingEveningGuest => 'Good evening';

  @override
  String widgetDueAt(String day, String time) {
    return '$day, $time';
  }

  @override
  String widgetMoreTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String widgetTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
      zero: 'No tasks',
    );
    return '$_temp0';
  }

  @override
  String widgetMarkDone(String title) {
    return 'Mark “$title” done';
  }

  @override
  String widgetUpcomingTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Next $days days',
      one: 'Next day',
    );
    return '$_temp0';
  }

  @override
  String get widgetAccountRemovedTitle => 'Account removed';

  @override
  String get widgetChooseAnotherList => 'Choose another list for this widget.';

  @override
  String get widgetTodayEmptyBody => 'Nothing is due today.';

  @override
  String get widgetOverdueEmptyTitle => 'Nothing overdue';

  @override
  String widgetAccountSubtitle(String name, String host) {
    return '$name · $host';
  }

  @override
  String get widgetsTitle => 'Home-screen widgets';

  @override
  String get widgetsEntrySubtitle =>
      'Your tasks on the home screen, ticked off right there';

  @override
  String get widgetsIntro =>
      'A widget shows one list of an account: today\'s tasks, the next days, the overdue ones, your favourites, a project, a label or a saved filter. Tick a task off right there, or tap it to open it here.';

  @override
  String get widgetsHowToHeading => 'How to add one';

  @override
  String get widgetsHowToIos =>
      'Touch and hold an empty spot on your Home Screen, tap Edit, then Add Widget, and look for Rurana. To choose the account and the list, touch and hold the widget and tap Edit Widget.';

  @override
  String get widgetsAddHeading => 'Add a widget';

  @override
  String get widgetsAddHint =>
      'It shows the active account; you can change that in its settings.';

  @override
  String get widgetsAdd => 'Add';

  @override
  String get widgetsPinUnsupported =>
      'Your home screen can\'t add widgets from here. Add it on the home screen instead.';

  @override
  String get widgetsPlacedHeading => 'On your home screen';

  @override
  String get widgetsPlacedAccountRemoved => 'Account removed – choose another';

  @override
  String get widgetsPrivacyNote =>
      'Widgets show your task titles on the home screen, where anyone who sees your phone can read them.';

  @override
  String get widgetKindToday => 'Today';

  @override
  String get widgetKindTodayHint => 'Overdue and due today';

  @override
  String get widgetKindUpcoming => 'Upcoming';

  @override
  String get widgetKindUpcomingHint => 'Due in the next days';

  @override
  String get widgetKindOverdue => 'Overdue';

  @override
  String get widgetKindOverdueHint => 'Past their due date';

  @override
  String get widgetKindFavorites => 'Favourites';

  @override
  String get widgetKindFavoritesHint => 'Your favourite tasks';

  @override
  String get widgetKindProject => 'Project';

  @override
  String get widgetKindLabel => 'Label';

  @override
  String get widgetKindSavedFilter => 'Saved filter';

  @override
  String get widgetKindQuickAdd => 'New task button';

  @override
  String get widgetKindQuickAddHint => 'One tap to a new task';

  @override
  String widgetUpcomingDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get widgetConfigureTitle => 'Set up widget';

  @override
  String get widgetConfigureAccountHeading => 'Account';

  @override
  String get widgetConfigureListHeading => 'Shows';

  @override
  String get widgetConfigureDaysLabel => 'Days ahead';

  @override
  String get widgetConfigureChoose => 'Choose';

  @override
  String get widgetConfigureNoProjects =>
      'This account has no projects to show.';

  @override
  String get widgetConfigureNoLabels => 'This account has no labels yet.';

  @override
  String get widgetConfigureNoSavedFilters =>
      'This account has no saved filters yet.';

  @override
  String get widgetConfigurePreviewHeading => 'Preview';

  @override
  String get widgetConfigurePreviewNone => 'No preview yet';

  @override
  String get widgetConfigureSave => 'Save';

  @override
  String get widgetConfigureSaving => 'Saving…';

  @override
  String get widgetConfigureSaved => 'Widget set up';

  @override
  String get widgetConfigureSaveFailed =>
      'The widget couldn\'t be saved. Try again.';

  @override
  String get widgetsHeading => 'Home screen';

  @override
  String get widgetsEntryTitle => 'Widgets';

  @override
  String get widgetsHowToAndroid =>
      'Touch and hold an empty spot on your home screen, tap Widgets and look for Rurana. To choose the account and the list, tap the widget under “On your home screen” below. Some home screens also offer this in the widget\'s settings when you touch and hold it.';

  @override
  String get widgetsPlacedNotSetUp =>
      'Not set up yet – shows the active account';

  @override
  String get notificationContentReminderTitle => 'Task reminder';

  @override
  String get notificationContentDueTitle => 'Task due';

  @override
  String get notificationContentBody => 'Open Rurana to see it';

  @override
  String get notificationContentActivityTitle => 'New activity';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyEntryTitle => 'App lock and privacy';

  @override
  String get privacyEntryAppLockOff => 'App lock: Off';

  @override
  String get privacyEntryAppLockImmediately => 'App lock: On · immediately';

  @override
  String privacyEntryAppLockAfter(String duration) {
    return 'App lock: On · after $duration';
  }

  @override
  String get privacyLockAfterImmediately => 'Immediately';

  @override
  String privacyLockAfterMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String privacyLockAfterHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get privacyAppLockHeading => 'App lock';

  @override
  String get privacyAppLockSwitch => 'Lock Rurana';

  @override
  String get privacyAppLockSubtitle =>
      'Unlock with biometrics or the device screen lock';

  @override
  String get privacyAppLockUnsupported =>
      'Set a screen lock on this device first';

  @override
  String get privacyAppLockLockedOut => 'Too many attempts. Try again later.';

  @override
  String get privacyAppLockFailed =>
      'Couldn\'t check your screen lock. Try again.';

  @override
  String get privacyLockAfter => 'Lock after';

  @override
  String get privacyLockAfterRestart => 'Rurana always locks after a restart.';

  @override
  String get privacyAppSwitcherHidden =>
      'While the lock is on, the app switcher hides Rurana\'s content.';

  @override
  String get privacyAppSwitcherBestEffort =>
      'While the lock is on, the app switcher hides Rurana\'s content as far as this Android version allows. To be sure, turn on Block screenshots.';

  @override
  String get privacyScreenshotsHeading => 'Screenshots';

  @override
  String get privacyBlockScreenshots => 'Block screenshots';

  @override
  String get privacyBlockScreenshotsSubtitle =>
      'Also hides Rurana from screen recordings and the app overview.';

  @override
  String get privacyNotificationContentHeading => 'Notification content';

  @override
  String get privacyNotificationContentAll => 'Show everything';

  @override
  String get privacyNotificationContentAllSubtitle =>
      'Task titles and comments, also on the lock screen';

  @override
  String get privacyNotificationContentHidden => 'Hide on the lock screen';

  @override
  String get privacyNotificationContentHiddenSubtitle =>
      'The content shows only while the phone is unlocked';

  @override
  String get privacyNotificationContentNoTitles => 'Never show task titles';

  @override
  String get privacyNotificationContentNoTitlesSubtitle =>
      'Generic texts without task titles, names or comments';

  @override
  String get privacyNotificationContentIosHint =>
      'On iPhone, iOS decides this for each app: in Settings → Notifications → Rurana, set Show Previews to When Unlocked.';

  @override
  String get privacyWidgetsHeading => 'Widgets';

  @override
  String get privacyWidgetTitles => 'Show task titles in widgets';

  @override
  String get privacyWidgetTitlesSubtitle =>
      'When off, widgets show only how many tasks there are';

  @override
  String get privacySettingsUnreadable =>
      'Your privacy settings couldn\'t be read, so Rurana locked itself. Choose them again here.';

  @override
  String get appLockPromptReason => 'Unlock Rurana';

  @override
  String get privacyAppLockReasonOn =>
      'Confirm it\'s you to turn on the app lock';

  @override
  String get privacyAppLockReasonOff =>
      'Confirm it\'s you to turn off the app lock';

  @override
  String get privacySaveFailed => 'The setting couldn\'t be saved. Try again.';

  @override
  String get appLockTitle => 'Rurana is locked';

  @override
  String get appLockBody =>
      'Unlock with biometrics or your device\'s screen lock.';

  @override
  String get appLockUnlock => 'Unlock';

  @override
  String get appLockLockedOut => 'Too many attempts. Try again later.';

  @override
  String get appLockUnavailable =>
      'Rurana couldn\'t check your screen lock. Try again.';

  @override
  String get appLockTurnedOff =>
      'App lock was turned off because this device has no screen lock.';

  @override
  String get appLockPromptHint => 'Use your fingerprint, face or screen lock';

  @override
  String get appLockPromptStuck =>
      'The unlock prompt doesn\'t respond. Close Rurana completely and open it again.';

  @override
  String widgetTitlesHiddenHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Open Rurana to see them',
      one: 'Open Rurana to see it',
    );
    return '$_temp0';
  }

  @override
  String get privacyNotificationContentHiddenSubtitleAndroid =>
      'Notifications don\'t appear on the lock screen; you see them once you unlock';

  @override
  String get connectionClientCertificateFailureTitle =>
      'Client certificate not accepted';

  @override
  String connectionClientCertificateFailureExplanation(String host) {
    return '$host did not accept a client certificate from this device.';
  }

  @override
  String connectionClientCertificateNeededExplanation(String host) {
    return '$host needs a client certificate.';
  }

  @override
  String connectionClientCertificateRefusedExplanation(String host) {
    return '$host refused the stored client certificate.';
  }

  @override
  String get connectionClientCertificateFailureSuggestion =>
      'Add the client certificate (a .p12 or .pfx file) in this server\'s connection settings.';

  @override
  String get connectionClientCertificateRefusedSuggestion =>
      'Check that it is the right certificate and still valid, or replace it in this server\'s connection settings.';

  @override
  String get connectionCleartextBlockedTitle =>
      'Unencrypted connection not allowed';

  @override
  String connectionCleartextBlockedExplanation(String host) {
    return 'Unencrypted connections to $host are not allowed on this device.';
  }

  @override
  String get connectionCleartextBlockedSuggestion =>
      'Allow unencrypted connections in this server\'s connection settings if you trust the network.';

  @override
  String get connectionProfileLockedTitle =>
      'Connection settings not available yet';

  @override
  String connectionProfileLockedExplanation(String host) {
    return 'The connection settings for $host are not available until the device has been unlocked once.';
  }

  @override
  String get connectionProfileLockedSuggestion =>
      'Unlock the device, then try again.';

  @override
  String get connectionProfileIncompleteTitle =>
      'Connection settings incomplete';

  @override
  String connectionProfileIncompleteExplanation(String host) {
    return 'Some connection settings for $host are missing and need to be entered again.';
  }

  @override
  String get connectionProfileIncompleteSuggestion =>
      'Open this server\'s connection settings and enter them again.';

  @override
  String get connectionProfileDamagedTitle => 'Connection settings unreadable';

  @override
  String get connectionProfileDamagedExplanation =>
      'The stored connection settings could not be read. Reset them to continue.';

  @override
  String get connectionProfileDamagedSuggestion =>
      'Afterwards, enter the settings again for the servers that need them.';

  @override
  String get connectionTlsSuggestion =>
      'If your server uses its own certificate authority, install its certificate in your device settings, or trust the certificate in this server\'s connection settings.';

  @override
  String get connectionTlsSuggestionIos =>
      'If your server uses its own certificate authority, install its certificate profile and turn on full trust for it under Settings › General › About › Certificate Trust Settings, or trust the certificate in this server\'s connection settings.';

  @override
  String get connectionLoginProxySuggestion =>
      'If the proxy accepts access tokens, such as a Cloudflare Access service token, add them as access headers in this server\'s connection settings; otherwise ask whoever runs the server to let the app reach the Vikunja API directly.';

  @override
  String connectionPinMismatchExplanation(String host) {
    return '$host presented a certificate other than the one trusted in the app.';
  }

  @override
  String get connectionPinMismatchSuggestion =>
      'Review the new certificate in this server\'s connection settings before you accept it.';

  @override
  String get connectionOpenSettings => 'Open connection settings';

  @override
  String get connectionReset => 'Reset connection settings';

  @override
  String get connectionResetTitle => 'Reset connection settings?';

  @override
  String get connectionResetBody =>
      'This removes the connection settings and the permissions for unencrypted connections of every server. The affected accounts stop working until the settings are entered again.';

  @override
  String get connectionResetConfirm => 'Reset';

  @override
  String get connectionViewCertificate => 'View certificate';

  @override
  String get connectionAddHeaders => 'Add access headers';

  @override
  String get connectionAddClientCertificate => 'Add client certificate';

  @override
  String get connectionReplaceClientCertificate => 'Replace client certificate';

  @override
  String get connectionSaveFailed =>
      'The connection settings could not be saved.';

  @override
  String get connectionOptions => 'Connection options';

  @override
  String connectionOptionsFor(String origin) {
    return 'Settings for $origin';
  }

  @override
  String get connectionOptionsSaved => 'Saved settings';

  @override
  String get connectionTitle => 'Connection';

  @override
  String get connectionIntro =>
      'Used by this app for every account on this address. The browser that opens the sign-in page does not use them.';

  @override
  String get connectionServerCertificateHeading => 'Server certificate';

  @override
  String get connectionPinnedTitle => 'Trusted certificate';

  @override
  String connectionPinnedSince(String date) {
    return 'Trusted since $date';
  }

  @override
  String get connectionCaTitle => 'Trusted CA certificate';

  @override
  String connectionFileAdded(String fileName, String date) {
    return '$fileName, added $date';
  }

  @override
  String get connectionCaIosHint =>
      'On iPhone and iPad, server certificates from this authority must name the server and be valid for at most 825 days; otherwise trust the server\'s certificate itself.';

  @override
  String get connectionDeviceTrust =>
      'The certificates trusted by the device are used.';

  @override
  String get connectionCheckCertificate => 'Check the server\'s certificate';

  @override
  String get connectionClientCertificateHeading => 'Client certificate';

  @override
  String get connectionClientCertificateNone =>
      'None. Only needed when the server asks for one.';

  @override
  String get connectionRemove => 'Remove';

  @override
  String get connectionHeadersHeading => 'Access headers';

  @override
  String get connectionHeadersNone =>
      'None. Only needed behind an access proxy such as Cloudflare Access.';

  @override
  String get connectionEditHeaders => 'Edit access headers';

  @override
  String get connectionHeaderValueHidden => 'value hidden';

  @override
  String get connectionCleartextHeading => 'Unencrypted connections';

  @override
  String connectionCleartextAllowedSince(String date) {
    return 'Allowed since $date';
  }

  @override
  String get connectionCleartextNotAllowed =>
      'Not allowed. Requests to this address fail until you allow them.';

  @override
  String get connectionCleartextRevoke => 'Revoke';

  @override
  String get connectionCleartextRevokeTitle => 'Revoke the permission?';

  @override
  String connectionCleartextRevokeBody(String host) {
    return 'Requests to $host will fail. The accounts on this server stop working until unencrypted connections are allowed again.';
  }

  @override
  String get connectionCleartextAllow => 'Allow unencrypted connection';

  @override
  String get connectionHeadersUnencrypted =>
      'Like everything else on this address, the headers travel unencrypted.';

  @override
  String get connectionHeadersNeedCleartext =>
      'Access headers can be added once unencrypted connections are allowed.';

  @override
  String get connectionForget => 'Forget connection settings';

  @override
  String get connectionForgetTitle => 'Forget connection settings?';

  @override
  String connectionForgetBody(String host) {
    return 'The accounts on $host stop working until the settings are entered again. The permission for unencrypted connections is removed too.';
  }

  @override
  String get connectionForgetConfirm => 'Forget';

  @override
  String get connectionStatusPinMismatch => 'Certificate changed';

  @override
  String get connectionStatusNeedsReentry => 'Needs re-entry';

  @override
  String get connectionStatusUnavailable => 'Not available yet';

  @override
  String get connectionStatusDamaged => 'Settings could not be read';

  @override
  String get connectionNeedsReentryTitle =>
      'Some settings need to be entered again';

  @override
  String get connectionNeedsReentryBody =>
      'The stored access headers or client certificate are missing or could not be used. Requests to this address fail until you enter them again or remove them.';

  @override
  String get connectionMismatchTitle => 'The server\'s certificate changed';

  @override
  String connectionMismatchBody(String date) {
    return 'On $date the server presented a certificate other than the trusted one. Requests are refused until you review it.';
  }

  @override
  String get connectionMismatchReview => 'Review';

  @override
  String get connectionSummaryPinned => 'Trusted certificate';

  @override
  String get connectionSummaryCa => 'Trusted CA certificate';

  @override
  String get connectionSummaryClientCertificate => 'Client certificate';

  @override
  String get connectionSummaryHeaders => 'Access headers';

  @override
  String get connectionSummaryCleartext => 'Unencrypted connections allowed';

  @override
  String connectionCertificateChecking(String origin) {
    return 'Fetching the certificate of $origin…';
  }

  @override
  String get connectionFingerprintLabel => 'SHA-256 fingerprint';

  @override
  String get connectionCopyFingerprint => 'Copy fingerprint';

  @override
  String get connectionIssuedTo => 'Issued to';

  @override
  String get connectionIssuedBy => 'Issued by';

  @override
  String get connectionSelfSigned => 'Self-signed';

  @override
  String connectionValidity(String from, String until) {
    return 'Valid from $from until $until';
  }

  @override
  String get connectionCertificateExpired => 'This certificate has expired.';

  @override
  String get connectionCertificateNotYetValid =>
      'This certificate is not valid yet.';

  @override
  String get connectionCompareHint =>
      'Compare the fingerprint with the one on your server, for example with:';

  @override
  String get connectionBrowserWarnsToo =>
      'Your browser will also warn about this certificate when you sign in; check that it shows the same fingerprint.';

  @override
  String connectionTrustOnlyFor(String origin) {
    return 'The app trusts it only for $origin.';
  }

  @override
  String get connectionTrustCertificate => 'Trust this certificate';

  @override
  String get connectionUseCa => 'Use a CA certificate instead';

  @override
  String get connectionPinReplacesCa =>
      'Trusting this certificate replaces the trusted CA certificate.';

  @override
  String get connectionCaReplacesPin =>
      'A CA certificate replaces the trusted certificate.';

  @override
  String get connectionReviewTitle => 'Review the new certificate';

  @override
  String connectionReviewRecorded(String date) {
    return 'Certificate seen on $date';
  }

  @override
  String get connectionReviewProbed => 'Certificate the server presents now';

  @override
  String get connectionReviewSame =>
      'The server still presents the certificate seen then.';

  @override
  String get connectionReviewDiffers =>
      'The server now presents yet another certificate than the one seen then. Check it carefully before you accept it.';

  @override
  String get connectionReviewMatchesTrusted =>
      'The server presents the trusted certificate again.';

  @override
  String get connectionReviewAccept => 'Accept new certificate';

  @override
  String get connectionReviewKeep => 'Keep current certificate';

  @override
  String get connectionCaNotTrusted =>
      'This CA certificate did not issue the server\'s certificate.';

  @override
  String connectionCaCheckFailed(String host) {
    return 'The CA certificate could not be checked, because $host could not be reached securely.';
  }

  @override
  String get connectionCaSaveAnyway => 'Save anyway';

  @override
  String get connectionCaFileInvalid =>
      'The file is not a PEM certificate file, or it also contains a private key.';

  @override
  String get connectionFileTooLarge => 'The file is larger than 64 KB.';

  @override
  String get connectionFileEmpty => 'The file is empty.';

  @override
  String get connectionFileUnreadable => 'The file could not be read.';

  @override
  String get connectionPickerFailed => 'The file picker could not be opened.';

  @override
  String get connectionChooseFile => 'Choose file';

  @override
  String get connectionChooseOtherFile => 'Choose another file';

  @override
  String get connectionNoFileChosen => 'Choose a file first.';

  @override
  String get connectionFilePassword => 'File password';

  @override
  String get connectionShowPassword => 'Show password';

  @override
  String get connectionHidePassword => 'Hide password';

  @override
  String get connectionWrongPasswordOrUnsupported =>
      'Wrong password or unsupported file.';

  @override
  String get connectionClientCertificatePrivateCaHint =>
      'If the server\'s certificate comes from your own certificate authority, trust it under Server certificate too: certificates installed in the device settings do not apply to connections with a client certificate.';

  @override
  String get connectionSave => 'Save';

  @override
  String connectionHeadersIntro(String origin) {
    return 'Sent with every request of this app to $origin, and to no other address.';
  }

  @override
  String get connectionHeaderPresetCloudflare =>
      'Cloudflare Access service token';

  @override
  String get connectionHeaderPresetCustom => 'Custom header';

  @override
  String get connectionHeaderName => 'Header name';

  @override
  String get connectionHeaderValue => 'Value';

  @override
  String get connectionShowValue => 'Show value';

  @override
  String get connectionHideValue => 'Hide value';

  @override
  String get connectionRemoveHeader => 'Remove header';

  @override
  String get connectionAddHeader => 'Add header';

  @override
  String get connectionServiceTokenHint =>
      'Cloudflare Access apps that allow only service tokens let the app reach the server, but signing in through the browser is then not possible. Opening a shared link as a guest still works.';

  @override
  String get connectionHeaderNameEmpty => 'Enter a name.';

  @override
  String get connectionHeaderNameInvalid => 'Not a valid header name.';

  @override
  String get connectionHeaderNameReserved =>
      'The app or the system sets this header itself.';

  @override
  String get connectionHeaderNameDuplicate =>
      'This header is already in the list.';

  @override
  String get connectionHeaderValueEmpty => 'Enter a value.';

  @override
  String get connectionHeaderValueNonAscii =>
      'Only visible ASCII characters are allowed.';

  @override
  String get connectionHeaderValueTooLong => 'At most 4 KB.';

  @override
  String get connectionHeadersTooMany => 'At most 10 headers.';

  @override
  String get connectionBrowserHintTitle => 'Before you sign in';

  @override
  String get connectionBrowserHintPinned =>
      'Your browser will warn about this server\'s certificate. Check that it shows the same SHA-256 fingerprint as the one trusted here:';

  @override
  String get connectionBrowserHintCa =>
      'Your browser may warn about this server\'s certificate, unless its certificate authority is also installed in the device settings.';

  @override
  String get connectionBrowserHintClientCertificate =>
      'The browser needs the client certificate installed in the device settings too, or the sign-in page must be reachable without it.';

  @override
  String get connectionBrowserHintHeaders =>
      'The browser goes through the access login itself.';

  @override
  String connectionBrowserHintOtherHost(String host) {
    return 'Sign-in opens $host.';
  }

  @override
  String get connectionBrowserHintContinue => 'Continue';

  @override
  String get connectionForgetCheckbox =>
      'Also forget this server\'s connection settings';

  @override
  String connectionProbeUnreachable(String host) {
    return '$host could not be reached.';
  }

  @override
  String connectionProbeTimeout(String host) {
    return '$host did not answer in time.';
  }

  @override
  String connectionProbeNotTls(String host) {
    return '$host did not start a secure connection, so there is no certificate to show.';
  }

  @override
  String get connectionNotAvailableBody =>
      'Try again once the device has been unlocked.';

  @override
  String get connectionRemoveTrustTitle => 'Stop trusting this certificate?';

  @override
  String connectionRemoveTrustBody(String host) {
    return 'Requests to $host then fail unless the device itself trusts the server\'s certificate.';
  }

  @override
  String get connectionRemoveClientCertificateTitle =>
      'Remove the client certificate?';

  @override
  String connectionRemoveClientCertificateBody(String host) {
    return 'Requests to $host then fail if the server requires a client certificate.';
  }

  @override
  String get connectionRemoveHeadersTitle => 'Remove the access headers?';

  @override
  String connectionRemoveHeadersBody(String host) {
    return 'Requests to $host then fail if the access proxy requires them.';
  }

  @override
  String get connectionAlreadyTrusted =>
      'This is the certificate the app trusts for this address.';

  @override
  String get connectionCaNotTrustedLeaf =>
      'The server presented this certificate:';

  @override
  String connectionClientCertificateIntroFor(String origin) {
    return 'Choose the certificate file (.p12 or .pfx) and enter its password. The certificate is presented only to $origin; its private key and the password stay encrypted on this device.';
  }

  @override
  String get connectionHeadersHeldBack =>
      'These headers are stored but not sent until unencrypted connections to this address are allowed.';

  @override
  String get connectionTrustDeviceTrusted =>
      'This device already trusts this certificate, so no extra trust is needed.';

  @override
  String get connectionTrustShortLived =>
      'This certificate is valid for less than 100 days, so the server replaces it often. Trusting this exact certificate stops working at every renewal; trusting the CA certificate that issued it keeps working.';
}
