import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/oauth/oauth_service.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/core/utils/network.dart';
import 'package:vikunja_app/core/utils/validator.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/widgets/button.dart';
import 'package:vikunja_app/presentation/widgets/sentry_dialog.dart';
import 'package:vikunja_app/presentation/widgets/version_mismatch_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  List<String> pastServers = [];

  final _serverController = TextEditingController();
  final _oauthService = OAuthService();

  @override
  void initState() {
    super.initState();

    var settingsDatasource = SettingsDatasource(FlutterSecureStorage());
    settingsDatasource.clearAuthData();

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
    var client = ref.read(clientProviderProvider);

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
              Padding(
                padding: vStandardVerticalPadding,
                child: SizedBox(
                  width: double.infinity,
                  child: FancyButton(
                    onPressed: !_loading
                        ? () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState?.save();
                              _connectAndLogin(context);
                            }
                          }
                        : null,
                    child: _loading
                        ? CircularProgressIndicator()
                        : Text(AppLocalizations.of(context).login),
                  ),
                ),
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

  Future<void> _connectAndLogin(BuildContext context) async {
    String server = normalizeServerURL(_serverController.text);
    if (server.isEmpty) return;

    setState(() => _loading = true);

    try {
      // Step 1: Set up the client so we can call the API
      ref.read(authDataProvider.notifier).set(AuthModel(server));
      ref.read(settingsRepositoryProvider).saveServer(server);

      // Step 2: Validate via /api/v1/info
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
        return;
      }

      Sentry.configureScope(
        (scope) => scope.setTag(
          'server.version',
          info.toSuccess().body.version ?? "-",
        ),
      );

      Version? serverVersion = Version.fromServerString(
        info.toSuccess().body.version ?? "-",
      );

      // Save to past servers
      if (!pastServers.contains(server)) {
        pastServers.add(server);
        ref.read(settingsRepositoryProvider).setPastServers(pastServers);
      }

      // Step 3: Launch OAuth PKCE flow
      String code = await _oauthService.authorize(server);

      // Step 4: Exchange code for tokens
      var client = ref.read(clientProviderProvider);
      OAuthTokenResponse tokens = await _oauthService.exchangeCode(
        client,
        code,
      );

      // Step 5: Store tokens and navigate
      await ref
          .read(settingsRepositoryProvider)
          .saveUserToken(tokens.accessToken);
      await ref
          .read(settingsRepositoryProvider)
          .saveRefreshToken(tokens.refreshToken);

      // Re-set auth data so the client picks up the new token
      ref.read(authDataProvider.notifier).set(AuthModel(server));

      // Step 6: Fetch current user
      var currentUser = await ref.read(userRepositoryProvider).getCurrentUser();
      if (currentUser.isSuccessful) {
        ref
            .read(currentUserProvider.notifier)
            .set(currentUser.toSuccess().body);

        if (serverVersion != null &&
            !serverVersion.isCompatibleWith(minimumServerVersion) &&
            context.mounted) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return VersionMismatchDialog(serverVersion: serverVersion);
            },
          );
        }

        if (context.mounted) {
          Navigator.pushReplacementNamed(context, "/home");
        }
      } else {
        if (context.mounted) {
          _showGenericError(context);
        }
      }
    } on OAuthException catch (e) {
      log("OAuth error: ${e.error}");
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        final message = switch (e.error) {
          OAuthError.browserLaunchFailed => l10n.oauthBrowserLaunchFailed,
          OAuthError.stateMismatch => l10n.oauthStateMismatch,
          OAuthError.noAuthorizationCode => l10n.oauthNoAuthorizationCode,
          OAuthError.tokenExchangeFailed =>
            e.serverMessage ?? l10n.oauthTokenExchangeFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      log("Login failed: $e");
      if (context.mounted) {
        _showGenericError(context);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showGenericError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)),
    );
  }
}
