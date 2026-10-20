import 'package:meta/meta.dart';

/// One tap on a checkbox in a task's description, kept so that it can be
/// applied again to a description someone changed on the web meanwhile.
/// The item is named by its `data-task-id` when it has one, else by its
/// position among the description's task items (document order, nested
/// items included) together with its text.
@immutable
final class ChecklistToggle {
  const new byId(String this.itemId, {required this.checked})
    : ordinal = null,
      text = null;

  const new byPosition({
    required int this.ordinal,
    required String this.text,
    required this.checked,
  }) : itemId = null;

  /// `data-task-id`.
  final String? itemId;

  /// Zero-based.
  final int? ordinal;

  /// The item's own text with whitespace collapsed, without nested task
  /// lists.
  final String? text;

  /// The state the tap asked for.
  final bool checked;

  @override
  bool operator ==(Object other) =>
      other is ChecklistToggle &&
      other.itemId == itemId &&
      other.ordinal == ordinal &&
      other.text == text &&
      other.checked == checked;

  @override
  int get hashCode => Object.hash(itemId, ordinal, text, checked);

  // The text is user content and stays out of logs.
  @override
  String toString() => itemId != null
      ? 'ChecklistToggle(#$itemId → $checked)'
      : 'ChecklistToggle(@$ordinal → $checked)';
}
