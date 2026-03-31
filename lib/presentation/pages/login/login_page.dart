import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/oauth/oauth_service.dart';
import 'package:vikunja_app/core/utils/constants.dart'
    show minimumServerVersion;
import 'package:vikunja_app/core/utils/network.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
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
  String? _serverError;
  bool _showCustomUrl = false;
  bool _showCancel = false;
  bool _cancelled = false;
  String? _loadingServer;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () async {
      var settingsDatasource = SettingsDatasource(FlutterSecureStorage());
      await settingsDatasource.clearAuthData();

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

  @override
  void dispose() {
    _oauthService.cancelAuthorize();
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
    var client = ref.read(clientProviderProvider);

    return PopScope(
      canPop: !_loading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _loading) {
          _cancelled = true;
          _oauthService.cancelAuthorize();
          setState(() => _loading = false);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32.0,
                    vertical: 48.0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 48),
                        IndexedStack(
                          index: _showCustomUrl ? 1 : 0,
                          children: [_buildPresetView(), _buildCustomUrlView()],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showCustomUrl)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: CheckboxListTile(
                    value: client.ignoreCertificates,
                    onChanged: (value) {
                      ref
                          .read(settingsRepositoryProvider)
                          .setIgnoreCertificates(value ?? false);
                      setState(() {
                        client.setIgnoreCerts(value ?? false);
                      });
                    },
                    title: Text(
                      AppLocalizations.of(context).ignoreCertificates,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPresetButton(
          url: 'https://app.vikunja.cloud',
          label: AppLocalizations.of(context).vikunjaCloud,
          filled: true,
        ),
        const SizedBox(height: 12),
        _buildPresetButton(
          url: 'https://try.vikunja.io',
          label: AppLocalizations.of(context).tryDemo,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: !_loading
              ? () => setState(() => _showCustomUrl = true)
              : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            AppLocalizations.of(context).customServerUrl,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        Visibility(
          visible: _showCancel,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton(
              onPressed: _showCancel
                  ? () {
                      _cancelled = true;
                      _oauthService.cancelAuthorize();
                      setState(() => _loading = false);
                    }
                  : null,
              child: Text(AppLocalizations.of(context).cancel),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomUrlView() {
    return Form(
      autovalidateMode: AutovalidateMode.disabled,
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalizations.of(context).loginServerExplanation,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildServerInput(),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: !_loading ? () => _connectAndLogin(context) : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _loading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      AppLocalizations.of(context).login,
                      key: const ValueKey('text'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (_showCancel)
            TextButton(
              onPressed: () {
                _cancelled = true;
                _oauthService.cancelAuthorize();
                setState(() => _loading = false);
              },
              child: Text(AppLocalizations.of(context).cancel),
            )
          else
            TextButton(
              onPressed: !_loading
                  ? () => setState(() => _showCustomUrl = false)
                  : null,
              child: Text(AppLocalizations.of(context).cancel),
            ),
        ],
      ),
    );
  }

  Widget _buildServerInput() {
    return Autocomplete<String>(
      key: ValueKey(pastServers.length),
      optionsBuilder: (TextEditingValue textEditingValue) {
        List<String> matches = <String>[];
        matches.addAll(pastServers);
        matches.retainWhere((s) {
          return s.toLowerCase().contains(textEditingValue.text.toLowerCase());
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
          ) => _buildServerTextView(textEditingController, focusNode, context),
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) => _buildServerOptions(options, onSelected),
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
      onChanged: (_) {
        if (_serverError != null) {
          setState(() => _serverError = null);
          _formKey.currentState?.validate();
        }
      },
      validator: (_) => _serverError,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        labelText: AppLocalizations.of(context).serverAddress,
        hintText: AppLocalizations.of(
          context,
        ).serverAddressHint('https://try.vikunja.io'),
        prefixIcon: const Icon(Icons.dns_outlined),
        errorMaxLines: 3,
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

  Widget _buildPresetButton({
    required String url,
    required String label,
    bool filled = false,
  }) {
    final isThis = _loadingServer == url;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(double.infinity, 52)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    final child = isThis
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled ? Colors.white : null,
            ),
          )
        : Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          );

    if (filled) {
      return FilledButton(
        onPressed: !_loading ? () => _connectWithServer(url) : null,
        style: style,
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: !_loading ? () => _connectWithServer(url) : null,
      style: style,
      child: child,
    );
  }

  void _connectWithServer(String serverUrl) {
    _serverController.text = serverUrl;
    setState(() => _loadingServer = serverUrl);
    _connectAndLogin(context);
  }

  Widget _buildLogo() {
    return Image(
      image: Theme.of(context).brightness == Brightness.dark
          ? AssetImage('assets/vikunja_logo_full_white.png')
          : AssetImage('assets/vikunja_logo_full.png'),
      height: 85.0,
      semanticLabel: AppLocalizations.of(context).vikunjaLogoAlt,
    );
  }

  Future<void> _connectAndLogin(BuildContext context) async {
    String server = normalizeServerURL(_serverController.text);
    if (server.isEmpty) return;

    setState(() {
      _loading = true;
      _showCancel = false;
      _serverError = null;
      _cancelled = false;
    });
    _formKey.currentState?.validate();

    try {
      // Step 1: Set up the client so we can validate the server
      ref.read(authDataProvider.notifier).set(AuthModel(server));

      // Step 2: Validate via /api/v1/info
      Response<Server> info = await ref
          .read(serverRepositoryProvider)
          .getInfo();

      if (!info.isSuccessful) {
        setState(() {
          _serverError = AppLocalizations.of(context).cannotReachServer;
        });
        _formKey.currentState?.validate();
        return;
      }

      // Server validated — persist it
      ref.read(settingsRepositoryProvider).saveServer(server);

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
      setState(() => _showCancel = true);
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
          _showErrorSnackBar(
            context,
            AppLocalizations.of(context).somethingWentWrong,
          );
        }
      }
    } on OAuthException catch (e) {
      if (_cancelled) return;
      log("OAuth error: ${e.error}");
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        final message = switch (e.error) {
          OAuthError.browserLaunchFailed => l10n.oauthBrowserLaunchFailed,
          OAuthError.stateMismatch => l10n.oauthStateMismatch,
          OAuthError.noAuthorizationCode => l10n.oauthNoAuthorizationCode,
          OAuthError.tokenExchangeFailed =>
            e.serverMessage ?? l10n.oauthTokenExchangeFailed,
          OAuthError.cancelled => '', // unreachable
        };
        _showErrorSnackBar(context, message);
      }
    } catch (e) {
      if (_cancelled) return;
      log("Login failed: $e");
      if (context.mounted) {
        setState(() {
          _serverError = AppLocalizations.of(context).cannotReachServer;
        });
        _formKey.currentState?.validate();
      }
    } finally {
      setState(() {
        _loading = false;
        _showCancel = false;
        _loadingServer = null;
      });
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
