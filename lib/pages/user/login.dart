import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/pages/user/register.dart';
import 'package:vikunja_app/theme/button.dart';
import 'package:vikunja_app/theme/buttonText.dart';
import 'package:vikunja_app/theme/constants.dart';
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Builder(
            builder: (BuildContext context) => Form(
              autovalidateMode: AutovalidateMode.always,
              key: _formKey,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Image(
                        image: Theme.of(context).brightness == Brightness.dark
                            ? AssetImage('assets/vikunja_logo_full_white.png')
                            : AssetImage('assets/vikunja_logo_full.png'),
                        height: 85.0,
                        semanticLabel: 'Vikunja Logo',
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        enabled: !_loading,
                        onSaved: (serverAddress) => _server = serverAddress,
                        validator: (address) {
                          return isUrl(address) ? null : 'Invalid URL';
                        },
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Server Address'),
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        enabled: !_loading,
                        onSaved: (username) => _username = username,
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Username'),
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        enabled: !_loading,
                        onSaved: (password) => _password = password,
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Password'),
                        obscureText: true,
                      ),
                    ),
                    Builder(
                        builder: (context) => FancyButton(
                              onPressed: !_loading
                                  ? () {
                                      if (_formKey.currentState.validate()) {
                                        Form.of(context).save();
                                        _loginUser(context);
                                      }
                                    }
                                  : null,
                              child: _loading
                                  ? CircularProgressIndicator()
                                  : VikunjaButtonText('Login'),
                            )),
                    Builder(
                        builder: (context) => FancyButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => RegisterPage())),
                              child: VikunjaButtonText('Register'),
                            )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
                title: Text(
                    'Login failed! Please check your server url and credentials. ' +
                        ex.toString()),
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
