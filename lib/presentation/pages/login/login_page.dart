import 'dart:async';
import 'dart:core';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vikunja_app/core/di/data_source_provider.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/oauth_data_source.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/core/utils/network.dart';
import 'package:vikunja_app/core/utils/validator.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
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
  bool init = false;
  List<String> pastServers = [];

  final _serverController = TextEditingController();

  // OAuth flow state
  StreamSubscription<Uri>? _linkSubscription;
  String? _oauthCodeVerifier;
  String? _oauthState;

  @override
  void initState() {
    super.initState();

    var settingsDatasource = SettingsDatasource(FlutterSecureStorage());
    settingsDatasource.saveServer(null);
    settingsDatasource.saveUserToken(null);
    settingsDatasource.saveRefreshToken(null);
    settingsDatasource.saveTokenExpiry(null);
    settingsDatasource.saveAuthType(null);

    Future.delayed(Duration.zero, () async {
      ref.read(oAuthTokenManagerProvider.notifier).clear();

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

    // Listen for OAuth callback deep links
    final appLinks = AppLinks();
    _linkSubscription = appLinks.uriLinkStream.listen((Uri uri) {
      if (uri.scheme == 'vikunja' && uri.host == 'callback') {
        _handleOAuthCallback(uri);
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _serverController.dispose();
    super.dispose();
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
              Padding(
                padding: vStandardVerticalPadding,
                child: FancyButton(
                  onPressed: !_loading
                      ? () {
                          if (_serverController.text.isNotEmpty) {
                            _startOAuthLogin();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(context)
                                      .pleaseEnterValidFrontendUrl,
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  child: _loading
                      ? CircularProgressIndicator()
                      : Text(AppLocalizations.of(context).loginOrSignUp),
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

  Future<void> _startOAuthLogin() async {
    final server = normalizeServerURL(_serverController.text);
    if (server.isEmpty) return;

    setState(() => _loading = true);

    try {
      // Save server for later use in token exchange
      ref.read(authDataProvider.notifier).set(AuthModel(server, ""));
      ref.read(settingsRepositoryProvider).saveServer(server);

      // Add to past servers
      if (!pastServers.contains(server)) {
        pastServers.add(server);
        ref.read(settingsRepositoryProvider).setPastServers(pastServers);
      }

      // Generate PKCE pair
      _oauthCodeVerifier = OAuthDataSource.generateCodeVerifier();
      _oauthState = OAuthDataSource.generateState();
      final codeChallenge =
          OAuthDataSource.generateCodeChallenge(_oauthCodeVerifier!);

      // Build and open authorization URL
      final authUrl = OAuthDataSource.buildAuthorizationUrl(
        baseUrl: server,
        codeChallenge: codeChallenge,
        state: _oauthState!,
      );

      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _showGenericError(context);
      setState(() => _loading = false);
    }
    // Note: _loading stays true until the callback arrives or user returns
  }

  Future<void> _handleOAuthCallback(Uri callbackUri) async {
    final code = callbackUri.queryParameters['code'];
    final state = callbackUri.queryParameters['state'];

    // Verify state matches
    if (state != _oauthState) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OAuth state mismatch')),
        );
      }
      setState(() => _loading = false);
      return;
    }

    if (code == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authorization code received')),
        );
      }
      setState(() => _loading = false);
      return;
    }

    final server = normalizeServerURL(_serverController.text);

    try {
      final oauthDataSource = ref.read(oAuthDataSourceProvider);

      // Exchange code for tokens
      final tokens = await oauthDataSource.exchangeCode(
        baseUrl: server,
        code: code,
        codeVerifier: _oauthCodeVerifier!,
      );

      // Clear PKCE state
      _oauthCodeVerifier = null;
      _oauthState = null;

      // Persist tokens
      final settingsRepo = ref.read(settingsRepositoryProvider);
      await settingsRepo.saveUserToken(tokens.accessToken);
      await settingsRepo.saveRefreshToken(tokens.refreshToken);
      await settingsRepo.saveAuthType('oauth');
      await settingsRepo.saveTokenExpiry(
        DateTime.now().add(Duration(seconds: tokens.expiresIn)),
      );

      // Set up in-memory auth state
      ref
          .read(authDataProvider.notifier)
          .set(AuthModel(server, tokens.accessToken));

      // Set up OAuth token manager for proactive refresh
      ref.read(oAuthTokenManagerProvider.notifier).setTokens(
        OAuthTokenState(
          refreshToken: tokens.refreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: tokens.expiresIn)),
        ),
      );

      // Fetch current user to validate
      final currentUser =
          await ref.read(userRepositoryProvider).getCurrentUser();
      if (currentUser.isSuccessful) {
        ref
            .read(currentUserProvider.notifier)
            .set(currentUser.toSuccess().body);

        if (mounted) {
          Navigator.pushReplacementNamed(context, "/home");
        }
      } else {
        if (mounted) _showGenericError(context);
      }
    } on OAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) _showGenericError(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showGenericError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)),
    );
  }
}
