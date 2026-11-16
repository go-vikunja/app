// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Vikunja';

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
    return 'Vikunja wird unter $address gesucht …';
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
    return 'Diese App braucht Vikunja $minimum oder neuer. Auf diesem Server läuft $found.';
  }

  @override
  String get unsupportedSuggestion =>
      'Frage die Person, die den Server betreut, ob sie Vikunja aktualisieren kann.';

  @override
  String get unsupportedUnknownVersionTitle => 'Serverversion nicht erkannt';

  @override
  String unsupportedUnknownVersionBody(String minimum) {
    return 'Diese App braucht Vikunja $minimum oder neuer. Dieser Server meldet eine Version, die die App nicht erkennt.';
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
  String get signInWaiting => 'Anmeldung läuft …';

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
  String get homeSignOut => 'Abmelden';

  @override
  String get homeSignOutOfThisAccount => 'Von diesem Konto abmelden';

  @override
  String get homeSigningOut => 'Wird abgemeldet …';

  @override
  String get signOutDialogTitle => 'Abmelden?';

  @override
  String signOutDialogBody(String account, String host) {
    return 'Die App meldet $account von $host ab und löscht die auf diesem Gerät gespeicherten Aufgaben dieses Kontos. Du kannst dich jederzeit wieder anmelden.';
  }

  @override
  String signOutDialogAccount(String name, String username) {
    return '$name (@$username)';
  }

  @override
  String signOutDialogSwitchesTo(String name) {
    return 'Danach wechselt die App zu $name.';
  }

  @override
  String signOutDialogPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Änderungen wurden noch nicht an den Server gesendet und gehen verloren; tippe vorher auf „Jetzt senden“, um sie zu behalten.',
      one: 'Eine Änderung wurde noch nicht an den Server gesendet und geht verloren; tippe vorher auf „Jetzt senden“, um sie zu behalten.',
    );
    return '$_temp0';
  }

  @override
  String get signOutDialogCancel => 'Abbrechen';

  @override
  String get signOutDialogConfirm => 'Abmelden';

  @override
  String get removeAccountDialogTitle => 'Konto entfernen?';

  @override
  String get removeAccountDialogConfirm => 'Entfernen';

  @override
  String removeAccountDialogPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Änderungen wurden noch nicht an den Server gesendet und gehen verloren; wechsle vorher zu diesem Konto und tippe auf „Jetzt senden“, um sie zu behalten.',
      one: 'Eine Änderung wurde noch nicht an den Server gesendet und geht verloren; wechsle vorher zu diesem Konto und tippe auf „Jetzt senden“, um sie zu behalten.',
    );
    return '$_temp0';
  }

  @override
  String removeAccountDialogPendingChangesSignInFirst(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Änderungen wurden noch nicht an den Server gesendet und gehen verloren; wechsle vorher zu diesem Konto, melde dich erneut an und tippe auf „Jetzt senden“, um sie zu behalten.',
      one: 'Eine Änderung wurde noch nicht an den Server gesendet und geht verloren; wechsle vorher zu diesem Konto, melde dich erneut an und tippe auf „Jetzt senden“, um sie zu behalten.',
    );
    return '$_temp0';
  }

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
  String get accountsHeading => 'Konten';

  @override
  String accountSwitcherButton(String name, String host) {
    return 'Konten, angemeldet als $name auf $host';
  }

  @override
  String get accountCurrent => 'Aktuell';

  @override
  String accountSubtitle(String username, String host) {
    return '@$username · $host';
  }

  @override
  String get accountBadgeSignInAgain => 'Erneut anmelden';

  @override
  String accountBadgeUnsent(int count) {
    return '$count nicht gesendet';
  }

  @override
  String get accountAdd => 'Konto hinzufügen';

  @override
  String get accountManage => 'Konten verwalten';

  @override
  String accountMoreActions(String name) {
    return 'Mehr zu $name';
  }

  @override
  String get accountRemove => 'Entfernen …';

  @override
  String accountSwitchedTo(String name) {
    return 'Zu $name gewechselt';
  }

  @override
  String accountSignedOutOf(String name) {
    return '$name abgemeldet';
  }

  @override
  String get addAccountTagline =>
      'Melde dich mit einem weiteren Konto an – auf einem deiner Server oder einem neuen.';

  @override
  String get addAccountYourServers => 'Deine Server';

  @override
  String get addAccountAlreadyAdded =>
      'Bei diesem Konto bist du schon angemeldet – die App ist zu ihm gewechselt';

  @override
  String get addAccountAlreadyActive =>
      'Bei diesem Konto bist du schon angemeldet';

  @override
  String get overviewLoading => 'Deine Aufgaben werden geladen …';

  @override
  String get overviewEmptyTitle => 'Alles erledigt';

  @override
  String get overviewEmptyBody =>
      'Gerade gibt es keine offenen Aufgaben. Genieße die Ruhe oder erstelle eine mit „Neue Aufgabe“.';

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
      'Erstelle dein erstes Projekt, um Aufgaben hinzuzufügen.';

  @override
  String get projectsFavouritesHeading => 'Favoriten';

  @override
  String get projectsFavouriteTasks => 'Favorisierte Aufgaben';

  @override
  String get projectsAllHeading => 'Alle Projekte';

  @override
  String get projectsNoneOpenTitle => 'Kein Projekt geöffnet';

  @override
  String get projectsNoneOpenBody =>
      'Öffne ein Projekt aus der Liste, um seine Aufgaben hier zu sehen.';

  @override
  String get projectsShowSavedFilters => 'Gespeicherte Filter anzeigen';

  @override
  String get projectsShowArchived => 'Archivierte Projekte anzeigen';

  @override
  String get projectArchived => 'Archiviert';

  @override
  String get projectArchivedNote =>
      'Dieses Projekt ist schreibgeschützt, weil es archiviert ist: keine neuen Aufgaben, keine Änderungen.';

  @override
  String get savedFiltersHeading => 'Gespeicherte Filter';

  @override
  String get savedFilterUnknownTitle => 'Gespeicherter Filter';

  @override
  String smartListOpenTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offene Aufgaben',
      one: '1 offene Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String smartListFilterNotice(String when) {
    return 'Der Server wendet diesen Filter an. Stand: $when; neue Aufgaben und Änderungen von anderswo erscheinen nach dem nächsten Laden.';
  }

  @override
  String smartListFilterNotLoadedBody(String title) {
    return 'Der Server wendet den gespeicherten Filter „$title“ an. Seine Aufgaben werden geladen, wenn du ihn online öffnest.';
  }

  @override
  String get smartListFilterDownloadingTitle => 'Dieser Filter wird geladen …';

  @override
  String smartListFilterDownloadingBody(String title) {
    return 'Der Server wendet den gespeicherten Filter „$title“ an. Seine Aufgaben sind unterwegs.';
  }

  @override
  String get smartListFilterGoneTitle =>
      'Diesen gespeicherten Filter gibt es nicht mehr';

  @override
  String get smartListFilterGoneBody =>
      'Die letzte Synchronisierung hat ihn nicht mehr gefunden. Vielleicht wurde er im Web gelöscht.';

  @override
  String get smartListFilterDownloadFailedTitle =>
      'Dieser Filter ließ sich nicht laden';

  @override
  String smartListFilterDownloadFailedBody(String title) {
    return 'Der Server wendet den gespeicherten Filter „$title“ an. Zieh nach unten, um es erneut zu versuchen.';
  }

  @override
  String get favoritesEmptyTitle => 'Keine favorisierten Aufgaben';

  @override
  String get favoritesEmptyBody =>
      'Markiere eine Aufgabe mit ihrem Stern als Favorit, um sie hier zu finden.';

  @override
  String get appearanceHeading => 'Darstellung';

  @override
  String get appearanceTheme => 'Design';

  @override
  String get appearanceThemeLight => 'Hell';

  @override
  String get appearanceThemeSystem => 'System';

  @override
  String get appearanceThemeDark => 'Dunkel';

  @override
  String get appearanceOnThisDevice => 'Auf diesem Gerät';

  @override
  String get appearanceSystemColors => 'Systemfarben verwenden';

  @override
  String get appearanceSystemColorsSubtitle =>
      'Die Farben deines Hintergrundbilds statt des App-Blaus';

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
  String get moveUp => 'Nach oben verschieben';

  @override
  String get movedUp => 'Nach oben verschoben';

  @override
  String get moveDown => 'Nach unten verschieben';

  @override
  String get movedDown => 'Nach unten verschoben';

  @override
  String projectMoveOut(String project) {
    return 'Aus $project herausnehmen';
  }

  @override
  String projectMovedOut(String project) {
    return 'Aus $project herausgenommen';
  }

  @override
  String projectMoveInto(String project) {
    return 'In $project verschieben';
  }

  @override
  String projectMovedInto(String project) {
    return 'In $project verschoben';
  }

  @override
  String get projectMovedToTopLevel => 'Auf die oberste Ebene verschoben';

  @override
  String get projectMoveNeedsConnection =>
      'Zum Verschieben eines Projekts brauchst du eine Verbindung zum Server.';

  @override
  String get projectMoveWait => 'Ein Projekt wird noch verschoben';

  @override
  String get projectMoveUnconfirmed =>
      'Das Verschieben ließ sich nicht bestätigen. Prüf deine Verbindung und zieh nach unten, um neu zu laden.';

  @override
  String get projectMoveAdminOnly =>
      'Nur Projekt-Admins können ein Projekt unter ein anderes verschieben.';

  @override
  String get projectMoveForbidden =>
      'Du darfst dieses Projekt nicht verschieben.';

  @override
  String get projectMoveArchived =>
      'Archivierte Projekte lassen sich nicht verschieben und nehmen keine Projekte auf.';

  @override
  String get projectMoveNotPossible =>
      'Dorthin lässt sich das Projekt nicht verschieben.';

  @override
  String get projectMoveGone =>
      'Das Projekt oder sein neues übergeordnetes Projekt gibt es nicht mehr.';

  @override
  String projectMoveRefused(String message) {
    return 'Der Server hat das Verschieben abgelehnt: $message';
  }

  @override
  String get projectMoveFailed => 'Das Projekt konnte nicht verschoben werden.';

  @override
  String get projectUnknownTitle => 'Projekt';

  @override
  String get favouriteLabel => 'Favorit';

  @override
  String get projectTasksLoading => 'Aufgaben werden geladen …';

  @override
  String get projectTasksEmptyTitle => 'Keine offenen Aufgaben';

  @override
  String get projectTasksEmptyBody =>
      'In diesem Projekt ist alles erledigt. Schalte „Erledigte anzeigen“ ein, um sie zu sehen.';

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
  String get relativeJustNow => 'gerade eben';

  @override
  String momentDateAtTime(String date, String time) {
    return '$date um $time';
  }

  @override
  String get taskDetailDueDate => 'Fälligkeitsdatum';

  @override
  String get taskDetailStartDate => 'Startdatum';

  @override
  String get taskDetailEndDate => 'Enddatum';

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
  String get taskDetailClose => 'Details schließen';

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
    return 'Die App speichert alles von $host auf diesem Gerät, damit sie auch offline funktioniert.';
  }

  @override
  String get firstSyncPreparing => 'Wird vorbereitet …';

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
  String get syncIndicatorLabel => 'Wird mit dem Server synchronisiert';

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
  String get accountSyncing => 'Wird synchronisiert …';

  @override
  String get accountSyncFailed =>
      'Die letzte Synchronisierung ist fehlgeschlagen.';

  @override
  String get accountSyncNow => 'Jetzt synchronisieren';

  @override
  String get accountFullResync => 'Alles neu laden';

  @override
  String accountBackgroundSync(String when) {
    return 'Hintergrundsynchronisierung: $when';
  }

  @override
  String get accountBackgroundSyncJustNow =>
      'Hintergrundsynchronisierung: gerade eben';

  @override
  String get accountBackgroundSyncNever =>
      'Die Hintergrundsynchronisierung lief noch nicht';

  @override
  String get accountBackgroundSyncIosHint =>
      'iOS entscheidet, wann Apps im Hintergrund synchronisieren dürfen.';

  @override
  String get taskMarkDone => 'Als erledigt markieren';

  @override
  String get taskMarkNotDone => 'Als nicht erledigt markieren';

  @override
  String get taskMarkedDone => 'Als erledigt markiert';

  @override
  String get undo => 'Rückgängig';

  @override
  String get taskAddFavourite => 'Zu Favoriten hinzufügen';

  @override
  String get taskRemoveFavourite => 'Aus Favoriten entfernen';

  @override
  String get taskNotYetSynced => 'Noch nicht synchronisiert';

  @override
  String get taskDelete => 'Aufgabe löschen';

  @override
  String get taskDeleteDialogTitle => 'Aufgabe löschen?';

  @override
  String taskDeleteDialogBody(String title) {
    return '„$title“ wird auch auf dem Server gelöscht. Das lässt sich nicht rückgängig machen.';
  }

  @override
  String taskDeleteDialogBodyTrash(String title) {
    return '„$title“ wird in den Papierkorb verschoben, für alle. Im Tab „Konto“ lässt sich die Aufgabe 30 Tage lang aus dem Papierkorb wiederherstellen.';
  }

  @override
  String taskDeleteDialogBodyTrashGuest(String title) {
    return '„$title“ wird in den Papierkorb verschoben, für alle. Von dort lässt sich die Aufgabe 30 Tage lang wiederherstellen.';
  }

  @override
  String taskDeleteDialogBodyUnsent(String title) {
    return '„$title“ ist noch nicht beim Server angekommen. Die Aufgabe wird gelöscht und kommt nicht in den Papierkorb.';
  }

  @override
  String get taskDeleteDialogCancel => 'Abbrechen';

  @override
  String get taskDeleteDialogConfirm => 'Löschen';

  @override
  String get taskDeleted => 'Aufgabe gelöscht';

  @override
  String get taskMovedToTrash => 'Aufgabe in den Papierkorb verschoben';

  @override
  String get taskRestored => 'Aufgabe wiederhergestellt';

  @override
  String accountPendingChanges(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Ausstehende Änderungen: $countString';
  }

  @override
  String get accountSendNow => 'Jetzt senden';

  @override
  String get accountSending => 'Wird gesendet …';

  @override
  String accountSendNowFailed(String reason) {
    return 'Nicht gesendet. $reason';
  }

  @override
  String get accountSyncProblems => 'Synchronisierungsprobleme';

  @override
  String get syncProblemUpdateFailed =>
      'Die Änderung konnte nicht gespeichert werden.';

  @override
  String get syncProblemDeleteFailed =>
      'Die Aufgabe konnte nicht gelöscht werden.';

  @override
  String get syncProblemForbidden =>
      'Du hast keinen Zugriff mehr auf das Projekt der Aufgabe.';

  @override
  String get syncProblemProjectMissing =>
      'Das Projekt der Aufgabe gibt es auf dem Server nicht mehr.';

  @override
  String get syncProblemProjectInTrash =>
      'Das Projekt der Aufgabe ist auf dem Server im Papierkorb.';

  @override
  String get syncProblemTaskMissing =>
      'Die Aufgabe gibt es auf dem Server nicht mehr.';

  @override
  String get syncProblemTaskInTrash =>
      'Die Aufgabe ist auf dem Server im Papierkorb.';

  @override
  String get syncProblemLabelMissing =>
      'Eines ihrer Labels gibt es auf dem Server nicht mehr.';

  @override
  String get syncProblemUserMissing =>
      'Eine der zugewiesenen Personen gibt es auf dem Server nicht mehr.';

  @override
  String get syncProblemProjectArchived =>
      'Das Projekt der Aufgabe ist archiviert.';

  @override
  String get syncProblemRelatedTaskMissing =>
      'Eine verknüpfte Aufgabe gibt es auf dem Server nicht mehr.';

  @override
  String get syncProblemRelationCycle =>
      'Die Verknüpfung würde einen Kreis aus Aufgaben ergeben.';

  @override
  String get syncProblemRelationToItself =>
      'Eine Aufgabe kann nicht mit sich selbst verknüpft werden.';

  @override
  String get syncProblemColumnFull => 'Diese Spalte ist voll.';

  @override
  String get syncProblemColumnMissing => 'Die Spalte gibt es nicht mehr.';

  @override
  String get syncProblemListNotReorderable =>
      'Diese Liste kann nicht umsortiert werden.';

  @override
  String get syncProblemListMissing => 'Die Liste gibt es nicht mehr.';

  @override
  String get syncProblemRejected => 'Der Server hat die Änderung abgelehnt.';

  @override
  String get syncProblemUnexpected => 'Der Server hat unerwartet geantwortet.';

  @override
  String syncProblemFailedAt(String when) {
    return 'Fehlgeschlagen $when';
  }

  @override
  String get syncProblemFailedJustNow => 'Gerade eben fehlgeschlagen';

  @override
  String get syncProblemDiscard => 'Verwerfen';

  @override
  String get syncProblemCreateFailed =>
      'Die Aufgabe konnte nicht erstellt werden.';

  @override
  String get taskEdit => 'Bearbeiten';

  @override
  String get taskEditTitle => 'Aufgabe bearbeiten';

  @override
  String get taskEditSave => 'Speichern';

  @override
  String get taskEditSaved => 'Gespeichert';

  @override
  String get taskEditLoading => 'Aufgabe wird geladen …';

  @override
  String get taskEditGoneTitle => 'Aufgabe nicht gefunden';

  @override
  String get taskEditGoneBody =>
      'Diese Aufgabe gibt es auf diesem Gerät nicht mehr.';

  @override
  String get taskEditTitleLabel => 'Titel';

  @override
  String get taskEditTitleRequired => 'Gib einen Titel ein.';

  @override
  String get taskEditProject => 'Projekt';

  @override
  String get taskEditProjectPickerTitle => 'Projekt wählen';

  @override
  String taskEditProjectSemantics(String project) {
    return 'Projekt: $project';
  }

  @override
  String get taskEditDateNotSet => 'Nicht festgelegt';

  @override
  String get taskEditClearDueDate => 'Fälligkeitsdatum entfernen';

  @override
  String get taskEditClearStartDate => 'Startdatum entfernen';

  @override
  String get taskEditClearEndDate => 'Enddatum entfernen';

  @override
  String get shortcutToday => 'Heute';

  @override
  String get shortcutTomorrow => 'Morgen';

  @override
  String get shortcutNextMonday => 'Nächster Montag';

  @override
  String get shortcutThisWeekend => 'Dieses Wochenende';

  @override
  String get shortcutLaterThisWeek => 'Später diese Woche';

  @override
  String get shortcutNextWeek => 'Nächste Woche';

  @override
  String get shortcutNextWeekend => 'Nächstes Wochenende';

  @override
  String get shortcutEndOfMonth => 'Monatsende';

  @override
  String get shortcutInAMonth => 'In einem Monat';

  @override
  String shortcutSemantics(String label, String date) {
    return '$label, $date';
  }

  @override
  String shortcutAtTime(String label, String time) {
    return '$label um $time';
  }

  @override
  String get taskEditColour => 'Farbe';

  @override
  String get taskEditNoColour => 'Keine Farbe';

  @override
  String taskEditColourSemantics(String hex) {
    return 'Farbe $hex';
  }

  @override
  String get taskEditRepeat => 'Wiederholung';

  @override
  String get repeatModeNone => 'Nie';

  @override
  String get repeatModeEvery => 'Alle …';

  @override
  String get repeatModeMonthly => 'Monatlich';

  @override
  String get repeatModeFromCompletion => 'Ab Erledigung';

  @override
  String get repeatAmountLabel => 'Alle';

  @override
  String get repeatAmountInvalid => 'Gib mehr als 0 ein.';

  @override
  String get repeatUnitHours => 'Stunden';

  @override
  String get repeatUnitDays => 'Tage';

  @override
  String get repeatUnitWeeks => 'Wochen';

  @override
  String get repeatPresetDaily => 'Jeden Tag';

  @override
  String get repeatPresetWeekly => 'Jede Woche';

  @override
  String get repeatPresetThirtyDays => 'Alle 30 Tage';

  @override
  String get taskEditDiscardTitle => 'Änderungen verwerfen?';

  @override
  String get taskEditDiscardBody =>
      'Deine Änderungen an dieser Aufgabe gehen verloren.';

  @override
  String get taskEditKeepEditing => 'Weiter bearbeiten';

  @override
  String get taskEditDiscard => 'Verwerfen';

  @override
  String get pickerDone => 'Fertig';

  @override
  String get pickerCancel => 'Abbrechen';

  @override
  String get newTask => 'Neue Aufgabe';

  @override
  String get newTaskTitleHint => 'Was ist zu tun?';

  @override
  String get newTaskAdd => 'Hinzufügen';

  @override
  String get newTaskMoreOptions => 'Mehr Optionen';

  @override
  String get newTaskFewerOptions => 'Weniger Optionen';

  @override
  String get newTaskPickDate => 'Datum wählen …';

  @override
  String get newTaskNoProject => 'Kein Projekt';

  @override
  String newTaskCreated(String title) {
    return '„$title“ hinzugefügt';
  }

  @override
  String newTaskAddMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben hinzufügen',
      one: '1 Aufgabe hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String newTaskCreatedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben hinzugefügt',
      one: '1 Aufgabe hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String newTaskLabelsNotCreated(String labels) {
    return 'Diese Labels konnten nicht erstellt werden und fehlen deshalb: $labels';
  }

  @override
  String newTaskNamesKept(String names) {
    return 'Für $names wurde niemand gefunden; der Text bleibt im Titel.';
  }

  @override
  String get newTaskNoProjectError =>
      'Es gibt noch kein Projekt für neue Aufgaben. Erstelle zuerst eins im Tab „Projekte“.';

  @override
  String newTaskAddFailed(String reason) {
    return 'Die Aufgabe konnte nicht hinzugefügt werden: $reason';
  }

  @override
  String get newTaskAddFailedUnknown =>
      'Die Aufgabe konnte nicht hinzugefügt werden.';

  @override
  String newTaskLineCountOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben, eine pro Zeile',
      one: '1 Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String newTaskAddedPartly(int added, int total) {
    return '$added von $total Aufgaben wurden hinzugefügt; die übrigen stehen noch hier.';
  }

  @override
  String newTaskLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben, eine pro Zeile',
      one: '1 Aufgabe',
    );
    return '$_temp0 · die erste:';
  }

  @override
  String quickAddMagicOnly(String title) {
    return 'Nur magische Wörter, deshalb wird nichts erkannt: Die Aufgabe heißt dann „$title“.';
  }

  @override
  String quickAddDueLabel(String date, String relative) {
    return '$date · $relative';
  }

  @override
  String quickAddDueSemantics(String date, String relative) {
    return 'Fällig $date, $relative';
  }

  @override
  String quickAddRepeatSemantics(String repeat) {
    return 'Wiederholung: $repeat';
  }

  @override
  String quickAddProjectAmbiguous(String project) {
    return 'Mehrere Projekte heißen „$project“. Entferne es und wähle das Projekt unten.';
  }

  @override
  String quickAddProjectNotFound(String project) {
    return 'Projekt „$project“ nicht gefunden';
  }

  @override
  String quickAddNewLabel(String label) {
    return '$label · neu';
  }

  @override
  String quickAddNewLabelSemantics(String label) {
    return 'Neues Label $label, wird beim Hinzufügen erstellt';
  }

  @override
  String quickAddAssigneeSemantics(String name) {
    return 'Zugewiesen an $name';
  }

  @override
  String quickAddLookedUp(String name) {
    return '$name · wird gesucht';
  }

  @override
  String quickAddLookedUpSemantics(String name) {
    return '$name, wird beim Hinzufügen gesucht';
  }

  @override
  String quickAddReminderSemantics(String reminder) {
    return 'Erinnerung: $reminder';
  }

  @override
  String quickAddRemovePart(String part) {
    return '$part entfernen';
  }

  @override
  String get quickAddSuggestions => 'Vorschläge';

  @override
  String get quickAddHelp => 'So funktioniert Quick Add Magic';

  @override
  String get quickAddHelpTitle => 'Quick Add Magic';

  @override
  String get quickAddHelpIntro =>
      'Schreib die ganze Aufgabe in eine Zeile. Diese Teile werden erkannt, farbig markiert und aus dem Titel genommen:';

  @override
  String get quickAddHelpLabelsTitle => 'Labels';

  @override
  String quickAddHelpLabelsBody(String prefix) {
    return 'Ein Wort, das mit $prefix beginnt. Labels, die es noch nicht gibt, werden beim Hinzufügen erstellt; ohne Verbindung bleibt das Wort im Titel. Für Leerzeichen nimm Anführungszeichen.';
  }

  @override
  String get quickAddHelpProjectTitle => 'Projekt';

  @override
  String quickAddHelpProjectBody(String prefix) {
    return '$prefix und Titel oder Bezeichner eines Projekts. Ohne Angabe landet die Aufgabe im Projekt, das unter dem Feld steht.';
  }

  @override
  String get quickAddHelpPriorityTitle => 'Priorität';

  @override
  String quickAddHelpPriorityBody(String prefix) {
    return '$prefix und eine Zahl von 1 (niedrig) bis 5 (sofort).';
  }

  @override
  String get quickAddHelpPeopleTitle => 'Personen';

  @override
  String quickAddHelpPeopleBody(String prefix) {
    return '$prefix und ein Benutzername oder Name. Wer nicht gefunden wird, bleibt im Titel.';
  }

  @override
  String get quickAddHelpDatesTitle => 'Datum und Uhrzeit';

  @override
  String get quickAddHelpDatesBody => 'Zum Beispiel:';

  @override
  String get quickAddHelpTimesBody => 'Eine Uhrzeit hängst du mit „at“ an:';

  @override
  String get quickAddHelpRepeatsTitle => 'Wiederholungen';

  @override
  String get quickAddHelpRepeatsBody =>
      'Eine Wiederholung ohne Datum macht die Aufgabe heute fällig.';

  @override
  String get quickAddHelpEnglish =>
      'Wörter für Datum und Wiederholung sind immer Englisch, wie im Web.';

  @override
  String get quickAddHelpMoreTitle => 'Gut zu wissen';

  @override
  String get quickAddHelpQuotes =>
      'Setz den ganzen Titel in Anführungszeichen, um die Magie für eine Aufgabe auszuschalten.';

  @override
  String get quickAddHelpLines =>
      'Füg mehrere Zeilen ein, um pro Zeile eine Aufgabe zu erstellen.';

  @override
  String get quickAddHelpExampleTitle => 'Beispiel';

  @override
  String get quickAddHelpExampleTask => 'Reifen wechseln';

  @override
  String get quickAddHelpExampleLabel => 'Auto';

  @override
  String get quickAddHelpExampleProject => 'Zuhause';

  @override
  String quickAddHelpMode(String mode) {
    return 'Das sind die $mode-Präfixe, wie in deinen Kontoeinstellungen festgelegt.';
  }

  @override
  String get taskEditAddLabel => 'Label hinzufügen';

  @override
  String taskEditRemoveLabel(String label) {
    return 'Label $label entfernen';
  }

  @override
  String get taskEditAssign => 'Zuweisen';

  @override
  String taskEditUnassign(String name) {
    return 'Zuweisung an $name aufheben';
  }

  @override
  String get taskEditAddReminder => 'Erinnerung hinzufügen';

  @override
  String get taskEditEditReminder => 'Erinnerung bearbeiten';

  @override
  String taskEditRemoveReminder(String reminder) {
    return 'Erinnerung entfernen: $reminder';
  }

  @override
  String get taskEditReminderDuplicate => 'Diese Erinnerung gibt es schon.';

  @override
  String get reminderDueDateNotSet => 'Kein Fälligkeitsdatum festgelegt';

  @override
  String get reminderStartDateNotSet => 'Kein Startdatum festgelegt';

  @override
  String get reminderEndDateNotSet => 'Kein Enddatum festgelegt';

  @override
  String get taskEditRemindersCoincide =>
      'Einige Erinnerungen fallen auf denselben Zeitpunkt. Der Server behält nur eine davon.';

  @override
  String get labelPickerTitle => 'Labels wählen';

  @override
  String get labelPickerSearch => 'Label suchen oder erstellen';

  @override
  String get labelPickerEmpty =>
      'Noch keine Labels. Gib einen Namen ein, um eins zu erstellen.';

  @override
  String labelPickerCreate(String title) {
    return 'Label „$title“ erstellen';
  }

  @override
  String get labelPickerCreating => 'Label wird erstellt …';

  @override
  String get labelPickerCreateUnconfirmed =>
      'Ob das Label erstellt wurde, ließ sich nicht bestätigen. Prüf deine Verbindung und versuch es noch einmal.';

  @override
  String labelPickerCreateRejected(String message) {
    return 'Der Server hat das Label nicht erstellt: $message';
  }

  @override
  String get labelPickerCreateFailed =>
      'Das Label konnte nicht erstellt werden.';

  @override
  String labelPickerTitleTooLong(int max) {
    return 'Ein Label-Titel darf höchstens $max Zeichen haben.';
  }

  @override
  String get assigneePickerTitle => 'Personen zuweisen';

  @override
  String get assigneePickerSearch => 'Personen suchen';

  @override
  String get assigneePickerSearching => 'Suche läuft …';

  @override
  String get assigneePickerNoResults => 'Niemand gefunden.';

  @override
  String get assigneePickerOffline =>
      'Offline – du siehst Personen aus deinen synchronisierten Aufgaben';

  @override
  String assigneePickerFallback(String reason) {
    return '$reason – du siehst Personen aus deinen synchronisierten Aufgaben';
  }

  @override
  String get assigneePickerSearchFailed => 'Suche fehlgeschlagen';

  @override
  String assigneeUsername(String username) {
    return '@$username';
  }

  @override
  String get reminderPickerCustom => 'Eigene Erinnerung …';

  @override
  String get reminderPickerDateTime => 'Datum und Uhrzeit …';

  @override
  String get reminderPickerAlreadySet => 'Schon vorhanden';

  @override
  String get reminderPickerNoDateHint =>
      'Leg ein Fälligkeits-, Start- oder Enddatum fest, um hier eine schnelle Auswahl zu bekommen.';

  @override
  String get reminderPickerCustomTitle => 'Eigene Erinnerung';

  @override
  String get reminderAmountLabel => 'Anzahl';

  @override
  String get reminderAmountInvalid => 'Gib eine ganze Zahl ab 0 ein.';

  @override
  String get reminderUnitCaption => 'Einheit';

  @override
  String get reminderDirectionCaption => 'Wann';

  @override
  String get reminderUnitMinutes => 'Minuten';

  @override
  String get reminderUnitHours => 'Stunden';

  @override
  String get reminderUnitDays => 'Tage';

  @override
  String get reminderUnitWeeks => 'Wochen';

  @override
  String get reminderDirectionBefore => 'Vorher';

  @override
  String get reminderDirectionAfter => 'Nachher';

  @override
  String get reminderRelativeToLabel => 'Bezogen auf';

  @override
  String get reminderRelativeToDueDate => 'Fälligkeitsdatum';

  @override
  String get reminderRelativeToStartDate => 'Startdatum';

  @override
  String get reminderRelativeToEndDate => 'Enddatum';

  @override
  String reminderRelativeToUnset(String date) {
    return '$date (nicht festgelegt)';
  }

  @override
  String get inboxTitle => 'Benachrichtigungen';

  @override
  String inboxButton(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Benachrichtigungen, $countString ungelesen',
      one: 'Benachrichtigungen, 1 ungelesen',
      zero: 'Benachrichtigungen',
    );
    return '$_temp0';
  }

  @override
  String get inboxLoading => 'Benachrichtigungen werden geladen …';

  @override
  String get inboxEmptyTitle => 'Du bist auf dem neuesten Stand';

  @override
  String get inboxEmptyBody =>
      'Kommentare, Zuweisungen und Erwähnungen von deinem Vikunja-Server erscheinen hier.';

  @override
  String get inboxMarkAllRead => 'Alle als gelesen markieren';

  @override
  String get inboxToday => 'Heute';

  @override
  String get inboxYesterday => 'Gestern';

  @override
  String get inboxEarlier => 'Früher';

  @override
  String get inboxUnread => 'Ungelesen';

  @override
  String get inboxTaskNotLocal => 'Diese Aufgabe ist nicht auf diesem Gerät';

  @override
  String get inboxProjectNotLocal =>
      'Dieses Projekt ist nicht auf diesem Gerät';

  @override
  String get inboxSomeone => 'Jemand';

  @override
  String get inboxATask => 'eine Aufgabe';

  @override
  String get inboxUnnamed => 'ohne Namen';

  @override
  String inboxCommented(String doer, String task) {
    return '$doer hat $task kommentiert';
  }

  @override
  String inboxAssignedYou(String doer, String task) {
    return '$doer hat dir $task zugewiesen';
  }

  @override
  String inboxAssigned(String doer, String assignee, String task) {
    return '$doer hat $assignee $task zugewiesen';
  }

  @override
  String inboxAssignedSomeone(String doer, String task) {
    return '$doer hat $task jemandem zugewiesen';
  }

  @override
  String inboxMentioned(String doer, String task) {
    return '$doer hat dich in $task erwähnt';
  }

  @override
  String inboxTaskCreated(String doer, String task) {
    return '$doer hat $task erstellt';
  }

  @override
  String inboxTaskDeleted(String doer, String task) {
    return '$doer hat $task gelöscht';
  }

  @override
  String inboxProjectCreated(String doer, String project) {
    return '$doer hat $project erstellt';
  }

  @override
  String inboxAddedYouToTeam(String doer, String team) {
    return '$doer hat dich zum Team $team hinzugefügt';
  }

  @override
  String inboxAddedToTeam(String doer, String member, String team) {
    return '$doer hat $member zum Team $team hinzugefügt';
  }

  @override
  String inboxAddedSomeoneToTeam(String doer, String team) {
    return '$doer hat jemanden zum Team $team hinzugefügt';
  }

  @override
  String get inboxTaskWasDeleted => 'Diese Aufgabe wurde gelöscht';

  @override
  String inboxReminder(String task) {
    return 'Erinnerung an $task';
  }

  @override
  String get inboxOther => 'Neue Benachrichtigung';

  @override
  String inboxQuoted(String text) {
    return '„$text“';
  }

  @override
  String get notificationSetupTitle => 'Behalte deine Aufgaben im Blick';

  @override
  String get notificationSetupBody =>
      'Die App kann dich auf diesem Gerät benachrichtigen, ohne dass der Server etwas senden muss:';

  @override
  String get notificationSetupReminders => 'Erinnerungen zu ihrer Zeit';

  @override
  String get notificationSetupDueDates => 'Fälligkeiten zur genauen Uhrzeit';

  @override
  String get notificationSetupOnlyYours =>
      'Nur für Aufgaben, die du erstellt hast oder die dir zugewiesen sind';

  @override
  String get notificationSetupFollowed =>
      'Nur für Aufgaben, denen du folgst – du folgst automatisch allen, die du erstellst oder die dir zugewiesen werden';

  @override
  String get notificationSetupTurnOn => 'Benachrichtigungen einschalten';

  @override
  String get notificationSetupNotNow => 'Jetzt nicht';

  @override
  String get notificationSetupExactTitle => 'Erinnerungen auf die Minute';

  @override
  String get notificationSetupExactBody =>
      'Ohne genaue Alarme zeigt Android Erinnerungen unter Umständen Minuten zu spät. Du kannst sie in den Systemeinstellungen erlauben; die App funktioniert so oder so.';

  @override
  String get notificationSetupExactAllow => 'Genaue Alarme erlauben';

  @override
  String get notificationSetupSkip => 'Überspringen';

  @override
  String get notificationsHeading => 'Benachrichtigungen';

  @override
  String get notificationsForFollowedTasks =>
      'Erinnerungen und Fälligkeiten bekommst du zu den Aufgaben, denen du folgst: zu denen, die du erstellst oder die dir zugewiesen werden, und zu denen in Projekten, denen du folgst. Folge einer Aufgabe nicht mehr, um ihre Benachrichtigungen abzuschalten.';

  @override
  String get notificationsForOwnTasks =>
      'Erinnerungen und Fälligkeiten bekommst du zu den Aufgaben, die du erstellt hast oder die dir zugewiesen sind.';

  @override
  String get notificationsReminders => 'Erinnerungen';

  @override
  String get notificationsRemindersSubtitle => 'Zum Zeitpunkt jeder Erinnerung';

  @override
  String get notificationsDueDates => 'Fälligkeiten';

  @override
  String get notificationsDueDatesSubtitle => 'Zur genauen Fälligkeitszeit';

  @override
  String get notificationsActivity => 'Aktivitäten';

  @override
  String get notificationsActivitySubtitle =>
      'Kommentare, Zuweisungen und Erwähnungen';

  @override
  String get notificationsOff => 'Benachrichtigungen sind aus';

  @override
  String get notificationsOpenSettings => 'Einstellungen öffnen';

  @override
  String get notificationsTurnOn => 'Einschalten';

  @override
  String get notificationsMayBeLate => 'Erinnerungen können sich verspäten';

  @override
  String get notificationsAllowExactAlarms => 'Genaue Alarme erlauben';

  @override
  String notificationsScheduled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count geplant',
      one: '1 geplant',
      zero: 'Nichts geplant',
    );
    return '$_temp0';
  }

  @override
  String get notificationsSendTest => 'Testbenachrichtigung senden';

  @override
  String get notificationTestTitle => 'Testbenachrichtigung';

  @override
  String get notificationTestBody =>
      'Die Benachrichtigungen der App funktionieren auf diesem Gerät.';

  @override
  String get notificationTaskGone => 'Diese Aufgabe gibt es nicht mehr';

  @override
  String get notificationTestReceived => 'Benachrichtigungen funktionieren';

  @override
  String get notificationChannelReminders => 'Erinnerungen';

  @override
  String get notificationChannelRemindersDescription =>
      'Erinnerungen und Fälligkeiten deiner Aufgaben';

  @override
  String get notificationChannelActivity => 'Aktivitäten';

  @override
  String get notificationChannelActivityDescription =>
      'Kommentare, Zuweisungen und Erwähnungen von deinen Vikunja-Servern';

  @override
  String activityNotificationCommented(String name, String comment) {
    return '$name hat kommentiert: $comment';
  }

  @override
  String activityNotificationCommentedNoText(String name) {
    return '$name hat kommentiert';
  }

  @override
  String activityNotificationAssignedYou(String name) {
    return '$name hat dir diese Aufgabe zugewiesen';
  }

  @override
  String activityNotificationAssignedOther(String name, String assignee) {
    return '$name hat diese Aufgabe $assignee zugewiesen';
  }

  @override
  String activityNotificationAssignedSomeone(String name) {
    return '$name hat diese Aufgabe jemandem zugewiesen';
  }

  @override
  String activityNotificationMentioned(String name) {
    return '$name hat dich erwähnt';
  }

  @override
  String activityNotificationTaskCreated(String name, String project) {
    return '$name hat diese Aufgabe in $project erstellt';
  }

  @override
  String activityNotificationTaskCreatedNoProject(String name) {
    return '$name hat diese Aufgabe erstellt';
  }

  @override
  String activityNotificationTaskDeleted(String name) {
    return '$name hat diese Aufgabe gelöscht';
  }

  @override
  String activityNotificationProjectCreated(String name, String project) {
    return '$name hat das Projekt $project erstellt';
  }

  @override
  String activityNotificationTeamAddedYou(String name, String team) {
    return '$name hat dich zum Team $team hinzugefügt';
  }

  @override
  String activityNotificationTeamAddedOther(
    String name,
    String member,
    String team,
  ) {
    return '$name hat $member zum Team $team hinzugefügt';
  }

  @override
  String activityNotificationTeamAddedSomeone(String name, String team) {
    return '$name hat jemanden zum Team $team hinzugefügt';
  }

  @override
  String get activityNotificationMoreTitle => 'Weitere Aktivitäten';

  @override
  String activityNotificationMoreBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere neue Benachrichtigungen',
      one: '1 weitere neue Benachrichtigung',
    );
    return '$_temp0';
  }

  @override
  String get activityNotificationUntitled => 'Vikunja';

  @override
  String sessionEndedNotificationTitle(String host) {
    return 'Melde dich wieder bei $host an';
  }

  @override
  String sessionEndedNotificationBody(String username) {
    return 'Deine Sitzung als $username ist beendet. Die App kann dieses Konto erst wieder synchronisieren, wenn du dich neu anmeldest.';
  }

  @override
  String get notificationActionDone => 'Erledigt';

  @override
  String get notificationActionSnooze10Minutes => '10 Min. später';

  @override
  String get notificationActionSnooze1Hour => '1 Std. später';

  @override
  String notificationReminderBody(String project) {
    return 'Erinnerung · $project';
  }

  @override
  String get notificationReminderBodyNoProject => 'Erinnerung';

  @override
  String notificationDueBody(String project) {
    return 'Jetzt fällig · $project';
  }

  @override
  String get notificationDueBodyNoProject => 'Jetzt fällig';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get taskDetailSubtasks => 'Unteraufgaben';

  @override
  String taskDetailSubtasksDone(int done, int total) {
    return '$done von $total erledigt';
  }

  @override
  String get taskDetailAddSubtask => 'Unteraufgabe hinzufügen';

  @override
  String get taskDetailAddSubtaskFailed =>
      'Die Unteraufgabe konnte nicht hinzugefügt werden';

  @override
  String get taskDetailSubtaskNotLinked =>
      'Die Aufgabe wurde hinzugefügt, aber nicht als Unteraufgabe';

  @override
  String get taskDetailParentTask => 'Übergeordnete Aufgabe';

  @override
  String get taskDetailRelatedTasks => 'Verknüpfte Aufgaben';

  @override
  String get taskDetailAddRelation => 'Verknüpfung hinzufügen';

  @override
  String get taskRelationSubtask => 'Unteraufgabe';

  @override
  String get taskRelationParentTask => 'Übergeordnete Aufgabe';

  @override
  String get taskRelationRelated => 'Verwandt mit';

  @override
  String get taskRelationBlocking => 'Blockierend';

  @override
  String get taskRelationBlocked => 'Blockiert durch';

  @override
  String get taskRelationPrecedes => 'Geht voraus';

  @override
  String get taskRelationFollows => 'Folgt auf';

  @override
  String get taskRelationDuplicateOf => 'Duplikat von';

  @override
  String get taskRelationDuplicates => 'Dupliziert durch';

  @override
  String get taskRelationCopiedFrom => 'Kopiert von';

  @override
  String get taskRelationCopiedTo => 'Kopiert nach';

  @override
  String get taskRelationRemove => 'Verknüpfung entfernen';

  @override
  String get taskRelationRemoveTitle => 'Verknüpfung entfernen?';

  @override
  String taskRelationRemoveBody(String title) {
    return 'Die Verknüpfung mit „$title“ wird auch auf dem Server entfernt. Die Aufgabe selbst bleibt.';
  }

  @override
  String get taskRelationRemoveConfirm => 'Entfernen';

  @override
  String get addRelationKind => 'Art der Verknüpfung';

  @override
  String get addRelationSearch => 'Nach Titel suchen';

  @override
  String get addRelationShowDone => 'Erledigte Aufgaben anzeigen';

  @override
  String get addRelationNoMatches => 'Keine passenden Aufgaben';

  @override
  String get taskDuplicate => 'Duplizieren';

  @override
  String get taskDuplicated => 'Dupliziert';

  @override
  String get taskDuplicateOpen => 'Öffnen';

  @override
  String get taskDuplicateNeedsConnection =>
      'Zum Duplizieren brauchst du eine Verbindung zum Server.';

  @override
  String get taskDuplicateNotSynced =>
      'Du kannst diese Aufgabe duplizieren, sobald ihre Änderungen synchronisiert sind.';

  @override
  String taskDuplicateFailed(String message) {
    return 'Die Aufgabe konnte nicht dupliziert werden: $message';
  }

  @override
  String get taskDuplicateFailedUnknown =>
      'Die Aufgabe konnte nicht dupliziert werden.';

  @override
  String get followTask => 'Aufgabe folgen';

  @override
  String get unfollowTask => 'Aufgabe nicht mehr folgen';

  @override
  String get followProject => 'Projekt folgen';

  @override
  String get unfollowProject => 'Projekt nicht mehr folgen';

  @override
  String get followNeedsConnection =>
      'Zum Folgen brauchst du eine Verbindung zum Server.';

  @override
  String get followFailed =>
      'Das Folgen ließ sich nicht ändern. Versuch es noch einmal.';

  @override
  String get followTaskOnceSynced =>
      'Du kannst dieser Aufgabe folgen, sobald sie synchronisiert ist.';

  @override
  String get followTaskUnavailable =>
      'Aufgabe folgen (braucht eine Verbindung)';

  @override
  String get followChecking => 'Wird geprüft, ob du folgst …';

  @override
  String followingViaProject(String project) {
    return 'Du folgst dem Projekt $project';
  }

  @override
  String get followingViaSomeProject => 'Du folgst über ein Projekt';

  @override
  String get followInheritedTaskTitle => 'Dieser Aufgabe nicht mehr folgen?';

  @override
  String followInheritedTaskBody(String project) {
    return 'Du folgst dem Projekt „$project“, zu dem diese Aufgabe gehört. Du bekommst dann zu dieser Aufgabe keine Benachrichtigungen mehr, folgst dem Projekt aber weiter.';
  }

  @override
  String get followInheritedProjectTitle => 'Diesem Projekt nicht mehr folgen?';

  @override
  String followInheritedProjectBody(String project) {
    return 'Du folgst dem übergeordneten Projekt „$project“. Du bekommst dann zu diesem Projekt keine Benachrichtigungen mehr, folgst „$project“ aber weiter.';
  }

  @override
  String get followInheritedConfirm => 'Nicht mehr folgen';

  @override
  String get projectFollowed => 'Du folgst jetzt diesem Projekt';

  @override
  String get projectUnfollowed => 'Du folgst diesem Projekt nicht mehr';

  @override
  String newTaskTreeCount(int count, int subtasks) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '1 Aufgabe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subtasks,
      locale: localeName,
      other: '$subtasks davon als Unteraufgaben',
      one: '1 davon als Unteraufgabe',
    );
    return '$_temp0, $_temp1 · die erste:';
  }

  @override
  String newTaskTreeCountOnly(int count, int subtasks) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '1 Aufgabe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subtasks,
      locale: localeName,
      other: '$subtasks davon als Unteraufgaben',
      one: '1 davon als Unteraufgabe',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get tabUpcoming => 'Anstehend';

  @override
  String get upcomingEmptyTitle => 'Nichts fällig – genieß den Tag!';

  @override
  String get upcomingEmptyBody =>
      'In diesem Zeitraum ist keine offene Aufgabe fällig.';

  @override
  String get upcomingShowOverdue => 'Überfällige Aufgaben anzeigen';

  @override
  String get upcomingShowWithoutDate => 'Aufgaben ohne Datum anzeigen';

  @override
  String get upcomingSelectRange => 'Datumsbereich wählen';

  @override
  String get upcomingRangeCustom => 'Benutzerdefiniert';

  @override
  String get upcomingRangeCustomEntry => 'Benutzerdefiniert …';

  @override
  String upcomingRangeDates(String from, String to) {
    return '$from – $to';
  }

  @override
  String upcomingRangeSemantics(String name, String dates) {
    return 'Zeitraum $name, $dates';
  }

  @override
  String get upcomingRangeFrom => 'Von';

  @override
  String get upcomingRangeTo => 'Bis';

  @override
  String get rangeToday => 'Heute';

  @override
  String get rangeTomorrow => 'Morgen';

  @override
  String get rangeLastWeek => 'Letzte Woche';

  @override
  String get rangeThisWeek => 'Diese Woche';

  @override
  String get rangeRestOfThisWeek => 'Der Rest dieser Woche';

  @override
  String get rangeNextWeek => 'Nächste Woche';

  @override
  String get rangeNext7Days => 'Nächste 7 Tage';

  @override
  String get rangeLastMonth => 'Letzter Monat';

  @override
  String get rangeThisMonth => 'Dieser Monat';

  @override
  String get rangeRestOfThisMonth => 'Der Rest dieses Monats';

  @override
  String get rangeNextMonth => 'Nächster Monat';

  @override
  String get rangeNext30Days => 'Nächste 30 Tage';

  @override
  String get rangeThisYear => 'Dieses Jahr';

  @override
  String get rangeRestOfThisYear => 'Der Rest dieses Jahres';

  @override
  String get sectionTomorrow => 'Morgen';

  @override
  String overviewFilterSubtitle(String title) {
    return 'Filter: $title';
  }

  @override
  String get overviewFilterNotLoadedTitle =>
      'Dieser Filter wird geladen, sobald du online bist';

  @override
  String overviewFilterNotLoadedBody(String title) {
    return 'Dein Überblick zeigt den gespeicherten Filter „$title“, den du in deinen Kontoeinstellungen gewählt hast. Seine Aufgaben kommen mit der nächsten Synchronisierung.';
  }

  @override
  String overviewFilterEmptyBody(String title) {
    return 'Der gespeicherte Filter „$title“ hat keine offenen Aufgaben.';
  }

  @override
  String get projectViewList => 'Liste';

  @override
  String get projectViewGantt => 'Gantt';

  @override
  String get projectViewTable => 'Tabelle';

  @override
  String get projectViewKanban => 'Kanban';

  @override
  String get projectViewSwitch => 'Ansicht wechseln';

  @override
  String get projectSort => 'Sortieren';

  @override
  String projectSortCurrent(String sort) {
    return 'Sortiert: $sort';
  }

  @override
  String get sortManual => 'Manuell';

  @override
  String get sortTitleAsc => 'Titel (A–Z)';

  @override
  String get sortTitleDesc => 'Titel (Z–A)';

  @override
  String get sortPriorityDesc => 'Priorität (höchste zuerst)';

  @override
  String get sortPriorityAsc => 'Priorität (niedrigste zuerst)';

  @override
  String get sortDueDateAsc => 'Fälligkeitsdatum (frühestes zuerst)';

  @override
  String get sortDueDateDesc => 'Fälligkeitsdatum (spätestes zuerst)';

  @override
  String get sortStartDateAsc => 'Startdatum (frühestes zuerst)';

  @override
  String get sortStartDateDesc => 'Startdatum (spätestes zuerst)';

  @override
  String get sortEndDateAsc => 'Enddatum (frühestes zuerst)';

  @override
  String get sortEndDateDesc => 'Enddatum (spätestes zuerst)';

  @override
  String get sortPercentDoneDesc => '% erledigt (am meisten erledigt zuerst)';

  @override
  String get sortPercentDoneAsc => '% erledigt (am wenigsten erledigt zuerst)';

  @override
  String get sortCreatedDesc => 'Erstellt (neueste zuerst)';

  @override
  String get sortCreatedAsc => 'Erstellt (älteste zuerst)';

  @override
  String get sortUpdatedDesc => 'Aktualisiert (neueste zuerst)';

  @override
  String get sortUpdatedAsc => 'Aktualisiert (älteste zuerst)';

  @override
  String get projectTasksDoneSection => 'Erledigt';

  @override
  String get projectTasksEmptyDoneTitle => 'Keine erledigten Aufgaben';

  @override
  String get projectTasksEmptyDoneBody =>
      'In dieser Ansicht ist noch nichts erledigt.';

  @override
  String projectViewFilterNotice(String filter, String when) {
    return 'Der Server wendet den Filter „$filter“ dieser Ansicht an. Stand: $when; Änderungen von anderswo erscheinen nach dem nächsten Laden.';
  }

  @override
  String get projectViewNotLoadedTitle =>
      'Diese Ansicht wird geladen, sobald du online bist';

  @override
  String projectViewNotLoadedBody(String filter) {
    return 'Der Server wendet den Filter „$filter“ dieser Ansicht an. Die Aufgaben werden geladen, wenn du die Ansicht online öffnest.';
  }

  @override
  String get projectViewEmptyTitle => 'Keine passenden Aufgaben';

  @override
  String get projectViewEmptyBody =>
      'Beim letzten Laden passte nichts zum Filter dieser Ansicht.';

  @override
  String get taskDoneSemantics => 'Erledigt';

  @override
  String taskAssigneesSemantics(String names) {
    return 'Zugewiesen an $names';
  }

  @override
  String taskMoreAssignees(int count) {
    return '+$count';
  }

  @override
  String taskChecklistProgress(int checked, int total) {
    return '$checked von $total Aufgaben';
  }

  @override
  String taskChecklistAllDone(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total Aufgaben',
      one: '1 Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String get taskHasDescription => 'Hat eine Beschreibung';

  @override
  String get taskRepeats => 'Wiederholt sich';

  @override
  String get savedFilterMyOpenTasks => 'Meine offenen Aufgaben';

  @override
  String get projectInboxTitle => 'Eingang';

  @override
  String get projectFavouritesTitle => 'Favoriten';

  @override
  String overviewFilterNotice(String title, String when) {
    return 'Filter: $title, Stand: $when. Hier erstellte Aufgaben erscheinen nach der nächsten Synchronisierung.';
  }

  @override
  String get overviewFilterNotDownloadedTitle =>
      'Dieser Filter ist noch nicht geladen';

  @override
  String get projectViewDownloadingTitle => 'Diese Ansicht wird geladen …';

  @override
  String projectViewDownloadingBody(String filter) {
    return 'Der Server wendet den Filter „$filter“ dieser Ansicht an. Die Aufgaben sind unterwegs.';
  }

  @override
  String get projectViewDownloadFailedTitle =>
      'Diese Ansicht ließ sich nicht laden';

  @override
  String projectViewDownloadFailedBody(String filter) {
    return 'Der Server wendet den Filter „$filter“ dieser Ansicht an. Zieh nach unten, um es erneut zu versuchen.';
  }

  @override
  String get boardNotLoadedBody =>
      'Spalten und Karten werden geladen, wenn du die Ansicht online öffnest.';

  @override
  String get boardDownloadingBody => 'Spalten und Karten sind unterwegs.';

  @override
  String get boardDownloadFailedBody =>
      'Zieh nach unten, um es erneut zu versuchen.';

  @override
  String get boardNoColumnsTitle => 'Keine Spalten';

  @override
  String get boardNoColumnsBody =>
      'Dieses Board hatte beim letzten Laden keine Spalten.';

  @override
  String get boardFilterColumnsNote =>
      'Die Spalten dieses Boards entstehen aus Filtern, deshalb lassen sich seine Karten hier nicht verschieben.';

  @override
  String get boardDoneColumnHint =>
      'Verschiebst du eine Aufgabe hierher, ist sie damit erledigt.';

  @override
  String boardColumnTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '1 Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String boardColumnTaskCountOfLimit(int count, int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: '$limit Aufgaben',
      one: '1 Aufgabe',
    );
    return '$count von höchstens $_temp0';
  }

  @override
  String get boardColumnFull => 'Voll';

  @override
  String get boardColumnLimitReached =>
      'Diese Spalte ist voll. Um hier eine Aufgabe hinzuzufügen, verschieb eine andere hinaus oder erhöh das Limit der Spalte.';

  @override
  String boardTasksLeftInDefaultColumn(int count, String column) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Aufgaben passten nicht mehr in die Spalte und liegen jetzt in $column.',
      one:
          '1 Aufgabe passte nicht mehr in die Spalte und liegt jetzt in $column.',
    );
    return '$_temp0';
  }

  @override
  String get boardAddTask => 'Eine Aufgabe hinzufügen';

  @override
  String get boardAddAnotherTask => 'Weitere Aufgabe hinzufügen';

  @override
  String get boardLoadMore => 'Mehr laden';

  @override
  String get boardLoadingMore => 'Weitere Aufgaben werden geladen …';

  @override
  String get boardLoadMoreFailed =>
      'Weitere Aufgaben ließen sich nicht laden. Versuch es später erneut.';

  @override
  String boardMoveTo(String column) {
    return 'Nach $column verschieben';
  }

  @override
  String boardMovedTo(String column) {
    return 'Nach $column verschoben';
  }

  @override
  String boardColumnOptionsFor(String column) {
    return 'Optionen für „$column“';
  }

  @override
  String get boardColumnSaving => 'Spalte wird gespeichert …';

  @override
  String get boardColumnRename => 'Umbenennen';

  @override
  String boardColumnLimit(String limit) {
    return 'Limit: $limit';
  }

  @override
  String get boardColumnLimitNotSet => 'Nicht festgelegt';

  @override
  String get boardDoneColumn => 'Erledigt-Spalte';

  @override
  String get boardDoneColumnHintExtended =>
      'Verschiebst du eine Aufgabe in diese Spalte, ist sie damit erledigt, und eine anderswo als erledigt markierte Aufgabe wandert hierher.';

  @override
  String get boardDefaultColumn => 'Standardspalte';

  @override
  String get boardDefaultColumnHint =>
      'Neue Aufgaben ohne eigene Spalte landen hier.';

  @override
  String get boardColumnMoveLeft => 'Nach links verschieben';

  @override
  String get boardColumnMoveRight => 'Nach rechts verschieben';

  @override
  String get boardColumnMovedLeft => 'Spalte nach links verschoben';

  @override
  String get boardColumnMovedRight => 'Spalte nach rechts verschoben';

  @override
  String get boardColumnDelete => 'Löschen';

  @override
  String get boardColumnDeleteLast =>
      'Du kannst die letzte Spalte nicht löschen.';

  @override
  String get boardColumnDeleteMoveTasksFirst =>
      'Verschiebe ihre Aufgaben zuerst in eine andere Spalte: Löschst du die Spalte jetzt, landen sie in keiner Spalte, und nur Projekt-Admins können eine andere Standardspalte festlegen.';

  @override
  String get boardColumnRenameTitle => 'Spalte umbenennen';

  @override
  String get boardColumnTitleLabel => 'Titel';

  @override
  String get boardColumnTitleHint => 'Gib einen Spaltentitel ein …';

  @override
  String get boardColumnTitleEmpty => 'Gib einen Titel ein.';

  @override
  String get boardColumnSave => 'Speichern';

  @override
  String get boardNewColumn => 'Neue Spalte';

  @override
  String get boardNewColumnCreate => 'Erstellen';

  @override
  String get boardCreateColumn => 'Spalte erstellen';

  @override
  String get boardColumnLimitTitle => 'Spaltenlimit';

  @override
  String get boardColumnLimitLabel => 'Limit';

  @override
  String boardColumnLimitHelp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gerade sind $count Aufgaben in dieser Spalte.',
      one: 'Gerade ist 1 Aufgabe in dieser Spalte.',
    );
    return '$_temp0 Lass das Feld leer, wenn die Spalte kein Limit haben soll.';
  }

  @override
  String get boardColumnLimitBelowCount =>
      'Das ist weniger, als sie gerade enthält. Bis Aufgaben herausgenommen werden, nimmt sie keine neuen auf.';

  @override
  String get boardDeleteColumnTitle => 'Spalte löschen?';

  @override
  String boardDeleteColumnBody(String column) {
    return 'Bist du sicher, dass du die Spalte „$column“ löschen möchtest?';
  }

  @override
  String boardDeleteColumnTasksMove(String column) {
    return 'Die Aufgaben darin werden nicht gelöscht, sondern kommen nach „$column“.';
  }

  @override
  String boardDeleteColumnBecomesDefault(String column) {
    return '„$column“ wird zur Standardspalte.';
  }

  @override
  String get boardDeleteColumnConfirm => 'Löschen';

  @override
  String get boardColumnCreated => 'Spalte erstellt';

  @override
  String get boardColumnRenamed => 'Spalte umbenannt';

  @override
  String get boardColumnLimitSaved => 'Spaltenlimit gespeichert';

  @override
  String get boardDoneColumnSaved => 'Erledigt-Spalte gespeichert';

  @override
  String get boardDefaultColumnSaved => 'Standardspalte gespeichert';

  @override
  String get boardColumnDeleted => 'Spalte gelöscht';

  @override
  String get boardColumnNeedsConnection =>
      'Zum Ändern von Spalten brauchst du eine Verbindung zum Server.';

  @override
  String get boardColumnUnconfirmed =>
      'Die Änderung ließ sich nicht bestätigen. Prüf deine Verbindung und zieh nach unten, um das Board neu zu laden.';

  @override
  String get boardColumnAdminOnly =>
      'Nur Projekt-Admins können die Erledigt- oder Standardspalte festlegen.';

  @override
  String boardColumnDeleteFailedNewDefault(String newDefault, String column) {
    return '„$newDefault“ ist jetzt die Standardspalte, aber „$column“ ließ sich nicht löschen.';
  }

  @override
  String boardColumnDeleteNewDefaultGone(String newDefault, String column) {
    return '„$newDefault“ gibt es nicht mehr, deshalb wurde „$column“ nicht gelöscht.';
  }

  @override
  String get boardColumnForbidden =>
      'Du darfst die Spalten dieses Boards nicht ändern.';

  @override
  String get boardColumnLastOne => 'Ein Board braucht mindestens eine Spalte.';

  @override
  String get boardColumnsAtMaximum =>
      'Dieses Board hat schon so viele Spalten, wie der Server erlaubt.';

  @override
  String get boardColumnArchived =>
      'Dieses Projekt ist archiviert, deshalb lassen sich seine Spalten nicht ändern.';

  @override
  String get boardColumnInvalid =>
      'Der Server hat diesen Titel oder dieses Limit nicht angenommen.';

  @override
  String boardColumnChangeRefused(String message) {
    return 'Der Server hat die Änderung abgelehnt: $message';
  }

  @override
  String get boardColumnChangeFailed =>
      'Die Änderung konnte nicht gespeichert werden.';

  @override
  String taskSubtaskOfSemantics(String parent) {
    return 'Unteraufgabe von $parent';
  }

  @override
  String get linkCannotOpen => 'Dieser Link lässt sich nicht öffnen';

  @override
  String get richTextImage => 'Bild';

  @override
  String richTextImageFrom(String host) {
    return 'Bild von $host';
  }

  @override
  String get richTextImageFailed => 'Das Bild konnte nicht geladen werden';

  @override
  String get richTextImageUnsupported =>
      'Dieses Bild kann hier nicht angezeigt werden';

  @override
  String get richTextShowImage => 'Im Vollbild anzeigen';

  @override
  String get richTextOpensInBrowser => 'Öffnet sich im Browser';

  @override
  String richTextReplyTo(String author) {
    return 'Antwort auf $author';
  }

  @override
  String get imageViewerClose => 'Bild schließen';

  @override
  String get taskDetailDetailsOffline =>
      'Anhänge, Kommentare und Reaktionen brauchen eine Verbindung';

  @override
  String get taskDetailDetailsFailed =>
      'Anhänge, Kommentare und Reaktionen konnten nicht geladen werden';

  @override
  String get taskDetailAttachments => 'Anhänge';

  @override
  String get taskDetailCoverImage => 'Titelbild';

  @override
  String get attachmentAdd => 'Anhang hinzufügen';

  @override
  String get attachmentSourceFiles => 'Dateien';

  @override
  String get attachmentSourcePhotos => 'Fotos';

  @override
  String get attachmentSourceCamera => 'Foto aufnehmen';

  @override
  String attachmentTooLarge(String name, String limit) {
    return '„$name“ ist zu groß: Anhänge dürfen höchstens $limit groß sein.';
  }

  @override
  String attachmentsQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien werden hochgeladen',
      one: '1 Datei wird hochgeladen',
    );
    return '$_temp0';
  }

  @override
  String attachmentAddFailed(String name) {
    return '„$name“ konnte nicht hinzugefügt werden.';
  }

  @override
  String get attachmentPickFailed =>
      'Die Dateien konnten nicht geöffnet werden.';

  @override
  String get attachmentUploading => 'Wird hochgeladen …';

  @override
  String get attachmentWaiting => 'Wartet auf das Hochladen';

  @override
  String get attachmentUploadFailed =>
      'Nicht hochgeladen: siehe „Synchronisierungsprobleme“ im Tab „Konto“';

  @override
  String get attachmentUploadTooLarge => 'Nicht hochgeladen: zu groß';

  @override
  String attachmentCancelUpload(String name) {
    return 'Hochladen von $name abbrechen';
  }

  @override
  String attachmentOptions(String name) {
    return 'Optionen für $name';
  }

  @override
  String get attachmentOpen => 'Öffnen';

  @override
  String get attachmentShare => 'Teilen';

  @override
  String get attachmentSaveToDevice => 'Auf dem Gerät speichern';

  @override
  String get attachmentMakeCover => 'Als Titelbild festlegen';

  @override
  String get attachmentRemoveCover => 'Titelbild entfernen';

  @override
  String get attachmentDelete => 'Anhang löschen';

  @override
  String get attachmentDeleteTitle => 'Anhang löschen?';

  @override
  String attachmentDeleteBody(String name) {
    return '„$name“ wird aus dieser Aufgabe gelöscht. Das lässt sich nicht rückgängig machen.';
  }

  @override
  String get attachmentDeleteConfirm => 'Löschen';

  @override
  String get attachmentDeleted => 'Der Anhang wurde gelöscht.';

  @override
  String get attachmentCoverSet => 'Das Titelbild wurde geändert.';

  @override
  String get attachmentCoverRemoved => 'Das Titelbild wurde entfernt.';

  @override
  String get attachmentSaved => 'Gespeichert.';

  @override
  String get attachmentDownloading => 'Wird heruntergeladen …';

  @override
  String get attachmentDeleting => 'Wird gelöscht …';

  @override
  String get attachmentSaving => 'Wird gespeichert …';

  @override
  String attachmentCancelDownload(String name) {
    return 'Herunterladen von $name abbrechen';
  }

  @override
  String get attachmentNoApp =>
      'Keine App auf diesem Gerät kann diese Datei öffnen.';

  @override
  String get attachmentNeedsConnection =>
      'Dafür ist eine Verbindung zum Server nötig.';

  @override
  String get attachmentUnconfirmed =>
      'Die Änderung konnte nicht bestätigt werden. Prüfe die Verbindung und versuche es erneut.';

  @override
  String get attachmentForbidden =>
      'Du darfst die Anhänge dieser Aufgabe nicht ändern.';

  @override
  String get attachmentArchived =>
      'Dieses Projekt ist archiviert, deshalb können seine Anhänge nicht geändert werden.';

  @override
  String get attachmentGone => 'Den Anhang gibt es nicht mehr.';

  @override
  String get attachmentsDisabled =>
      'Anhänge sind auf diesem Server abgeschaltet.';

  @override
  String get attachmentFileTooLarge => 'Die Datei ist zu groß für den Server.';

  @override
  String attachmentFileTooLargeLimit(String limit) {
    return 'Die Datei ist zu groß: Anhänge dürfen höchstens $limit groß sein.';
  }

  @override
  String get attachmentNotSynced =>
      'Das geht, sobald die Aufgabe synchronisiert ist.';

  @override
  String attachmentRefused(String message) {
    return 'Der Server hat abgelehnt: $message';
  }

  @override
  String get attachmentFailed =>
      'Das hat nicht geklappt. Versuche es später erneut.';

  @override
  String get editorImage => 'Bild einfügen';

  @override
  String get editorImageUploading => 'Das Bild wird hochgeladen …';

  @override
  String get editorImageInserted => 'Bild eingefügt';

  @override
  String get shareSignedOut =>
      'Melde dich zuerst bei Vikunja an und teile dann erneut.';

  @override
  String get sharePickAccountTitle => 'In welches Konto teilen?';

  @override
  String get sharePickAccountBody =>
      'Was du teilst, landet auf dem Server dieses Kontos.';

  @override
  String get shareSheetTitle => 'Mit Vikunja teilen';

  @override
  String get shareAddToTask => 'Zu Aufgabe hinzufügen';

  @override
  String get shareFiles => 'Dateien';

  @override
  String shareRemoveFile(String name) {
    return '$name entfernen';
  }

  @override
  String get shareFilePreparing => 'Wird vorbereitet …';

  @override
  String shareFileTooLarge(String limit) {
    return 'Zu groß: Anhänge dürfen höchstens $limit groß sein';
  }

  @override
  String get shareFileUnreadable => 'Konnte nicht gelesen werden';

  @override
  String get shareFilesLeftOut =>
      'Dieser Server nimmt keine Anhänge an, deshalb werden die Dateien weggelassen.';

  @override
  String shareTooManyFiles(int count) {
    return 'Nur die ersten $count Dateien werden hinzugefügt.';
  }

  @override
  String get shareAppendHint =>
      'Der Text kommt ans Ende der Beschreibung der Aufgabe.';

  @override
  String get sharePickTask => 'Wähle eine Aufgabe.';

  @override
  String get shareCreate => 'Aufgabe erstellen';

  @override
  String get shareAdd => 'Hinzufügen';

  @override
  String shareTaskCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aufgabe erstellt, $count Dateien werden hochgeladen',
      one: 'Aufgabe erstellt, 1 Datei wird hochgeladen',
      zero: 'Aufgabe erstellt',
    );
    return '$_temp0';
  }

  @override
  String shareAddedToTask(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zur Aufgabe hinzugefügt, $count Dateien werden hochgeladen',
      one: 'Zur Aufgabe hinzugefügt, 1 Datei wird hochgeladen',
      zero: 'Zur Aufgabe hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get shareFailed => 'Das Geteilte konnte nicht hinzugefügt werden.';

  @override
  String syncProblemUploadFailed(String name) {
    return '„$name“ konnte nicht hochgeladen werden.';
  }

  @override
  String get syncProblemUploadTooLarge => 'Die Datei ist zu groß.';

  @override
  String get syncProblemUploadTimedOut =>
      'Das Hochladen hat mehrmals zu lange gedauert; versuche es mit einer schnelleren Verbindung erneut.';

  @override
  String get syncProblemUploadForbidden =>
      'Du darfst dieser Aufgabe keine Anhänge hinzufügen.';

  @override
  String get syncProblemAttachmentsDisabled =>
      'Anhänge sind auf dem Server abgeschaltet.';

  @override
  String get syncProblemUploadFileMissing =>
      'Die auf diesem Gerät gespeicherte Kopie fehlt; verwirf sie.';

  @override
  String taskDetailComments(int count) {
    return 'Kommentare ($count)';
  }

  @override
  String get taskDetailShowComments => 'Kommentare anzeigen';

  @override
  String get taskDetailMoreComments => 'Weitere Kommentare laden';

  @override
  String get commentsOldestFirst => 'Älteste zuerst';

  @override
  String get commentsNewestFirst => 'Neueste zuerst';

  @override
  String get commentsChangeOrder => 'Reihenfolge ändern';

  @override
  String get commentsLoading => 'Kommentare werden geladen …';

  @override
  String get commentsNeedConnection => 'Kommentare brauchen eine Verbindung';

  @override
  String get commentsFailed => 'Kommentare konnten nicht geladen werden';

  @override
  String commentEdited(String when) {
    return 'bearbeitet $when';
  }

  @override
  String reactionByOne(String user, String reaction) {
    return '$user hat mit $reaction reagiert';
  }

  @override
  String reactionBySeveral(String users, String lastUser, String reaction) {
    return '$users und $lastUser haben mit $reaction reagiert';
  }

  @override
  String reactionByMany(String users, int count, String reaction) {
    return '$users und $count weitere haben mit $reaction reagiert';
  }

  @override
  String taskDetailCreatedBy(String when, String name) {
    return 'Erstellt $when von $name';
  }

  @override
  String taskDetailCreated(String when) {
    return 'Erstellt $when';
  }

  @override
  String taskDetailUpdated(String when) {
    return 'Aktualisiert $when';
  }

  @override
  String taskDetailDoneWhen(String when) {
    return 'Erledigt $when';
  }

  @override
  String get taskDetailOpenProjectHint => 'Öffnet das Projekt';

  @override
  String get taskOpenNotFound => 'Diese Aufgabe wurde nicht gefunden';

  @override
  String get taskOpenInTrash => 'Diese Aufgabe ist im Papierkorb';

  @override
  String get taskOpenProjectInTrash =>
      'Das Projekt dieser Aufgabe ist im Papierkorb';

  @override
  String get trashRestore => 'Wiederherstellen';

  @override
  String get taskOpenForbidden => 'Du hast keinen Zugriff auf diese Aufgabe';

  @override
  String get taskOpenOffline =>
      'Diese Aufgabe ist nicht auf diesem Gerät. Verbinde dich, um sie zu öffnen.';

  @override
  String get taskOpenFailed => 'Diese Aufgabe konnte nicht geöffnet werden';

  @override
  String get deepLinkPickAccountTitle => 'In welchem Konto öffnen?';

  @override
  String get deepLinkPickAccountBody =>
      'Diese Aufgabe ist in mehreren deiner Konten.';

  @override
  String get richTextImageOffline => 'Das Bild braucht eine Verbindung';

  @override
  String commentsLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kommentare geladen',
      one: '1 Kommentar geladen',
      zero: 'Keine weiteren Kommentare',
    );
    return '$_temp0';
  }

  @override
  String get taskOpening => 'Aufgabe wird geöffnet …';

  @override
  String get deepLinkSwitchAccountTitle => 'Konto wechseln?';

  @override
  String get deepLinkSwitchAccountBody =>
      'Diese Aufgabe ist in einem anderen deiner Konten. Wähl es aus, um zu wechseln und die Aufgabe zu öffnen.';

  @override
  String get projectNew => 'Neues Projekt';

  @override
  String get projectCreate => 'Erstellen';

  @override
  String get projectCreating => 'Wird erstellt …';

  @override
  String get projectCreated => 'Projekt erstellt';

  @override
  String get projectTitleLabel => 'Titel';

  @override
  String get projectTitleHint => 'Zum Beispiel Einkäufe';

  @override
  String get projectTitleRequired => 'Gib einen Titel ein.';

  @override
  String get projectParentLabel => 'Übergeordnetes Projekt';

  @override
  String get projectParentTopLevel => 'Keins (oberste Ebene)';

  @override
  String get projectEdit => 'Bearbeiten';

  @override
  String get projectEditTitle => 'Projekt bearbeiten';

  @override
  String get projectSave => 'Speichern';

  @override
  String get projectSaving => 'Wird gespeichert …';

  @override
  String get projectEditSaved => 'Projekt gespeichert';

  @override
  String get projectEditDiscardBody =>
      'Deine Änderungen an diesem Projekt gehen verloren.';

  @override
  String get projectIdentifierLabel => 'Projektbezeichner';

  @override
  String get projectIdentifierHelp =>
      'Bis zu 10 Zeichen, eindeutig auf dem Server. Wird in Aufgabenlinks wie PROJ-12 verwendet. Lass das Feld leer, wenn das Projekt keinen haben soll.';

  @override
  String get projectIdentifierTaken =>
      'Dieser Bezeichner wird schon verwendet. Bezeichner sind auf dem ganzen Server eindeutig.';

  @override
  String get projectIdentifierTakenTrash =>
      'Dieser Bezeichner wird schon verwendet. Bezeichner sind auf dem ganzen Server eindeutig, und ein Projekt im Papierkorb behält seinen Bezeichner 30 Tage lang.';

  @override
  String get projectGoneTitle => 'Dieses Projekt gibt es nicht mehr';

  @override
  String get projectGoneBody =>
      'Vielleicht wurde es gelöscht, hier oder im Web.';

  @override
  String get projectViews => 'Ansichten';

  @override
  String get projectDuplicate => 'Duplizieren';

  @override
  String get projectDuplicateTitle => 'Projekt duplizieren';

  @override
  String get projectDuplicateBody =>
      'Die Kopie bekommt die Aufgaben, Ansichten und Spalten dieses Projekts, aber nicht seine Unterprojekte. Wähl das Projekt, in das sie kommt:';

  @override
  String get projectDuplicateShares => 'Auch die Freigaben kopieren';

  @override
  String get projectDuplicateSharesHint =>
      'Personen, Teams und Linkfreigaben. Jede Linkfreigabe wird zu einem neuen öffentlichen Link auf die Kopie.';

  @override
  String get projectDuplicating => 'Wird dupliziert …';

  @override
  String get projectDuplicated => 'Projekt dupliziert';

  @override
  String get projectArchive => 'Archivieren';

  @override
  String get projectUnarchive => 'Archivierung aufheben';

  @override
  String get projectArchiveTitle => 'Dieses Projekt archivieren?';

  @override
  String get projectUnarchiveTitle => 'Archivierung dieses Projekts aufheben?';

  @override
  String get projectArchiveBody =>
      'Es ist dann schreibgeschützt: keine Änderungen und keine neuen Aufgaben, solange es archiviert ist. Seine Unterprojekte werden ebenfalls archiviert.';

  @override
  String get projectUnarchiveBody =>
      'Du kannst es wieder bearbeiten und Aufgaben darin erstellen. Auch bei seinen Unterprojekten wird die Archivierung aufgehoben.';

  @override
  String get projectArchivedDone => 'Projekt archiviert';

  @override
  String get projectUnarchivedDone => 'Archivierung aufgehoben';

  @override
  String get projectArchiveDefaultHint =>
      'Dein Standardprojekt lässt sich nicht archivieren.';

  @override
  String get projectNewSubproject => 'Neues Unterprojekt';

  @override
  String get projectAddToFavourites => 'Zu Favoriten hinzufügen';

  @override
  String get projectRemoveFromFavourites => 'Aus Favoriten entfernen';

  @override
  String get projectFavourited => 'Zu Favoriten hinzugefügt';

  @override
  String get projectUnfavourited => 'Aus Favoriten entfernt';

  @override
  String get projectDelete => 'Löschen';

  @override
  String projectDeleteTitle(String project) {
    return '„$project“ löschen?';
  }

  @override
  String projectDeleteTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dadurch werden $count Aufgaben gelöscht, für alle.',
      one: 'Dadurch wird 1 Aufgabe gelöscht, für alle.',
      zero: 'Es enthält keine Aufgaben. Es wird für alle gelöscht.',
    );
    return '$_temp0';
  }

  @override
  String projectDeleteTasksAndSubprojects(int tasks, int subprojects) {
    String _temp0 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks Aufgaben',
      one: '1 Aufgabe',
      zero: 'keine Aufgaben',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subprojects,
      locale: localeName,
      other: '$subprojects Unterprojekte',
      one: '1 Unterprojekt',
    );
    return 'Dadurch werden $_temp0 und $_temp1 gelöscht, für alle.';
  }

  @override
  String get projectDeleteCannotBeUndone =>
      'Das lässt sich nicht rückgängig machen.';

  @override
  String projectIncludesDefault(String project) {
    return 'Darunter ist dein Standardprojekt „$project“.';
  }

  @override
  String projectTrashTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Es wird mit $count Aufgaben in den Papierkorb verschoben, für alle.',
      one: 'Es wird mit $count Aufgabe in den Papierkorb verschoben, für alle.',
      zero: 'Es enthält keine Aufgaben. Es wird in den Papierkorb verschoben, für alle.',
    );
    return '$_temp0';
  }

  @override
  String projectTrashTasksAndSubprojects(int tasks, int subprojects) {
    String _temp0 = intl.Intl.pluralLogic(
      subprojects,
      locale: localeName,
      other: '$subprojects Unterprojekten',
      one: '$subprojects Unterprojekt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks Aufgaben',
      one: '$tasks Aufgabe',
      zero: 'keinen Aufgaben',
    );
    return 'Es wird mit $_temp0 und $_temp1 in den Papierkorb verschoben, für alle.';
  }

  @override
  String get projectTrashEverything =>
      'Es wird mit seinen Aufgaben und Unterprojekten in den Papierkorb verschoben, für alle.';

  @override
  String projectTrashIncludesDefault(String project) {
    return 'Darunter ist dein Standardprojekt „$project“. Es ist danach nicht mehr dein Standardprojekt, auch wenn es wiederhergestellt wird.';
  }

  @override
  String get projectTrashRestorable =>
      'Im Tab „Konto“ lässt sich das Projekt 30 Tage lang aus dem Papierkorb wiederherstellen.';

  @override
  String get projectDeleted => 'Projekt gelöscht';

  @override
  String get projectMovedToTrash => 'Projekt in den Papierkorb verschoben';

  @override
  String get projectRestored => 'Projekt wiederhergestellt';

  @override
  String get projectChangeNeedsConnection =>
      'Zum Verwalten von Projekten brauchst du eine Verbindung zum Server.';

  @override
  String get projectChangeUnconfirmed =>
      'Die Änderung ließ sich nicht bestätigen. Prüf deine Verbindung und zieh nach unten, um neu zu laden.';

  @override
  String get projectFormUnconfirmed =>
      'Die Änderung ließ sich nicht bestätigen. Vielleicht ist sie trotzdem angekommen, also prüf das, bevor du es noch einmal versuchst.';

  @override
  String get projectChangeForbidden => 'Du darfst dieses Projekt nicht ändern.';

  @override
  String get projectCreateForbidden =>
      'Du darfst dort kein Projekt hinzufügen.';

  @override
  String get projectDeleteAdminOnly =>
      'Nur Projekt-Admins können ein Projekt löschen.';

  @override
  String get projectViewsAdminOnly =>
      'Nur Projekt-Admins können Ansichten ändern.';

  @override
  String get projectDeleteDefault =>
      'Das ist das Standardprojekt einer Person. Nur sie selbst kann es löschen.';

  @override
  String get projectArchiveDefault =>
      'Das ist das Standardprojekt einer Person, deshalb lässt es sich nicht archivieren.';

  @override
  String get projectUnarchiveParentFirst =>
      'Sein übergeordnetes Projekt ist archiviert. Heb zuerst dort die Archivierung auf.';

  @override
  String get projectChangeArchived =>
      'Dieses Projekt ist archiviert. Heb die Archivierung auf, um es zu ändern.';

  @override
  String get projectParentArchived =>
      'Das übergeordnete Projekt ist archiviert, deshalb lässt sich darin nichts hinzufügen.';

  @override
  String get projectGone => 'Das Projekt gibt es nicht mehr.';

  @override
  String get projectChangeInvalid =>
      'Der Server hat diesen Titel oder Bezeichner nicht angenommen.';

  @override
  String get projectTitleTooLong =>
      'Ein Titel darf höchstens 250 Zeichen lang sein, und ein Emoji kann als mehrere zählen. Kürz diesen, um zu speichern.';

  @override
  String get projectTitleTooLongToChange =>
      'Der Titel dieses Projekts ist länger, als der Server annimmt. Kürz ihn zuerst unter „Bearbeiten“.';

  @override
  String projectChangeRefused(String message) {
    return 'Der Server hat die Änderung abgelehnt: $message';
  }

  @override
  String get projectChangeFailed =>
      'Die Änderung konnte nicht gespeichert werden.';

  @override
  String get projectViewNew => 'Neue Ansicht';

  @override
  String get projectViewEditTitle => 'Ansicht bearbeiten';

  @override
  String projectViewOptionsFor(String view) {
    return 'Optionen für $view';
  }

  @override
  String get projectViewDelete => 'Löschen';

  @override
  String projectViewDeleteTitle(String view) {
    return '„$view“ löschen?';
  }

  @override
  String get projectViewDeleteBody =>
      'Niemand kann sie dann noch verwenden, um die Aufgaben dieses Projekts anzusehen. Es werden keine Aufgaben gelöscht. Das lässt sich nicht rückgängig machen.';

  @override
  String get projectViewLastOne =>
      'Ein Projekt braucht mindestens eine Ansicht.';

  @override
  String get projectViewCreated => 'Ansicht erstellt';

  @override
  String get projectViewSaved => 'Ansicht gespeichert';

  @override
  String get projectViewDeleted => 'Ansicht gelöscht';

  @override
  String get projectViewKindLabel => 'Art';

  @override
  String get projectViewShowDone => 'Erledigte Aufgaben anzeigen';

  @override
  String get projectViewShowDoneHint =>
      'Aus fügt dem Filter „done = false“ hinzu, wie bei der Listenansicht im Web.';

  @override
  String projectViewFilterInvalid(String message) {
    return 'Dieser Filter ist ungültig: $message';
  }

  @override
  String get projectViewColumnsLabel => 'Spalten';

  @override
  String get projectViewColumnsManual => 'Manuell';

  @override
  String get projectViewColumnsFilter => 'Aus Filtern';

  @override
  String get projectViewFilterColumnsOnWeb =>
      'Die Filter dieser Spalten werden im Web eingerichtet.';

  @override
  String get projectViewGone => 'Die Ansicht gibt es nicht mehr.';

  @override
  String get projectViewInvalid =>
      'Der Server hat diese Ansicht nicht angenommen.';

  @override
  String get projectDeleteEverything =>
      'Dadurch werden seine Aufgaben und Unterprojekte gelöscht, für alle.';

  @override
  String get filterLabel => 'Filter';

  @override
  String get filterHint => 'done = false && labels in Arbeit';

  @override
  String get filterHelp =>
      'In der Filtersyntax des Webs, mit Titeln von Labels und Projekten. Vorschläge folgen dem, was du tippst.';

  @override
  String filterMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben auf diesem Gerät passen',
      one: '1 Aufgabe auf diesem Gerät passt',
      zero: 'Keine Aufgabe auf diesem Gerät passt',
    );
    return '$_temp0';
  }

  @override
  String get filterNotCountable =>
      'Diesen Filter wendet der Server an; die App kann ihn hier nicht zählen.';

  @override
  String get filterErrorUnknownField =>
      'Ein Feld in diesem Filter gibt es nicht. Felder schreibt man wie dueDate oder labels.';

  @override
  String filterErrorUnknownFieldNamed(String field) {
    return '„$field“ ist kein Feld. Felder schreibt man wie dueDate oder labels.';
  }

  @override
  String filterErrorLabelValue(String value) {
    return 'Kein Label heißt „$value“.';
  }

  @override
  String filterErrorProjectValue(String value) {
    return 'Kein Projekt heißt „$value“.';
  }

  @override
  String filterErrorFieldValue(String value, String field) {
    return '„$value“ ist kein gültiger Wert für $field.';
  }

  @override
  String get filterErrorOperator =>
      'Dieser Filter verwendet einen Operator, den es nicht gibt.';

  @override
  String get filterErrorValue =>
      'Ein Wert passt nicht zu seinem Feld, oder kein Label und kein Projekt hat diesen Titel.';

  @override
  String get filterErrorSyntax =>
      'Dieser Filter ist unvollständig. Verbinde Bedingungen mit && oder ||, schließ jede Klammer und verwende & | ( ) nicht in Werten.';

  @override
  String get filterErrorTooComplex =>
      'Dieser Filter ist zu lang oder zu tief verschachtelt.';

  @override
  String get filterErrorInvalid => 'Dieser Filter ist ungültig.';

  @override
  String get filterSuggestions => 'Filtervorschläge';

  @override
  String get filterSuggestionAnd => 'und';

  @override
  String get filterSuggestionOr => 'oder';

  @override
  String get filterDateNow => 'Jetzt';

  @override
  String get filterDateStartOfToday => 'Heute, Beginn';

  @override
  String get filterDateStartOfTomorrow => 'Morgen, Beginn';

  @override
  String get filterDateInSevenDays => 'In 7 Tagen';

  @override
  String get filterDateStartOfWeek => 'Diese Woche, Beginn';

  @override
  String get filterDateStartOfNextWeek => 'Nächste Woche, Beginn';

  @override
  String get filterDateStartOfMonth => 'Dieser Monat, Beginn';

  @override
  String get filterDateSevenDaysAgo => 'Vor 7 Tagen';

  @override
  String get savedFilterNew => 'Neuer gespeicherter Filter';

  @override
  String get savedFilterEditTitle => 'Gespeicherten Filter bearbeiten';

  @override
  String get savedFilterDescriptionLabel => 'Beschreibung';

  @override
  String get savedFilterIncludeNulls => 'Aufgaben ohne Wert einschließen';

  @override
  String get savedFilterIncludeNullsHint =>
      'Listet auch Aufgaben, die dort keinen Wert haben, wo der Filter einen vergleicht, etwa Aufgaben ohne Fälligkeitsdatum.';

  @override
  String get savedFilterFavourite => 'Favorit';

  @override
  String get savedFilterFavouriteHint =>
      'Zeigt ihn bei den Favoriten im Tab „Projekte“.';

  @override
  String get savedFilterFilterRequired =>
      'Ein gespeicherter Filter braucht einen Filter.';

  @override
  String get savedFilterCreated => 'Gespeicherter Filter erstellt';

  @override
  String get savedFilterSaved => 'Gespeicherter Filter gespeichert';

  @override
  String get savedFilterDeleted => 'Gespeicherter Filter gelöscht';

  @override
  String savedFilterDeleteTitle(String title) {
    return '„$title“ löschen?';
  }

  @override
  String get savedFilterDeleteBody =>
      'Es werden keine Aufgaben gelöscht, nur der Filter und seine Ansichten. Das lässt sich nicht rückgängig machen.';

  @override
  String get savedFilterEditDiscardBody =>
      'Deine Änderungen an diesem gespeicherten Filter gehen verloren.';

  @override
  String get savedFilterLoading => 'Gespeicherter Filter wird geladen …';

  @override
  String get savedFilterLoadFailed =>
      'Der gespeicherte Filter konnte nicht geladen werden.';

  @override
  String get savedFilterChangeNeedsConnection =>
      'Zum Verwalten gespeicherter Filter brauchst du eine Verbindung zum Server.';

  @override
  String get savedFilterChangeForbidden =>
      'Nur wer diesen gespeicherten Filter erstellt hat, kann ihn ändern.';

  @override
  String get savedFilterGone => 'Den gespeicherten Filter gibt es nicht mehr.';

  @override
  String get savedFilterChangeInvalid =>
      'Der Server hat diesen gespeicherten Filter nicht angenommen.';

  @override
  String get search => 'Suchen';

  @override
  String get searchPreparing => 'Suche wird vorbereitet';

  @override
  String get searchHint => 'Aufgaben, Projekte, Filter, Labels';

  @override
  String get searchTasks => 'Aufgaben';

  @override
  String get searchProjects => 'Projekte';

  @override
  String get searchLabels => 'Labels';

  @override
  String get searchStartTitle => 'Auf diesem Gerät suchen';

  @override
  String get searchStartBody =>
      'Aufgaben nach Titel oder Beschreibung; Projekte, gespeicherte Filter und Labels nach Namen. Funktioniert offline.';

  @override
  String get searchNoResultsTitle => 'Nichts gefunden';

  @override
  String searchNoResultsBody(String query) {
    return 'Nichts auf diesem Gerät passt zu „$query“.';
  }

  @override
  String searchMoreTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count weitere Aufgaben passen. Tipp mehr, um die Suche einzugrenzen.',
      one: '1 weitere Aufgabe passt. Tipp mehr, um die Suche einzugrenzen.',
    );
    return '$_temp0';
  }

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ergebnisse',
      one: '1 Ergebnis',
      zero: 'Keine Ergebnisse',
    );
    return '$_temp0';
  }

  @override
  String get labelTasksEmptyTitle => 'Keine offenen Aufgaben';

  @override
  String labelTasksEmptyBody(String label) {
    return 'Offene Aufgaben mit dem Label „$label“ erscheinen hier.';
  }

  @override
  String get labelTasksGoneTitle => 'Dieses Label gibt es nicht mehr';

  @override
  String get labelTasksGoneBody =>
      'Es wurde vielleicht gelöscht, hier oder im Web.';

  @override
  String get projectViewEmptyMatchingBody =>
      'Keine Aufgabe passt zum Filter dieser Ansicht.';

  @override
  String get clearSearch => 'Suche leeren';

  @override
  String get descriptionEditorTitle => 'Beschreibung';

  @override
  String get descriptionEditorPlaceholder => 'Beschreibung schreiben …';

  @override
  String get descriptionEditorLoading => 'Editor wird geöffnet …';

  @override
  String get descriptionEditorFailed =>
      'Der Editor konnte nicht geöffnet werden.';

  @override
  String get descriptionEditorSaved => 'Beschreibung gespeichert';

  @override
  String get descriptionEditorSaveFailed =>
      'Die Beschreibung konnte nicht gespeichert werden. Versuch es noch einmal.';

  @override
  String get descriptionEditorLeaveTitle => 'Beschreibung speichern?';

  @override
  String get descriptionEditorLeaveBody =>
      'Deine Änderungen an der Beschreibung sind noch nicht gespeichert.';

  @override
  String get descriptionEditorChangedTitle =>
      'Die Beschreibung wurde inzwischen geändert';

  @override
  String get descriptionEditorChangedBody =>
      'Sie wurde im Web geändert, seit du mit dem Bearbeiten begonnen hast. Diese Änderung mit deiner überschreiben oder neu laden und deine Änderungen verwerfen?';

  @override
  String get descriptionEditorOverwrite => 'Überschreiben';

  @override
  String get descriptionEditorReload => 'Neu laden';

  @override
  String get descriptionEditorStoppedKept =>
      'Der Editor wurde beendet. Lade ihn neu, um mit deinen Änderungen weiterzumachen.';

  @override
  String get descriptionEditorStoppedLost =>
      'Der Editor wurde beendet, deine letzten Änderungen sind verloren. Lade ihn neu, um weiterzumachen.';

  @override
  String get descriptionEditorImage => 'Bild (beim Bearbeiten nicht sichtbar)';

  @override
  String get descriptionEditorRestoreTitle =>
      'Ungespeicherte Änderungen wiederherstellen?';

  @override
  String get descriptionEditorRestoreBody =>
      'Du hast diese Beschreibung mit Änderungen verlassen, die nicht gespeichert wurden.';

  @override
  String get descriptionEditorRestore => 'Wiederherstellen';

  @override
  String get editorToolbar => 'Textformatierung';

  @override
  String get editorBold => 'Fett';

  @override
  String get editorItalic => 'Kursiv';

  @override
  String get editorUnderline => 'Unterstrichen';

  @override
  String get editorStrike => 'Durchgestrichen';

  @override
  String get editorCode => 'Code im Text';

  @override
  String get editorTextStyle => 'Textstil';

  @override
  String get editorParagraph => 'Absatz';

  @override
  String editorHeading(int level) {
    return 'Überschrift $level';
  }

  @override
  String get editorBulletList => 'Aufzählung';

  @override
  String get editorOrderedList => 'Nummerierte Liste';

  @override
  String get editorTaskList => 'Checkliste';

  @override
  String get editorQuote => 'Zitat';

  @override
  String get editorCodeBlock => 'Codeblock';

  @override
  String get editorLink => 'Link';

  @override
  String get editorTable => 'Tabelle';

  @override
  String get editorInsertTable => 'Tabelle einfügen';

  @override
  String get editorAddRow => 'Zeile hinzufügen';

  @override
  String get editorAddColumn => 'Spalte hinzufügen';

  @override
  String get editorDeleteRow => 'Zeile löschen';

  @override
  String get editorDeleteColumn => 'Spalte löschen';

  @override
  String get editorDeleteTable => 'Tabelle löschen';

  @override
  String get editorDivider => 'Trennlinie';

  @override
  String get editorUndo => 'Rückgängig';

  @override
  String get editorRedo => 'Wiederholen';

  @override
  String get editorClearFormatting => 'Formatierung entfernen';

  @override
  String get editorLinkAddTitle => 'Link hinzufügen';

  @override
  String get editorLinkEditTitle => 'Link bearbeiten';

  @override
  String get editorLinkAddress => 'Webadresse';

  @override
  String get editorLinkApply => 'Übernehmen';

  @override
  String get editorLinkRemove => 'Link entfernen';

  @override
  String get editorMentions => 'Personen zum Erwähnen';

  @override
  String get editorMentionsSearching => 'Suche läuft …';

  @override
  String get editorMentionsNone => 'Niemand gefunden';

  @override
  String get editorMentionsFromDevice =>
      'Keine Verbindung: Personen, die dieses Gerät kennt';

  @override
  String get taskDetailEditDescription => 'Beschreibung bearbeiten';

  @override
  String get taskDetailAddDescription => 'Beschreibung hinzufügen';

  @override
  String get checklistItemChecked => 'Abgehakt';

  @override
  String get checklistItemUnchecked => 'Nicht abgehakt';

  @override
  String get projectEditDescription => 'Beschreibung';

  @override
  String get projectEditNoDescription => 'Keine Beschreibung';

  @override
  String get syncProblemDescriptionConflict =>
      'Die Beschreibung wurde auch im Web geändert.';

  @override
  String get syncProblemKeepMine => 'Meine Version behalten';

  @override
  String get syncProblemUseWebs => 'Web-Version übernehmen';

  @override
  String editorMentionsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen gefunden',
      one: '1 Person gefunden',
    );
    return '$_temp0';
  }

  @override
  String get syncProblemCompare => 'Versionen vergleichen';

  @override
  String get syncProblemCompareTitle => 'Welche Beschreibung soll bleiben?';

  @override
  String get syncProblemYourVersion => 'Deine Version';

  @override
  String get syncProblemWebVersion => 'Web-Version';

  @override
  String get syncProblemWebTaskGone =>
      'Diese Aufgabe gibt es auf dem Server nicht mehr.';

  @override
  String get syncProblemNoDescription => 'Keine Beschreibung';

  @override
  String get accountSettingsEntry => 'Kontoeinstellungen';

  @override
  String get accountSettingsEntrySubtitle =>
      'Name, Avatar und Vorlieben, auf dem Server für alle deine Geräte gespeichert';

  @override
  String get accountHeaderTapHint => 'Kontoeinstellungen öffnen';

  @override
  String get onThisDeviceHeading => 'Auf diesem Gerät';

  @override
  String get onThisDeviceSubtitle =>
      'Diese Einstellungen bleiben auf diesem Gerät und werden nicht in deinem Konto gespeichert.';

  @override
  String get accountSettingsTitle => 'Kontoeinstellungen';

  @override
  String accountSettingsIntro(String host) {
    return 'In deinem Konto auf $host gespeichert und im Web und auf allen deinen Geräten gültig.';
  }

  @override
  String get accountSettingsOffline =>
      'Offline: Kontoeinstellungen lassen sich ändern, sobald der Server wieder erreichbar ist.';

  @override
  String get accountSettingsLoading => 'Kontoeinstellungen werden geladen …';

  @override
  String get accountSettingsSaved => 'Gespeichert';

  @override
  String get accountSettingsSaving => 'Wird gespeichert';

  @override
  String get accountSettingsProfile => 'Profil';

  @override
  String get accountSettingsName => 'Name';

  @override
  String accountSettingsNameHelp(String username) {
    return 'Wird statt deines Benutzernamens angezeigt. Lass das Feld leer, um @$username anzuzeigen.';
  }

  @override
  String accountSettingsNameManaged(String provider) {
    return 'Dein Anmeldedienst ($provider) setzt deinen Namen bei jeder Anmeldung. Ändere ihn dort.';
  }

  @override
  String get accountSettingsNameSave => 'Namen speichern';

  @override
  String get accountSettingsNameDiscardBody =>
      'Der eingegebene Name wurde nicht gespeichert.';

  @override
  String get accountSettingsNameSaved => 'Name gespeichert';

  @override
  String get accountSettingsAvatar => 'Avatar';

  @override
  String get accountSettingsSignIn => 'Passwort und E-Mail';

  @override
  String get accountSettingsWaitingForProfile =>
      'Verfügbar, sobald der Server mitgeteilt hat, wie du dich anmeldest.';

  @override
  String get accountSettingsChangePassword => 'Passwort ändern';

  @override
  String get accountSettingsChangePasswordHint =>
      'Öffnet das Web in deinem Browser. Melde dich danach hier erneut an; noch nicht gesendete Änderungen bleiben erhalten.';

  @override
  String get accountSettingsChangeEmail => 'E-Mail-Adresse ändern';

  @override
  String get accountSettingsOpensWeb => 'Öffnet das Web in deinem Browser';

  @override
  String accountSettingsPendingEmail(String email) {
    return 'Wartet auf Bestätigung von $email';
  }

  @override
  String accountSettingsManagedBySignInNamed(String provider) {
    return 'Wird von deinem Anmeldedienst ($provider) verwaltet';
  }

  @override
  String get accountSettingsWebNotOpened =>
      'Der Browser konnte nicht geöffnet werden.';

  @override
  String get accountSettingsDefaults => 'Voreinstellungen';

  @override
  String get accountSettingsDefaultProject => 'Standardprojekt';

  @override
  String get accountSettingsDefaultProjectNone => 'Keines';

  @override
  String get accountSettingsDefaultProjectUnknown =>
      'Ein Projekt, das nicht auf diesem Gerät ist';

  @override
  String get accountSettingsDefaultProjectInvalid =>
      'Wähle ein Projekt, in dem du Aufgaben erstellen darfst und das nicht archiviert ist.';

  @override
  String get accountSettingsDefaultView => 'Standardansicht';

  @override
  String get accountSettingsDefaultViewFirst => 'Erste Ansicht';

  @override
  String get accountSettingsQuickAddMagic => 'Quick Add Magic';

  @override
  String get accountSettingsQuickAddMagicDisabled => 'Aus';

  @override
  String get accountSettingsQuickAddMagicVikunja => 'Vikunja';

  @override
  String get accountSettingsQuickAddMagicTodoist => 'Todoist';

  @override
  String get accountSettingsMinimumPriority => 'Prioritäten anzeigen ab';

  @override
  String get accountSettingsOverviewFilter => 'Überblick zeigt';

  @override
  String get accountSettingsOverviewFilterNone => 'Alle offenen Aufgaben';

  @override
  String get accountSettingsOverviewFilterUnknown =>
      'Ein gespeicherter Filter, der nicht auf diesem Gerät ist';

  @override
  String get accountSettingsWeekStart => 'Erster Tag der Woche';

  @override
  String get accountSettingsTimeAndLanguage => 'Zeit und Sprache';

  @override
  String get accountSettingsTimezone => 'Zeitzone';

  @override
  String get accountSettingsTimezoneServerDefault => 'Standard des Servers';

  @override
  String get accountSettingsTimezoneHelp =>
      'Für gespeicherte Filter, E-Mails und Erinnerungen des Servers. Die App zeigt Zeiten in der Zeitzone dieses Geräts.';

  @override
  String get accountSettingsTimezoneSearch => 'Zeitzonen durchsuchen';

  @override
  String get accountSettingsTimezoneDevice => 'Dieses Gerät';

  @override
  String get accountSettingsTimezoneSameAsDevice =>
      'Gleiche Zeit wie dieses Gerät';

  @override
  String get accountSettingsTimezoneAll => 'Alle Zeitzonen';

  @override
  String accountSettingsTimezoneInvalid(String zone) {
    return 'Der Server kennt die Zeitzone $zone nicht. Wähle eine andere.';
  }

  @override
  String get accountSettingsLanguage => 'Sprache';

  @override
  String get accountSettingsLanguageHelp =>
      'Für E-Mails und das Web. Die App folgt der Sprache deines Geräts.';

  @override
  String get accountSettingsLanguageNotSet => 'Nicht festgelegt';

  @override
  String get accountSettingsLanguageSearch => 'Sprachen durchsuchen';

  @override
  String get accountSettingsDateDisplay => 'Datumsformat';

  @override
  String get accountSettingsDateDisplayDevice => 'Wie auf diesem Gerät';

  @override
  String get accountSettingsDateDisplayRelative => 'Relativ, z. B. in 3 Tagen';

  @override
  String get accountSettingsDateMonthDayYearDashed => 'MM-TT-JJJJ';

  @override
  String get accountSettingsDateDayMonthYearDashed => 'TT-MM-JJJJ';

  @override
  String get accountSettingsDateYearMonthDayDashed => 'JJJJ-MM-TT';

  @override
  String get accountSettingsDateMonthDayYearSlashed => 'MM/TT/JJJJ';

  @override
  String get accountSettingsDateDayMonthYearSlashed => 'TT/MM/JJJJ';

  @override
  String get accountSettingsDateYearMonthDaySlashed => 'JJJJ/MM/TT';

  @override
  String accountSettingsDateExample(String example) {
    return 'Beispiel: $example';
  }

  @override
  String get accountSettingsTimeFormat => 'Zeitformat';

  @override
  String get accountSettingsTimeFormatDevice => 'Wie auf diesem Gerät';

  @override
  String get accountSettingsTimeFormat12 => '12-Stunden-Format';

  @override
  String get accountSettingsTimeFormat24 => '24-Stunden-Format';

  @override
  String get accountSettingsEmailNotifications => 'E-Mail-Benachrichtigungen';

  @override
  String get accountSettingsEmailsOff =>
      'Dieser Server verschickt derzeit keine Erinnerungs-E-Mails. Die Einstellungen bleiben für später erhalten.';

  @override
  String get accountSettingsEmailReminders => 'Erinnerungen per E-Mail';

  @override
  String get accountSettingsEmailRemindersSubtitle =>
      'Eine E-Mail zu jeder Erinnerung, zusätzlich zu den Benachrichtigungen auf diesem Gerät';

  @override
  String get accountSettingsOverdueReminders =>
      'Tägliche Zusammenfassung überfälliger Aufgaben';

  @override
  String get accountSettingsOverdueRemindersSubtitle =>
      'Eine E-Mail mit deinen überfälligen, nicht erledigten Aufgaben';

  @override
  String get accountSettingsOverdueTime => 'Uhrzeit der Zusammenfassung';

  @override
  String get accountSettingsOverdueTimeInvalid =>
      'Der Server hat diese Uhrzeit abgelehnt.';

  @override
  String get accountSettingsPrivacy => 'Privatsphäre';

  @override
  String get accountSettingsDiscoverableByName => 'Über den Namen auffindbar';

  @override
  String get accountSettingsDiscoverableByNameSubtitle =>
      'Andere können dich über die Suche nach deinem Namen zu Teams und Projekten hinzufügen';

  @override
  String get accountSettingsDiscoverableByEmail =>
      'Über die E-Mail-Adresse auffindbar';

  @override
  String get accountSettingsDiscoverableByEmailSubtitle =>
      'Andere können dich über die Suche nach deiner vollständigen E-Mail-Adresse zu Teams und Projekten hinzufügen';

  @override
  String get accountSettingsNothingFound => 'Nichts gefunden';

  @override
  String get accountSettingsNeedsConnection =>
      'Kontoeinstellungen lassen sich nur mit Verbindung zum Server ändern.';

  @override
  String get accountSettingsUnconfirmed =>
      'Die Änderung konnte nicht bestätigt werden. Prüfe sie erneut, sobald die Verbindung zurück ist.';

  @override
  String get accountSettingsSignInAgain =>
      'Melde dich erneut an, um Kontoeinstellungen zu ändern.';

  @override
  String accountSettingsRefused(String message) {
    return 'Der Server hat die Änderung abgelehnt: $message';
  }

  @override
  String get accountSettingsInvalid => 'Der Server hat diesen Wert abgelehnt.';

  @override
  String get accountSettingsFailed =>
      'Die Änderung konnte nicht gespeichert werden. Versuche es später erneut.';

  @override
  String get avatarTitle => 'Avatar';

  @override
  String get avatarCurrent => 'Dein Avatar';

  @override
  String get avatarProviderDefault => 'Standard';

  @override
  String get avatarProviderDefaultSubtitle => 'Ein schlichtes Bild';

  @override
  String get avatarProviderInitials => 'Initialen';

  @override
  String get avatarProviderInitialsSubtitle => 'Deine Initialen';

  @override
  String get avatarProviderGravatar => 'Gravatar';

  @override
  String get avatarProviderGravatarSubtitle =>
      'Das Bild zu deiner E-Mail-Adresse bei gravatar.com';

  @override
  String get avatarProviderMarble => 'Murmel';

  @override
  String get avatarProviderMarbleSubtitle =>
      'Ein buntes Muster aus deinem Benutzernamen';

  @override
  String get avatarProviderUpload => 'Dein Foto';

  @override
  String get avatarProviderUploadSubtitle => 'Ein Foto von diesem Gerät';

  @override
  String get avatarProviderUploadReplace => 'Anderes Foto wählen';

  @override
  String get avatarProviderLdap => 'Aus deinem Verzeichnis';

  @override
  String get avatarProviderOpenId => 'Von deinem Anmeldedienst';

  @override
  String get avatarAppShowsInitials =>
      'Diese App zeigt für die Avatare Standard, Initialen und Murmel deine Initialen; das Web zeichnet sie.';

  @override
  String get avatarManagedLdap =>
      'Dein Avatar kommt aus dem Verzeichnisdienst deiner Organisation (LDAP). Frag dein IT-Team, wie du ihn änderst.';

  @override
  String avatarManagedOpenId(String provider) {
    return 'Dein Avatar kommt von deinem Anmeldedienst ($provider). Ändere ihn dort.';
  }

  @override
  String get avatarChoosePhoto => 'Foto auswählen';

  @override
  String get avatarTakePhoto => 'Foto aufnehmen';

  @override
  String get avatarChanged => 'Avatar geändert';

  @override
  String get avatarUploaded => 'Foto hochgeladen';

  @override
  String get avatarCropTitle => 'Dein neuer Avatar';

  @override
  String get avatarCropHint =>
      'Ziehe das Foto, um es zu verschieben, und zoome mit zwei Fingern. Das Quadrat wird dein Avatar.';

  @override
  String get avatarCropUpload => 'Hochladen';

  @override
  String get avatarUploading => 'Wird hochgeladen …';

  @override
  String get avatarImageUnusable =>
      'Dieses Bild kann nicht verwendet werden. Wähle ein PNG- oder JPEG-Foto.';

  @override
  String get avatarImageTooLarge => 'Dieses Bild ist zu groß für den Server.';

  @override
  String get avatarPickFailed => 'Die Fotos konnten nicht geöffnet werden.';

  @override
  String get accountSettingsSecurity => 'Sicherheit';

  @override
  String get accountSettingsTotp => 'Zwei-Faktor-Authentifizierung';

  @override
  String get accountSettingsTotpOn => 'An';

  @override
  String get accountSettingsTotpOff => 'Aus';

  @override
  String get accountSettingsTotpSetupStarted =>
      'Einrichtung nicht abgeschlossen';

  @override
  String get accountSettingsTotpChecking => 'Wird geprüft …';

  @override
  String get accountSettingsTotpUnknown => 'Konnte nicht geprüft werden';

  @override
  String get accountSettingsTotpNotOffered =>
      'Von diesem Server nicht angeboten';

  @override
  String get accountSettingsTotpNotAvailable =>
      'Für dieses Konto nicht verfügbar';

  @override
  String get accountSettingsTotpNotChecked =>
      'Über eine unverschlüsselte Verbindung nicht geprüft';

  @override
  String get accountSettingsTotpTurnOnNote =>
      'Öffnet das Web in deinem Browser. Das Einschalten meldet dich überall ab, auch in dieser App. Melde dich danach hier erneut an; dein Browser fragt nach dem Code.';

  @override
  String get accountSettingsTotpTurnOnPasswordNote =>
      'Öffnet das Web in deinem Browser. Das Einschalten erfordert dein Passwort und meldet dich überall ab, auch in dieser App. Melde dich danach hier erneut an; dein Browser fragt nach dem Code.';

  @override
  String get accountSettingsTotpOnNote =>
      'Öffnet das Web in deinem Browser. Zum Ausschalten brauchst du dein Passwort, neuere Server fragen auch nach einem Code.';

  @override
  String get accountSettingsSessions => 'Sitzungen';

  @override
  String accountSettingsSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count angemeldete Geräte und Browser',
      one: '1 angemeldetes Gerät oder Browser',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsSessionsHint => 'Wo du angemeldet bist';

  @override
  String get accountSettingsIntegrations => 'Integrationen';

  @override
  String get accountSettingsApiTokens => 'API-Tokens';

  @override
  String accountSettingsApiTokensCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tokens',
      one: '1 Token',
      zero: 'Keine Tokens',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsApiTokensHint => 'Für Skripte und andere Apps';

  @override
  String get accountSettingsCaldav => 'CalDAV';

  @override
  String get accountSettingsCaldavHint =>
      'Deine Aufgaben in Kalender- und Aufgaben-Apps';

  @override
  String get accountSettingsYourData => 'Deine Daten';

  @override
  String get accountSettingsExport => 'Deine Daten exportieren';

  @override
  String accountSettingsExportReady(String date) {
    return 'Bereit zum Herunterladen bis $date';
  }

  @override
  String get accountSettingsExportNone => 'Noch kein Export';

  @override
  String get accountSettingsExportHint =>
      'Eine Kopie deiner Projekte und Aufgaben';

  @override
  String get accountSettingsDeleteAccount => 'Konto löschen';

  @override
  String get accountSettingsWebAsksPassword =>
      'Das Web fragt nach deinem Passwort.';

  @override
  String get accountSettingsAccountLockout =>
      'Zehn falsche Passwörter melden dich auf allen Geräten ab und sperren dein Konto, bis du dein Passwort zurücksetzt.';

  @override
  String accountDeletionScheduled(String date) {
    return 'Dein Konto wird am $date gelöscht.';
  }

  @override
  String accountDeletionOverdue(String date) {
    return 'Dein Konto ist seit $date zur Löschung fällig.';
  }

  @override
  String get accountDeletionCancel => 'Löschung abbrechen';

  @override
  String accountDeletionScheduledRow(String date) {
    return 'Löschung am $date. Abbrechen kannst du sie im Web.';
  }

  @override
  String accountDeletionOverdueRow(String date) {
    return 'Löschung seit $date fällig. Abbrechen kannst du sie im Web.';
  }

  @override
  String get accountDeletionDialogTitle => 'Dein Konto löschen?';

  @override
  String get accountDeletionDialogPermanent =>
      'Das Löschen deines Kontos ist endgültig. Alle Projekte und Aufgaben, die dir gehören, werden mit gelöscht; was du mit anderen geteilt hast, geht an sie über.';

  @override
  String get accountDeletionDialogEmail =>
      'Der Server schickt dir einen Link zur Bestätigung per E-Mail. Nach der Bestätigung wird dein Konto nach drei Tagen gelöscht; bis dahin kannst du es dir anders überlegen.';

  @override
  String get accountDeletionDialogNoEmail =>
      'Verschickt dein Server keine E-Mails, bitte die Person, die ihn betreut, dein Konto zu löschen.';

  @override
  String get accountDeletionContinue => 'Im Browser fortfahren';

  @override
  String get accountDeletionNotAllowedRow => 'Von diesem Server nicht erlaubt';

  @override
  String get accountDeletionNotAllowedTitle =>
      'Frage die Person, die den Server betreut';

  @override
  String get accountDeletionNotAllowedBody =>
      'Dieser Server erlaubt nicht, Konten in der App zu löschen. Die Person, die ihn betreut, kann dein Konto für dich löschen.';

  @override
  String get accountDeletionNotAllowedOk => 'OK';

  @override
  String get accountSecurityNeedsConnection =>
      'Dafür ist eine Verbindung zum Server nötig.';

  @override
  String get accountSecurityUnconfirmed =>
      'Die Antwort des Servers kam nicht an. Aktualisiere, um zu sehen, ob es geklappt hat.';

  @override
  String get accountSecuritySignInAgain => 'Melde dich zuerst erneut an.';

  @override
  String get accountSecurityNotOffered => 'Dieser Server bietet das nicht an.';

  @override
  String get accountSecurityRateLimited =>
      'Der Server ist ausgelastet. Versuche es in einer Minute erneut.';

  @override
  String accountSecurityRefused(String message) {
    return 'Der Server hat abgelehnt: $message';
  }

  @override
  String get accountSecurityFailed =>
      'Das hat nicht geklappt. Versuche es später erneut.';

  @override
  String get accountSecurityWorking => 'Wird ausgeführt';

  @override
  String accountSecurityCreated(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get sessionsTitle => 'Sitzungen';

  @override
  String get sessionsIntro =>
      'Diese Geräte und Browser sind in deinem Konto angemeldet. Beendest du eine Sitzung, wird das Gerät oder der Browser abgemeldet; das kann bis zu 10 Minuten dauern.';

  @override
  String get sessionsLoading => 'Sitzungen werden geladen …';

  @override
  String get sessionsThisDevice => 'Dieses Gerät';

  @override
  String get sessionsThisDeviceHint =>
      'Um diese Sitzung zu beenden, melde dich in dieser App vom Konto ab.';

  @override
  String sessionsLastActive(String when) {
    return 'Zuletzt aktiv $when';
  }

  @override
  String get sessionsLastActiveLabel => 'Zuletzt aktiv';

  @override
  String get sessionsSignedIn => 'Angemeldet am';

  @override
  String get sessionsDevice => 'Gerät';

  @override
  String get sessionsIpAddress => 'IP-Adresse';

  @override
  String get sessionsUnknownDevice => 'Unbekanntes Gerät';

  @override
  String sessionsBrowserOn(String browser, String system) {
    return '$browser unter $system';
  }

  @override
  String get sessionsDartClient => 'Eine App ohne Namen';

  @override
  String get sessionsVikunjaApp => 'Vikunja-App';

  @override
  String get sessionsEnd => 'Sitzung beenden';

  @override
  String get sessionsEndTitle => 'Diese Sitzung beenden?';

  @override
  String sessionsEndBody(String device) {
    return '$device wird abgemeldet. Das kann bis zu 10 Minuten dauern.';
  }

  @override
  String get sessionsEnded =>
      'Sitzung beendet. Es kann bis zu 10 Minuten dauern, bis das wirkt.';

  @override
  String get sessionsEndOthers => 'Alle anderen Sitzungen beenden';

  @override
  String get sessionsEndOthersTitle => 'Alle anderen Sitzungen beenden?';

  @override
  String sessionsEndOthersBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count anderen Geräte und Browser werden',
      one: 'Das andere Gerät oder der andere Browser wird',
    );
    return '$_temp0 innerhalb von 10 Minuten abgemeldet. Dieses Gerät bleibt angemeldet.';
  }

  @override
  String sessionsEndedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Sitzungen beendet. Es kann bis zu 10 Minuten dauern, bis das wirkt.',
      one:
          '1 Sitzung beendet. Es kann bis zu 10 Minuten dauern, bis das wirkt.',
      zero: 'Keine andere Sitzung zu beenden.',
    );
    return '$_temp0';
  }

  @override
  String sessionsNotAllEnded(int ended, int notEnded) {
    return 'Beendet: $ended. Noch angemeldet: $notEnded.';
  }

  @override
  String get sessionsNoOthers => 'Keine anderen Sitzungen';

  @override
  String get sessionsNoOthersBody =>
      'Nur dieses Gerät ist in deinem Konto angemeldet.';

  @override
  String sessionsOptionsFor(String device) {
    return 'Optionen für $device';
  }

  @override
  String get apiTokensTitle => 'API-Tokens';

  @override
  String get apiTokensIntro =>
      'Mit API-Tokens können Skripte und andere Apps die API von Vikunja ohne dein Passwort nutzen. Ein Token darf nur, was seine Berechtigungen erlauben.';

  @override
  String get apiTokensDocs => 'API-Dokumentation';

  @override
  String get apiTokensLoading => 'API-Tokens werden geladen …';

  @override
  String get apiTokensEmptyTitle => 'Keine API-Tokens';

  @override
  String get apiTokensEmptyBody =>
      'Erstelle eins für ein Skript oder eine andere App.';

  @override
  String get apiTokensNew => 'Neues Token';

  @override
  String apiTokensExpires(String date) {
    return 'Läuft am $date ab';
  }

  @override
  String apiTokensExpired(String when) {
    return 'Abgelaufen $when';
  }

  @override
  String apiTokensPermissionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Berechtigungen',
      one: '1 Berechtigung',
    );
    return '$_temp0';
  }

  @override
  String get apiTokensPermissions => 'Berechtigungen';

  @override
  String get apiTokensDelete => 'Token löschen';

  @override
  String apiTokensDeleteTitle(String title) {
    return 'Das Token „$title“ löschen?';
  }

  @override
  String get apiTokensDeleteBody =>
      'Apps und Skripte, die es nutzen, funktionieren dann nicht mehr. Das lässt sich nicht rückgängig machen.';

  @override
  String get apiTokensDeleted => 'Token gelöscht';

  @override
  String get apiTokenFormTitle => 'Neues API-Token';

  @override
  String get apiTokenFormCreate => 'Erstellen';

  @override
  String get apiTokenFormCreating => 'Wird erstellt …';

  @override
  String get apiTokenFormLoading => 'Berechtigungen werden geladen …';

  @override
  String get apiTokenFormName => 'Titel';

  @override
  String get apiTokenFormNameHint => 'Ein Titel, den du später wiedererkennst';

  @override
  String get apiTokenFormNameRequired => 'Gib einen Titel ein.';

  @override
  String get apiTokenFormExpiry => 'Läuft ab';

  @override
  String apiTokenFormExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days Tagen',
      one: 'In 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get apiTokenFormExpiryCustom => 'Tag auswählen …';

  @override
  String get apiTokenFormExpiryPick => 'Gültig bis einschließlich';

  @override
  String apiTokenFormExpiryThrough(String date) {
    return 'Bis einschließlich $date';
  }

  @override
  String get apiTokenFormExpiryPast =>
      'Wähle einen Tag, der noch nicht vorbei ist.';

  @override
  String get apiTokenFormPermissions => 'Berechtigungen';

  @override
  String get apiTokenFormPermissionsHelp =>
      'Wähle, was das Token darf. Die Namen kommen vom Server und sind nicht übersetzt.';

  @override
  String get apiTokenFormPermissionsRequired =>
      'Wähle mindestens eine Berechtigung.';

  @override
  String get apiTokenFormNoPermissions =>
      'Dieser Server bietet keine Berechtigungen für Tokens an.';

  @override
  String get apiTokenFormPresets => 'Voreinstellungen';

  @override
  String get apiTokenPresetReadOnly => 'Nur lesen';

  @override
  String get apiTokenPresetTasks => 'Aufgabenverwaltung';

  @override
  String get apiTokenPresetProjects => 'Projektverwaltung';

  @override
  String get apiTokenPresetFullAccess => 'Voller Zugriff';

  @override
  String apiTokenFormGroupSelected(int selected, int total) {
    return '$selected von $total';
  }

  @override
  String apiTokenFormShowGroup(String group) {
    return 'Berechtigungen von $group anzeigen';
  }

  @override
  String apiTokenFormHideGroup(String group) {
    return 'Berechtigungen von $group ausblenden';
  }

  @override
  String get apiTokenFormDiscardBody => 'Das Token wurde nicht erstellt.';

  @override
  String get oneTimeSecretApiTitle => 'Dein neues API-Token';

  @override
  String get oneTimeSecretCaldavTitle => 'Dein neues CalDAV-Token';

  @override
  String get oneTimeSecretLabel => 'Das neue Token';

  @override
  String get oneTimeSecretCopy => 'Kopieren';

  @override
  String get copiedToClipboard => 'Kopiert';

  @override
  String get copyToClipboardFailed =>
      'Kopieren hat nicht geklappt. Versuch es noch einmal.';

  @override
  String get oneTimeSecretOnce =>
      'Du wirst es nicht noch einmal sehen. Bewahre es sicher auf, etwa in einem Passwort-Manager.';

  @override
  String get oneTimeSecretApiUsage =>
      'Skripte und Apps senden es als Bearer-Token im Authorization-Header.';

  @override
  String oneTimeSecretCaldavUsage(String username) {
    return 'Gib es in deiner CalDAV-App als Passwort ein, mit dem Benutzernamen $username.';
  }

  @override
  String get oneTimeSecretDone => 'Fertig';

  @override
  String get oneTimeSecretLeaveTitle => 'Ohne Kopieren verlassen?';

  @override
  String get oneTimeSecretLeaveBody =>
      'Das Token wird nur jetzt angezeigt. Ohne es musst du ein neues erstellen.';

  @override
  String get oneTimeSecretStay => 'Bleiben';

  @override
  String get oneTimeSecretLeave => 'Verlassen';

  @override
  String get secretHiddenWhileCaptured =>
      'Ausgeblendet, solange dein Bildschirm aufgenommen oder gespiegelt wird.';

  @override
  String get caldavTitle => 'CalDAV';

  @override
  String get caldavIntro =>
      'Verbinde Kalender- und Aufgaben-Apps, die CalDAV unterstützen, um deine Aufgaben dort zu sehen und zu ändern. Gib diese Adresse in der App ein:';

  @override
  String get caldavAddress => 'CalDAV-Adresse';

  @override
  String get caldavUsername => 'Benutzername';

  @override
  String get caldavCopyAddress => 'Adresse kopieren';

  @override
  String get caldavCopyUsername => 'Benutzernamen kopieren';

  @override
  String get caldavPasswordOrToken =>
      'Als Passwort nimmst du ein CalDAV-Token oder dein Kontopasswort.';

  @override
  String get caldavTokenTotp =>
      'Die Zwei-Faktor-Authentifizierung ist an, daher funktioniert dein Kontopasswort hier nicht. Nimm ein CalDAV-Token als Passwort.';

  @override
  String caldavTokenProvider(String provider) {
    return 'Du meldest dich über $provider an, nimm daher ein CalDAV-Token als Passwort.';
  }

  @override
  String get caldavTokenUnknown =>
      'Nimm ein CalDAV-Token als Passwort. Dein Kontopasswort geht auch, außer die Zwei-Faktor-Authentifizierung ist an.';

  @override
  String get caldavTokenRecommended =>
      'Nimm als Passwort lieber ein CalDAV-Token statt deines Kontopassworts: Eine Kalender-App, die es weiter mit einem alten Passwort versucht, etwa nach einer Passwortänderung, sperrt dein Konto nach zehn Versuchen.';

  @override
  String get caldavApiTokenHint =>
      'Ein API-Token mit der CalDAV-Berechtigung funktioniert ebenfalls als Passwort.';

  @override
  String get caldavDocs => 'Mehr über CalDAV in Vikunja';

  @override
  String get caldavTokens => 'CalDAV-Tokens';

  @override
  String get caldavTokensLoading => 'CalDAV-Tokens werden geladen …';

  @override
  String get caldavTokensEmpty => 'Noch keine CalDAV-Tokens.';

  @override
  String caldavTokenName(int id) {
    return 'Token $id';
  }

  @override
  String get caldavNewToken => 'Neues CalDAV-Token';

  @override
  String caldavDeleteToken(int id) {
    return 'Token $id löschen';
  }

  @override
  String caldavDeleteTitle(int id) {
    return 'Token $id löschen?';
  }

  @override
  String get caldavDeleteBody =>
      'CalDAV-Apps, die es nutzen, können sich dann nicht mehr anmelden. Das lässt sich nicht rückgängig machen.';

  @override
  String get caldavDeleteBodyLockout =>
      'CalDAV-Apps, die es nutzen, können sich dann nicht mehr anmelden. Das lässt sich nicht rückgängig machen. Entferne es vorher aus diesen Apps, sonst zählt jeder weitere Versuch damit als falsches Passwort, und zehn falsche Passwörter sperren dein Konto, bis du dein Passwort zurücksetzt.';

  @override
  String get caldavDelete => 'Löschen';

  @override
  String get caldavTokenDeleted => 'CalDAV-Token gelöscht';

  @override
  String get dataExportTitle => 'Deine Daten exportieren';

  @override
  String get dataExportIntro =>
      'Der Export enthält deine Projekte, Aufgaben, Kommentare, Anhänge und gespeicherten Filter. Du kannst ihn in jeden Vikunja-Server importieren.';

  @override
  String get dataExportLoading => 'Export wird gesucht …';

  @override
  String get dataExportReadyTitle => 'Bereit zum Herunterladen';

  @override
  String dataExportReadyBody(String size, String date) {
    return '$size, verfügbar bis $date';
  }

  @override
  String get dataExportNoneTitle => 'Noch kein Export';

  @override
  String get dataExportNoneBody =>
      'Fordere unten einen an. Ein Export wird sieben Tage aufbewahrt.';

  @override
  String get dataExportRequest => 'Neuen Export anfordern';

  @override
  String get dataExportRequestNote =>
      'Öffnet das Web in deinem Browser. Der Server schickt dir eine E-Mail, sobald der Export bereit ist, und diese Seite zeigt ihn dann auch.';

  @override
  String get dataExportDownload => 'Herunterladen';

  @override
  String overviewGreetingMorning(String name) {
    return 'Guten Morgen, $name';
  }

  @override
  String overviewGreetingAfternoon(String name) {
    return 'Guten Tag, $name';
  }

  @override
  String overviewGreetingEvening(String name) {
    return 'Guten Abend, $name';
  }

  @override
  String overviewTasksLeftToday(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $countString Aufgaben für heute',
      one: 'Noch 1 Aufgabe für heute',
      zero: 'Für heute ist nichts mehr offen',
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
      other: '$countString offen',
      one: '1 offen',
      zero: 'nichts offen',
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
      other: '$countString offen',
      one: '1 offen',
      zero: 'nichts offen',
    );
    return '$day, $_temp0';
  }

  @override
  String get upcomingShowDayHint => 'Nur diesen Tag anzeigen';

  @override
  String get upcomingShowRangeHint => 'Ganzen Zeitraum anzeigen';

  @override
  String get upcomingNothingPlanned => 'Nichts geplant';

  @override
  String get taskDetailMarkDone => 'Als erledigt markieren';

  @override
  String get taskDetailMarkNotDone => 'Als nicht erledigt markieren';

  @override
  String get taskDetailStatusOpen => 'Offen';

  @override
  String get projectShowDoneChip => 'Erledigte anzeigen';

  @override
  String projectProgressDone(int done, int total) {
    return '$done von $total erledigt';
  }

  @override
  String projectProgressSemantics(int done, int total) {
    return 'Projektfortschritt: $done von $total Aufgaben erledigt';
  }

  @override
  String get accountHeaderEdit => 'Bearbeiten';

  @override
  String get accountSyncHeading => 'Synchronisierung';

  @override
  String get accountServerHeading => 'Server';

  @override
  String accountAppVersion(String version, String build) {
    return 'Vikunja-App $version ($build)';
  }

  @override
  String accountAppVersionWithoutBuild(String version) {
    return 'Vikunja-App $version';
  }

  @override
  String get commentsHeading => 'Kommentare';

  @override
  String get commentsEmpty => 'Noch keine Kommentare';

  @override
  String get commentComposerHint => 'Schreib einen Kommentar …';

  @override
  String get commentSend => 'Kommentar senden';

  @override
  String get commentSending => 'Kommentar wird gesendet …';

  @override
  String get commentPosted => 'Kommentar gesendet';

  @override
  String get commentComposerOffline =>
      'Braucht eine Verbindung. Was du geschrieben hast, bleibt hier.';

  @override
  String commentReplyingTo(String name) {
    return 'Antwort an $name';
  }

  @override
  String get commentReplyCancel => 'Nicht antworten';

  @override
  String commentOptions(String name) {
    return 'Optionen für den Kommentar von $name';
  }

  @override
  String get commentReply => 'Antworten';

  @override
  String get commentCopyLink => 'Link kopieren';

  @override
  String get commentLinkCopied => 'Link kopiert';

  @override
  String get commentEdit => 'Bearbeiten';

  @override
  String get commentDelete => 'Löschen';

  @override
  String get commentDeleteTitle => 'Diesen Kommentar löschen?';

  @override
  String get commentDeleteBody => 'Das lässt sich nicht rückgängig machen.';

  @override
  String get commentDeleted => 'Kommentar gelöscht';

  @override
  String get commentSaved => 'Kommentar gespeichert';

  @override
  String get commentWorking => 'Änderung wird gespeichert …';

  @override
  String get commentEditorTitle => 'Kommentar bearbeiten';

  @override
  String get commentEmptyRefused => 'Ein Kommentar kann nicht leer sein';

  @override
  String get commentsArchivedNote =>
      'Dieses Projekt ist archiviert, deshalb können seine Kommentare nicht geändert werden.';

  @override
  String get commentsReadOnlyNote => 'Du kannst diese Aufgabe nur lesen.';

  @override
  String get commentFailedNotAuthor =>
      'Nur wer einen Kommentar geschrieben hat, kann ihn ändern.';

  @override
  String get commentFailedGone => 'Den Kommentar gibt es nicht mehr.';

  @override
  String get commentFailedNeedsConnection =>
      'Dafür ist eine Verbindung zum Server nötig.';

  @override
  String get commentFailedTooLong => 'Dieser Kommentar ist zu lang.';

  @override
  String get commentFailedUnconfirmed =>
      'Der Server hat nicht geantwortet. Schau in die Kommentare, bevor du noch einmal sendest.';

  @override
  String get commentFailedSend =>
      'Der Kommentar konnte nicht gesendet werden. Versuche es später erneut.';

  @override
  String get commentFailedSave =>
      'Der Kommentar konnte nicht gespeichert werden. Versuche es später erneut.';

  @override
  String get commentFailedDelete =>
      'Der Kommentar konnte nicht gelöscht werden. Versuche es später erneut.';

  @override
  String get reactionAdd => 'Reaktion hinzufügen';

  @override
  String get reactionOther => 'Anderes Emoji';

  @override
  String get reactionOtherHint => 'Emoji eingeben';

  @override
  String get reactionOtherAdd => 'Hinzufügen';

  @override
  String get reactionTooLong => 'Höchstens 20 Zeichen';

  @override
  String get reactionAddMine => 'deine Reaktion hinzufügen';

  @override
  String get reactionRemoveMine => 'deine Reaktion entfernen';

  @override
  String get reactionFailed =>
      'Die Reaktion konnte nicht gespeichert werden. Versuche es später erneut.';

  @override
  String taskCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kommentare',
      one: '1 Kommentar',
    );
    return '$_temp0';
  }

  @override
  String taskCommentCountUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kommentare, ungelesen',
      one: '1 Kommentar, ungelesen',
    );
    return '$_temp0';
  }

  @override
  String get commentReplyDropped => 'Du antwortest nicht mehr';

  @override
  String get shareMenuItem => 'Teilen';

  @override
  String sharePageTitle(String project) {
    return '$project teilen';
  }

  @override
  String get sharePageLoading => 'Zugriffe werden geladen …';

  @override
  String get sharePeopleSection => 'Personen';

  @override
  String get shareTeamsSection => 'Teams';

  @override
  String get shareLinksSection => 'Links';

  @override
  String get sharePeopleEmpty => 'Noch mit niemandem geteilt';

  @override
  String get shareTeamsEmpty => 'Noch mit keinem Team geteilt';

  @override
  String get shareLinksEmpty => 'Noch keine Links';

  @override
  String get shareLinksIntro =>
      'Wer einen Link hat, kann dieses Projekt ohne Konto öffnen, mit der Berechtigung des Links.';

  @override
  String shareUserIsYou(String name) {
    return '$name (du)';
  }

  @override
  String get sharePermissionRead => 'Nur lesen';

  @override
  String get sharePermissionWrite => 'Lesen & schreiben';

  @override
  String get sharePermissionAdmin => 'Admin';

  @override
  String get shareAddPerson => 'Person hinzufügen';

  @override
  String get shareAddTeam => 'Team hinzufügen';

  @override
  String get shareHiddenTeam => 'Verborgenes Team';

  @override
  String shareTeamMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get shareReadOnlyNote =>
      'Nur Projekt-Admins können ändern, wer Zugriff hat';

  @override
  String shareAccessFor(String name) {
    return 'Zugriff für $name';
  }

  @override
  String sharePermissionFor(String name) {
    return 'Berechtigung für $name';
  }

  @override
  String get shareRemove => 'Entfernen';

  @override
  String shareRemoveTitle(String name) {
    return '$name entfernen?';
  }

  @override
  String shareRemovePersonBody(String name) {
    return '$name verliert sofort den Zugriff auf dieses Projekt und die Projekte darunter.';
  }

  @override
  String get shareRemoveSelfBody =>
      'Du verlierst sofort den Zugriff auf dieses Projekt und die Projekte darunter, wenn du ihn nicht auf anderem Weg hast.';

  @override
  String shareRemoveTeamBody(String name) {
    return 'Die Mitglieder von $name verlieren sofort den Zugriff auf dieses Projekt und die Projekte darunter, wenn sie ihn nicht auf anderem Weg haben.';
  }

  @override
  String get shareCleanupOthersIntro =>
      'In den Projekten, die sie nicht mehr erreichen, löscht der Server außerdem:';

  @override
  String get shareCleanupOthersAssignments => 'ihre Aufgabenzuweisungen';

  @override
  String get shareCleanupOthersSubscriptions =>
      'ihre Abonnements von Aufgaben und Projekten';

  @override
  String get shareCleanupOthersWebhooks => 'Webhooks, die sie erstellt haben';

  @override
  String get shareCleanupSelfIntro =>
      'In den Projekten, die du nicht mehr erreichst, löscht der Server außerdem:';

  @override
  String get shareCleanupSelfAssignments => 'deine Aufgabenzuweisungen';

  @override
  String get shareCleanupSelfSubscriptions =>
      'deine Abonnements von Aufgaben und Projekten';

  @override
  String get shareCleanupSelfWebhooks => 'Webhooks, die du erstellt hast';

  @override
  String shareAdded(String name) {
    return '$name hat jetzt Zugriff';
  }

  @override
  String sharePermissionChanged(String name) {
    return 'Zugriff für $name geändert';
  }

  @override
  String shareRemoved(String name) {
    return '$name entfernt';
  }

  @override
  String get shareSaving => 'Wird gespeichert …';

  @override
  String get sharePeopleSearchField => 'Benutzername, Name oder E-Mail';

  @override
  String get sharePeopleSearchHint =>
      'Suche nach dem genauen Benutzernamen, oder nach Name oder E-Mail, wenn die Person es erlaubt';

  @override
  String get sharePeopleSearching => 'Suche läuft …';

  @override
  String get sharePeopleNoResults =>
      'Niemand gefunden, der hinzugefügt werden kann';

  @override
  String get sharePeopleSearchOffline =>
      'Die Suche nach Personen braucht eine Verbindung.';

  @override
  String get sharePeopleSearchFailed =>
      'Die Suche hat nicht geklappt. Versuch es noch einmal.';

  @override
  String get shareTeamsFilter => 'Teams filtern';

  @override
  String get shareTeamsLoading => 'Teams werden geladen …';

  @override
  String get shareTeamsNoneToAdd =>
      'Kein weiteres Team zum Hinzufügen. Du kannst die Teams hinzufügen, in denen du Mitglied bist.';

  @override
  String get shareTeamsNoneToAddPublic =>
      'Kein weiteres Team zum Hinzufügen. Du kannst die Teams hinzufügen, in denen du Mitglied bist, und öffentliche Teams.';

  @override
  String get shareTeamPublic => 'Öffentlich';

  @override
  String get linkShareUnnamed => 'Link ohne Namen';

  @override
  String get linkSharePasswordProtected => 'Passwortgeschützt';

  @override
  String linkShareCreatedBy(String name) {
    return 'Erstellt von $name';
  }

  @override
  String get linkShareShare => 'Teilen';

  @override
  String get linkShareCopy => 'Link kopieren';

  @override
  String get linkShareCopied => 'Link kopiert';

  @override
  String get linkShareQr => 'QR-Code';

  @override
  String linkShareView(String view) {
    return 'Öffnet $view';
  }

  @override
  String get linkShareViewTitle => 'Der Link öffnet';

  @override
  String get linkShareDelete => 'Löschen';

  @override
  String linkShareDeleteTitle(String name) {
    return 'Den Link „$name“ löschen?';
  }

  @override
  String get linkShareDeleteUnnamedTitle => 'Diesen Link löschen?';

  @override
  String get linkShareDeleteBody =>
      'Wer diesen Link nutzt, verliert sofort den Zugriff. Das lässt sich nicht rückgängig machen.';

  @override
  String get linkShareDeleted => 'Link gelöscht';

  @override
  String linkShareSubject(String project) {
    return 'Link zu $project';
  }

  @override
  String get linkShareCreate => 'Link erstellen';

  @override
  String get linkShareFormTitle => 'Neuer Link';

  @override
  String get linkShareFormPermission => 'Berechtigung';

  @override
  String get linkShareFormName => 'Name (optional)';

  @override
  String get linkShareFormNameHelper =>
      'Änderungen über den Link erscheinen mit diesem Namen';

  @override
  String get linkShareFormPassword => 'Passwort (optional)';

  @override
  String get linkShareFormPasswordHelper =>
      'Wer den Link öffnet, muss es eingeben';

  @override
  String get linkShareFormShowPassword => 'Passwort anzeigen';

  @override
  String get linkShareFormHidePassword => 'Passwort verbergen';

  @override
  String get linkShareFormSubmit => 'Erstellen';

  @override
  String get linkShareCreated => 'Link erstellt';

  @override
  String get linkShareCreatedBody =>
      'Teile ihn mit den Personen, die dieses Projekt öffnen sollen.';

  @override
  String get linkShareQrSemantics => 'QR-Code für den Link';

  @override
  String get linkShareQrTooLong => 'Dieser Link ist zu lang für einen QR-Code';

  @override
  String get linkShareQrHint =>
      'Scanne ihn mit der Kamera eines Handys, um das Projekt zu öffnen.';

  @override
  String get shareFailureOffline => 'Dafür braucht es eine Verbindung.';

  @override
  String get shareFailureUnconfirmed =>
      'Der Server hat nicht rechtzeitig geantwortet. Prüf die Liste, bevor du es noch einmal versuchst.';

  @override
  String get shareFailureForbidden =>
      'Nur Projekt-Admins können ändern, wer Zugriff hat.';

  @override
  String get shareFailureAlreadyShared =>
      'Diese Person hat schon Zugriff oder ihr gehört das Projekt.';

  @override
  String get shareFailureUnknownUser =>
      'Es gibt niemanden mit diesem Benutzernamen.';

  @override
  String get shareFailureGone => 'Dieser Zugriff wurde schon entfernt.';

  @override
  String get shareFailureTeamAlreadyShared => 'Dieses Team hat schon Zugriff.';

  @override
  String get shareFailureUnknownTeam => 'Dieses Team gibt es nicht mehr.';

  @override
  String get shareFailureLinkSharingOff =>
      'Linkfreigaben sind auf diesem Server ausgeschaltet.';

  @override
  String get shareFailureInvalid => 'Der Server hat das nicht angenommen.';

  @override
  String get shareFailureGeneric =>
      'Das hat nicht geklappt. Versuch es noch einmal.';

  @override
  String get shareReadOnlyProjectNote =>
      'Nur lesen: Du kannst dieses Projekt sehen, aber nicht ändern.';

  @override
  String get shareTaskReadOnly => 'Nur lesen';

  @override
  String get accountOrganiseHeading => 'Organisieren';

  @override
  String get accountLabelsEntry => 'Labels';

  @override
  String get accountTeamsEntry => 'Teams';

  @override
  String get accountTrashEntry => 'Papierkorb';

  @override
  String labelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Labels',
      one: '1 Label',
    );
    return '$_temp0';
  }

  @override
  String get labelsTitle => 'Labels';

  @override
  String get labelsLoading => 'Labels werden geladen …';

  @override
  String get labelsOwnSection => 'Deine Labels';

  @override
  String get labelsOthersSection => 'Von anderen';

  @override
  String labelsCreatedBy(String name) {
    return 'Von $name';
  }

  @override
  String labelsOptionsFor(String label) {
    return 'Optionen für $label';
  }

  @override
  String get labelsEdit => 'Bearbeiten';

  @override
  String get labelsDelete => 'Löschen';

  @override
  String get labelsSearch => 'Labels suchen';

  @override
  String labelsSearchEmpty(String query) {
    return 'Kein Label passt zu „$query“.';
  }

  @override
  String get labelsNew => 'Neues Label';

  @override
  String get labelsNewOffline =>
      'Zum Erstellen eines Labels brauchst du eine Verbindung zum Server.';

  @override
  String get labelsEmptyTitle => 'Noch keine Labels';

  @override
  String get labelsEmptyBody =>
      'Labels markieren Aufgaben über alle Projekte hinweg. Erstelle hier eins oder beim Bearbeiten einer Aufgabe.';

  @override
  String labelsShowTasks(String title) {
    return 'Aufgaben mit dem Label $title anzeigen';
  }

  @override
  String labelsDeleteTitle(String title) {
    return 'Label „$title“ löschen?';
  }

  @override
  String get labelsDeleteBody =>
      'Es wird von jeder Aufgabe entfernt, die es hat. Das lässt sich nicht rückgängig machen.';

  @override
  String get labelsDeleted => 'Label gelöscht';

  @override
  String get labelsEditTitle => 'Label bearbeiten';

  @override
  String get labelsTitleLabel => 'Titel';

  @override
  String get labelsTitleRequired => 'Gib einen Titel ein.';

  @override
  String labelsTitleRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Zeichen',
      one: 'Noch 1 Zeichen',
    );
    return '$_temp0';
  }

  @override
  String get labelsColour => 'Farbe';

  @override
  String get labelsCustomColour => 'Eigene Farbe';

  @override
  String get labelsCustomColourHelper => 'Sechs Hex-Ziffern, etwa 1973ff';

  @override
  String get labelsCustomColourInvalid =>
      'Gib drei oder sechs Hex-Ziffern ein.';

  @override
  String get labelsDescription => 'Beschreibung';

  @override
  String get labelsNoDescription => 'Keine Beschreibung';

  @override
  String get labelsEditDescription => 'Beschreibung bearbeiten';

  @override
  String get labelsAddDescription => 'Beschreibung hinzufügen';

  @override
  String get labelsDescriptionAfterCreate =>
      'Eine Beschreibung kannst du hinzufügen, sobald es das Label gibt.';

  @override
  String get labelsDescriptionCreatorOnly =>
      'Nur wer dieses Label erstellt hat, kann es ändern.';

  @override
  String get labelsCreate => 'Erstellen';

  @override
  String get labelsSave => 'Speichern';

  @override
  String get labelsSaving => 'Wird gespeichert …';

  @override
  String get labelsCreated => 'Label erstellt';

  @override
  String get labelsSaved => 'Label gespeichert';

  @override
  String get labelsDiscardBody =>
      'Deine Änderungen an diesem Label gehen verloren.';

  @override
  String get labelsGoneTitle => 'Dieses Label gibt es nicht mehr';

  @override
  String get labelsGoneBody =>
      'Vielleicht wurde es gelöscht, hier oder im Web.';

  @override
  String get labelsNeedsConnection =>
      'Zum Ändern eines Labels brauchst du eine Verbindung zum Server.';

  @override
  String get labelsUnconfirmed =>
      'Die Änderung ließ sich nicht bestätigen. Prüf deine Verbindung und zieh nach unten, um neu zu laden.';

  @override
  String get labelsNotCreator =>
      'Nur wer dieses Label erstellt hat, kann es ändern.';

  @override
  String get labelsGone => 'Dieses Label gibt es nicht mehr.';

  @override
  String get labelsInvalid =>
      'Der Server hat dieses Label nicht angenommen. Prüf Titel und Farbe.';

  @override
  String labelsRefused(String message) {
    return 'Der Server hat abgelehnt: $message';
  }

  @override
  String get labelsFailed => 'Das Label ließ sich nicht ändern.';

  @override
  String get teamsTitle => 'Teams';

  @override
  String get teamsLoading => 'Teams werden geladen …';

  @override
  String get teamsEmptyTitle => 'Noch keine Teams';

  @override
  String get teamsEmptyBody =>
      'Mit einem Team teilst du Projekte mit mehreren Personen auf einmal.';

  @override
  String get teamsNew => 'Neues Team';

  @override
  String get teamsNewOffline =>
      'Zum Erstellen eines Teams brauchst du eine Verbindung zum Server.';

  @override
  String teamMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get teamAdminBadge => 'Admin';

  @override
  String get teamPublicBadge => 'Öffentlich';

  @override
  String teamManagedBy(String provider) {
    return 'Verwaltet von $provider';
  }

  @override
  String get teamManagedExternally => 'Extern verwaltet';

  @override
  String get teamNewTitle => 'Neues Team';

  @override
  String get teamNameLabel => 'Name';

  @override
  String get teamNameRequired => 'Gib einen Namen ein.';

  @override
  String get teamPublicLabel => 'Öffentliches Team';

  @override
  String get teamPublicHelp =>
      'Alle auf diesem Server können es finden und Projekte mit ihm teilen.';

  @override
  String get teamCreate => 'Erstellen';

  @override
  String get teamCreating => 'Team wird erstellt …';

  @override
  String get teamCreated => 'Team erstellt';

  @override
  String get teamLoading => 'Team wird geladen …';

  @override
  String get teamGoneTitle => 'Dieses Team ist nicht verfügbar';

  @override
  String get teamGoneBody =>
      'Vielleicht wurde es gelöscht, oder du bist kein Mitglied mehr.';

  @override
  String get teamEdit => 'Team bearbeiten';

  @override
  String get teamEditDescription => 'Beschreibung bearbeiten';

  @override
  String get teamAddDescription => 'Beschreibung hinzufügen';

  @override
  String get teamSave => 'Speichern';

  @override
  String get teamSaving => 'Wird gespeichert …';

  @override
  String get teamSaved => 'Team gespeichert';

  @override
  String teamExternalNote(String provider) {
    return 'Dieses Team wird von $provider verwaltet. Wer Mitglied ist, wird dort festgelegt.';
  }

  @override
  String get teamExternalNoteGeneric =>
      'Dieses Team wird von der Anmeldung deiner Organisation verwaltet. Wer Mitglied ist, wird dort festgelegt.';

  @override
  String get teamMembersSection => 'Mitglieder';

  @override
  String teamMemberYou(String name) {
    return '$name (du)';
  }

  @override
  String get teamRoleAdmin => 'Admin';

  @override
  String get teamRoleMember => 'Mitglied';

  @override
  String teamMemberOptionsFor(String name) {
    return 'Optionen für $name';
  }

  @override
  String get teamMakeAdmin => 'Zum Admin machen';

  @override
  String get teamMakeMember => 'Zum Mitglied machen';

  @override
  String get teamRemoveMember => 'Aus dem Team entfernen';

  @override
  String teamMadeAdmin(String name) {
    return '$name ist jetzt Admin';
  }

  @override
  String teamMadeMember(String name) {
    return '$name ist jetzt Mitglied';
  }

  @override
  String get teamAddMember => 'Mitglied hinzufügen';

  @override
  String teamMemberAdded(String name) {
    return '$name zum Team hinzugefügt';
  }

  @override
  String teamMemberRemoved(String name) {
    return '$name aus dem Team entfernt';
  }

  @override
  String teamRemoveTitle(String name) {
    return '$name aus dem Team entfernen?';
  }

  @override
  String teamRemoveBody(String name) {
    return '$name verliert den Zugriff auf alle Projekte, die mit diesem Team geteilt sind.';
  }

  @override
  String get teamRemoveConfirm => 'Entfernen';

  @override
  String get teamLeave => 'Team verlassen';

  @override
  String teamLeaveTitle(String team) {
    return '„$team“ verlassen?';
  }

  @override
  String get teamLeaveBody =>
      'Du verlierst den Zugriff auf alle Projekte, die mit diesem Team geteilt sind. Ein Team-Admin müsste dich wieder hinzufügen.';

  @override
  String get teamLeaveConfirm => 'Verlassen';

  @override
  String get teamLeft => 'Du hast das Team verlassen';

  @override
  String get teamOnlyAdminTitle => 'Mach zuerst jemand anderen zum Admin';

  @override
  String get teamOnlyAdminBody =>
      'Außer dir ist niemand Admin in diesem Team. Ohne Admin könnte niemand es mehr ändern.';

  @override
  String get teamLastMemberTitle => 'Du bist das letzte Mitglied';

  @override
  String get teamLastMemberBody =>
      'Das letzte Mitglied kann ein Team nicht verlassen. Stattdessen das Team löschen?';

  @override
  String get teamDelete => 'Team löschen';

  @override
  String teamDeleteTitle(String team) {
    return '„$team“ löschen?';
  }

  @override
  String get teamDeleteBody =>
      'Alle Mitglieder verlieren den Zugriff auf alle Projekte, die mit diesem Team geteilt sind. Das lässt sich nicht rückgängig machen.';

  @override
  String get teamDeleted => 'Team gelöscht';

  @override
  String get teamAddMemberOffline =>
      'Zum Hinzufügen von Mitgliedern brauchst du eine Verbindung zum Server.';

  @override
  String get teamNeedsConnection =>
      'Zum Ändern eines Teams brauchst du eine Verbindung zum Server.';

  @override
  String get teamUnconfirmed =>
      'Die Änderung ließ sich nicht bestätigen. Prüf deine Verbindung und zieh nach unten, um neu zu laden.';

  @override
  String get teamForbidden => 'Das dürfen nur Team-Admins.';

  @override
  String get teamAlreadyMember => 'Diese Person ist schon Mitglied des Teams.';

  @override
  String get teamLastMemberRefused =>
      'Das letzte Mitglied kann ein Team nicht verlassen. Lösch stattdessen das Team.';

  @override
  String get teamExternalRefused =>
      'Aus einem Team, das von der Anmeldung deiner Organisation verwaltet wird, können keine Mitglieder entfernt werden.';

  @override
  String get teamUnknownUser => 'Diese Person gibt es auf diesem Server nicht.';

  @override
  String get teamNotMember => 'Diese Person ist nicht mehr im Team.';

  @override
  String get teamInvalid =>
      'Der Server hat das nicht angenommen. Ein Name braucht 1 bis 250 Zeichen.';

  @override
  String get teamGone =>
      'Dieses Team gibt es nicht mehr, oder du bist nicht mehr dabei.';

  @override
  String teamRefused(String message) {
    return 'Der Server hat abgelehnt: $message';
  }

  @override
  String get teamFailed => 'Das hat nicht geklappt. Versuch es noch einmal.';

  @override
  String get teamOk => 'OK';

  @override
  String get trashTitle => 'Papierkorb';

  @override
  String get trashTasksTab => 'Aufgaben';

  @override
  String get trashProjectsTab => 'Projekte';

  @override
  String get trashTabsLabel => 'Aufgaben oder Projekte im Papierkorb';

  @override
  String get trashLoading => 'Papierkorb wird geladen …';

  @override
  String get trashRetentionNote =>
      'Der Server löscht, was im Papierkorb liegt, nach 30 Tagen endgültig.';

  @override
  String get trashTasksEmptyTitle => 'Keine Aufgaben im Papierkorb';

  @override
  String get trashTasksEmptyBody =>
      'Gelöschte Aufgaben bleiben 30 Tage lang hier. Danach löscht der Server sie endgültig.';

  @override
  String get trashProjectsEmptyTitle => 'Keine Projekte im Papierkorb';

  @override
  String get trashProjectsEmptyBody =>
      'Gelöschte Projekte bleiben 30 Tage lang hier, nur für ihre Admins. Danach löscht der Server sie endgültig.';

  @override
  String trashDeletedBy(String when, String name) {
    return 'Gelöscht $when von $name';
  }

  @override
  String trashDeletedByYou(String when) {
    return 'Gelöscht $when von dir';
  }

  @override
  String trashDeletedByLinkShare(String when) {
    return 'Gelöscht $when über eine Linkfreigabe';
  }

  @override
  String trashDeletedWhen(String when) {
    return 'Gelöscht $when';
  }

  @override
  String trashDeletedForGoodIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Wird in $days Tagen endgültig gelöscht',
      one: 'Wird in $days Tag endgültig gelöscht',
      zero: 'Wird heute endgültig gelöscht',
    );
    return '$_temp0';
  }

  @override
  String trashSubprojects(int count, String titles) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mit $count Unterprojekten: $titles',
      one: 'Mit $count Unterprojekt: $titles',
    );
    return '$_temp0';
  }

  @override
  String trashRestoreItem(String title) {
    return '„$title“ wiederherstellen';
  }

  @override
  String trashDeleteForeverItem(String title) {
    return '„$title“ endgültig löschen';
  }

  @override
  String trashDeleteForeverTitle(String title) {
    return '„$title“ endgültig löschen?';
  }

  @override
  String get trashDeleteTaskForeverBody =>
      'Sie wird endgültig gelöscht, mit ihren Kommentaren, Anhängen, Erinnerungen und Verknüpfungen. Das lässt sich nicht rückgängig machen.';

  @override
  String get trashDeleteProjectForeverBody =>
      'Es wird endgültig gelöscht, mit seinen Unterprojekten, Aufgaben, Ansichten und Freigaben. Das lässt sich nicht rückgängig machen.';

  @override
  String get trashDeleteForever => 'Endgültig löschen';

  @override
  String get trashTaskDeletedForever => 'Aufgabe endgültig gelöscht';

  @override
  String get trashProjectDeletedForever => 'Projekt endgültig gelöscht';

  @override
  String get trashEmpty => 'Papierkorb leeren';

  @override
  String get trashEmptyTasksTitle =>
      'Aufgaben im Papierkorb endgültig löschen?';

  @override
  String get trashEmptyProjectsTitle =>
      'Projekte im Papierkorb endgültig löschen?';

  @override
  String trashEmptyTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben werden endgültig gelöscht.',
      one: '$count Aufgabe wird endgültig gelöscht.',
    );
    return '$_temp0';
  }

  @override
  String trashEmptyProjects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Projekte werden endgültig gelöscht, mit allem darin.',
      one: '$count Projekt wird endgültig gelöscht, mit allem darin.',
    );
    return '$_temp0';
  }

  @override
  String trashEmptyByOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count davon haben andere in den Papierkorb verschoben.',
      one: '$count davon hat jemand anderes in den Papierkorb verschoben.',
    );
    return '$_temp0';
  }

  @override
  String get trashEmptyKeepsOthers =>
      'Aufgaben in Projekten, in denen du kein Admin bist, bleiben im Papierkorb.';

  @override
  String get trashEmptyNothing =>
      'Nur Projekt-Admins können sie endgültig löschen, hier gibt es also nichts, was du löschen kannst.';

  @override
  String get trashCannotBeUndone => 'Das lässt sich nicht rückgängig machen.';

  @override
  String get trashEmptied => 'Papierkorb geleert';

  @override
  String get trashWorking => 'Wird ausgeführt';

  @override
  String get trashRestoreNeedsConnection =>
      'Zum Wiederherstellen brauchst du eine Verbindung zum Server.';

  @override
  String get trashNeedsConnection =>
      'Für den Papierkorb brauchst du eine Verbindung zum Server.';

  @override
  String get trashTaskGone => 'Diese Aufgabe ist nicht mehr im Papierkorb.';

  @override
  String get trashProjectGone => 'Dieses Projekt ist nicht mehr im Papierkorb.';

  @override
  String get trashRestoreArchived =>
      'Das Projekt der Aufgabe ist archiviert. Hebe die Archivierung des Projekts auf, um die Aufgabe wiederherzustellen.';

  @override
  String get trashDeleteArchived =>
      'Das Projekt der Aufgabe ist archiviert. Hebe die Archivierung des Projekts auf, um die Aufgabe endgültig zu löschen.';

  @override
  String get trashTaskProjectInTrash =>
      'Das Projekt der Aufgabe ist im Papierkorb. Stelle zuerst das Projekt wieder her.';

  @override
  String get trashRestoreParentInTrash =>
      'Sein übergeordnetes Projekt ist im Papierkorb. Stelle zuerst dieses wieder her.';

  @override
  String get trashRestoreTaskForbidden =>
      'Du hast keine Berechtigung, in diesem Projekt Aufgaben wiederherzustellen.';

  @override
  String get trashRestoreProjectAdminOnly =>
      'Nur Projekt-Admins können ein Projekt wiederherstellen.';

  @override
  String get trashDeleteTaskAdminOnly =>
      'Nur Projekt-Admins können Aufgaben endgültig löschen.';

  @override
  String get trashDeleteProjectAdminOnly =>
      'Nur Projekt-Admins können ein Projekt endgültig löschen.';

  @override
  String get trashDeleteStillSending =>
      'Das Löschen ist noch unterwegs zum Server. Versuche es gleich noch einmal.';

  @override
  String get trashUnavailable => 'Dieser Server hat keinen Papierkorb.';

  @override
  String trashActionRefused(String message) {
    return 'Der Server hat das abgelehnt: $message';
  }

  @override
  String get trashActionFailed =>
      'Das hat nicht geklappt. Versuche es noch einmal.';

  @override
  String get shareLowerOwnAccessTitle => 'Deinen eigenen Zugriff einschränken?';

  @override
  String get shareLowerOwnAccessAdminBody =>
      'Danach kannst du womöglich nicht mehr ändern, wer Zugriff auf dieses Projekt hat, und es auch nicht selbst rückgängig machen.';

  @override
  String get shareLowerOwnAccessWriteBody =>
      'Danach kannst du dieses Projekt und seine Aufgaben womöglich nicht mehr ändern.';

  @override
  String get shareLowerOwnAccessConfirm => 'Zugriff einschränken';

  @override
  String get shareRemovedSelf => 'Du hast dich entfernt';

  @override
  String get shareNoAccessTitle =>
      'Du hast keinen Zugriff mehr auf dieses Projekt';

  @override
  String get shareNoAccessBody =>
      'Es ist von diesem Gerät verschwunden. Jemand mit Zugriff kann es wieder mit dir teilen.';

  @override
  String get shareChangeAccessHint => 'Zugriff ändern';

  @override
  String get linkShareRowHint => 'Link teilen, kopieren oder löschen';

  @override
  String linkShareShareNamed(String name) {
    return '$name teilen';
  }

  @override
  String get projectTimelineRangeTitle => 'Zeitraum';

  @override
  String projectTimelineRangeCurrent(String dates) {
    return 'Zeitraum: $dates';
  }

  @override
  String get projectTimelineRangeDefault =>
      'Standard (15 Tage zurück, 55 voraus)';

  @override
  String get projectTimelineRangeCustom => 'Eigener Zeitraum …';

  @override
  String get projectTimelineReset => 'Auf Standard zurücksetzen';

  @override
  String get projectTimelineZoomIn => 'Vergrößern';

  @override
  String get projectTimelineZoomOut => 'Verkleinern';

  @override
  String get projectTimelineGoToToday => 'Zu heute springen';

  @override
  String projectTimelineSpanSemantics(String from, String to) {
    return '$from bis $to';
  }

  @override
  String projectTimelineStartOnlySemantics(String date) {
    return 'beginnt am $date, offenes Ende';
  }

  @override
  String projectTimelineEndOnlySemantics(String date) {
    return 'endet am $date, offener Beginn';
  }

  @override
  String projectTimelineDueOnlySemantics(String date) {
    return 'fällig am $date, offener Beginn';
  }

  @override
  String get projectTimelineEstimatedSemantics => 'ohne Datum, geschätzt';

  @override
  String get projectTimelineDerivedSemantics => 'Daten aus den Unteraufgaben';

  @override
  String projectTimelineExpand(String title) {
    return 'Unteraufgaben von $title anzeigen';
  }

  @override
  String projectTimelineCollapse(String title) {
    return 'Unteraufgaben von $title ausblenden';
  }

  @override
  String projectTimelineEmptyTitle(String from, String to) {
    return 'Keine Aufgaben zwischen $from und $to';
  }

  @override
  String get projectTimelineEmptyBody =>
      'Wähle einen anderen Zeitraum oder zeige Aufgaben ohne Datum an.';

  @override
  String get projectTimelineEmptyRangeBody => 'Wähle einen anderen Zeitraum.';

  @override
  String get projectTableColumns => 'Spalten';

  @override
  String get projectTableColumnsHint =>
      'Wähle, was jede Zeile zeigt. Die Auswahl gilt für alle Tabellenansichten.';

  @override
  String get projectTableColumnsReset => 'Standardspalten';

  @override
  String get projectTableColumnTitleAlways => 'Jede Zeile zeigt ihn';

  @override
  String get projectTableColumnComments => 'Kommentare';

  @override
  String get projectTableColumnDoneAt => 'Erledigt am';

  @override
  String get projectTableColumnCreated => 'Erstellt';

  @override
  String get projectTableColumnUpdated => 'Aktualisiert';

  @override
  String get projectTableColumnCreatedBy => 'Erstellt von';

  @override
  String get projectTableSortDefault => 'Standard (neueste zuerst)';

  @override
  String get projectTableSortDoneAsc => 'Erledigt (offene zuerst)';

  @override
  String get projectTableSortDoneDesc => 'Erledigt (erledigte zuerst)';

  @override
  String get projectTableSortDoneAtDesc => 'Erledigt am (neueste zuerst)';

  @override
  String get projectTableSortDoneAtAsc => 'Erledigt am (älteste zuerst)';

  @override
  String projectTableStartsSemantics(String when) {
    return 'Beginnt $when';
  }

  @override
  String projectTableEndsSemantics(String when) {
    return 'Endet $when';
  }

  @override
  String projectTableCreatedBySemantics(String name) {
    return 'Erstellt von $name';
  }

  @override
  String projectTableCellPercent(int percent) {
    return '$percent %';
  }

  @override
  String projectViewsIntro(String project) {
    return 'Die Ansichten von $project in der Reihenfolge, in der die App und das Web sie anzeigen.';
  }

  @override
  String get projectTimelineShowUndated => 'Ohne Datum anzeigen';

  @override
  String get overviewCreateAccount => 'Konto erstellen';

  @override
  String get overviewCreateAccountHint =>
      'Wähle auf der Anmeldeseite „Account erstellen“. Danach kommst du hierher zurück.';

  @override
  String get overviewForgotPassword => 'Passwort vergessen?';

  @override
  String get overviewRegistrationNeedsInvitation =>
      'Zum Registrieren brauchst du eine Einladung.';

  @override
  String get overviewSignInPageOffersBoth =>
      'Auf der Anmeldeseite kannst du auch ein Konto erstellen und dein Passwort zurücksetzen.';

  @override
  String get overviewSignInPageOffersRegistration =>
      'Auf der Anmeldeseite kannst du auch ein Konto erstellen.';

  @override
  String get overviewSignInPageOffersPasswordReset =>
      'Auf der Anmeldeseite kannst du auch dein Passwort zurücksetzen.';

  @override
  String get overviewDemoNote =>
      'Das ist ein Demo-Server. Die Daten darauf können jederzeit gelöscht werden.';

  @override
  String guestAccountSubtitle(String host) {
    return 'Gast · $host';
  }

  @override
  String get guestOpenLinkAgain => 'Link erneut öffnen';

  @override
  String get guestReauthTitle => 'Gastzugang beendet';

  @override
  String guestReauthBody(String host) {
    return '$host hat diesen Gastzugang beendet. Öffne den geteilten Link erneut, damit das Projekt synchron bleibt: Ein Link mit Passwort fragt danach, und für einen gelöschten Link brauchst du einen neuen von der Person, die ihn geteilt hat. Auf diesem Gerät geht nichts verloren.';
  }

  @override
  String guestSwitcherButton(String name, String host) {
    return 'Konten, Gast in $name auf $host';
  }

  @override
  String guestNotePermission(String permission) {
    return 'Geteilter Link: $permission';
  }

  @override
  String get guestNoteCanView =>
      'Du kannst die Aufgaben, Kommentare und Anhänge dieses Projekts ansehen.';

  @override
  String get guestNoteCanChange =>
      'Du kannst die Aufgaben dieses Projekts ansehen und ändern, kommentieren und Anhänge hinzufügen.';

  @override
  String get guestNoteNeedsAccount =>
      'Kontoeinstellungen, Labels, Teams, Favoriten, Reaktionen und die Benachrichtigungen des Servers brauchen ein eigenes Konto.';

  @override
  String get guestRemove => 'Gastzugang entfernen';

  @override
  String get guestRemoveDialogTitle => 'Gastzugang entfernen?';

  @override
  String guestRemoveDialogBody(String name, String host) {
    return 'Die App entfernt den Gastzugang zu $name auf $host und löscht die auf diesem Gerät gespeicherten Aufgaben. Du kannst den geteilten Link jederzeit wieder öffnen.';
  }

  @override
  String guestRemoveDialogPendingChangesOpenLinkFirst(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Änderungen wurden noch nicht an den Server gesendet und gehen verloren; wechsle vorher zu diesem Gastzugang, öffne den Link erneut und tippe auf „Jetzt senden“, um sie zu behalten.',
      one: 'Eine Änderung wurde noch nicht an den Server gesendet und geht verloren; wechsle vorher zu diesem Gastzugang, öffne den Link erneut und tippe auf „Jetzt senden“, um sie zu behalten.',
    );
    return '$_temp0';
  }

  @override
  String guestRemoved(String name) {
    return 'Gastzugang zu $name entfernt';
  }

  @override
  String get guestOpenSharedLink => 'Geteilten Link öffnen';

  @override
  String get guestLinkExplanation =>
      'Du hast einen Link zu einem geteilten Projekt bekommen? Öffne ihn hier als Gast, ohne eigenes Konto.';

  @override
  String get guestLinkLabel => 'Geteilter Link';

  @override
  String get guestLinkHint => 'https://vikunja.example.com/share/…/auth';

  @override
  String get guestLinkPaste => 'Einfügen';

  @override
  String get guestLinkOpen => 'Öffnen';

  @override
  String get guestLinkInvalid =>
      'Das ist kein Link zu einem geteilten Projekt. So ein Link endet auf /share/…/auth.';

  @override
  String get guestLinkClipboardEmpty => 'In der Zwischenablage ist kein Text.';

  @override
  String guestConnectingTo(String link) {
    return 'Geteilter Link $link wird geöffnet …';
  }

  @override
  String get guestPasswordTitle => 'Passwort nötig';

  @override
  String get guestPasswordBody =>
      'Dieses geteilte Projekt ist mit einem Passwort geschützt. Gib das Passwort ein, das du mit dem Link bekommen hast.';

  @override
  String get guestPasswordLabel => 'Passwort';

  @override
  String get guestPasswordWrong =>
      'Falsches Passwort. Prüf es und versuch es noch einmal.';

  @override
  String get guestPasswordNotStored =>
      'Die App speichert dieses Passwort nicht. Muss der Link später erneut geöffnet werden, fragt sie wieder danach.';

  @override
  String get guestShareTitle => 'Geteiltes Projekt öffnen?';

  @override
  String guestShareBody(String host) {
    return 'Das ist ein Link zu einem Projekt auf $host. Öffne es als Gast, ohne eigenes Konto.';
  }

  @override
  String get guestShareOpen => 'Als Gast öffnen';

  @override
  String get guestShareNewTask => 'Stattdessen als neue Aufgabe erstellen';

  @override
  String get guestLinkGoneTitle => 'Dieser Link funktioniert nicht';

  @override
  String guestLinkGoneExplanation(String host) {
    return '$host nimmt diesen geteilten Link nicht an. Er wurde gelöscht oder ist unvollständig, oder der Server erlaubt keine geteilten Links mehr.';
  }

  @override
  String get guestLinkGoneSuggestion =>
      'Bitte die Person, die das Projekt geteilt hat, um einen neuen Link.';

  @override
  String inviteConnectingTo(String host) {
    return 'Einladung zu $host wird geprüft …';
  }

  @override
  String inviteHeading(String host) {
    return 'Einladung zu $host';
  }

  @override
  String inviteTeams(String teams) {
    return 'Du trittst bei: $teams';
  }

  @override
  String get inviteNoEmailConfirmation =>
      'Dein Konto funktioniert sofort, ohne dass du deine E-Mail-Adresse bestätigst.';

  @override
  String get inviteEmailConfirmation =>
      'Eventuell musst du deine E-Mail-Adresse bestätigen, bevor du dich anmelden kannst.';

  @override
  String get inviteSteps =>
      'Erstelle dein Konto im Browser, komm dann hierher zurück und melde dich an.';

  @override
  String get inviteCreateAccount => 'Konto im Browser erstellen';

  @override
  String get inviteUnchecked =>
      'Dieser Server kann Einladungen nicht aus der App prüfen. Öffne die Einladung im Browser, um dein Konto zu erstellen.';

  @override
  String get inviteCheckFailed =>
      'Die Einladung konnte gerade nicht geprüft werden. Du kannst sie trotzdem im Browser öffnen.';

  @override
  String get inviteInvalidTitle => 'Einladung nicht gültig';

  @override
  String get inviteInvalidExplanation =>
      'Diese Einladung ist ungültig, abgelaufen oder aufgebraucht.';

  @override
  String get inviteInvalidSuggestion =>
      'Bitte die Person, die dich eingeladen hat, um einen neuen Link. Mit einem eigenen Konto gib stattdessen die Adresse des Servers ein.';

  @override
  String get guestLabelPickerNote =>
      'Über einen geteilten Link kannst du nur Labels hinzufügen, die dieses Projekt schon verwendet, aber keine neuen.';

  @override
  String guestSharingOffExplanation(String host) {
    return '$host erlaubt nicht, Projekte über geteilte Links zu öffnen.';
  }

  @override
  String get guestSharingOffSuggestion =>
      'Bitte die Person, die das Projekt geteilt hat, es stattdessen mit einem Konto von dir zu teilen.';

  @override
  String get guestServerNeededTitle => 'Welcher Server ist es?';

  @override
  String guestServerNeededExplanation(String host) {
    return 'Der Link zeigt auf $host, aber dort antwortet kein Vikunja-Server. Der Server hat vielleicht eine eigene Adresse.';
  }

  @override
  String get guestServerNeededSuggestion =>
      'Gib oben die Adresse des Servers ein und tippe auf „Weiter“, um den Link zu öffnen.';

  @override
  String get guestAlreadyAdded =>
      'Dieses geteilte Projekt war schon auf diesem Gerät. Zu ihm gewechselt.';

  @override
  String guestAccessEndedNotificationTitle(String name) {
    return 'Gastzugang zu $name beendet';
  }

  @override
  String guestAccessEndedNotificationBody(String host) {
    return '$host hat diesen Gastzugang beendet. Die App kann das Projekt erst wieder synchronisieren, wenn du den geteilten Link erneut öffnest.';
  }

  @override
  String guestDataFailureAccessEnded(String host) {
    return 'Dein Gastzugang auf $host ist beendet. Öffne den Link im Tab „Konto“ erneut.';
  }

  @override
  String get overviewGreetingMorningGuest => 'Guten Morgen';

  @override
  String get overviewGreetingAfternoonGuest => 'Guten Tag';

  @override
  String get overviewGreetingEveningGuest => 'Guten Abend';

  @override
  String widgetDueAt(String day, String time) {
    return '$day, $time';
  }

  @override
  String widgetMoreTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count weitere',
      one: '+1 weitere',
    );
    return '$_temp0';
  }

  @override
  String widgetTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '1 Aufgabe',
      zero: 'Keine Aufgaben',
    );
    return '$_temp0';
  }

  @override
  String widgetMarkDone(String title) {
    return '„$title“ als erledigt markieren';
  }

  @override
  String widgetUpcomingTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Nächste $days Tage',
      one: 'Nächster Tag',
    );
    return '$_temp0';
  }

  @override
  String get widgetAccountRemovedTitle => 'Konto entfernt';

  @override
  String get widgetChooseAnotherList =>
      'Wähle eine andere Liste für dieses Widget.';

  @override
  String get widgetTodayEmptyBody => 'Heute ist nichts fällig.';

  @override
  String get widgetOverdueEmptyTitle => 'Nichts überfällig';

  @override
  String widgetAccountSubtitle(String name, String host) {
    return '$name · $host';
  }

  @override
  String get widgetsTitle => 'Widgets für den Startbildschirm';

  @override
  String get widgetsEntrySubtitle =>
      'Deine Aufgaben auf dem Startbildschirm, direkt dort abhaken';

  @override
  String get widgetsIntro =>
      'Ein Widget zeigt eine Liste eines Kontos: die Aufgaben von heute, die nächsten Tage, die überfälligen, deine Favoriten, ein Projekt, ein Label oder einen gespeicherten Filter. Hake eine Aufgabe direkt dort ab oder tippe sie an, um sie hier zu öffnen.';

  @override
  String get widgetsHowToHeading => 'So fügst du eins hinzu';

  @override
  String get widgetsHowToIos =>
      'Halte eine freie Stelle auf dem Home-Bildschirm gedrückt, tippe auf „Bearbeiten“ und dann auf „Widget hinzufügen“ und suche nach Vikunja. Um Konto und Liste zu wählen, halte das Widget gedrückt und tippe auf „Widget bearbeiten“.';

  @override
  String get widgetsAddHeading => 'Widget hinzufügen';

  @override
  String get widgetsAddHint =>
      'Es zeigt das aktive Konto; das kannst du in seinen Einstellungen ändern.';

  @override
  String get widgetsAdd => 'Hinzufügen';

  @override
  String get widgetsPinUnsupported =>
      'Dein Startbildschirm kann von hier aus keine Widgets hinzufügen. Füge es direkt auf dem Startbildschirm hinzu.';

  @override
  String get widgetsPlacedHeading => 'Auf deinem Startbildschirm';

  @override
  String get widgetsPlacedAccountRemoved =>
      'Konto entfernt – wähle ein anderes';

  @override
  String get widgetsPrivacyNote =>
      'Widgets zeigen die Titel deiner Aufgaben auf dem Startbildschirm, wo jeder sie lesen kann, der dein Gerät sieht.';

  @override
  String get widgetKindToday => 'Heute';

  @override
  String get widgetKindTodayHint => 'Überfällig und heute fällig';

  @override
  String get widgetKindUpcoming => 'Anstehend';

  @override
  String get widgetKindUpcomingHint => 'In den nächsten Tagen fällig';

  @override
  String get widgetKindOverdue => 'Überfällig';

  @override
  String get widgetKindOverdueHint => 'Fälligkeit überschritten';

  @override
  String get widgetKindFavorites => 'Favoriten';

  @override
  String get widgetKindFavoritesHint => 'Deine Favoriten unter den Aufgaben';

  @override
  String get widgetKindProject => 'Projekt';

  @override
  String get widgetKindLabel => 'Label';

  @override
  String get widgetKindSavedFilter => 'Gespeicherter Filter';

  @override
  String get widgetKindQuickAdd => 'Button „Neue Aufgabe“';

  @override
  String get widgetKindQuickAddHint => 'Mit einem Tipp zur neuen Aufgabe';

  @override
  String widgetUpcomingDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get widgetConfigureTitle => 'Widget einrichten';

  @override
  String get widgetConfigureAccountHeading => 'Konto';

  @override
  String get widgetConfigureListHeading => 'Zeigt';

  @override
  String get widgetConfigureDaysLabel => 'Tage im Voraus';

  @override
  String get widgetConfigureChoose => 'Auswählen';

  @override
  String get widgetConfigureNoProjects =>
      'Dieses Konto hat keine Projekte zum Anzeigen.';

  @override
  String get widgetConfigureNoLabels => 'Dieses Konto hat noch keine Labels.';

  @override
  String get widgetConfigureNoSavedFilters =>
      'Dieses Konto hat noch keine gespeicherten Filter.';

  @override
  String get widgetConfigurePreviewHeading => 'Vorschau';

  @override
  String get widgetConfigurePreviewNone => 'Noch keine Vorschau';

  @override
  String get widgetConfigureSave => 'Speichern';

  @override
  String get widgetConfigureSaving => 'Wird gespeichert …';

  @override
  String get widgetConfigureSaved => 'Widget eingerichtet';

  @override
  String get widgetConfigureSaveFailed =>
      'Das Widget konnte nicht gespeichert werden. Versuch es noch einmal.';

  @override
  String get widgetsHeading => 'Startbildschirm';

  @override
  String get widgetsEntryTitle => 'Widgets';

  @override
  String get widgetsHowToAndroid =>
      'Halte eine freie Stelle auf dem Startbildschirm gedrückt, tippe auf „Widgets“ und suche nach Vikunja. Um Konto und Liste zu wählen, tippe unten unter „Auf deinem Startbildschirm“ auf das Widget. Manche Startbildschirme bieten das auch in den Einstellungen des Widgets an, wenn du es gedrückt hältst.';

  @override
  String get widgetsPlacedNotSetUp =>
      'Noch nicht eingerichtet – zeigt das aktive Konto';

  @override
  String get notificationContentReminderTitle => 'Erinnerung an eine Aufgabe';

  @override
  String get notificationContentDueTitle => 'Aufgabe fällig';

  @override
  String get notificationContentBody => 'Öffne Vikunja, um sie zu sehen';

  @override
  String get notificationContentActivityTitle => 'Neue Aktivität';

  @override
  String get privacyTitle => 'Privatsphäre';

  @override
  String get privacyEntryTitle => 'App-Sperre und Privatsphäre';

  @override
  String get privacyEntryAppLockOff => 'App-Sperre: Aus';

  @override
  String get privacyEntryAppLockImmediately => 'App-Sperre: An · sofort';

  @override
  String privacyEntryAppLockAfter(String duration) {
    return 'App-Sperre: An · nach $duration';
  }

  @override
  String get privacyLockAfterImmediately => 'Sofort';

  @override
  String privacyLockAfterMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String privacyLockAfterHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String get privacyAppLockHeading => 'App-Sperre';

  @override
  String get privacyAppLockSwitch => 'Vikunja sperren';

  @override
  String get privacyAppLockSubtitle =>
      'Mit Biometrie oder der Displaysperre des Geräts entsperren';

  @override
  String get privacyAppLockUnsupported =>
      'Richte zuerst eine Displaysperre auf diesem Gerät ein';

  @override
  String get privacyAppLockLockedOut =>
      'Zu viele Versuche. Versuch es später noch einmal.';

  @override
  String get privacyAppLockFailed =>
      'Die Displaysperre ließ sich nicht prüfen. Versuch es noch einmal.';

  @override
  String get privacyLockAfter => 'Sperren nach';

  @override
  String get privacyLockAfterRestart =>
      'Nach einem Neustart sperrt sich Vikunja immer.';

  @override
  String get privacyAppSwitcherHidden =>
      'Solange die Sperre an ist, verbirgt die App-Übersicht den Inhalt von Vikunja.';

  @override
  String get privacyAppSwitcherBestEffort =>
      'Solange die Sperre an ist, verbirgt die App-Übersicht den Inhalt von Vikunja, soweit diese Android-Version es zulässt. Schalte „Screenshots blockieren“ ein, um sicherzugehen.';

  @override
  String get privacyScreenshotsHeading => 'Screenshots';

  @override
  String get privacyBlockScreenshots => 'Screenshots blockieren';

  @override
  String get privacyBlockScreenshotsSubtitle =>
      'Verbirgt Vikunja auch vor Bildschirmaufnahmen und der App-Übersicht.';

  @override
  String get privacyNotificationContentHeading =>
      'Inhalt von Benachrichtigungen';

  @override
  String get privacyNotificationContentAll => 'Alles anzeigen';

  @override
  String get privacyNotificationContentAllSubtitle =>
      'Aufgabentitel und Kommentare, auch auf dem Sperrbildschirm';

  @override
  String get privacyNotificationContentHidden =>
      'Auf dem Sperrbildschirm verbergen';

  @override
  String get privacyNotificationContentHiddenSubtitle =>
      'Der Inhalt erscheint nur, wenn das Gerät entsperrt ist';

  @override
  String get privacyNotificationContentNoTitles => 'Nie Aufgabentitel anzeigen';

  @override
  String get privacyNotificationContentNoTitlesSubtitle =>
      'Allgemeine Texte ohne Aufgabentitel, Namen oder Kommentare';

  @override
  String get privacyNotificationContentIosHint =>
      'iOS legt das für jede App fest: Stelle unter Einstellungen › Mitteilungen › Vikunja „Vorschauen zeigen“ auf „Wenn entsperrt“.';

  @override
  String get privacyWidgetsHeading => 'Widgets';

  @override
  String get privacyWidgetTitles => 'Aufgabentitel in Widgets anzeigen';

  @override
  String get privacyWidgetTitlesSubtitle =>
      'Wenn aus, zeigen Widgets nur, wie viele Aufgaben es sind';

  @override
  String get privacySettingsUnreadable =>
      'Deine Privatsphäre-Einstellungen ließen sich nicht lesen, deshalb hat sich Vikunja gesperrt. Wähle sie hier neu.';

  @override
  String get appLockPromptReason => 'Vikunja entsperren';

  @override
  String get privacyAppLockReasonOn =>
      'Bestätige, dass du es bist, um die App-Sperre einzuschalten';

  @override
  String get privacyAppLockReasonOff =>
      'Bestätige, dass du es bist, um die App-Sperre auszuschalten';

  @override
  String get privacySaveFailed =>
      'Die Einstellung ließ sich nicht speichern. Versuch es noch einmal.';

  @override
  String get appLockTitle => 'Vikunja ist gesperrt';

  @override
  String get appLockBody =>
      'Entsperre mit Biometrie oder der Displaysperre deines Geräts.';

  @override
  String get appLockUnlock => 'Entsperren';

  @override
  String get appLockLockedOut =>
      'Zu viele Versuche. Versuch es später noch einmal.';

  @override
  String get appLockUnavailable =>
      'Vikunja konnte deine Displaysperre nicht prüfen. Versuch es noch einmal.';

  @override
  String get appLockTurnedOff =>
      'Die App-Sperre wurde ausgeschaltet, weil dieses Gerät keine Displaysperre hat.';

  @override
  String get appLockPromptHint =>
      'Nutze Fingerabdruck, Gesicht oder Displaysperre';

  @override
  String get appLockPromptStuck =>
      'Die Entsperrabfrage reagiert nicht. Schließe Vikunja ganz und öffne es neu.';

  @override
  String widgetTitlesHiddenHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Öffne Vikunja, um sie zu sehen',
    );
    return '$_temp0';
  }

  @override
  String get privacyNotificationContentHiddenSubtitleAndroid =>
      'Benachrichtigungen erscheinen nicht auf dem Sperrbildschirm; du siehst sie nach dem Entsperren';

  @override
  String get connectionClientCertificateFailureTitle =>
      'Client-Zertifikat nicht akzeptiert';

  @override
  String connectionClientCertificateFailureExplanation(String host) {
    return '$host hat kein Client-Zertifikat von diesem Gerät akzeptiert.';
  }

  @override
  String connectionClientCertificateNeededExplanation(String host) {
    return '$host verlangt ein Client-Zertifikat.';
  }

  @override
  String connectionClientCertificateRefusedExplanation(String host) {
    return '$host hat das gespeicherte Client-Zertifikat abgelehnt.';
  }

  @override
  String get connectionClientCertificateFailureSuggestion =>
      'Füge das Client-Zertifikat (eine .p12- oder .pfx-Datei) in den Verbindungseinstellungen dieses Servers hinzu.';

  @override
  String get connectionClientCertificateRefusedSuggestion =>
      'Prüfe, ob es das richtige Zertifikat und noch gültig ist, oder ersetze es in den Verbindungseinstellungen dieses Servers.';

  @override
  String get connectionCleartextBlockedTitle =>
      'Unverschlüsselte Verbindung nicht erlaubt';

  @override
  String connectionCleartextBlockedExplanation(String host) {
    return 'Unverschlüsselte Verbindungen zu $host sind auf diesem Gerät nicht erlaubt.';
  }

  @override
  String get connectionCleartextBlockedSuggestion =>
      'Erlaube unverschlüsselte Verbindungen in den Verbindungseinstellungen dieses Servers, wenn du dem Netzwerk vertraust.';

  @override
  String get connectionProfileLockedTitle =>
      'Verbindungseinstellungen noch nicht verfügbar';

  @override
  String connectionProfileLockedExplanation(String host) {
    return 'Die Verbindungseinstellungen für $host sind erst verfügbar, wenn das Gerät einmal entsperrt wurde.';
  }

  @override
  String get connectionProfileLockedSuggestion =>
      'Entsperre das Gerät und versuche es dann noch einmal.';

  @override
  String get connectionProfileIncompleteTitle =>
      'Verbindungseinstellungen unvollständig';

  @override
  String connectionProfileIncompleteExplanation(String host) {
    return 'Einige Verbindungseinstellungen für $host fehlen und müssen neu eingegeben werden.';
  }

  @override
  String get connectionProfileIncompleteSuggestion =>
      'Öffne die Verbindungseinstellungen dieses Servers und gib sie neu ein.';

  @override
  String get connectionProfileDamagedTitle =>
      'Verbindungseinstellungen nicht lesbar';

  @override
  String get connectionProfileDamagedExplanation =>
      'Die gespeicherten Verbindungseinstellungen konnten nicht gelesen werden. Setze sie zurück, um fortzufahren.';

  @override
  String get connectionProfileDamagedSuggestion =>
      'Gib die Einstellungen danach für die Server neu ein, die sie brauchen.';

  @override
  String get connectionTlsSuggestion =>
      'Wenn dein Server eine eigene Zertifizierungsstelle nutzt, installiere deren Zertifikat in den Einstellungen deines Geräts oder vertraue dem Zertifikat in den Verbindungseinstellungen dieses Servers.';

  @override
  String get connectionTlsSuggestionIos =>
      'Wenn dein Server eine eigene Zertifizierungsstelle nutzt, installiere deren Zertifikatsprofil und aktiviere unter Einstellungen › Allgemein › Info › Zertifikatsvertrauenseinstellungen das volle Vertrauen dafür, oder vertraue dem Zertifikat in den Verbindungseinstellungen dieses Servers.';

  @override
  String get connectionLoginProxySuggestion =>
      'Wenn der Proxy Zugangstokens annimmt, etwa ein Cloudflare-Access-Diensttoken, füge sie als Zugangs-Header in den Verbindungseinstellungen dieses Servers hinzu; sonst frage die Person, die den Server betreut, ob sie der App direkten Zugriff auf die Vikunja-API erlauben kann.';

  @override
  String connectionPinMismatchExplanation(String host) {
    return '$host hat ein anderes Zertifikat vorgelegt als das, dem die App vertraut.';
  }

  @override
  String get connectionPinMismatchSuggestion =>
      'Prüfe das neue Zertifikat in den Verbindungseinstellungen dieses Servers, bevor du es akzeptierst.';

  @override
  String get connectionOpenSettings => 'Verbindungseinstellungen öffnen';

  @override
  String get connectionReset => 'Verbindungseinstellungen zurücksetzen';

  @override
  String get connectionResetTitle => 'Verbindungseinstellungen zurücksetzen?';

  @override
  String get connectionResetBody =>
      'Damit werden die Verbindungseinstellungen und die Erlaubnis für unverschlüsselte Verbindungen aller Server entfernt. Die betroffenen Konten funktionieren erst wieder, wenn die Einstellungen neu eingegeben sind.';

  @override
  String get connectionResetConfirm => 'Zurücksetzen';

  @override
  String get connectionViewCertificate => 'Zertifikat ansehen';

  @override
  String get connectionAddHeaders => 'Zugangs-Header hinzufügen';

  @override
  String get connectionAddClientCertificate => 'Client-Zertifikat hinzufügen';

  @override
  String get connectionReplaceClientCertificate => 'Client-Zertifikat ersetzen';

  @override
  String get connectionSaveFailed =>
      'Die Verbindungseinstellungen konnten nicht gespeichert werden.';

  @override
  String get connectionOptions => 'Verbindungsoptionen';

  @override
  String connectionOptionsFor(String origin) {
    return 'Einstellungen für $origin';
  }

  @override
  String get connectionOptionsSaved => 'Gespeicherte Einstellungen';

  @override
  String get connectionTitle => 'Verbindung';

  @override
  String get connectionIntro =>
      'Diese Einstellungen nutzt die App für alle Konten unter dieser Adresse. Der Browser, der die Anmeldeseite öffnet, nutzt sie nicht.';

  @override
  String get connectionServerCertificateHeading => 'Serverzertifikat';

  @override
  String get connectionPinnedTitle => 'Vertrautes Zertifikat';

  @override
  String connectionPinnedSince(String date) {
    return 'Vertraut seit $date';
  }

  @override
  String get connectionCaTitle => 'Vertrautes CA-Zertifikat';

  @override
  String connectionFileAdded(String fileName, String date) {
    return '$fileName, hinzugefügt am $date';
  }

  @override
  String get connectionCaIosHint =>
      'Auf iPhone und iPad müssen Serverzertifikate dieser Stelle den Server nennen und höchstens 825 Tage gültig sein; sonst vertraue dem Zertifikat des Servers selbst.';

  @override
  String get connectionDeviceTrust =>
      'Es gelten die Zertifikate, denen das Gerät vertraut.';

  @override
  String get connectionCheckCertificate => 'Zertifikat des Servers prüfen';

  @override
  String get connectionClientCertificateHeading => 'Client-Zertifikat';

  @override
  String get connectionClientCertificateNone =>
      'Keins. Nur nötig, wenn der Server eins verlangt.';

  @override
  String get connectionRemove => 'Entfernen';

  @override
  String get connectionHeadersHeading => 'Zugangs-Header';

  @override
  String get connectionHeadersNone =>
      'Keine. Nur nötig hinter einem Zugangs-Proxy wie Cloudflare Access.';

  @override
  String get connectionEditHeaders => 'Zugangs-Header bearbeiten';

  @override
  String get connectionHeaderValueHidden => 'Wert verborgen';

  @override
  String get connectionCleartextHeading => 'Unverschlüsselte Verbindungen';

  @override
  String connectionCleartextAllowedSince(String date) {
    return 'Erlaubt seit $date';
  }

  @override
  String get connectionCleartextNotAllowed =>
      'Nicht erlaubt. Anfragen an diese Adresse schlagen fehl, bis du sie erlaubst.';

  @override
  String get connectionCleartextRevoke => 'Widerrufen';

  @override
  String get connectionCleartextRevokeTitle => 'Erlaubnis widerrufen?';

  @override
  String connectionCleartextRevokeBody(String host) {
    return 'Anfragen an $host schlagen dann fehl. Die Konten auf diesem Server funktionieren erst wieder, wenn unverschlüsselte Verbindungen wieder erlaubt sind.';
  }

  @override
  String get connectionCleartextAllow => 'Unverschlüsselte Verbindung erlauben';

  @override
  String get connectionHeadersUnencrypted =>
      'Wie alles andere an diese Adresse gehen auch die Header unverschlüsselt.';

  @override
  String get connectionHeadersNeedCleartext =>
      'Zugangs-Header kannst du hinzufügen, sobald unverschlüsselte Verbindungen erlaubt sind.';

  @override
  String get connectionForget => 'Verbindungseinstellungen vergessen';

  @override
  String get connectionForgetTitle => 'Verbindungseinstellungen vergessen?';

  @override
  String connectionForgetBody(String host) {
    return 'Die Konten auf $host funktionieren erst wieder, wenn die Einstellungen neu eingegeben sind. Auch die Erlaubnis für unverschlüsselte Verbindungen wird entfernt.';
  }

  @override
  String get connectionForgetConfirm => 'Vergessen';

  @override
  String get connectionStatusPinMismatch => 'Zertifikat geändert';

  @override
  String get connectionStatusNeedsReentry => 'Neu eingeben';

  @override
  String get connectionStatusUnavailable => 'Noch nicht verfügbar';

  @override
  String get connectionStatusDamaged => 'Einstellungen nicht lesbar';

  @override
  String get connectionNeedsReentryTitle =>
      'Einige Einstellungen müssen neu eingegeben werden';

  @override
  String get connectionNeedsReentryBody =>
      'Die gespeicherten Zugangs-Header oder das Client-Zertifikat fehlen oder sind nicht nutzbar. Anfragen an diese Adresse schlagen fehl, bis du sie neu eingibst oder entfernst.';

  @override
  String get connectionMismatchTitle =>
      'Das Zertifikat des Servers hat sich geändert';

  @override
  String connectionMismatchBody(String date) {
    return 'Am $date hat der Server ein anderes Zertifikat als das vertraute vorgelegt. Anfragen werden abgelehnt, bis du es prüfst.';
  }

  @override
  String get connectionMismatchReview => 'Prüfen';

  @override
  String get connectionSummaryPinned => 'Vertrautes Zertifikat';

  @override
  String get connectionSummaryCa => 'Vertrautes CA-Zertifikat';

  @override
  String get connectionSummaryClientCertificate => 'Client-Zertifikat';

  @override
  String get connectionSummaryHeaders => 'Zugangs-Header';

  @override
  String get connectionSummaryCleartext =>
      'Unverschlüsselte Verbindungen erlaubt';

  @override
  String connectionCertificateChecking(String origin) {
    return 'Zertifikat von $origin wird abgerufen …';
  }

  @override
  String get connectionFingerprintLabel => 'SHA-256-Fingerabdruck';

  @override
  String get connectionCopyFingerprint => 'Fingerabdruck kopieren';

  @override
  String get connectionIssuedTo => 'Ausgestellt für';

  @override
  String get connectionIssuedBy => 'Ausgestellt von';

  @override
  String get connectionSelfSigned => 'Selbstsigniert';

  @override
  String connectionValidity(String from, String until) {
    return 'Gültig vom $from bis $until';
  }

  @override
  String get connectionCertificateExpired =>
      'Dieses Zertifikat ist abgelaufen.';

  @override
  String get connectionCertificateNotYetValid =>
      'Dieses Zertifikat ist noch nicht gültig.';

  @override
  String get connectionCompareHint =>
      'Vergleiche den Fingerabdruck mit dem auf deinem Server, zum Beispiel so:';

  @override
  String get connectionBrowserWarnsToo =>
      'Auch dein Browser wird beim Anmelden vor diesem Zertifikat warnen; prüfe, ob er denselben Fingerabdruck zeigt.';

  @override
  String connectionTrustOnlyFor(String origin) {
    return 'Die App vertraut ihm nur für $origin.';
  }

  @override
  String get connectionTrustCertificate => 'Diesem Zertifikat vertrauen';

  @override
  String get connectionUseCa => 'Stattdessen ein CA-Zertifikat verwenden';

  @override
  String get connectionPinReplacesCa =>
      'Wenn du diesem Zertifikat vertraust, ersetzt es das vertraute CA-Zertifikat.';

  @override
  String get connectionCaReplacesPin =>
      'Ein CA-Zertifikat ersetzt das vertraute Zertifikat.';

  @override
  String get connectionReviewTitle => 'Neues Zertifikat prüfen';

  @override
  String connectionReviewRecorded(String date) {
    return 'Am $date gesehenes Zertifikat';
  }

  @override
  String get connectionReviewProbed =>
      'Zertifikat, das der Server jetzt vorlegt';

  @override
  String get connectionReviewSame =>
      'Der Server legt noch das damals gesehene Zertifikat vor.';

  @override
  String get connectionReviewDiffers =>
      'Der Server legt jetzt ein weiteres, anderes Zertifikat vor als das damals gesehene. Prüfe es genau, bevor du es akzeptierst.';

  @override
  String get connectionReviewMatchesTrusted =>
      'Der Server legt wieder das vertraute Zertifikat vor.';

  @override
  String get connectionReviewAccept => 'Neues Zertifikat akzeptieren';

  @override
  String get connectionReviewKeep => 'Aktuelles Zertifikat behalten';

  @override
  String get connectionCaNotTrusted =>
      'Dieses CA-Zertifikat hat das Zertifikat des Servers nicht ausgestellt.';

  @override
  String connectionCaCheckFailed(String host) {
    return 'Das CA-Zertifikat konnte nicht geprüft werden, weil $host nicht sicher erreichbar war.';
  }

  @override
  String get connectionCaSaveAnyway => 'Trotzdem speichern';

  @override
  String get connectionCaFileInvalid =>
      'Die Datei ist keine PEM-Zertifikatsdatei oder enthält auch einen privaten Schlüssel.';

  @override
  String get connectionFileTooLarge => 'Die Datei ist größer als 64 KB.';

  @override
  String get connectionFileEmpty => 'Die Datei ist leer.';

  @override
  String get connectionFileUnreadable =>
      'Die Datei konnte nicht gelesen werden.';

  @override
  String get connectionPickerFailed =>
      'Die Dateiauswahl ließ sich nicht öffnen.';

  @override
  String get connectionChooseFile => 'Datei auswählen';

  @override
  String get connectionChooseOtherFile => 'Andere Datei auswählen';

  @override
  String get connectionNoFileChosen => 'Wähle zuerst eine Datei aus.';

  @override
  String get connectionFilePassword => 'Passwort der Datei';

  @override
  String get connectionShowPassword => 'Passwort anzeigen';

  @override
  String get connectionHidePassword => 'Passwort verbergen';

  @override
  String get connectionWrongPasswordOrUnsupported =>
      'Falsches Passwort oder nicht unterstützte Datei.';

  @override
  String get connectionClientCertificatePrivateCaHint =>
      'Wenn das Zertifikat des Servers von deiner eigenen Zertifizierungsstelle stammt, vertraue ihm auch unter „Serverzertifikat“: In den Geräteeinstellungen installierte Zertifikate gelten nicht für Verbindungen mit Client-Zertifikat.';

  @override
  String get connectionSave => 'Speichern';

  @override
  String connectionHeadersIntro(String origin) {
    return 'Wird mit jeder Anfrage der App an $origin gesendet und an keine andere Adresse.';
  }

  @override
  String get connectionHeaderPresetCloudflare =>
      'Cloudflare-Access-Diensttoken';

  @override
  String get connectionHeaderPresetCustom => 'Eigener Header';

  @override
  String get connectionHeaderName => 'Header-Name';

  @override
  String get connectionHeaderValue => 'Wert';

  @override
  String get connectionShowValue => 'Wert anzeigen';

  @override
  String get connectionHideValue => 'Wert verbergen';

  @override
  String get connectionRemoveHeader => 'Header entfernen';

  @override
  String get connectionAddHeader => 'Header hinzufügen';

  @override
  String get connectionServiceTokenHint =>
      'Cloudflare-Access-Apps, die nur Diensttokens zulassen, lassen die App zum Server durch, aber die Anmeldung über den Browser ist dann nicht möglich. Geteilte Links als Gast zu öffnen, funktioniert weiterhin.';

  @override
  String get connectionHeaderNameEmpty => 'Gib einen Namen ein.';

  @override
  String get connectionHeaderNameInvalid => 'Kein gültiger Header-Name.';

  @override
  String get connectionHeaderNameReserved =>
      'Diesen Header setzt die App oder das System selbst.';

  @override
  String get connectionHeaderNameDuplicate =>
      'Dieser Header steht schon in der Liste.';

  @override
  String get connectionHeaderValueEmpty => 'Gib einen Wert ein.';

  @override
  String get connectionHeaderValueNonAscii =>
      'Nur sichtbare ASCII-Zeichen sind erlaubt.';

  @override
  String get connectionHeaderValueTooLong => 'Höchstens 4 KB.';

  @override
  String get connectionHeadersTooMany => 'Höchstens 10 Header.';

  @override
  String get connectionBrowserHintTitle => 'Bevor du dich anmeldest';

  @override
  String get connectionBrowserHintPinned =>
      'Dein Browser wird vor dem Zertifikat dieses Servers warnen. Prüfe, ob er denselben SHA-256-Fingerabdruck zeigt, dem du hier vertraust:';

  @override
  String get connectionBrowserHintCa =>
      'Dein Browser warnt eventuell vor dem Zertifikat dieses Servers, außer die Zertifizierungsstelle ist auch in den Geräteeinstellungen installiert.';

  @override
  String get connectionBrowserHintClientCertificate =>
      'Der Browser braucht das Client-Zertifikat ebenfalls in den Geräteeinstellungen, oder die Anmeldeseite muss ohne es erreichbar sein.';

  @override
  String get connectionBrowserHintHeaders =>
      'Der Browser durchläuft die Zugangsanmeldung selbst.';

  @override
  String connectionBrowserHintOtherHost(String host) {
    return 'Die Anmeldung öffnet $host.';
  }

  @override
  String get connectionBrowserHintContinue => 'Weiter';

  @override
  String signInOtherHostTitle(String signInHost) {
    return 'Bei $signInHost anmelden?';
  }

  @override
  String get signInOtherHostConfirm => 'Anmelden';

  @override
  String signInOtherHostBody(String server, String signInHost) {
    return 'Die Anmeldung für $server öffnet $signInHost. $server erhält Zugriff auf das Konto, mit dem du dich bei $signInHost anmeldest. Fahre nur fort, wenn $signInHost zu $server gehört.';
  }

  @override
  String get connectionForgetCheckbox =>
      'Auch die Verbindungseinstellungen dieses Servers vergessen';

  @override
  String connectionProbeUnreachable(String host) {
    return '$host war nicht erreichbar.';
  }

  @override
  String connectionProbeTimeout(String host) {
    return '$host hat nicht rechtzeitig geantwortet.';
  }

  @override
  String connectionProbeNotTls(String host) {
    return '$host hat keine sichere Verbindung aufgebaut, daher gibt es kein Zertifikat zum Anzeigen.';
  }

  @override
  String get connectionNotAvailableBody =>
      'Versuche es noch einmal, sobald das Gerät entsperrt wurde.';

  @override
  String get connectionRemoveTrustTitle =>
      'Diesem Zertifikat nicht mehr vertrauen?';

  @override
  String connectionRemoveTrustBody(String host) {
    return 'Anfragen an $host schlagen dann fehl, außer das Gerät selbst vertraut dem Zertifikat des Servers.';
  }

  @override
  String get connectionRemoveClientCertificateTitle =>
      'Client-Zertifikat entfernen?';

  @override
  String connectionRemoveClientCertificateBody(String host) {
    return 'Anfragen an $host schlagen dann fehl, wenn der Server ein Client-Zertifikat verlangt.';
  }

  @override
  String get connectionRemoveHeadersTitle => 'Zugangs-Header entfernen?';

  @override
  String connectionRemoveHeadersBody(String host) {
    return 'Anfragen an $host schlagen dann fehl, wenn der Zugangs-Proxy sie verlangt.';
  }

  @override
  String get connectionAlreadyTrusted =>
      'Diesem Zertifikat vertraut die App für diese Adresse bereits.';

  @override
  String get connectionCaNotTrustedLeaf =>
      'Der Server hat dieses Zertifikat vorgelegt:';

  @override
  String connectionClientCertificateIntroFor(String origin) {
    return 'Wähle die Zertifikatsdatei (.p12 oder .pfx) und gib ihr Passwort ein. Das Zertifikat wird nur $origin vorgelegt; sein privater Schlüssel und das Passwort bleiben verschlüsselt auf diesem Gerät.';
  }

  @override
  String get connectionHeadersHeldBack =>
      'Diese Header sind gespeichert, werden aber erst gesendet, wenn unverschlüsselte Verbindungen zu dieser Adresse erlaubt sind.';

  @override
  String get connectionTrustDeviceTrusted =>
      'Dieses Gerät vertraut diesem Zertifikat bereits, du musst ihm also nicht zusätzlich vertrauen.';

  @override
  String get connectionTrustShortLived =>
      'Dieses Zertifikat ist weniger als 100 Tage gültig, der Server ersetzt es also oft. Das Vertrauen in genau dieses Zertifikat endet bei jeder Erneuerung; das Vertrauen in das CA-Zertifikat, das es ausgestellt hat, bleibt bestehen.';

  @override
  String get widgetConfigureUnknownTitle =>
      'Dieses Widget kann hier nicht eingerichtet werden';

  @override
  String get widgetConfigureUnknownBody =>
      'Nur Vikunja-Widgets auf dem Startbildschirm dieses Geräts lassen sich einrichten. Öffne stattdessen die Einstellungen des Widgets auf dem Startbildschirm.';

  @override
  String get aboutTitle => 'Über die App';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String aboutVersionWithoutBuild(String version) {
    return 'Version $version';
  }

  @override
  String get aboutLicenceHeading => 'Lizenz';

  @override
  String get aboutLicence =>
      'Diese App ist Open Source unter der MIT-Lizenz: Du darfst sie nutzen, verändern und weitergeben, solange ihr Copyright- und Lizenzhinweis dabei bleibt.';

  @override
  String get aboutNoWarranty =>
      'Für diese App gibt es keine Gewährleistung, soweit das Gesetz dies zulässt.';

  @override
  String get aboutLicences => 'Lizenzen';

  @override
  String get aboutLicencesSubtitle =>
      'Die Lizenz der App unter „vikunja_app“ sowie die Lizenzen der Software, die die App enthält';

  @override
  String get aboutSourceCodeHeading => 'Quellcode';

  @override
  String get aboutSourceCodeLater =>
      'Dieser Build hat keinen Link zu seinem Quellcode. Jede Veröffentlichung der App verlinkt den Quellcode, aus dem sie gebaut wurde.';

  @override
  String get aboutSourceCodeOpen => 'Quellcode ansehen';

  @override
  String get aboutWebsiteHeading => 'Hilfe, Datenschutz und Impressum';

  @override
  String get aboutSupport => 'Hilfe und Fehler melden';

  @override
  String get aboutSupportSubtitle =>
      'Antworten auf häufige Fragen und wie du einen Fehler meldest';

  @override
  String get aboutPrivacyPolicy => 'Datenschutzerklärung';

  @override
  String get aboutPrivacyPolicySubtitle =>
      'Wie die App mit deinen Daten umgeht';

  @override
  String get aboutLegalNotice => 'Impressum';

  @override
  String get aboutLegalNoticeSubtitle => 'Wer die App veröffentlicht';

  @override
  String get aboutNameAndLogoHeading => 'Name und Logo';

  @override
  String get aboutNameAndLogo =>
      'Der Name Vikunja und das Vikunja-Logo gehören dem Vikunja-Projekt und stehen nicht unter der MIT-Lizenz. Die Icons der App sind vom Logo abgeleitet und werden mit Erlaubnis des Projekts verwendet. Ein Fork, der einen eigenen Build verbreitet, verwendet einen eigenen Namen und ein eigenes Logo.';

  @override
  String projectTimelineBlocksSemantics(String titles) {
    return 'blockiert $titles';
  }

  @override
  String projectTimelineBlockedBySemantics(String titles) {
    return 'blockiert durch $titles';
  }

  @override
  String projectTimelinePrecedesSemantics(String titles) {
    return 'geht $titles voraus';
  }

  @override
  String projectTimelineFollowsSemantics(String titles) {
    return 'folgt auf $titles';
  }

  @override
  String projectTimelineSummarySemantics(String today, String range) {
    return 'Heute, $today; Zeitraum: $range';
  }

  @override
  String taskDetailPaneBack(String title) {
    return 'Zurück zu „$title“';
  }

  @override
  String taskDetailPaneMore(String title) {
    return 'Mehr zu „$title“';
  }

  @override
  String get actionFailureServerError =>
      'Der Server hat mit einem Fehler geantwortet. Versuche es in ein paar Minuten noch einmal.';

  @override
  String get actionFailureSessionEnded =>
      'Deine Sitzung ist beendet. Melde dich im Tab „Konto“ neu an.';

  @override
  String get actionFailureRateLimited =>
      'Der Server begrenzt Anfragen gerade. Warte eine Minute und versuche es dann noch einmal.';

  @override
  String get actionFailureGuestAccessEnded =>
      'Dein Gastzugang ist beendet. Öffne den Link im Tab „Konto“ erneut.';

  @override
  String get attachmentFileMissing => 'Die Datei fehlt auf dem Server.';

  @override
  String get attachmentDownloadForbidden =>
      'Du hast keinen Zugriff mehr auf diesen Anhang.';

  @override
  String get taskDuplicateForbidden =>
      'Du darfst diesem Projekt keine Aufgaben hinzufügen.';

  @override
  String get taskDuplicateArchived =>
      'Dieses Projekt ist archiviert, deshalb lassen sich seine Aufgaben nicht duplizieren.';

  @override
  String get taskDuplicateFileMissing =>
      'Die Aufgabe konnte nicht dupliziert werden: Einer ihrer Anhänge fehlt auf dem Server.';

  @override
  String get projectDuplicateFileMissing =>
      'Das Projekt konnte nicht dupliziert werden: Eine Datei darin fehlt auf dem Server.';

  @override
  String get assigneePickerNoAccess => 'Kein Zugriff auf dieses Projekt';

  @override
  String get appLanguageTitle => 'App-Sprache';

  @override
  String get appLanguageName => 'Deutsch';

  @override
  String get taskDetailDueDateRow => 'Fällig am';

  @override
  String get taskDetailAddDueDate => 'Fälligkeitsdatum festlegen';

  @override
  String get taskDetailAddPriority => 'Priorität festlegen';

  @override
  String get taskDetailAddLineReminder => 'Erinnerung';

  @override
  String get taskDetailAddLineLabel => 'Label';

  @override
  String get taskDetailChangeDueDate => 'Fälligkeitsdatum ändern';

  @override
  String get taskDetailChangePriority => 'Priorität ändern';

  @override
  String get taskDetailEditReminders => 'Erinnerungen bearbeiten';

  @override
  String get taskDetailChangeLabels => 'Labels ändern';

  @override
  String get taskDetailDueDateRemoved => 'Fälligkeitsdatum entfernt';

  @override
  String get taskDetailReminderAdded => 'Erinnerung hinzugefügt';

  @override
  String get taskDetailReminderChanged => 'Erinnerung geändert';

  @override
  String get taskDetailReminderRemoved => 'Erinnerung entfernt';

  @override
  String get taskDetailLabelsChanged => 'Labels geändert';

  @override
  String get taskDetailReminderSameMoment =>
      'Für diesen Zeitpunkt gibt es schon eine Erinnerung.';

  @override
  String get taskCopyLink => 'Link kopieren';

  @override
  String get taskShareLink => 'Teilen';

  @override
  String get taskLinkCopied => 'Link kopiert';

  @override
  String get taskMoveToColumn => 'In Spalte verschieben …';

  @override
  String get taskMoveToColumnTitle => 'In Spalte verschieben';

  @override
  String get searchLinkedTask => 'Aufgabe aus dem Link';

  @override
  String get searchOpenLinkedTask => 'Verlinkte Aufgabe öffnen';

  @override
  String get signOutStillFinishingTitle => 'Die Abmeldung läuft noch';

  @override
  String get signOutStillFinishingExplanation =>
      'Ein Teil der App schließt noch die Daten eines Kontos, von dem du dich abgemeldet hast.';

  @override
  String get signOutStillFinishingSuggestion =>
      'Warte einen Moment und versuche es noch einmal. Wenn es so bleibt, schließe die App und öffne sie wieder.';

  @override
  String newTaskLabelsKept(String labels) {
    return 'Diese Labels konnten nicht erstellt werden und bleiben deshalb im Titel: $labels';
  }

  @override
  String quickAddNewLabelOffline(String label) {
    return '$label · braucht eine Verbindung';
  }

  @override
  String quickAddNewLabelOfflineSemantics(String label) {
    return 'Neues Label $label, braucht eine Verbindung, sonst bleibt es im Titel';
  }

  @override
  String quickAddLabelStaysInTitle(String label) {
    return '$label · bleibt im Titel';
  }

  @override
  String quickAddLabelStaysInTitleSemantics(String label) {
    return 'Das Label $label gibt es nicht; es bleibt im Titel';
  }

  @override
  String get supportDetailsTitle => 'Support-Details';

  @override
  String get supportDetailsSubtitle =>
      'Was du beilegen kannst, wenn du einen Fehler meldest; du siehst es, bevor du es teilst';

  @override
  String get supportDetailsIntro =>
      'Diese Details helfen, einen Fehler zu finden: Versionen, Zeiten, Anzahlen und Einstellungen. Sie enthalten nie deine Aufgaben, Titel, Namen, E-Mail-Adressen oder Passwörter. Nichts verlässt dein Gerät, bevor du es teilst.';

  @override
  String get supportDetailsShowServers => 'Serveradressen anzeigen';

  @override
  String get supportDetailsShowServersSubtitle =>
      'Sonst erscheinen sie als <server-1>, <server-2> und so weiter';

  @override
  String get supportDetailsShare => 'Teilen';

  @override
  String get signInFinishingSignOut => 'Abmeldung wird abgeschlossen …';

  @override
  String get guestRemoveStillFinishingTitle =>
      'Der Gastzugang wird noch entfernt';

  @override
  String get guestRemoveStillFinishingExplanation =>
      'Ein Teil der App schließt noch die Daten eines Gastzugangs, den du entfernt hast.';

  @override
  String quickAddHelpLabelsBodyGuest(String prefix) {
    return 'Ein Wort, das mit $prefix beginnt. Labels, die es schon gibt, werden hinzugefügt; als Gast kannst du keine neuen erstellen, deshalb bleiben andere Wörter im Titel. Für Leerzeichen nimm Anführungszeichen.';
  }

  @override
  String get previousAppNoteTitle => 'Das ist die neue Vikunja-App';

  @override
  String get previousAppNoteSignInAgain =>
      'Sie ersetzt die bisherige App auf diesem Gerät. Dein Server ist schon eingetragen – melde dich noch einmal an, um weiterzumachen.';

  @override
  String get previousAppNoteSignIn =>
      'Sie ersetzt die bisherige App auf diesem Gerät. Melde dich an, um weiterzumachen.';

  @override
  String get previousAppNoteSignedIn =>
      'Sie ersetzt die bisherige App auf diesem Gerät, und du bist weiterhin angemeldet.';

  @override
  String get previousAppNoteWidgets =>
      'Tippe auf ein Widget der bisherigen App, um auszuwählen, was es zeigt.';

  @override
  String get previousAppNoteWidgetsAfterSignIn =>
      'Tippe nach der Anmeldung auf ein Widget der bisherigen App, um auszuwählen, was es zeigt.';

  @override
  String get widgetsPlacedPreviousApp => 'Widget der bisherigen App';

  @override
  String get widgetsPlacedPreviousAppNotSetUp => 'Noch nicht eingerichtet';

  @override
  String previousAppSigningIn(String host) {
    return 'Deine Anmeldung bei $host wird übernommen …';
  }
}
