import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

Label parseLabel(Object? json) {
  final map = objectOf(json, 'label');
  return Label(
    id: requireInt(map, 'id', 'label'),
    title: requireString(map, 'title', 'label'),
    description: stringOr(map, 'description', ''),
    hexColor: hexColorOf(map['hex_color']),
    createdBy: parseUser(map['created_by']),
    created: dateOf(map['created']),
    updated: dateOf(map['updated']),
  );
}
