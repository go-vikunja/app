import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A person mentioned in the composer: the text from [start] to [end] (the
/// `@` and the name shown) stands for [user].
@immutable
final class ComposerMention {
  const new({required this.start, required this.end, required this.user});

  final int start;
  final int end;
  final User user;

  ComposerMention shifted(int by) =>
      ComposerMention(start: start + by, end: end + by, user: user);

  @override
  bool operator ==(Object other) =>
      other is ComposerMention &&
      other.start == start &&
      other.end == end &&
      other.user == user;

  @override
  int get hashCode => Object.hash(start, end, user);
}

/// The `@` being typed before the cursor and what follows it.
typedef MentionQueryAt = ({int at, String query});

/// The composer's text with the people mentioned in it: an edit inside a
/// mention turns it back into plain text, an edit before one moves it.
/// Mentions show in the primary colour.
final class CommentTextController extends TextEditingController {
  new({super.text});

  List<ComposerMention> _mentions = const [];

  List<ComposerMention> get mentions => _mentions;

  static const _maxQueryLength = 64;

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != text) {
      _mentions = _following(_mentions, text, newValue.text);
    }
    super.value = newValue;
  }

  /// Replaces the text and its mentions, e.g. from a draft.
  void restore(String text, List<ComposerMention> mentions) {
    _mentions = [
      for (final mention in mentions)
        if (mention.start >= 0 &&
            mention.end <= text.length &&
            mention.start < mention.end)
          mention,
    ]..sort((a, b) => a.start.compareTo(b.start));
    super.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// The `@` right before the cursor, as the web's suggestion finds it: at
  /// the start or after a space, no space in the query, not inside a
  /// mention.
  MentionQueryAt? activeMention() {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final cursor = selection.baseOffset;
    final text = this.text;
    if (cursor > text.length) return null;
    for (var i = cursor - 1; i >= 0 && cursor - i <= _maxQueryLength; i--) {
      final unit = text.codeUnitAt(i);
      if (_isSpace(unit)) return null;
      if (unit != 0x40) continue;
      if (i > 0 && !_isSpace(text.codeUnitAt(i - 1))) return null;
      if (_mentions.any((m) => i >= m.start && i < m.end)) return null;
      return (at: i, query: text.substring(i + 1, cursor));
    }
    return null;
  }

  /// [user] in place of the `@` query at [at], followed by a space.
  void insertMention(User user, {required int at}) {
    final cursor = value.selection.baseOffset;
    if (at < 0 || cursor < at || cursor > text.length) return;
    final shown = '@${user.displayName}';
    final before = text.substring(0, at);
    final after = text.substring(cursor);
    final spacer = after.startsWith(' ') ? '' : ' ';
    final mentions = [
      for (final mention in _mentions)
        if (mention.end <= at)
          mention
        else if (mention.start >= cursor)
          mention.shifted(shown.length + spacer.length - (cursor - at)),
      ComposerMention(start: at, end: at + shown.length, user: user),
    ]..sort((a, b) => a.start.compareTo(b.start));
    final next = '$before$shown$spacer$after';
    // Before the listeners hear of the new text.
    _mentions = mentions;
    super.value = TextEditingValue(
      text: next,
      // After the space, typed or already there.
      selection: TextSelection.collapsed(offset: at + shown.length + 1),
    );
  }

  @override
  void clear() {
    _mentions = const [];
    super.clear();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final mentions = _mentions;
    final text = this.text;
    if (mentions.isEmpty || mentions.last.end > text.length) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final mentionStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    final children = <TextSpan>[];
    var at = 0;
    for (final mention in mentions) {
      if (mention.start > at) {
        children.add(TextSpan(text: text.substring(at, mention.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(mention.start, mention.end),
          style: mentionStyle,
        ),
      );
      at = mention.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }

  static bool _isSpace(int unit) =>
      unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0x0D;

  /// [mentions] after [before] became [after], from the common start and
  /// end of the two.
  static List<ComposerMention> _following(
    List<ComposerMention> mentions,
    String before,
    String after,
  ) {
    if (mentions.isEmpty) return mentions;
    final shorter = before.length < after.length ? before.length : after.length;
    var prefix = 0;
    while (prefix < shorter &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shorter - prefix &&
        before.codeUnitAt(before.length - 1 - suffix) ==
            after.codeUnitAt(after.length - 1 - suffix)) {
      suffix++;
    }
    final changedEnd = before.length - suffix;
    final delta = after.length - before.length;
    return [
      for (final mention in mentions)
        if (mention.end <= prefix)
          mention
        else if (mention.start >= changedEnd)
          mention.shifted(delta),
    ];
  }
}
