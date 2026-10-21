import 'package:flutter/foundation.dart';

@immutable
final class ServerLanguage {
  const new(this.code, this.name);

  /// What the web stores in the `language` setting.
  final String code;

  /// The language's own name, as the web lists it.
  final String name;
}

/// The languages the web offers for the account (its emails and the web's
/// own text), sorted by their own names as the web shows them. The server
/// accepts any value, so a stored code may be missing here.
final List<ServerLanguage> serverLanguages = List.unmodifiable(
  <ServerLanguage>[
    const ServerLanguage('en', 'English'),
    const ServerLanguage('de-DE', 'Deutsch'),
    const ServerLanguage('de-swiss', 'Schwizertütsch'),
    const ServerLanguage('ru-RU', 'Русский'),
    const ServerLanguage('fr-FR', 'Français'),
    const ServerLanguage('vi-VN', 'Tiếng Việt'),
    const ServerLanguage('it-IT', 'Italiano'),
    const ServerLanguage('cs-CZ', 'Čeština'),
    const ServerLanguage('pl-PL', 'Polski'),
    const ServerLanguage('nl-NL', 'Nederlands'),
    const ServerLanguage('pt-PT', 'Português'),
    const ServerLanguage('zh-CN', '简体中文'),
    const ServerLanguage('zh-TW', '繁體中文'),
    const ServerLanguage('no-NO', 'Norsk Bokmål'),
    const ServerLanguage('es-ES', 'Español'),
    const ServerLanguage('da-DK', 'Dansk'),
    const ServerLanguage('ja-JP', '日本語'),
    const ServerLanguage('hu-HU', 'Magyar'),
    const ServerLanguage('ar-SA', 'العربية'),
    const ServerLanguage('fa-IR', 'فارسی'),
    const ServerLanguage('sl-SI', 'Slovenščina'),
    const ServerLanguage('pt-BR', 'Português Brasileiro'),
    const ServerLanguage('hr-HR', 'Hrvatski'),
    const ServerLanguage('uk-UA', 'Українська'),
    const ServerLanguage('lt-LT', 'Lietuvių'),
    const ServerLanguage('bg-BG', 'Български'),
    const ServerLanguage('ko-KR', '한국어'),
    const ServerLanguage('tr-TR', 'Türkçe'),
    const ServerLanguage('fi-FI', 'Suomi'),
    const ServerLanguage('he-IL', 'עברית'),
    const ServerLanguage('sv-SE', 'Svenska'),
    const ServerLanguage('el-GR', 'Ελληνικά'),
  ]..sort((a, b) => _sortKey(a.name).compareTo(_sortKey(b.name))),
);

/// Accents sort with their base letter, as the web's `localeCompare` does
/// for the Latin names.
String _sortKey(String name) {
  const folded = {'č': 'c', 'ç': 'c', 'ế': 'e', 'ü': 'u', 'š': 's'};
  return [
    for (final letter in name.toLowerCase().split('')) folded[letter] ?? letter,
  ].join();
}

ServerLanguage? serverLanguageOf(String code) =>
    serverLanguages.where((language) => language.code == code).firstOrNull;
