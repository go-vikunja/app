import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/pages/home.dart';
import 'package:vikunja_app/pages/user/login.dart';
import 'package:vikunja_app/theme/theme.dart';
//import 'package:alice/alice.dart';

void main() => runApp(VikunjaGlobal(
    child: new VikunjaApp(home: HomePage()),
    login: new VikunjaApp(home: LoginPage())));

class VikunjaApp extends StatefulWidget {
  final Widget home;

  VikunjaApp({Key key, this.home}) : super(key: key);

  @override
  _VikunjaAppState createState() => _VikunjaAppState();
}

class _VikunjaAppState extends State<VikunjaApp> {
  //Alice alice = Alice(showNotification: true);

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      //navigatorKey: alice.getNavigatorKey(),
      title: 'Vikunja',
      theme: buildVikunjaTheme(),
      darkTheme: buildVikunjaDarkTheme(),
      home: this.widget.home,
    );
  }
}
