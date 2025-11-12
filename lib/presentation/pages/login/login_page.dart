import 'dart:core';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';
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
                      SnackBar(
                        content: Text("Please enter a valid frontend url"),
                      ),
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
                    client.setIgnoreCerts(value ?? false);
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
              return (isUrl(address) || address == null || address.isEmpty)
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

  Future<Response<UserToken>?> _showOtpDialog(
    BuildContext context,
    String username,
    String password,
  ) async {
    TextEditingController totpController = TextEditingController();
    return showDialog<Response<UserToken>>(
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
              Navigator.pop(
                context,
                ref
                    .read(userRepositoryProvider)
                    .login(
                      username,
                      password,
                      rememberMe: _rememberMe,
                      totp: totpController.text,
                    ),
              );
            },
            child: Text("Login"),
          ),
        ],
      ),
    );
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
      if (currentUser.isSuccessful) {
        ref
            .read(currentUserProvider.notifier)
            .set(currentUser.toSuccess().body);
      } else {
        _showGenericError(context);
      }

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
      ref.read(authDataProvider.notifier).set(AuthModel(server, ""));
      ref.read(settingsRepositoryProvider).saveServer(server);

      Response<Server> info = await ref
          .read(serverRepositoryProvider)
          .getInfo();
      if (!info.isSuccessful) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Cannot reach server")));
      } else {
        Sentry.configureScope(
          (scope) => scope.setTag(
            'server.version',
            info.toSuccess().body.version ?? "-",
          ),
        );
      }

      if (!pastServers.contains(server)) {
        pastServers.add(server);
        ref.read(settingsRepositoryProvider).setPastServers(pastServers);
      }

      Response<UserToken> response = await ref
          .read(userRepositoryProvider)
          .login(username, password, rememberMe: _rememberMe);

      if (response.isSuccessful) {
        var success = response.toSuccess();
        var userToken = success.body.token;
        onUserToken(server, userToken, context);
      } else if (response.isError) {
        var error = response.toError();
        if (error.error["code"] == 1017) {
          var response = await _showOtpDialog(context, username, password);

          //Otherwise user cancelled
          if (response != null) {
            if (response.isSuccessful) {
              var success = response.toSuccess();
              var userToken = success.body.token;
              onUserToken(server, userToken, context);
            } else {
              _showGenericError(context);
            }
          }
        } else if (error.error["code"] > 0) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.error["message"])));
        }
      }
    } catch (ex) {
      _showGenericError(context);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showGenericError(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Something went wrong")));
  }

  Future<void> onUserToken(
    String server,
    String userToken,
    BuildContext context,
  ) async {
    ref.read(authDataProvider.notifier).set(AuthModel(server, userToken));
    await ref.read(settingsRepositoryProvider).saveUserToken(userToken);

    var currentUser = await ref.read(userRepositoryProvider).getCurrentUser();

    if (currentUser.isSuccessful) {
      ref.read(currentUserProvider.notifier).set(currentUser.toSuccess().body);

      Navigator.pushReplacementNamed(context, "/home");
    } else {
      _showGenericError(context);
    }
  }
}
