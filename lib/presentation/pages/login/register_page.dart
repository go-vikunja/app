import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/constants.dart';
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
      appBar: AppBar(title: Text(AppLocalizations.of(ctx).register)),
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
                      return isUrl(address)
                          ? null
                          : AppLocalizations.of(context).invalidUrl;
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText:
                          AppLocalizations.of(context).serverAddress,
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
                          : AppLocalizations.of(context)
                              .pleaseSpecifyUsername;
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: AppLocalizations.of(context).username,
                    ),
                  ),
                ),
                Padding(
                  padding: vStandardVerticalPadding,
                  child: TextFormField(
                    onSaved: (email) => _email = email,
                    validator: (email) {
                      return isEmail(email)
                          ? null
                          : AppLocalizations.of(context).emailInvalid;
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: AppLocalizations.of(context).emailAddress,
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
                          : AppLocalizations.of(context).passwordMinChars;
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: AppLocalizations.of(context).password,
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
                          : AppLocalizations.of(context).passwordsDontMatch;
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: AppLocalizations.of(context).repeatAfter,
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
                        : Text(AppLocalizations.of(context).register),
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
        ).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).registrationFailed)));
      }
    } catch (ex) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)
              .registrationFailedLong(ex.toString())),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).close),
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
