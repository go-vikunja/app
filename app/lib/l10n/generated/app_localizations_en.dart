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
  String get homeSigningOut => 'Signing out…';

  @override
  String get signOutDialogTitle => 'Sign out?';

  @override
  String signOutDialogBody(String host) {
    return 'Rurana will sign you out of $host and delete the tasks saved on this device. You can sign in again at any time.';
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
  String get overviewLoading => 'Loading your tasks…';

  @override
  String get overviewEmptyTitle => 'All done';

  @override
  String get overviewEmptyBody =>
      'No open tasks right now. Enjoy the quiet, or add some on the web.';

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
  String get projectsAllHeading => 'All projects';

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
  String get projectTasksLoadMore => 'Load more';

  @override
  String get projectTasksLoadingMore => 'Loading more tasks…';

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
  String taskDetailIdentifierInProject(String identifier, String project) {
    return '$identifier in $project';
  }

  @override
  String get taskDetailDueDate => 'Due date';

  @override
  String get taskDetailStartDate => 'Start date';

  @override
  String get taskDetailEndDate => 'End date';

  @override
  String get taskDetailDoneAt => 'Done at';

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
  String get syncProblemProjectArchived => 'Its project is archived.';

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
}
