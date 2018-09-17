import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttering_vikunja/global.dart';
import 'package:fluttering_vikunja/pages/home_page.dart';
import 'package:fluttering_vikunja/pages/login_page.dart';
import 'package:fluttering_vikunja/style.dart';

void main() => runApp(VikunjaGlobal(
    child: new VikunjaApp(home: HomePage()),
    login: new VikunjaApp(home: LoginPage())));

class VikunjaApp extends StatelessWidget {
  final Widget home;

  const VikunjaApp({Key key, this.home}) : super(key: key);
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Vikunja',
      theme: buildVikunjaTheme(),
      home: this.home,
    );
  }
}
