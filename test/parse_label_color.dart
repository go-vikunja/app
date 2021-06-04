import 'dart:convert';
import 'dart:ui';

import 'package:test/test.dart';
import 'package:vikunja_app/models/label.dart';

void main() {
  test('label color from json', () {
    final String json = '{"TaskID": 123,"id": 1,"title": "this","description": "","hex_color": "e8e8e8","created_by":{"id": 1,"username": "user","email": "test@example.com","created": 1537855131,"updated": 1545233325},"created": 1552903790,"updated": 1552903790}';
    final JsonDecoder _decoder = new JsonDecoder();
    Label label = Label.fromJson(_decoder.convert(json));

    expect(label.color, Color(0xFFe8e8e8));
  });

  test('hex color string from object', () {
    Label label = Label(id: 1, color: Color(0xFFe8e8e8));
    var json = label.toJSON();

    expect(json.toString(), '{id: 1, title: null, description: null, hex_color: e8e8e8, created_by: null, updated: null, created: null}');
  });
}