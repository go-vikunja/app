import 'package:meta/meta.dart';

/// The fields of one label edit; a null field stays as it is on the server.
@immutable
final class LabelChanges {
  const new({this.title, this.description, this.hexColor});

  /// 1 to 250 code points, not blank.
  final String? title;

  /// HTML as the web's editor writes it.
  final String? description;

  /// Six hex digits without `#`; empty removes the colour.
  final String? hexColor;

  bool get isEmpty => title == null && description == null && hexColor == null;

  @override
  bool operator ==(Object other) =>
      other is LabelChanges &&
      other.title == title &&
      other.description == description &&
      other.hexColor == hexColor;

  @override
  int get hashCode => Object.hash(title, description, hexColor);

  /// Names the fields set, without user text.
  @override
  String toString() {
    final fields = [
      if (title != null) 'title',
      if (description != null) 'description',
      if (hexColor != null) 'hexColor',
    ];
    return 'LabelChanges(${fields.join(', ')})';
  }
}
