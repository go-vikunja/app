import 'dart:core';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/core/utils/validator.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:vikunja_app/presentation/pages/login/login_webview.dart';
import 'package:vikunja_app/presentation/pages/login/register_page.dart';
import 'package:vikunja_app/presentation/widgets/button.dart';
import 'package:vikunja_app/presentation/widgets/sentry_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _rememberMe = false;
  bool init = false;
  List<String> pastServers = [];

  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      var pastSevers = await ref
          .read(settingsRepositoryProvider)
          .getPastServers();
      setState(() => pastServers = pastSevers);

      var sentryDialogShown = await ref
          .read(settingsRepositoryProvider)
          .getSentryDialogShown();

      if (!sentryDialogShown) {
        ref.read(settingsRepositoryProvider).setSentryDialogShown(true);
        return _showSentryDialog();
      }
    });
  }

  Future<void> _showSentryDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SentryDialog(
          onAccepts: () {
            ref
                .read(settingsControllerProvider.notifier)
                .setSentryEnabled(true);
          },
          onRefuse: () {
            ref
                .read(settingsControllerProvider.notifier)
                .setSentryEnabled(false);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext ctx) {
    Client client = ref.read(clientProviderProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          autovalidateMode: AutovalidateMode.always,
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _buildLogo(),
              _buildServerInput(),
              _buildUserInput(),
              _buildPasswordInput(),
              Padding(
                padding: vStandardVerticalPadding,
                child: CheckboxListTile(
                  value: _rememberMe,
                  onChanged: (value) =>
                      setState(() => _rememberMe = value ?? false),
                  title: Text("Remember me"),
                ),
              ),
              FancyButton(
                onPressed: !_loading
                    ? () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState?.save();
                          _loginUser(context);
                        }
                      }
                    : null,
                child: _loading ? CircularProgressIndicator() : Text('Login'),
              ),
              FancyButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                ),
                child: Text('Register'),
              ),
              FancyButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() == true &&
                      _serverController.text.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LoginWithWebView(_serverController.text),
                      ),
                    ).then((btp) {
                      if (btp != null) _loginUserByClientToken(btp);
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Please enter your frontend url")),
                    );
                  }
                },
                child: Text("Login with Frontend"),
              ),
              CheckboxListTile(
                title: Text("Ignore Certificates"),
                value: client.ignoreCertificates,
                onChanged: (value) {
                  ref
                      .read(settingsRepositoryProvider)
                      .setIgnoreCertificates(value ?? false);
                  setState(() {
                    client.reloadIgnoreCerts(value ?? false);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Padding _buildPasswordInput() {
    return Padding(
      padding: vStandardVerticalPadding,
      child: TextFormField(
        enabled: !_loading,
        controller: _passwordController,
        autofillHints: [AutofillHints.password],
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Password',
        ),
        obscureText: true,
      ),
    );
  }

  Padding _buildUserInput() {
    return Padding(
      padding: vStandardVerticalPadding,
      child: TextFormField(
        enabled: !_loading,
        controller: _usernameController,
        autofillHints: [AutofillHints.username],
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Username',
        ),
      ),
    );
  }

  Padding _buildServerInput() {
    return Padding(
      padding: vStandardVerticalPadding,
      child: TypeAheadField(
        controller: _serverController,
        builder: (context, controller, focusnode) {
          return TextFormField(
            controller: controller,
            focusNode: focusnode,
            enabled: !_loading,
            validator: (address) {
              return (isUrl(address) || address != null || address!.isEmpty)
                  ? null
                  : 'Invalid URL';
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Server Address',
            ),
          );
        },
        onSelected: (suggestion) {
          _serverController.text = suggestion;
          setState(() => _serverController.text = suggestion);
        },
        itemBuilder: (BuildContext context, Object? itemData) {
          return Card(
            child: Container(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(itemData.toString()),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        pastServers.remove(itemData.toString());
                        ref
                            .read(settingsRepositoryProvider)
                            .setPastServers(pastServers);
                      });
                    },
                    icon: Icon(Icons.clear),
                  ),
                ],
              ),
            ),
          );
        },
        suggestionsCallback: (String pattern) {
          List<String> matches = <String>[];
          matches.addAll(pastServers);
          matches.retainWhere((s) {
            return s.toLowerCase().contains(pattern.toLowerCase());
          });
          return matches;
        },
      ),
    );
  }

  Padding _buildLogo() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Image(
        image: Theme.of(context).brightness == Brightness.dark
            ? AssetImage('assets/vikunja_logo_full_white.png')
            : AssetImage('assets/vikunja_logo_full.png'),
        height: 85.0,
        semanticLabel: 'Vikunja Logo',
      ),
    );
  }

  Future<UserToken> _showOtpDialog(
    BuildContext context,
    UserToken newUser,
    String username,
    String password,
  ) async {
    TextEditingController totpController = TextEditingController();
    bool dismissed = true;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enter One Time Passcode"),
        content: TextField(
          controller: totpController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              dismissed = false;
              Navigator.pop(context);
            },
            child: Text("Login"),
          ),
        ],
      ),
    );
    if (!dismissed) {
      newUser = await ref
          .read(userRepositoryProvider)
          .login(
            username,
            password,
            rememberMe: _rememberMe,
            totp: totpController.text,
          );
    } else {
      throw Exception();
    }
    return newUser;
  }

  Future<void> _loginUserByClientToken(BaseTokenPair baseTokenPair) async {
    ref.read(settingsRepositoryProvider).saveUserToken(baseTokenPair.token);
    ref.read(settingsRepositoryProvider).saveServer(baseTokenPair.base);
    ref
        .read(authDataProvider.notifier)
        .set(AuthModel(baseTokenPair.base, baseTokenPair.token));

    setState(() {
      _loading = true;
    });

    try {
      var currentUser = await ref.read(userRepositoryProvider).getCurrentUser();
      ref.read(currentUserProvider.notifier).set(currentUser);

      globalNavigatorKey.currentState?.pushNamed("/home");
    } catch (e) {
      log("failed to change to user by client token");
      log(e.toString());
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _loginUser(BuildContext context) async {
    String server = _serverController.text;
    String username = _usernameController.text;
    String password = _passwordController.text;
    if (server.isEmpty) return;

    setState(() {
      _loading = true;
    });

    try {
      ref.read(clientProviderProvider).showSnackBar = false;

      ref.read(authDataProvider.notifier).set(AuthModel(server, ""));
      ref.read(settingsRepositoryProvider).saveServer(server);

      Server? info = await ref.read(serverRepositoryProvider).getInfo();
      if (info == null) {
        throw Exception(
          "Getting server info failed",
        ); //TODO server not reachable?
      }

      if (!pastServers.contains(server)) {
        pastServers.add(server);
        ref.read(settingsRepositoryProvider).setPastServers(pastServers);
      }

      UserToken newUser = await ref
          .read(userRepositoryProvider)
          .login(username, password, rememberMe: _rememberMe);

      if (newUser.error == 1017) {
        newUser = await _showOtpDialog(context, newUser, username, password);
      } else if (newUser.error > 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(newUser.errorString)));
      } else if (newUser.error == 0) {
        ref
            .read(authDataProvider.notifier)
            .set(AuthModel(server, newUser.token));
        await ref.read(settingsRepositoryProvider).saveUserToken(newUser.token);

        var currentUser = await ref
            .read(userRepositoryProvider)
            .getCurrentUser();
        ref.read(currentUserProvider.notifier).set(currentUser);

        Navigator.pushNamed(context, "/home");
      }
    } catch (ex) {
      print(ex);
    } finally {
      ref.read(clientProviderProvider).showSnackBar = true;
      setState(() {
        _loading = false;
      });
    }
  }
}
