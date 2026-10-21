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
  String get homeSignOut => 'Abmelden';

  @override
  String get homeSignOutOfThisAccount => 'Von diesem Konto abmelden';

  @override
  String get homeSigningOut => 'Wird abgemeldet …';

  @override
  String get signOutDialogTitle => 'Abmelden?';

  @override
  String signOutDialogBody(String account, String host) {
    return 'Rurana meldet $account von $host ab und löscht die auf diesem Gerät gespeicherten Aufgaben dieses Kontos. Du kannst dich jederzeit wieder anmelden.';
  }

  @override
  String signOutDialogAccount(String name, String username) {
    return '$name (@$username)';
  }

  @override
  String signOutDialogSwitchesTo(String name) {
    return 'Danach wechselt Rurana zu $name.';
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
      'Bei diesem Konto bist du schon angemeldet – Rurana ist zu ihm gewechselt';

  @override
  String get addAccountAlreadyActive =>
      'Bei diesem Konto bist du schon angemeldet';

  @override
  String get overviewLoading => 'Deine Aufgaben werden geladen …';

  @override
  String get overviewEmptyTitle => 'Alles erledigt';

  @override
  String get overviewEmptyBody =>
      'Gerade gibt es keine offenen Aufgaben. Genieß die Ruhe oder leg mit „Neue Aufgabe“ eine an.';

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
      'Leg dein erstes Projekt an, um Aufgaben hinzuzufügen.';

  @override
  String get projectsFavouritesHeading => 'Favoriten';

  @override
  String get projectsFavouriteTasks => 'Favorisierte Aufgaben';

  @override
  String get projectsAllHeading => 'Alle Projekte';

  @override
  String get projectsShowArchived => 'Archivierte Projekte anzeigen';

  @override
  String get projectArchived => 'Archiviert';

  @override
  String get projectArchivedNote =>
      'Dieses Projekt ist archiviert. Es ist nicht möglich, neue Aufgaben zu erstellen oder es zu bearbeiten.';

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
    return 'Der Server wendet den gespeicherten Filter „$title“ an. Seine Aufgaben laden, wenn du ihn online öffnest.';
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
  String get appearanceSystemColors => 'Systemfarben verwenden';

  @override
  String get appearanceSystemColorsSubtitle =>
      'Die Farben deines Hintergrundbilds statt des App-Blaus';

  @override
  String get appearanceLightDarkHint =>
      'Hell oder dunkel ist das Farbschema deines Kontos, in den Kontoeinstellungen.';

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
      'In diesem Projekt ist alles erledigt. Schalte „Erledigte zeigen“ ein, um sie zu sehen.';

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
  String get taskDetailDueDate => 'Fällig am';

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
  String get taskAddFavourite => 'Zu den Favoriten hinzufügen';

  @override
  String get taskRemoveFavourite => 'Aus den Favoriten entfernen';

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
  String get taskDeleteDialogCancel => 'Abbrechen';

  @override
  String get taskDeleteDialogConfirm => 'Löschen';

  @override
  String get taskDeleted => 'Aufgabe gelöscht';

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
  String get syncProblemTaskMissing =>
      'Die Aufgabe gibt es auf dem Server nicht mehr.';

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
      'Die Aufgabe konnte nicht angelegt werden.';

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
  String get taskEditDateNotSet => 'Nicht gesetzt';

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
    return 'Diese Labels konnten nicht angelegt werden und fehlen deshalb: $labels';
  }

  @override
  String newTaskNamesKept(String names) {
    return 'Für $names wurde niemand gefunden; der Text bleibt im Titel.';
  }

  @override
  String get newTaskNoProjectError =>
      'Es gibt noch kein Projekt für neue Aufgaben. Leg zuerst im Web eins an.';

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
    return 'Mehrere Projekte heißen „$project“. Entferne es und wähl das Projekt unten.';
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
    return 'Neues Label $label, wird beim Hinzufügen angelegt';
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
  String quickAddInsertLabel(String prefix) {
    return 'Label hinzufügen ($prefix)';
  }

  @override
  String quickAddInsertProject(String prefix) {
    return 'Projekt wählen ($prefix)';
  }

  @override
  String quickAddInsertAssignee(String prefix) {
    return 'Jemanden zuweisen ($prefix)';
  }

  @override
  String quickAddSetPriority(String prefix) {
    return 'Priorität setzen ($prefix)';
  }

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
    return 'Ein Wort, das mit $prefix beginnt. Labels, die es noch nicht gibt, werden beim Hinzufügen angelegt. Für Leerzeichen nimm Anführungszeichen.';
  }

  @override
  String get quickAddHelpProjectTitle => 'Projekt';

  @override
  String quickAddHelpProjectBody(String prefix) {
    return '$prefix und Titel oder Kennung eines Projekts. Ohne landet die Aufgabe im Projekt, das unter dem Feld steht.';
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
      'Füg mehrere Zeilen ein, um pro Zeile eine Aufgabe anzulegen.';

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
  String get reminderDueDateNotSet => 'Kein Fälligkeitsdatum gesetzt';

  @override
  String get reminderStartDateNotSet => 'Kein Startdatum gesetzt';

  @override
  String get reminderEndDateNotSet => 'Kein Enddatum gesetzt';

  @override
  String get taskEditRemindersCoincide =>
      'Einige Erinnerungen fallen auf denselben Zeitpunkt. Der Server behält nur eine davon.';

  @override
  String get labelPickerTitle => 'Labels wählen';

  @override
  String get labelPickerSearch => 'Label suchen oder anlegen';

  @override
  String get labelPickerEmpty =>
      'Noch keine Labels. Gib einen Namen ein, um eins anzulegen.';

  @override
  String labelPickerCreate(String title) {
    return 'Label „$title“ anlegen';
  }

  @override
  String get labelPickerCreating => 'Label wird angelegt …';

  @override
  String get labelPickerCreateOffline =>
      'Zum Anlegen eines Labels brauchst du eine Verbindung zum Server.';

  @override
  String get labelPickerCreateUnconfirmed =>
      'Ob das Label angelegt wurde, ließ sich nicht bestätigen. Prüf deine Verbindung und versuch es noch mal.';

  @override
  String labelPickerCreateRejected(String message) {
    return 'Der Server hat das Label nicht angelegt: $message';
  }

  @override
  String get labelPickerCreateFailed =>
      'Das Label konnte nicht angelegt werden.';

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
  String get reminderPickerAlreadySet => 'Schon gesetzt';

  @override
  String get reminderPickerNoDateHint =>
      'Setze ein Fälligkeits-, Start- oder Enddatum, um hier eine schnelle Auswahl zu bekommen.';

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
    return '$date (nicht gesetzt)';
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
      'Rurana kann dich auf diesem Handy benachrichtigen, ohne dass der Server etwas senden muss:';

  @override
  String get notificationSetupReminders => 'Erinnerungen zu ihrer Zeit';

  @override
  String get notificationSetupDueDates => 'Fälligkeiten zur genauen Uhrzeit';

  @override
  String get notificationSetupOnlyYours =>
      'Nur für Aufgaben, die du erstellt hast oder die dir zugewiesen sind';

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
  String get notificationsReminders => 'Erinnerungen';

  @override
  String get notificationsRemindersSubtitle => 'Zum Zeitpunkt jeder Erinnerung';

  @override
  String get notificationsDueDates => 'Fälligkeiten';

  @override
  String get notificationsDueDatesSubtitle => 'Zur genauen Fälligkeitszeit';

  @override
  String get notificationsActivity => 'Aktivität';

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
      'Benachrichtigungen von Rurana funktionieren auf diesem Handy.';

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
    return 'Deine Sitzung als $username ist abgelaufen. Rurana kann dieses Konto erst wieder synchronisieren, wenn du dich neu anmeldest.';
  }

  @override
  String get notificationActionDone => 'Erledigt';

  @override
  String get notificationActionSnooze10Minutes => '10 Min. später';

  @override
  String get notificationActionSnooze1Hour => '1 Std. später';

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
  String notificationBodyWithIdentifier(String body, String identifier) {
    return '$body · $identifier';
  }

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
  String get addRelationSearch => 'Nach Titel oder Kennung suchen';

  @override
  String get addRelationShowDone => 'Erledigte Aufgaben zeigen';

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
      'Duplizieren braucht eine Verbindung zum Server.';

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
      'Folgen braucht eine Verbindung zum Server.';

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
  String get followChecking => 'Prüfe, ob du folgst …';

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
  String get upcomingEmptyTitle => 'Nichts zu tun – einen schönen Tag noch!';

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
  String get rangeRestOfThisYear => 'Der Rest des Jahres';

  @override
  String get sectionTomorrow => 'Morgen';

  @override
  String overviewFilterSubtitle(String title) {
    return 'Filter: $title';
  }

  @override
  String get overviewFilterNotLoadedTitle =>
      'Dieser Filter lädt, sobald du online bist';

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
      'Diese Ansicht lädt, sobald du online bist';

  @override
  String projectViewNotLoadedBody(String filter) {
    return 'Der Server wendet den Filter „$filter“ dieser Ansicht an. Ihre Aufgaben laden, wenn du sie online öffnest.';
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
    return 'Der Server wendet den Filter „$filter“ dieser Ansicht an. Ihre Aufgaben sind unterwegs.';
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
      'Ihre Spalten und Karten laden, wenn du sie online öffnest.';

  @override
  String get boardDownloadingBody => 'Ihre Spalten und Karten sind unterwegs.';

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
      'Alle Aufgaben, die in diese Spalte verschoben werden, werden automatisch als erledigt markiert.';

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
      'Du hast das Limit dieser Spalte erreicht. Entferne Aufgaben oder erhöhe das Limit, um neue Aufgaben hinzuzufügen.';

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
      'Alle Aufgaben, die in die Erledigt-Spalte verschoben werden, werden automatisch als erledigt markiert. Aufgaben, die anderswo als erledigt markiert werden, kommen ebenfalls in diese Spalte.';

  @override
  String get boardDefaultColumn => 'Standard-Spalte';

  @override
  String get boardDefaultColumnHint =>
      'Wenn Aufgaben ohne Angabe einer Spalte erstellt werden, werden sie zu dieser Spalte hinzugefügt.';

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
      'Du kannst die letzte Spalte nicht entfernen.';

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
    return '$_temp0 Lass das Feld leer für kein Limit.';
  }

  @override
  String get boardColumnLimitBelowCount =>
      'Das ist weniger, als sie gerade enthält. Bis Aufgaben herausgenommen werden, nimmt sie keine neuen auf.';

  @override
  String get boardDeleteColumnTitle => 'Spalte löschen';

  @override
  String boardDeleteColumnBody(String column) {
    return 'Bist du sicher, dass du die Spalte „$column“ löschen möchtest?';
  }

  @override
  String boardDeleteColumnTasksMove(String column) {
    return 'Ihre Aufgaben werden nicht gelöscht, sondern kommen nach „$column“.';
  }

  @override
  String boardDeleteColumnBecomesDefault(String column) {
    return '„$column“ wird zur Standard-Spalte.';
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
  String get boardDefaultColumnSaved => 'Standard-Spalte gespeichert';

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
      'Nur Projekt-Admins können die Erledigt- oder Standard-Spalte festlegen.';

  @override
  String get boardColumnDeleteAdminOnly =>
      'Nur Projekt-Admins können die Spalte für neue Aufgaben löschen, solange Aufgaben darin sind.';

  @override
  String boardColumnDeleteFailedNewDefault(String newDefault, String column) {
    return '„$newDefault“ ist jetzt die Standard-Spalte, aber „$column“ ließ sich nicht löschen.';
  }

  @override
  String get boardColumnForbidden =>
      'Du darfst die Spalten dieses Boards nicht ändern.';

  @override
  String get boardColumnLastOne => 'Ein Board braucht mindestens eine Spalte.';

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
  String get richTextShowImage => 'Im Vollbild zeigen';

  @override
  String get richTextOpensInBrowser => 'Öffnet im Browser';

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
      'Nicht hochgeladen: siehe Synchronisierungsprobleme im Tab Konto';

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
  String get attachmentMakeCover => 'Als Titelbild setzen';

  @override
  String get attachmentRemoveCover => 'Titelbild entfernen';

  @override
  String get attachmentDelete => 'Anhang löschen';

  @override
  String get attachmentDeleteTitle => 'Anhang löschen';

  @override
  String attachmentDeleteBody(String name) {
    return 'Soll der Anhang $name gelöscht werden? Dies kann nicht rückgängig gemacht werden!';
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
      'Melde dich zuerst bei Rurana an und teile dann erneut.';

  @override
  String get sharePickAccountTitle => 'In welches Konto teilen?';

  @override
  String get sharePickAccountBody =>
      'Was du teilst, landet auf dem Server dieses Kontos.';

  @override
  String get shareSheetTitle => 'Mit Rurana teilen';

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
  String get taskOpening => 'Aufgabe wird geöffnet…';

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
  String get projectTitleHint => 'Der Titel des Projekts kommt hier hin …';

  @override
  String get projectTitleRequired => 'Bitte gib einen Titel an.';

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
      'Bis zu 10 Zeichen, eindeutig auf dem Server. Die Bezeichner der Aufgaben dieses Projekts beginnen damit und ändern sich mit ihm. Lass das Feld leer für keinen.';

  @override
  String get projectIdentifierTaken =>
      'Dieser Bezeichner wird schon verwendet. Bezeichner sind auf dem ganzen Server eindeutig.';

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
      'Du kannst dieses Projekt nicht bearbeiten oder Aufgaben erstellen, bis du die Archivierung aufhebst. Seine Unterprojekte werden ebenfalls archiviert.';

  @override
  String get projectUnarchiveBody =>
      'Du kannst Aufgaben erstellen oder es bearbeiten. Auch bei seinen Unterprojekten wird die Archivierung aufgehoben.';

  @override
  String get projectArchivedDone => 'Projekt archiviert';

  @override
  String get projectUnarchivedDone => 'Archivierung aufgehoben';

  @override
  String get projectArchiveDefaultHint =>
      'Du kannst dieses Projekt nicht archivieren, da es dein Standardprojekt ist.';

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
      'Das kann nicht rückgängig gemacht werden.';

  @override
  String projectIncludesDefault(String project) {
    return 'Darunter ist dein Standardprojekt „$project“.';
  }

  @override
  String get projectDeleted => 'Projekt gelöscht';

  @override
  String get projectChangeNeedsConnection =>
      'Zum Verwalten von Projekten brauchst du eine Verbindung zum Server.';

  @override
  String get projectChangeUnconfirmed =>
      'Die Änderung ließ sich nicht bestätigen. Prüf deine Verbindung und zieh nach unten, um neu zu laden.';

  @override
  String get projectFormUnconfirmed =>
      'Die Änderung ließ sich nicht bestätigen. Vielleicht ist sie trotzdem angekommen, also prüf das, bevor du es noch mal versuchst.';

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
      'Das übergeordnete Projekt ist archiviert. Heb zuerst dessen Archivierung auf.';

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
      'Ein Titel darf höchstens 250 Zeichen lang sein, und ein Emoji kann mehrere zählen. Kürz diesen, um zu speichern.';

  @override
  String get projectTitleTooLongToChange =>
      'Der Titel dieses Projekts ist länger, als der Server annimmt. Kürz ihn zuerst unter Bearbeiten.';

  @override
  String projectChangeRefused(String message) {
    return 'Der Server hat die Änderung abgelehnt: $message';
  }

  @override
  String get projectChangeFailed =>
      'Die Änderung konnte nicht gespeichert werden.';

  @override
  String projectViewsIntro(String project) {
    return 'Die Ansichten von $project in der Reihenfolge, in der App und Web sie zeigen. Tabellen- und Gantt-Ansichten erscheinen vorerst nur im Web.';
  }

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
      'Niemand kann sie dann noch verwenden, um die Aufgaben dieses Projekts anzusehen. Es werden keine Aufgaben gelöscht. Das kann nicht rückgängig gemacht werden.';

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
  String projectViewKindWebOnly(String kind) {
    return '$kind – vorerst nur im Web';
  }

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
  String get savedFilterIncludeNulls => 'Aufgaben ohne Werte einbeziehen';

  @override
  String get savedFilterIncludeNullsHint =>
      'Listet auch Aufgaben, die dort keinen Wert haben, wo der Filter einen vergleicht, etwa Aufgaben ohne Fälligkeitsdatum.';

  @override
  String get savedFilterFavourite => 'Favorit';

  @override
  String get savedFilterFavouriteHint =>
      'Zeigt ihn bei den Favoriten im Tab Projekte.';

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
      'Es werden keine Aufgaben gelöscht, nur der Filter und seine Ansichten. Das kann nicht rückgängig gemacht werden.';

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
      'Zum Verwalten gespeicherter Filter braucht es eine Verbindung zum Server.';

  @override
  String get savedFilterChangeForbidden =>
      'Nur wer diesen gespeicherten Filter angelegt hat, kann ihn ändern.';

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
      'Aufgaben nach Titel, Beschreibung, #12 oder PROJ-12; Projekte, gespeicherte Filter und Labels nach Namen. Funktioniert offline.';

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
      other: '$count weitere Aufgaben passen. Tipp mehr, um einzugrenzen.',
      one: '1 weitere Aufgabe passt. Tipp mehr, um einzugrenzen.',
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
      'Name, Avatar, Farbschema und Vorlieben, auf dem Server für alle deine Geräte gespeichert';

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
    return 'Wird statt deines Benutzernamens angezeigt. Leer lassen, um @$username anzuzeigen.';
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
      'Wähle ein Projekt, in dem du Aufgaben anlegen darfst und das nicht archiviert ist.';

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
  String get accountSettingsDateDisplayRelative => 'Relativ, z. B. in 3 Tagen';

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
  String get accountSettingsTimeFormat12 => '12 Stunden';

  @override
  String get accountSettingsTimeFormat24 => '24 Stunden';

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
  String get accountSettingsAppearance => 'Darstellung';

  @override
  String get accountSettingsColorScheme => 'Farbschema';

  @override
  String get accountSettingsColorSchemeLight => 'Hell';

  @override
  String get accountSettingsColorSchemeSystem => 'System';

  @override
  String get accountSettingsColorSchemeDark => 'Dunkel';

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
  String get accountSettingsTotpOnNote =>
      'Öffnet das Web in deinem Browser. Zum Ausschalten brauchst du dein Passwort.';

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
      'Verschickt dein Server keine E-Mails, bitte seine Administration, dein Konto zu löschen.';

  @override
  String get accountDeletionContinue => 'Im Browser fortfahren';

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
    return 'Läuft ab am $date';
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
    return 'Berechtigungen von $group zeigen';
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
  String get upcomingShowDayHint => 'Nur diesen Tag zeigen';

  @override
  String get upcomingShowRangeHint => 'Ganzen Zeitraum zeigen';

  @override
  String get upcomingNothingPlanned => 'Nichts geplant';

  @override
  String get taskDetailMarkDone => 'Als erledigt markieren';

  @override
  String get taskDetailMarkNotDone => 'Als nicht erledigt markieren';

  @override
  String get taskDetailStatusOpen => 'Offen';

  @override
  String get projectShowDoneChip => 'Erledigte zeigen';

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
  String get accountServerHeading => 'Server';

  @override
  String accountAppVersion(String version, String build) {
    return 'Rurana $version ($build)';
  }

  @override
  String accountAppVersionWithoutBuild(String version) {
    return 'Rurana $version';
  }
}
