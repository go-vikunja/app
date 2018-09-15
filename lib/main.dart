import 'package:flutter/material.dart';
import 'package:fluttering_vikunja/pages/home_page.dart';
import 'package:fluttering_vikunja/style.dart';

void main() => runApp(new VikunjaApp());

class VikunjaApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Vikunja',
      theme: buildVikunjaTheme(),
      home: new HomePage(),
    );
  }
}
