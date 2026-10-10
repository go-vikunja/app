// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Rurana';

  @override
  String get connectTagline =>
      'Deine Aufgaben von deinem eigenen Vikunja-Server, direkt auf dem Handy.';

  @override
  String get connectAddressLabel => 'Serveradresse';

  @override
  String get connectAddressHint => 'vikunja.example.com';

  @override
  String get connectAddressHelper =>
      'Die Adresse, mit der du Vikunja im Browser öffnest, zum Beispiel https://vikunja.example.com';

  @override
  String get connectAddressEmpty =>
      'Gib die Adresse deines Vikunja-Servers ein.';

  @override
  String get connectClearAddress => 'Adresse löschen';

  @override
  String get connectContinue => 'Weiter';

  @override
  String get connectCancel => 'Abbrechen';

  @override
  String get connectConnecting => 'Verbinde …';

  @override
  String connectConnectingTo(String address) {
    return 'Suche Vikunja unter $address …';
  }

  @override
  String get connectTryDemo => 'Öffentliche Demo ausprobieren';

  @override
  String get failureInvalidAddressTitle =>
      'Das sieht nicht nach einer Serveradresse aus';

  @override
  String failureInvalidAddressExplanation(String input) {
    return '„$input“ ist keine Webadresse, die die App öffnen kann.';
  }

  @override
  String get failureInvalidAddressSuggestion =>
      'Gib die Adresse ein, mit der du Vikunja im Browser öffnest, zum Beispiel vikunja.example.com.';

  @override
  String get failureUnreachableTitle => 'Server nicht erreichbar';

  @override
  String failureUnreachableExplanation(String host) {
    return '$host ist nicht erreichbar. Vielleicht ist die Adresse falsch geschrieben, der Server ist offline oder dein Gerät hat keine Internetverbindung.';
  }

  @override
  String get failureUnreachableSuggestion =>
      'Prüfe die Adresse und deine Verbindung und versuche es noch einmal. Wenn der Server bei dir zu Hause läuft, verbinde dich zuerst mit demselben WLAN oder VPN.';

  @override
  String get failureTimeoutTitle => 'Der Server hat zu lange gebraucht';

  @override
  String failureTimeoutExplanation(String host) {
    return '$host hat nicht rechtzeitig geantwortet.';
  }

  @override
  String get failureTimeoutSuggestion =>
      'Versuche es gleich noch einmal. Wenn das öfter passiert, ist der Server vielleicht überlastet oder eine Firewall blockiert ihn.';

  @override
  String get failureTlsTitle => 'Sichere Verbindung fehlgeschlagen';

  @override
  String failureTlsExplanation(String host) {
    return 'Dein Gerät vertraut dem Zertifikat von $host nicht. Es ist vielleicht selbst signiert, für eine andere Adresse ausgestellt oder abgelaufen.';
  }

  @override
  String get failureTlsSuggestion =>
      'Wenn dein Server eine eigene Zertifizierungsstelle nutzt, installiere deren Zertifikat in den Einstellungen deines Geräts. Selbst signierten Zertifikaten direkt in der App zu vertrauen, ist geplant.';

  @override
  String get failureTlsSuggestionIos =>
      'Wenn dein Server eine eigene Zertifizierungsstelle nutzt, installiere deren Zertifikatsprofil und aktiviere danach unter Einstellungen › Allgemein › Info › Zertifikatsvertrauenseinstellungen das volle Vertrauen dafür. Selbst signierten Zertifikaten direkt in der App zu vertrauen, ist geplant.';

  @override
  String failureTlsHandshakeExplanation(String host) {
    return '$host hat keine sichere (HTTPS-)Verbindung aufgebaut. Vielleicht spricht die Adresse nur unverschlüsseltes http, oder HTTPS ist auf dem Server nicht fertig eingerichtet.';
  }

  @override
  String get failureTlsHandshakeSuggestion =>
      'Prüfe den Port und ob die Adresse mit http:// statt https:// beginnen muss. Wenn HTTPS funktionieren soll, prüfe die TLS-Einstellungen deines Reverse-Proxys.';

  @override
  String get failureNotVikunjaTitle => 'Kein Vikunja-Server gefunden';

  @override
  String failureNotVikunjaExplanation(String host) {
    return '$host hat geantwortet, aber nicht wie ein Vikunja-Server.';
  }

  @override
  String get failureNotVikunjaSuggestion =>
      'Prüfe die Adresse. Wenn Vikunja in einem Unterordner läuft, gib ihn mit an, zum Beispiel example.com/vikunja.';

  @override
  String get failureUnavailableTitle => 'Server vorübergehend nicht verfügbar';

  @override
  String failureUnavailableExplanation(String host) {
    return '$host hat mit einem Fehler statt mit Vikunja geantwortet. Vikunja ist vielleicht ausgefallen, startet gerade neu oder ist überlastet.';
  }

  @override
  String get failureUnavailableSuggestion =>
      'Versuche es in ein paar Minuten noch einmal. Wenn das öfter passiert, frage die Person, die den Server betreut, ob sie ihn prüfen kann.';

  @override
  String get failureLoginProxyTitle =>
      'Der Server liegt hinter einer Anmeldeseite';

  @override
  String failureLoginProxyExplanation(String host) {
    return 'Ein Proxy vor $host verlangt eine eigene Anmeldung, bevor Vikunja erreichbar ist.';
  }

  @override
  String get failureLoginProxySuggestion =>
      'Frage die Person, die den Server betreut, ob sie der App direkten Zugriff auf die Vikunja-API erlauben kann. Eigene Proxy-Header, etwa Tokens für Cloudflare Access, sind geplant.';

  @override
  String get failureUnexpectedTitle => 'Etwas ist schiefgelaufen';

  @override
  String get failureUnexpectedExplanation =>
      'Beim Verbinden ist ein unerwarteter Fehler aufgetreten.';

  @override
  String get failureUnexpectedSuggestion => 'Versuche es gleich noch einmal.';

  @override
  String get insecureDialogTitle => 'Unverschlüsselte Verbindung';

  @override
  String insecureDialogBody(String host) {
    return '$host nutzt http:// statt https://. Dein Passwort und deine Aufgaben würden unverschlüsselt übertragen, und alle im selben Netzwerk könnten sie mitlesen oder verändern.\n\nFahre nur fort, wenn du dem Netzwerk vertraust, etwa deinem Heimnetz oder einem VPN.';
  }

  @override
  String get insecureDialogCancel => 'Abbrechen';

  @override
  String get insecureDialogContinue => 'Trotzdem fortfahren';

  @override
  String get overviewTitle => 'Server gefunden';

  @override
  String overviewVikunjaVersion(String version) {
    return 'Vikunja $version';
  }

  @override
  String get overviewVikunjaVersionUnknown => 'Vikunja, Version unbekannt';

  @override
  String overviewApiBadge(String version) {
    return 'API $version';
  }

  @override
  String get overviewDemoBadge => 'Demo-Server';

  @override
  String get overviewInsecureBadge => 'Unverschlüsselt';

  @override
  String get tierFullTitle => 'Voll unterstützt';

  @override
  String get tierFullBody =>
      'Dieser Server bietet die moderne API, daher funktionieren alle Funktionen der App mit ihm.';

  @override
  String get tierOauthTitle => 'Unterstützt';

  @override
  String get tierOauthBody =>
      'Die App funktioniert mit diesem Server. Einige neuere Funktionen brauchen Vikunja 2.4 oder neuer.';

  @override
  String get tierOauthV2UnreachableBody =>
      'Die App funktioniert mit diesem Server, aber seine neuere API (/api/v2) ist nicht erreichbar, daher fehlen einige Funktionen. Vielleicht blockiert sie ein Reverse-Proxy.';

  @override
  String get unsupportedTitle => 'Dieser Server ist zu alt';

  @override
  String unsupportedBody(String minimum, String found) {
    return 'Rurana braucht Vikunja $minimum oder neuer. Auf diesem Server läuft $found.';
  }

  @override
  String get unsupportedSuggestion =>
      'Frage die Person, die den Server betreut, ob sie Vikunja aktualisieren kann.';

  @override
  String get unsupportedUnknownVersionTitle => 'Serverversion nicht erkannt';

  @override
  String unsupportedUnknownVersionBody(String minimum) {
    return 'Rurana braucht Vikunja $minimum oder neuer. Dieser Server meldet eine Version, die die App nicht erkennt.';
  }

  @override
  String get unsupportedUnknownVersionSuggestion =>
      'Frage die Person, die den Server betreut, welche Vikunja-Version läuft.';

  @override
  String get signInMethodsHeading => 'Anmeldemöglichkeiten';

  @override
  String get signInBrowserTitle => 'Anmeldung im Browser';

  @override
  String get signInBrowserSubtitle =>
      'Nutzt die Anmeldeseite von Vikunja, auch mit Single Sign-on.';

  @override
  String signInBrowserProvidersSubtitle(String providers) {
    return 'Nutzt die Anmeldeseite von Vikunja, auch mit $providers.';
  }

  @override
  String get featuresHeading => 'Funktionen des Servers';

  @override
  String get featuresNone =>
      'Auf diesem Server sind keine optionalen Funktionen aktiviert.';

  @override
  String get featureAttachments => 'Anhänge';

  @override
  String featureAttachmentsWithLimit(String size) {
    return 'Anhänge bis $size';
  }

  @override
  String get featureComments => 'Kommentare';

  @override
  String get featureLinkSharing => 'Teilen per Link';

  @override
  String get featureTotp => 'Zwei-Faktor-Authentifizierung (TOTP)';

  @override
  String get featureCaldav => 'CalDAV-Synchronisierung';

  @override
  String get featureWebhooks => 'Webhooks';

  @override
  String get featureEmailReminders => 'Erinnerungen per E-Mail';

  @override
  String get featureRegistration => 'Offene Registrierung';

  @override
  String get featurePublicTeams => 'Öffentliche Teams';

  @override
  String get featureUserDeletion => 'Kontolöschung durch Nutzer';

  @override
  String get featureBackgrounds => 'Projekthintergründe';

  @override
  String get motdHeading => 'Nachricht vom Server';

  @override
  String get legalImprint => 'Impressum';

  @override
  String get legalPrivacy => 'Datenschutzerklärung';

  @override
  String get legalOpenFailed => 'Der Link konnte nicht geöffnet werden.';

  @override
  String get continueToSignIn => 'Weiter zur Anmeldung';

  @override
  String get useDifferentServer => 'Anderen Server verwenden';

  @override
  String get signInWaiting => 'Warte auf Anmeldung …';

  @override
  String get signInRateLimitedTitle => 'Zu viele Anmeldeversuche';

  @override
  String signInRateLimitedExplanation(String host) {
    return '$host begrenzt Anmeldungen aus deinem Netzwerk gerade.';
  }

  @override
  String get signInRateLimitedSuggestion =>
      'Warte eine Minute und versuche es dann noch einmal.';

  @override
  String signInRateLimitedSuggestionSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds Sekunden',
      one: '1 Sekunde',
    );
    return 'Warte $_temp0 und versuche es dann noch einmal.';
  }

  @override
  String signInRateLimitedSuggestionMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes Minuten',
      one: '1 Minute',
    );
    return 'Warte $_temp0 und versuche es dann noch einmal.';
  }

  @override
  String signInServerErrorExplanation(String host, String status) {
    return '$host hat die Anmeldung mit einem Fehler beantwortet (HTTP $status).';
  }

  @override
  String get signInExpiredTitle => 'Anmeldung abgelaufen';

  @override
  String get signInExpiredExplanation =>
      'Die Anmeldung hat zu lange gedauert oder wurde schon einmal verwendet.';

  @override
  String get signInRetrySuggestion => 'Bitte melde dich noch einmal an.';

  @override
  String get signInRejectedTitle => 'Anmeldung abgelehnt';

  @override
  String signInRejectedExplanation(String host, String code) {
    return '$host hat die Anmeldung dieser App nicht akzeptiert (Fehler $code).';
  }

  @override
  String get signInRejectedSuggestion =>
      'Versuche es noch einmal. Wenn das öfter passiert, bitte die Person, die den Server betreut, ihn zu prüfen.';

  @override
  String get signInDiscardedTitle => 'Anmeldung verworfen';

  @override
  String get signInDiscardedExplanation =>
      'Der Browser hat eine Anmeldung zurückgegeben, die nicht zu diesem Versuch gehört. Zum Schutz deines Kontos hat die App sie verworfen.';

  @override
  String get signInIncompleteTitle => 'Anmeldung nicht abgeschlossen';

  @override
  String get signInIncompleteExplanation =>
      'Der Browser ist ohne abgeschlossene Anmeldung zur App zurückgekehrt.';

  @override
  String get signInIncompleteSuggestion =>
      'Versuche es noch einmal und schließe die Anmeldung auf der Seite des Servers ab.';

  @override
  String get signInNoBrowserTitle => 'Kein Browser verfügbar';

  @override
  String get signInNoBrowserExplanation =>
      'Für die Anmeldung wird ein Webbrowser gebraucht, aber auf diesem Gerät ist keiner verfügbar.';

  @override
  String get signInNoBrowserSuggestion =>
      'Installiere oder aktiviere einen Browser und versuche es dann noch einmal.';

  @override
  String get signInBrowserFailedTitle =>
      'Anmeldeseite konnte nicht geöffnet werden';

  @override
  String get signInBrowserFailedExplanation =>
      'Die App konnte die Anmeldeseite des Servers nicht anzeigen.';

  @override
  String get signInBrowserFailedSuggestion =>
      'Versuche es noch einmal. Wenn das öfter passiert, starte die App neu.';

  @override
  String get signInAccountDisabledTitle => 'Konto deaktiviert';

  @override
  String signInAccountDisabledExplanation(String host) {
    return 'Dein Konto auf $host ist deaktiviert.';
  }

  @override
  String get signInAccountLockedTitle => 'Konto gesperrt';

  @override
  String signInAccountLockedExplanation(String host) {
    return 'Dein Konto auf $host ist gesperrt.';
  }

  @override
  String get signInAccountBlockedSuggestion =>
      'Sieh in deinen E-Mails nach Anweisungen oder frage die Person, die den Server betreut.';

  @override
  String signInSessionEndedExplanation(String host) {
    return '$host hat die neue Sitzung sofort wieder beendet.';
  }

  @override
  String get signInEndpointMissingTitle => 'Anmeldung nicht verfügbar';

  @override
  String signInEndpointMissingExplanation(String host) {
    return '$host antwortet nicht unter der Anmeldeadresse, die die App braucht. Vielleicht blockiert ein Reverse-Proxy sie.';
  }

  @override
  String get signInEndpointMissingSuggestion =>
      'Bitte die Person, die den Server betreut, die gesamte Vikunja-API erreichbar zu machen.';

  @override
  String get signInUnexpectedExplanation =>
      'Bei der Anmeldung ist ein unerwarteter Fehler aufgetreten.';

  @override
  String get signInDifferentUserTitle => 'Mit einem anderen Konto angemeldet';

  @override
  String signInDifferentUserExplanation(String signedIn, String expected) {
    return 'Die Anmeldeseite hat dich als @$signedIn angemeldet, dieses Konto ist aber @$expected. Es wurde nichts geändert.';
  }

  @override
  String signInDifferentUserSuggestion(String expected, String host) {
    return 'Melde dich erneut als @$expected an. Falls der Browser dich von selbst anmeldet, melde dich dort zuerst von $host ab.';
  }

  @override
  String homeUsername(String username) {
    return '@$username';
  }

  @override
  String get homeSignOut => 'Abmelden';

  @override
  String get homeSigningOut => 'Wird abgemeldet …';

  @override
  String get signOutDialogTitle => 'Abmelden?';

  @override
  String signOutDialogBody(String host) {
    return 'Rurana meldet dich von $host ab und löscht die auf diesem Gerät gespeicherten Aufgaben. Du kannst dich jederzeit wieder anmelden.';
  }

  @override
  String get signOutDialogCancel => 'Abbrechen';

  @override
  String get signOutDialogConfirm => 'Abmelden';

  @override
  String get reauthTitle => 'Vom Server abgemeldet';

  @override
  String reauthBody(String host) {
    return '$host hat deine Sitzung beendet. Melde dich erneut an, damit deine Aufgaben synchron bleiben. Auf diesem Gerät geht nichts verloren.';
  }

  @override
  String get reauthAction => 'Erneut anmelden';

  @override
  String get tabOverview => 'Überblick';

  @override
  String get tabProjects => 'Projekte';

  @override
  String get tabAccount => 'Konto';

  @override
  String get overviewLoading => 'Deine Aufgaben werden geladen …';

  @override
  String get overviewEmptyTitle => 'Alles erledigt';

  @override
  String get overviewEmptyBody =>
      'Gerade gibt es keine offenen Aufgaben. Genieß die Ruhe oder leg im Browser neue an.';

  @override
  String get sectionOverdue => 'Überfällig';

  @override
  String get sectionToday => 'Heute';

  @override
  String get sectionNextSevenDays => 'Nächste 7 Tage';

  @override
  String get sectionLater => 'Später';

  @override
  String get sectionNoDueDate => 'Ohne Fälligkeit';

  @override
  String get projectsLoading => 'Deine Projekte werden geladen …';

  @override
  String get projectsEmptyTitle => 'Noch keine Projekte';

  @override
  String get projectsEmptyBody =>
      'Leg dein erstes Projekt im Browser an, dann erscheint es hier.';

  @override
  String get projectsFavouritesHeading => 'Favoriten';

  @override
  String get projectsAllHeading => 'Alle Projekte';

  @override
  String projectChildCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Unterprojekte',
      one: '1 Unterprojekt',
    );
    return '$_temp0';
  }

  @override
  String projectExpand(String title) {
    return 'Unterprojekte von $title anzeigen';
  }

  @override
  String projectCollapse(String title) {
    return 'Unterprojekte von $title ausblenden';
  }

  @override
  String get projectUnknownTitle => 'Projekt';

  @override
  String get favouriteLabel => 'Favorit';

  @override
  String get projectTasksShowDone => 'Erledigte Aufgaben anzeigen';

  @override
  String get projectTasksLoading => 'Aufgaben werden geladen …';

  @override
  String get projectTasksLoadMore => 'Mehr laden';

  @override
  String get projectTasksLoadingMore => 'Weitere Aufgaben werden geladen …';

  @override
  String get projectTasksEmptyTitle => 'Keine offenen Aufgaben';

  @override
  String get projectTasksEmptyBody =>
      'In diesem Projekt ist alles erledigt. Schalte „Erledigte Aufgaben anzeigen“ ein, um sie zu sehen.';

  @override
  String get projectTasksEmptyAllTitle => 'Keine Aufgaben';

  @override
  String get projectTasksEmptyAllBody =>
      'Dieses Projekt hat noch keine Aufgaben.';

  @override
  String get moreActions => 'Mehr';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get taskDone => 'Erledigt';

  @override
  String get taskNotDone => 'Nicht erledigt';

  @override
  String taskDueSemantics(String when) {
    return 'Fällig $when';
  }

  @override
  String taskOverdueSemantics(String when) {
    return 'Überfällig, war fällig $when';
  }

  @override
  String prioritySemantics(String priority) {
    return 'Priorität: $priority';
  }

  @override
  String labelSemantics(String label) {
    return 'Label: $label';
  }

  @override
  String get priorityUnset => 'Keine';

  @override
  String get priorityLow => 'Niedrig';

  @override
  String get priorityMedium => 'Mittel';

  @override
  String get priorityHigh => 'Hoch';

  @override
  String get priorityUrgent => 'Dringend';

  @override
  String get priorityDoNow => 'Sofort';

  @override
  String get relativeNow => 'jetzt';

  @override
  String relativeInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Minuten',
      one: 'in 1 Minute',
    );
    return '$_temp0';
  }

  @override
  String relativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Minuten',
      one: 'vor 1 Minute',
    );
    return '$_temp0';
  }

  @override
  String relativeInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Stunden',
      one: 'in 1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Stunden',
      one: 'vor 1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String relativeInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Tagen',
      one: 'in 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String relativeInMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Monaten',
      one: 'in 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String relativeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Monaten',
      one: 'vor 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String relativeInYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Jahren',
      one: 'in 1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String relativeYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Jahren',
      one: 'vor 1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String get taskDetailStatusDone => 'Erledigt';

  @override
  String get taskDetailStatusOpen => 'Offen';

  @override
  String taskDetailIdentifierInProject(String identifier, String project) {
    return '$identifier in $project';
  }

  @override
  String get taskDetailDueDate => 'Fällig am';

  @override
  String get taskDetailStartDate => 'Startdatum';

  @override
  String get taskDetailEndDate => 'Enddatum';

  @override
  String get taskDetailDoneAt => 'Erledigt am';

  @override
  String get taskDetailPriority => 'Priorität';

  @override
  String get taskDetailProgress => 'Fortschritt';

  @override
  String taskPercentDone(int percent) {
    return '$percent % erledigt';
  }

  @override
  String get taskDetailLabels => 'Labels';

  @override
  String get taskDetailAssignees => 'Zugewiesen an';

  @override
  String get taskDetailReminders => 'Erinnerungen';

  @override
  String get taskDetailRepeat => 'Wiederholung';

  @override
  String get taskDetailDescription => 'Beschreibung';

  @override
  String get taskDetailNoDescription => 'Keine Beschreibung';

  @override
  String get taskDetailClose => 'Schließen';

  @override
  String get repeatMonthly => 'Jeden Monat';

  @override
  String repeatEverySeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Sekunden',
      one: 'Jede Sekunde',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Minuten',
      one: 'Jede Minute',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Stunden',
      one: 'Jede Stunde',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Tage',
      one: 'Jeden Tag',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Wochen',
      one: 'Jede Woche',
    );
    return '$_temp0';
  }

  @override
  String repeatFromCompletion(String repeat) {
    return '$repeat, gerechnet ab dem Erledigen';
  }

  @override
  String periodSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sekunden',
      one: '1 Sekunde',
    );
    return '$_temp0';
  }

  @override
  String periodMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String periodHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String periodDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String periodWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochen',
      one: '1 Woche',
    );
    return '$_temp0';
  }

  @override
  String reminderBefore(String period, String reference) {
    return '$period vor dem $reference';
  }

  @override
  String reminderAfter(String period, String reference) {
    return '$period nach dem $reference';
  }

  @override
  String reminderAtReference(String reference) {
    return 'Zum $reference';
  }

  @override
  String get reminderReferenceDueDate => 'Fälligkeitsdatum';

  @override
  String get reminderReferenceStartDate => 'Startdatum';

  @override
  String get reminderReferenceEndDate => 'Enddatum';

  @override
  String get dataFailureLoadTitle => 'Laden vom Server fehlgeschlagen';

  @override
  String get dataFailureRefreshTitle => 'Aktualisieren fehlgeschlagen';

  @override
  String get dataFailureStaleNote =>
      'Angezeigt wird der zuletzt geladene Stand.';

  @override
  String dataFailureSessionEnded(String host) {
    return 'Deine Sitzung auf $host ist beendet. Melde dich im Tab „Konto“ neu an.';
  }

  @override
  String dataFailureForbidden(String host) {
    return '$host hat die Anfrage abgelehnt. Vielleicht hast du keinen Zugriff mehr darauf.';
  }

  @override
  String dataFailureNotFound(String host) {
    return '$host kennt das nicht mehr. Vielleicht wurde es gelöscht.';
  }

  @override
  String dataFailureRateLimited(String host) {
    return '$host begrenzt Anfragen aus deinem Netzwerk gerade.';
  }

  @override
  String dataFailureUnexpected(String host) {
    return 'Beim Laden von $host ist ein unerwarteter Fehler aufgetreten.';
  }

  @override
  String get retry => 'Noch einmal versuchen';

  @override
  String get firstSyncTitle => 'Deine Aufgaben werden geladen';

  @override
  String firstSyncBody(String host) {
    return 'Rurana speichert alles von $host auf diesem Gerät, damit es auch offline funktioniert.';
  }

  @override
  String get firstSyncPreparing => 'Vorbereiten …';

  @override
  String get firstSyncCancel => 'Abbrechen und abmelden';

  @override
  String get syncPhaseAccount => 'Konto wird geprüft …';

  @override
  String get syncPhaseProjects => 'Projekte werden geladen …';

  @override
  String get syncPhaseLabels => 'Labels werden geladen …';

  @override
  String get syncPhaseTasks => 'Aufgaben werden geladen …';

  @override
  String get syncPhaseArchivedTasks => 'Archivierte Projekte werden geladen …';

  @override
  String get syncPhaseDelta => 'Änderungen werden geladen …';

  @override
  String get syncPhaseReconcile => 'Gelöschte Aufgaben werden gesucht …';

  @override
  String get syncPhaseFinishing => 'Fast fertig …';

  @override
  String syncProgressOfTotal(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString von $totalString';
  }

  @override
  String syncProgressCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Bisher $countString';
  }

  @override
  String get syncIndicatorLabel => 'Synchronisiert mit dem Server';

  @override
  String get offlineNotice => 'Offline – gespeicherte Daten werden angezeigt';

  @override
  String accountLastSynced(String when) {
    return 'Zuletzt synchronisiert $when';
  }

  @override
  String get accountLastSyncedJustNow => 'Gerade eben synchronisiert';

  @override
  String get accountNeverSynced => 'Noch nicht synchronisiert';

  @override
  String get accountSyncing => 'Synchronisiert …';

  @override
  String get accountSyncFailed =>
      'Die letzte Synchronisierung ist fehlgeschlagen.';

  @override
  String get accountSyncNow => 'Jetzt synchronisieren';

  @override
  String get accountFullResync => 'Alles neu laden';
}
