/// [text] without U+0000, which Vikunja 2.8.0 refuses anywhere in a JSON
/// body: what the server stores of a text the app sends, so a comparison
/// with the server's copy uses it too.
String withoutNul(String text) => text.replaceAll('\u0000', '');
