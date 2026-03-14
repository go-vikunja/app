import 'dart:core';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/core/utils/network.dart';
import 'package:vikunja_app/core/utils/validator.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/pages/login/login_webview.dart';
import 'package:vikunja_app/presentation/pages/login/register_page.dart';
import 'package:vikunja_app/presentation/widgets/button.dart';
import 'package:vikunja_app/presentation/widgets/sentry_dialog.dart';
import 'package:vikunja_app/init_page.dart';
import 'package:vikunja_app/presentation/widgets/version_mismatch_dialog.dart';

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

    var settingsDatasource = SettingsDatasource(FlutterSecureStorage());
    settingsDatasource.saveServer(null);
    settingsDatasource.saveUserToken(null);
    settingsDatasource.saveRefreshCookie(null);

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
            ref.read(settingsRepositoryProvider).setSentryEnabled(true);
          },
          onRefuse: () {
            ref.read(settingsRepositoryProvider).setSentryEnabled(false);
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
                  title: Text(AppLocalizations.of(context).rememberMe),
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
                child: _loading
                    ? CircularProgressIndicator()
                    : Text(AppLocalizations.of(context).login),
              ),
              FancyButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                ),
                child: Text(AppLocalizations.of(context).register),
              ),
              FancyButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() == true &&
                      _serverController.text.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginWithWebView(
                          normalizeServerURL(_serverController.text),
                        ),
                      ),
                    ).then((btp) {
                      if (btp != null) _loginUserByClientToken(btp);
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          ).pleaseEnterValidFrontendUrl,
                        ),
                      ),
                    );
                  }
                },
                child: Text(AppLocalizations.of(context).loginWithFrontend),
              ),
              CheckboxListTile(
                title: Text(AppLocalizations.of(context).ignoreCertificates),
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
          labelText: AppLocalizations.of(context).password,
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
          labelText: AppLocalizations.of(context).username,
        ),
      ),
    );
  }

  Padding _buildServerInput() {
    return Padding(
      padding: vStandardVerticalPadding,
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          List<String> matches = <String>[];
          matches.addAll(pastServers);
          matches.retainWhere((s) {
            return s.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            );
          });
          return matches;
        },
        focusNode: FocusNode(),
        textEditingController: _serverController,
        onSelected: (String selection) {
          _serverController.text = selection;
          setState(() => _serverController.text = selection);
        },
        fieldViewBuilder:
            (
              BuildContext context,
              TextEditingController textEditingController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted,
            ) =>
                _buildServerTextView(textEditingController, focusNode, context),
        optionsViewBuilder:
            (
              BuildContext context,
              AutocompleteOnSelected<String> onSelected,
              Iterable<String> options,
            ) => _buildServerOptions(options, onSelected),
      ),
    );
  }

  TextFormField _buildServerTextView(
    TextEditingController textEditingController,
    FocusNode focusNode,
    BuildContext context,
  ) {
    return TextFormField(
      controller: textEditingController,
      focusNode: focusNode,
      enabled: !_loading,
      validator: (address) {
        return isURLValid(address)
            ? null
            : AppLocalizations.of(context).invalidUrl;
      },
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        labelText: AppLocalizations.of(context).serverAddress,
      ),
    );
  }

  ListView _buildServerOptions(
    Iterable<String> options,
    AutocompleteOnSelected<String> onSelected,
  ) {
    return ListView(
      padding: EdgeInsets.zero,
      children: options.map((item) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: InkWell(
              onTap: () {
                onSelected(item);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        pastServers.remove(item);
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
          ),
        );
      }).toList(),
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
        semanticLabel: AppLocalizations.of(context).vikunjaLogoAlt,
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
        title: Text(AppLocalizations.of(context).enterOneTimePasscode),
        content: TextField(
          controller: totpController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              var loginResponse = await ref
                  .read(userRepositoryProvider)
                  .login(
                    username,
                    password,
                    rememberMe: _rememberMe,
                    totp: totpController.text,
                  );

              if (context.mounted) {
                Navigator.pop(context, loginResponse);
              }
            },
            child: Text(AppLocalizations.of(context).login),
          ),
        ],
      ),
    );
  }

  Future<void> _loginUserByClientToken(BaseTokenPair baseTokenPair) async {
    ref.read(settingsRepositoryProvider).saveUserToken(baseTokenPair.token);
    ref.read(settingsRepositoryProvider).saveServer(baseTokenPair.base);
    // Webview login does not provide a refresh cookie
    ref.read(settingsRepositoryProvider).saveRefreshCookie(null);
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
        var buildContext = context;
        if (buildContext.mounted) {
          _showGenericError(buildContext);
        }
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
    String server = normalizeServerURL(_serverController.text);
    String username = _usernameController.text;
    String password = _passwordController.text;
    if (server.isEmpty) return;

    setState(() {
      _loading = true;
    });

    try {
      ref.read(authDataProvider.notifier).set(AuthModel(server, ""));
      ref.read(settingsRepositoryProvider).saveServer(server);

      Version? serverVersion;
      Version? apiMinCompatible;

      Response<Server> info = await ref
          .read(serverRepositoryProvider)
          .getInfo();
      if (!info.isSuccessful) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).cannotReachServer),
            ),
          );
        }
      } else {
        final serverInfo = info.toSuccess().body;
        Sentry.configureScope(
          (scope) => scope.setTag('server.version', serverInfo.version ?? "-"),
        );

        serverVersion = Version.fromServerString(serverInfo.version ?? "-");
        if (serverInfo.apiMinCompatible != null) {
          apiMinCompatible = Version.fromString(serverInfo.apiMinCompatible!);
        }
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
        var refreshCookie = success.body.refreshCookie;
        if (context.mounted) {
          onUserToken(
            context,
            server,
            userToken,
            serverVersion,
            apiMinCompatible: apiMinCompatible,
            refreshCookie: refreshCookie,
          );
        }
      } else if (response.isError) {
        var error = response.toError();
        if (error.error["code"] == 1017) {
          if (context.mounted) {
            var response = await _showOtpDialog(context, username, password);

            //Otherwise user cancelled
            if (response != null && context.mounted) {
              if (response.isSuccessful) {
                var success = response.toSuccess();
                var userToken = success.body.token;
                var refreshCookie = success.body.refreshCookie;
                onUserToken(
                  context,
                  server,
                  userToken,
                  serverVersion,
                  refreshCookie: refreshCookie,
                );
              } else {
                _showGenericError(context);
              }
            }
          }
        } else if (error.error["code"] > 0) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.error["message"])));
          }
        }
      }
    } catch (ex) {
      if (context.mounted) {
        _showGenericError(context);
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showGenericError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)),
    );
  }

  Future<void> onUserToken(
    BuildContext context,
    String server,
    String userToken,
    Version? serverVersion, {
    Version? apiMinCompatible,
    String? refreshCookie,
  }) async {
    ref
        .read(authDataProvider.notifier)
        .set(AuthModel(server, userToken, refreshCookie: refreshCookie));
    await ref.read(settingsRepositoryProvider).saveUserToken(userToken);
    await ref.read(settingsRepositoryProvider).saveRefreshCookie(refreshCookie);

    var currentUser = await ref.read(userRepositoryProvider).getCurrentUser();

    if (currentUser.isSuccessful) {
      ref.read(currentUserProvider.notifier).set(currentUser.toSuccess().body);

      if (serverVersion != null && context.mounted) {
        final mismatchType = checkVersionCompatibility(
          serverVersion,
          apiMinCompatible,
        );
        if (mismatchType != null) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return VersionMismatchDialog(
                serverVersion: serverVersion,
                mismatchType: mismatchType,
              );
            },
          );
        }
      }

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    } else {
      if (context.mounted) {
        _showGenericError(context);
      }
    }
  }
}
