import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_button.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_header.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/insecure_connection_dialog.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/known_servers.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/server_address_field.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';

class ConnectServerScreen extends ConsumerStatefulWidget {
  const new({this.adding = false, super.key});

  /// Over the shell, for another account: with a close button and the
  /// servers of the accounts on this device, and the server overview is
  /// pushed, so that back leads here and then to the shell.
  final bool adding;

  @override
  ConsumerState<ConnectServerScreen> createState() =>
      _ConnectServerScreenState();
}

class _ConnectServerScreenState extends ConsumerState<ConnectServerScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _errorKey = GlobalKey();
  final _address = TextEditingController();

  ConnectServerController get _controller =>
      ref.read(connectServerControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // The shell keeps the sign-in state, so a failure of the active
    // account's "Sign in again" would otherwise show on the new server's
    // overview.
    if (widget.adding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(signInControllerProvider.notifier).reset();
      });
    }
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_controller.connect(_address.text));
  }

  void _tryDemo() {
    _address.text = publicDemoAddress;
    _submit();
  }

  void _useKnownServer(Uri server) {
    _address.text = server.toString();
    _submit();
  }

  void _onAddressChanged(String _) {
    if (ref.read(connectServerControllerProvider) is ConnectServerFailed) {
      _controller.reset();
    }
  }

  void _onStateChanged(ConnectServerState? previous, ConnectServerState next) {
    switch (next) {
      case ConnectServerFailed():
        unawaited(HapticFeedback.heavyImpact());
      case ConnectServerAwaitingInsecureConsent(:final connection):
        unawaited(_askForInsecureConsent(connection));
      case ConnectServerConnected() when widget.adding:
        unawaited(context.push(AppRoutes.addAccountServer));
      case ConnectServerConnected():
        context.go(AppRoutes.serverOverview);
      case ConnectServerIdle() || ConnectServerConnecting():
        break;
    }
  }

  // Runs once AnimatedSize has grown, because before that the scroll extent
  // does not include the card yet.
  void _revealError() {
    final errorContext = _errorKey.currentContext;
    if (errorContext == null) return;
    Scrollable.ensureVisible(
      errorContext,
      duration: const Duration(milliseconds: 250),
    );
  }

  Future<void> _askForInsecureConsent(ServerConnection connection) async {
    final accepted = await confirmInsecureConnection(
      context,
      rootUri: connection.rootUri,
    );
    if (!mounted) return;
    if (accepted) {
      _controller.acceptInsecureConnection();
    } else {
      _controller.declineInsecureConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectServerControllerProvider, _onStateChanged);
    final state = ref.watch(connectServerControllerProvider);
    final isConnecting = state is ConnectServerConnecting;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final accounts = widget.adding
        ? ref.watch(accountsProvider).value?.accountsByRecency
        : null;
    final knownServers = {
      for (final entry in accounts ?? const <RegisteredAccount>[])
        entry.connection.rootUri,
    }.toList();

    return Scaffold(
      appBar: widget.adding ? AppBar(leading: const CloseButton()) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, widget.adding ? 8 : 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConnectHeader(
                      title: widget.adding ? l10n.accountAdd : null,
                      tagline: widget.adding ? l10n.addAccountTagline : null,
                    ),
                    const SizedBox(height: 32),
                    ServerAddressField(
                      controller: _address,
                      enabled: !isConnecting,
                      onSubmitted: _submit,
                      onChanged: _onAddressChanged,
                    ),
                    if (knownServers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      KnownServers(
                        servers: knownServers,
                        enabled: !isConnecting,
                        onSelected: _useKnownServer,
                      ),
                    ],
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      onEnd: _revealError,
                      child: switch (state) {
                        ConnectServerFailed(:final failure, :final input) =>
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: ConnectionErrorCard(
                              key: _errorKey,
                              message: FailureMessage.describe(
                                l10n,
                                failure: failure,
                                input: input,
                                platform: theme.platform,
                              ),
                            ),
                          ),
                        _ => const SizedBox(width: double.infinity),
                      },
                    ),
                    const SizedBox(height: 24),
                    ConnectButton(
                      isConnecting: isConnecting,
                      onContinue: _submit,
                    ),
                    if (state case ConnectServerConnecting(:final input))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.connectConnectingTo(input.trim()),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isConnecting ? null : _tryDemo,
                      child: Text(l10n.connectTryDemo),
                    ),
                    // Below the other buttons, so a double tap on either of
                    // them cannot land on it once connecting starts.
                    if (isConnecting)
                      TextButton(
                        onPressed: _controller.cancel,
                        child: Text(l10n.connectCancel),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
