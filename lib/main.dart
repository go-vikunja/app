import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/pages/home.dart';
import 'package:vikunja_app/pages/user/login.dart';
import 'package:vikunja_app/theme/theme.dart';

void main() => runApp(VikunjaGlobal(
    child: new VikunjaApp(home: HomePage()),
    login: new VikunjaApp(home: LoginPage())));

class VikunjaApp extends StatelessWidget {
  final Widget home;

  const VikunjaApp({Key key, this.home}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Vikunja',
      theme: buildVikunjaTheme(),
      darkTheme: buildVikunjaDarkTheme(),
      home: this.home,
    );
  }
}
