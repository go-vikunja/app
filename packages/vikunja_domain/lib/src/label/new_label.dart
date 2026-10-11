import 'package:meta/meta.dart';

/// What the app sends to create a label; the server assigns the id.
@immutable
final class NewLabel {
  const new({required this.title, this.hexColor = '', this.description = ''});

  /// 1 to 250 characters.
  final String title;

  /// Six hex digits without `#`, or empty.
  final String hexColor;
  final String description;

  @override
  bool operator ==(Object other) =>
      other is NewLabel &&
      other.title == title &&
      other.hexColor == hexColor &&
      other.description == description;

  @override
  int get hashCode => Object.hash(title, hexColor, description);
}
