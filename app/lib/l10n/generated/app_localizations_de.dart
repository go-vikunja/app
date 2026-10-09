// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Taskuna';

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
    return 'Taskuna braucht Vikunja $minimum oder neuer. Auf diesem Server läuft $found.';
  }

  @override
  String get unsupportedSuggestion =>
      'Frage die Person, die den Server betreut, ob sie Vikunja aktualisieren kann.';

  @override
  String get unsupportedUnknownVersionTitle => 'Serverversion nicht erkannt';

  @override
  String unsupportedUnknownVersionBody(String minimum) {
    return 'Taskuna braucht Vikunja $minimum oder neuer. Dieser Server meldet eine Version, die die App nicht erkennt.';
  }

  @override
  String get unsupportedUnknownVersionSuggestion =>
      'Frage die Person, die den Server betreut, welche Vikunja-Version läuft.';

  @override
  String get signInMethodsHeading => 'Anmeldemöglichkeiten';

  @override
  String get signInBrowserTitle => 'Über den Browser anmelden';

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
  String get signInComingSoon =>
      'Die Anmeldung ist in dieser Version noch nicht verfügbar.';
}
