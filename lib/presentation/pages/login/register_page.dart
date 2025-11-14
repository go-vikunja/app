import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/core/utils/network.dart';
import 'package:vikunja_app/core/utils/validator.dart';
import 'package:vikunja_app/presentation/widgets/button.dart';

class RegisterPage extends ConsumerStatefulWidget {
  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  String? _server, _username, _email, _password;
  bool _loading = false;

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
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
                    onSaved: (serverAddress) =>
                        _server = normalizeServerURL(serverAddress ?? ''),
                    validator: (address) {
                      return isURLValid(address);
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Server Address',
                    ),
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
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Username',
                    ),
                  ),
                ),
                Padding(
                  padding: vStandardVerticalPadding,
                  child: TextFormField(
                    onSaved: (email) => _email = email,
                    validator: (email) {
                      return isEmail(email) ? null : 'Email adress is invalid';
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Email Address',
                    ),
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
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Password',
                    ),
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
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Repeat Password',
                    ),
                    obscureText: true,
                  ),
                ),
                Builder(
                  builder: (context) => FancyButton(
                    onPressed: !_loading
                        ? () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState?.save();
                              _registerUser(context);
                            }
                          }
                        : () => null,
                    child: _loading
                        ? CircularProgressIndicator()
                        : Text('Register'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _registerUser(BuildContext context) async {
    setState(() {
      _loading = true;
    });

    try {
      var newUserLoggedIn = await ref
          .read(userRepositoryProvider)
          .register(_username!, _email, _password);
      if (newUserLoggedIn.isSuccessful) {
        ref
            .read(settingsRepositoryProvider)
            .saveUserToken(newUserLoggedIn.toSuccess().body.token);
        ref.read(settingsRepositoryProvider).saveServer(_server!);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registration failed!')));
      }
    } catch (ex) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Registration failed! Please check your server url and credentials. $ex',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
}
