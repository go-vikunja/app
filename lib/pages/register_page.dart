import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/utils/validator.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  String _server, _username, _email, _password;
  bool _loading = false;

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Register to Vikunja'),
        ),
        body: Builder(
          builder: (BuildContext context) => SafeArea(
                top: false,
                bottom: false,
                child: Form(
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
                              return isUrl(address) ? null : 'Invalid URL';
                            },
                            decoration: new InputDecoration(
                                labelText: 'Server Address'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            onSaved: (username) => _username = username.trim(),
                            validator: (username) {
                              return username.trim().isNotEmpty
                                  ? null
                                  : 'Please specify a username';
                            },
                            decoration:
                                new InputDecoration(labelText: 'Username'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            onSaved: (email) => _email = email,
                            validator: (email) {
                              return isEmail(email)
                                  ? null
                                  : 'Email adress is invalid';
                            },
                            decoration:
                                new InputDecoration(labelText: 'Email Address'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            controller: passwordController,
                            onSaved: (password) => _password = password,
                            validator: (password) {
                              return password.length >= 8
                                  ? null
                                  : 'Please use at least 8 characters';
                            },
                            decoration:
                                new InputDecoration(labelText: 'Password'),
                            obscureText: true,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            validator: (password) {
                              return passwordController.text == password
                                  ? null
                                  : 'Passwords don\'t match.';
                            },
                            decoration: new InputDecoration(
                                labelText: 'Repeat Password'),
                            obscureText: true,
                          ),
                        ),
                        Builder(
                            builder: (context) => ButtonTheme(
                                height: _loading ? 55.0 : 36.0,
                                child: RaisedButton(
                                  onPressed: !_loading
                                      ? () {
                                          if (_formKey.currentState
                                              .validate()) {
                                            Form.of(context).save();
                                            _registerUser(context);
                                          } else {
                                            print("awhat");
                                          }
                                        }
                                      : null,
                                  child: _loading
                                      ? CircularProgressIndicator()
                                      : Text('Register'),
                                ))),
                      ],
                    )),
              ),
        ));
  }

  _registerUser(BuildContext context) async {
    setState(() => _loading = true);
    try {
      var vGlobal = VikunjaGlobal.of(context);
      var newUserLoggedIn = await vGlobal
          .newUserService(_server)
          .register(_username, _email, _password);
      vGlobal.changeUser(newUserLoggedIn.user,
          token: newUserLoggedIn.token, base: _server);
    } catch (ex) {
      showDialog(
          context: context,
          builder: (context) => new AlertDialog(
                title: const Text(
                    'Registration failed! Please check your server url and credentials.'),
                actions: <Widget>[
                  FlatButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CLOSE'))
                ],
              ));
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
}
