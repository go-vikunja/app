import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/theme/button.dart';
import 'package:vikunja_app/theme/buttonText.dart';
import 'package:vikunja_app/theme/constants.dart';
import 'package:vikunja_app/utils/validator.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  String? _server, _username, _email, _password;
  bool _loading = false;

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Register'),
        ),
        body: Builder(
          builder: (BuildContext context) => SafeArea(
            top: false,
            bottom: false,
            child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
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
                        onSaved: (username) => _username = username?.trim(),
                        validator: (username) {
                          return username!.trim().isNotEmpty
                              ? null
                              : 'Please specify a username';
                        },
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Username'),
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        onSaved: (email) => _email = email,
                        validator: (email) {
                          return isEmail(email)
                              ? null
                              : 'Email adress is invalid';
                        },
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Email Address'),
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        controller: passwordController,
                        onSaved: (password) => _password = password,
                        validator: (password) {
                          return (password?.length ?? 0) >= 8
                              ? null
                              : 'Please use at least 8 characters';
                        },
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Password'),
                        obscureText: true,
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        validator: (password) {
                          return passwordController.text == password
                              ? null
                              : 'Passwords don\'t match.';
                        },
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Repeat Password'),
                        obscureText: true,
                      ),
                    ),
                    Builder(
                        builder: (context) => FancyButton(
                              onPressed: !_loading
                                  ? () {
                                      if (_formKey.currentState!.validate()) {
                                        Form.of(context).save();
                                        _registerUser(context);
                                      } else {
                                        print("awhat");
                                      }
                                    }
                                  : () => null,
                              child: _loading
                                  ? CircularProgressIndicator()
                                  : VikunjaButtonText('Register'),
                            )),
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
          .newUserService
          ?.register(_username!, _email, _password);
      if(newUserLoggedIn != null)
        vGlobal.changeUser(newUserLoggedIn.user!,
            token: newUserLoggedIn.token, base: _server!);
    } catch (ex) {
      showDialog(
          context: context,
          builder: (context) => new AlertDialog(
                title: Text(
                    'Registration failed! Please check your server url and credentials. ' +
                        ex.toString()),
                actions: <Widget>[
                  TextButton(
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
