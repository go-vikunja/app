import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/application/connection_fix.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_button.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_failure_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_header.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_options_button.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/insecure_connection_dialog.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/invite_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/known_servers.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/link_failure_message.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/server_address_field.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/guest/share_password_sheet.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/guest/shared_link_sheet.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';
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
  final _addressFocus = FocusNode();

  /// The address the typed text names, for its connection settings.
  OriginKey? _typedOrigin;
  var _typedOriginHasSettings = false;

  ConnectServerController get _controller =>
      ref.read(connectServerControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _address.addListener(_onAddressEdited);
    // The shell keeps the sign-in state, so a failure of the active
    // account's "Sign in again" would otherwise show on the new server's
    // overview.
    if (widget.adding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(signInControllerProvider.notifier).reset();
      });
    }
  }

  void _onAddressEdited() {
    final origin = originOfTypedAddress(_address.text);
    if (origin == _typedOrigin) return;
    setState(() {
      _typedOrigin = origin;
      _typedOriginHasSettings = false;
    });
    if (origin != null) unawaited(_lookUpSettings(origin));
  }

  Future<void> _lookUpSettings(OriginKey origin) async {
    var stored = false;
    try {
      final profile = await ref
          .read(networkProfilesProvider)
          .metadataFor(origin);
      stored = profile != null && !profile.isEmpty;
    } on Object {
      // The options open anyway and say what is wrong.
    }
    if (mounted && origin == _typedOrigin) {
      setState(() => _typedOriginHasSettings = stored);
    }
  }

  Future<void> _openConnectionOptions(OriginKey origin) async {
    final changed = await openConnectionSettings(context, ref, origin);
    if (!mounted) return;
    unawaited(_lookUpSettings(origin));
    if (changed) unawaited(_controller.retryAfterConnectionChange());
  }

  Future<void> _fix(ConnectionFix fix, OriginKey origin) async {
    final profiles = ref.read(networkProfilesProvider);
    switch (fix) {
      case ConnectionFix.retry:
        await profiles.reload();
        if (mounted) unawaited(_controller.retryAfterConnectionChange());
      case ConnectionFix.reset:
        if (await resetConnectionSettings(context, profiles) && mounted) {
          unawaited(_controller.retryAfterConnectionChange());
        }
      case ConnectionFix.viewCertificate ||
          ConnectionFix.addHeaders ||
          ConnectionFix.clientCertificate ||
          ConnectionFix.openSettings:
        final changed = await openConnectionSettings(
          context,
          ref,
          origin,
          editor: switch (fix) {
            ConnectionFix.viewCertificate => ConnectionEditor.certificate,
            ConnectionFix.addHeaders => ConnectionEditor.headers,
            ConnectionFix.clientCertificate =>
              ConnectionEditor.clientCertificate,
            _ => null,
          },
        );
        if (!mounted) return;
        unawaited(_lookUpSettings(origin));
        if (changed) unawaited(_controller.retryAfterConnectionChange());
    }
  }

  void _onFix(ConnectionFix fix, OriginKey origin) =>
      unawaited(_fix(fix, origin));

  /// A shared link's own host that refused the app like an access proxy.
  static OriginKey? _headersFixOrigin(ServerConnectionFailure failure) =>
      switch ((connectionFixFor(failure), failure.uri)) {
        (ConnectionFix.addHeaders, final uri?) => OriginKey.tryOf(uri),
        _ => null,
      };

  @override
  void dispose() {
    _address.removeListener(_onAddressEdited);
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  /// The address field, Continue and the known servers also answer
  /// "Which server is it?" for a shared link; the demo never does.
  void _submit({bool forPendingShare = true}) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      _controller.connect(_address.text, forPendingShare: forPendingShare),
    );
  }

  void _tryDemo() {
    _address.text = publicDemoAddress;
    _submit(forPendingShare: false);
  }

  void _useKnownServer(Uri server) {
    _address.text = server.toString();
    _submit();
  }

  Future<void> _openSharedLink() async {
    final link = await askForSharedLink(context);
    if (link == null || !mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_controller.connect(link));
  }

  Future<void> _openInvite(ParsedInviteLink invite) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final opened = await ref
        .read(externalLinkOpenerProvider)
        .open(inviteUrl(invite));
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.legalOpenFailed)));
    }
  }

  void _onAddressChanged(String _) {
    if (ref.read(connectServerControllerProvider)
        case ConnectServerFailed() ||
            ConnectServerLinkFailed() ||
            ConnectServerInviteFound()) {
      _controller.reset();
    }
  }

  void _onStateChanged(ConnectServerState? previous, ConnectServerState next) {
    switch (next) {
      case ConnectServerFailed() || ConnectServerLinkFailed():
        unawaited(HapticFeedback.heavyImpact());
      case ConnectServerAwaitingInsecureConsent(:final connection):
        unawaited(_askForInsecureConsent(connection));
      case ConnectServerConnected() when widget.adding:
        unawaited(context.push(AppRoutes.addAccountServer));
      case ConnectServerConnected():
        context.go(AppRoutes.serverOverview);
      case ConnectServerShareNeedsServer():
        unawaited(HapticFeedback.heavyImpact());
        // The field holds the link, which is not the server's address.
        if (parseLinkShareUrl(_address.text) != null) _address.clear();
        // Once the field is enabled again; a disabled one takes no focus.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _addressFocus.requestFocus();
        });
      case ConnectServerSharePasswordNeeded()
          when previous is! ConnectServerSharePasswordNeeded:
        unawaited(_askForSharePassword());
      case ConnectServerGuestSignedIn(:final isNewAccount):
        // After the password sheet has closed.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _enterAsGuest(isNewAccount: isNewAccount);
        });
      case ConnectServerIdle() ||
          ConnectServerConnecting() ||
          ConnectServerInviteFound() ||
          ConnectServerSharePasswordNeeded():
        break;
    }
  }

  Future<void> _askForSharePassword() async {
    final outcome = await askForSharePassword(
      context,
      submit: _controller.submitSharePassword,
    );
    if (outcome == null && mounted) _controller.reset();
  }

  void _enterAsGuest({required bool isNewAccount}) {
    if (!isNewAccount) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.guestAlreadyAdded)));
    }
    // The router sends a guest that has not synced yet on to its first
    // sync, and the landing then opens the shared project.
    context.go(AppRoutes.home);
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
      unawaited(_controller.acceptInsecureConnection());
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
                      focusNode: _addressFocus,
                      enabled: !isConnecting,
                      onSubmitted: _submit,
                      onChanged: _onAddressChanged,
                    ),
                    ConnectionOptionsButton(
                      origin: _typedOrigin,
                      hasSettings: _typedOriginHasSettings,
                      onPressed: isConnecting
                          ? null
                          : (origin) =>
                                unawaited(_openConnectionOptions(origin)),
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
                            child: ConnectFailureCard(
                              key: _errorKey,
                              error: failure,
                              origin: switch (failure?.uri) {
                                final uri? => OriginKey.tryOf(uri),
                                null => null,
                              },
                              onFix: _onFix,
                              describe: (settings) => FailureMessage.describe(
                                l10n,
                                failure: failure,
                                input: input,
                                platform: theme.platform,
                                hasClientCertificate: settings == null
                                    ? null
                                    : settings.profile?.clientCertificate !=
                                          null,
                                pinned: settings?.profile?.pin != null,
                              ),
                            ),
                          ),
                        ConnectServerLinkFailed(
                          :final error,
                          :final serverRoot,
                        ) =>
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: ConnectFailureCard(
                              key: _errorKey,
                              error: error,
                              origin: OriginKey.tryOf(serverRoot),
                              onFix: _onFix,
                              describe: (_) => describeLinkFailure(
                                l10n,
                                error,
                                serverRoot: serverRoot,
                                platform: theme.platform,
                              ),
                            ),
                          ),
                        ConnectServerShareNeedsServer(
                          :final linkBase,
                          :final failure,
                        ) =>
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: StatusCard(
                              key: _errorKey,
                              icon: Icons.help_outline,
                              title: l10n.guestServerNeededTitle,
                              body: l10n.guestServerNeededExplanation(
                                displayHost(linkBase),
                              ),
                              footnote: l10n.guestServerNeededSuggestion,
                              background: theme.colorScheme.secondaryContainer,
                              foreground:
                                  theme.colorScheme.onSecondaryContainer,
                              liveRegion: true,
                              action: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                children: [
                                  if (_headersFixOrigin(failure)
                                      case final origin?)
                                    TextButton(
                                      onPressed: () => _onFix(
                                        ConnectionFix.addHeaders,
                                        origin,
                                      ),
                                      child: Text(l10n.connectionAddHeaders),
                                    ),
                                  TextButton(
                                    onPressed: _controller.reset,
                                    child: Text(l10n.cancel),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ConnectServerInviteFound(
                          :final connection,
                          :final invite,
                          :final check,
                          :final preview,
                        ) =>
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: InviteCard(
                              key: _errorKey,
                              serverRoot: connection.rootUri,
                              check: check,
                              preview: preview,
                              onCreateAccount: () =>
                                  unawaited(_openInvite(invite)),
                              onContinue: _controller.continueToSignIn,
                            ),
                          ),
                        _ => const SizedBox(width: double.infinity),
                      },
                    ),
                    if (state is! ConnectServerInviteFound) ...[
                      const SizedBox(height: 24),
                      ConnectButton(
                        isConnecting: isConnecting,
                        onContinue: _submit,
                      ),
                    ],
                    if (state case final ConnectServerConnecting connecting)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _connectingText(l10n, connecting),
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
                    TextButton.icon(
                      onPressed: isConnecting
                          ? null
                          : () => unawaited(_openSharedLink()),
                      icon: const Icon(Icons.link),
                      label: Text(
                        l10n.guestOpenSharedLink,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Below the other buttons, so a double tap on either of
                    // them cannot land on it once connecting starts.
                    if (isConnecting)
                      TextButton(
                        onPressed: _controller.cancel,
                        child: Text(l10n.connectCancel),
                      ),
                    // Signed in, the Account tab's version line opens it.
                    if (!widget.adding) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: isConnecting
                            ? null
                            : () => unawaited(context.push(AppRoutes.about)),
                        icon: const Icon(Icons.info_outline),
                        label: Text(l10n.aboutTitle),
                      ),
                    ],
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

String _connectingText(
  AppLocalizations l10n,
  ConnectServerConnecting connecting,
) => switch (connecting.target) {
  ConnectTarget.sharedLink => l10n.guestConnectingTo(connecting.input),
  ConnectTarget.invite => l10n.inviteConnectingTo(
    displayHost(Uri.parse(connecting.input)),
  ),
  ConnectTarget.server => l10n.connectConnectingTo(connecting.input.trim()),
};

/// The origin whose connection settings apply to what was typed: a shared
/// link's or an invite's server, else the address as the connector reads
/// it first (https when no scheme is typed); null while it is no address.
OriginKey? originOfTypedAddress(String input) {
  if (parseLinkShareUrl(input) case final share?) {
    return OriginKey.tryOf(share.base);
  }
  if (parseInviteLink(input) case final invite?) {
    return OriginKey.tryOf(invite.base);
  }
  try {
    return OriginKey.tryOf(normalizeServerAddress(input).root);
  } on InvalidServerAddress {
    return null;
  }
}
