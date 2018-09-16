import 'package:flutter/material.dart';
import 'package:fluttering_vikunja/global.dart';
import 'package:fluttering_vikunja/main.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

final RegExp _url = new RegExp(
    r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)');

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _server, _username, _password;
  bool _loading = false;

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Login to Vikunja'),
        ),
        body: Builder(
          builder: (BuildContext context) => SafeArea(
                top: false,
                bottom: false,
                child: Form(
                    autovalidate: true,
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image(
                            image: AssetImage('assets/vikunja_logo.png'),
                            height: 128.0,
                            semanticLabel: 'Vikunja Logo',
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: TextFormField(
                            onSaved: (serverAddress) => _server = serverAddress,
                            validator: (address) {
                              var hasMatch = _url.hasMatch(address);
                              return hasMatch ? null : 'Invalid URL';
                            },
                            decoration: new InputDecoration(
                                labelText: 'Server Address'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            onSaved: (username) => _username = username,
                            decoration:
                                new InputDecoration(labelText: 'Username'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            onSaved: (password) => _password = password,
                            decoration:
                                new InputDecoration(labelText: 'Password'),
                            obscureText: true,
                          ),
                        ),
                        ButtonTheme(
                            height: _loading ? 55.0 : 36.0,
                            child: RaisedButton(
                              onPressed: !_loading
                                  ? () {
                                      if (_formKey.currentState.validate()) {
                                        _loginUser(context);
                                      }
                                    }
                                  : null,
                              child: _loading
                                  ? CircularProgressIndicator()
                                  : Text('Login'),
                            ))
                      ],
                    )),
              ),
        ));
  }

  _loginUser(BuildContext context) async {
    setState(() => _loading = true);
    var vGlobal = VikunjaGlobal.of(context);
    var newUser = await vGlobal.userService.login(_username, _password);
    vGlobal.changeUser(newUser.user, token: newUser.token);
    setState(() {
      _loading = false;
    });
  }
}
