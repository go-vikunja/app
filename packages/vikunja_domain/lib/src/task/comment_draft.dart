import 'package:meta/meta.dart';

/// The body of a comment to write, in the web editor's HTML.
@immutable
final class CommentDraft {
  const new(this.html);

  final String html;

  @override
  bool operator ==(Object other) => other is CommentDraft && other.html == html;

  @override
  int get hashCode => html.hashCode;

  @override
  String toString() => 'CommentDraft(${html.length} characters)';
}
