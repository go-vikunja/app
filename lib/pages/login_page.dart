import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/pages/register_page.dart';
import 'package:vikunja_app/utils/validator.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

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
                              return isUrl(address) ? null : 'Invalid URL';
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
                        Builder(
                            builder: (context) => ButtonTheme(
                                height: _loading ? 55.0 : 36.0,
                                child: RaisedButton(
                                  onPressed: !_loading
                                      ? () {
                                          if (_formKey.currentState
                                              .validate()) {
                                            Form.of(context).save();
                                            _loginUser(context);
                                          }
                                        }
                                      : null,
                                  child: _loading
                                      ? CircularProgressIndicator()
                                      : Text('Login'),
                                ))),
                        Builder(
                            builder: (context) => ButtonTheme(
                                height: _loading ? 55.0 : 36.0,
                                child: RaisedButton(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              RegisterPage())),
                                  child: _loading
                                      ? CircularProgressIndicator()
                                      : Text('Register'),
                                ))),
                      ],
                    )),
              ),
        ));
  }

  _loginUser(BuildContext context) async {
    setState(() => _loading = true);
    try {
      var vGlobal = VikunjaGlobal.of(context);
      var newUser =
          await vGlobal.newUserService(_server).login(_username, _password);
      vGlobal.changeUser(newUser.user, token: newUser.token, base: _server);
    } catch (ex) {
      showDialog(
          context: context,
          builder: (context) => new AlertDialog(
                title: Text('Login failed! Please check your server url and credentials. ' + ex.toString()),
                actions: <Widget>[
                  FlatButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ],
              ));
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
}
