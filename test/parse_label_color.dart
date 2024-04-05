import 'dart:convert';
import 'dart:ui';

import 'package:test/test.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/user.dart';

void main() {
  test('label color from json', () {
    final String json =
        '{"TaskID": 123,"id": 1,"title": "this","description": "","hex_color": "e8e8e8","created_by":{"id": 1,"username": "user","email": "test@example.com","created": 1537855131,"updated": 1545233325},"created": 1552903790,"updated": 1552903790}';
    final JsonDecoder _decoder = new JsonDecoder();
    Label label = Label.fromJson(_decoder.convert(json));

    expect(label.color, Color(0xFFe8e8e8));
  });

  test('hex color string from object', () {
    Label label = Label(
        id: 1,
        title: '',
        color: Color(0xFFe8e8e8),
        createdBy: User(id: 0, username: ''));
    var json = label.toJSON();

    expect(json.toString(),
        '{id: 1, title: , description: null, hex_color: e8e8e8, created_by: {id: 0, username: ,}, updated: null, created: null}');
  });
}
