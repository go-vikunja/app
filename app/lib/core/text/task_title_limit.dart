import 'package:characters/characters.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// [text] cut to a title the server takes, at most [Task.maxTitleLength]
/// code points, and the rest that did not fit, empty when all of it does.
/// The cut is at the last space that fits, else after the last whole
/// character as shown that fits; the space at the cut is dropped. A web
/// address (http or https) the cut would split goes to the rest whole, as
/// the notes link only a whole one. That happens only when no space fits,
/// so nothing is before the address and the title is its host; without a
/// host that fits, the cut is as above.
({String title, String rest}) cutTaskTitle(String text) {
  if (text.runes.length <= Task.maxTitleLength) return (title: text, rest: '');
  var used = 0;
  var end = 0;
  var space = 0;
  var wordStart = 0;
  for (final character in text.characters) {
    if (character.trim().isEmpty) {
      space = end;
      wordStart = end + character.length;
    }
    used += character.runes.length;
    if (used > Task.maxTitleLength) break;
    end += character.length;
  }
  if (space > 0) return _cutAt(text, space);
  if (_webAddress.matchAsPrefix(text, wordStart) case final address?) {
    final host = Uri.tryParse(address[0]!)?.host ?? '';
    if (host.isNotEmpty && host.runes.length <= Task.maxTitleLength) {
      return (title: host, rest: text.substring(wordStart));
    }
  }
  return _cutAt(
    text,
    end > 0
        ? end
        : String.fromCharCodes(text.runes.take(Task.maxTitleLength)).length,
  );
}

final _webAddress = RegExp(r'https?://\S+', caseSensitive: false);

({String title, String rest}) _cutAt(String text, int at) => (
  title: text.substring(0, at).trimRight(),
  rest: text.substring(at).trimLeft(),
);
