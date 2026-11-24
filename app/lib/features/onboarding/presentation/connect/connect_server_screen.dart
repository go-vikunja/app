import 'dart:async';

import 'package:flutter/gestures.dart';
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
import 'package:vikunja_mobile/core/text/server_address_display.dart';
import 'package:vikunja_mobile/features/common/presentation/motion.dart';
import 'package:vikunja_mobile/features/connection/application/connection_fix.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/onboarding/application/previous_app.dart';
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
import 'package:vikunja_mobile/features/onboarding/presentation/previous_app_note.dart';
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
  final GlobalKey _continueKey = GlobalKey();
  final GlobalKey _keepingKey = GlobalKey();
  ConnectServerState? _revealedState;
  final _address = TextEditingController();
  final _addressFocus = FocusNode();
  Timer? _tapHold;
  var _holdingTaps = false;

  /// The address the typed text names, for its connection settings.
  OriginKey? _typedOrigin;
  var _typedOriginHasSettings = false;
  var _typedWithoutScheme = false;

  ConnectServerController get _controller =>
      ref.read(connectServerControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    if (!widget.adding) _fillInPreviousServer();
    _address.addListener(_onAddressEdited);
    // The shell keeps the sign-in state, so a failure of the active
    // account's "Sign in again" would otherwise show on the new server's
    // overview.
    if (widget.adding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(signInControllerProvider.notifier).reset();
      });
    } else {
      // The previous app's session may have been kept, or be being kept,
      // before this screen was built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goHomeIfKept();
        _revealKeeping();
      });
    }
  }

  /// Before the address listener is added, as initState allows no
  /// setState.
  void _fillInPreviousServer() {
    final server = ref.read(previousAppProvider).value?.record?.server;
    if (server == null || _address.text.isNotEmpty) return;
    _address.text = '$server';
    _typedWithoutScheme = typedWithoutScheme(_address.text);
    _typedOrigin = originOfTypedAddress(_address.text);
    if (_typedOrigin case final origin?) unawaited(_lookUpSettings(origin));
  }

  /// The router leaves this screen alone for a signed-in user; home sends
  /// the account on to its first sync.
  void _goHomeIfKept() {
    if (!mounted) return;
    final kept =
        ref.read(previousAppProvider).value?.session is PreviousAppSessionKept;
    final signedIn = ref.read(accountsProvider).value?.activeAccount != null;
    if (kept && signedIn) context.go(AppRoutes.home);
  }

  void _onPreviousAppChanged(
    AsyncValue<PreviousAppState>? previous,
    AsyncValue<PreviousAppState> next,
  ) {
    final wasKeeping = previous?.value?.session is PreviousAppSessionKeeping;
    final keeping = next.value?.session is PreviousAppSessionKeeping;
    if (keeping && !wasKeeping) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealKeeping());
    } else if (wasKeeping && !keeping) {
      _holdTaps();
    }
    _goHomeIfKept();
  }

  // At a larger text size, the line with its Cancel may start below the
  // screen, and nothing else there can be used.
  void _revealKeeping() {
    final keepingContext = _keepingKey.currentContext;
    if (!mounted || keepingContext == null) return;
    Scrollable.ensureVisible(
      keepingContext,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  // The note shows above once the try ends and pushes everything down, so
  // the second tap of a double tap on the Cancel would land on whatever
  // moved under it, such as one of the servers.
  void _holdTaps() {
    _tapHold?.cancel();
    setState(() => _holdingTaps = true);
    _tapHold = Timer(kDoubleTapTimeout, () {
      if (mounted) setState(() => _holdingTaps = false);
    });
  }

  void _onAddressEdited() {
    final withoutScheme = typedWithoutScheme(_address.text);
    if (withoutScheme != _typedWithoutScheme) {
      setState(() => _typedWithoutScheme = withoutScheme);
    }
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

  Widget _addressFailureCard(ConnectServerFailed failed, {Key? key}) {
    final l10n = context.l10n;
    final platform = Theme.of(context).platform;
    final failure = failed.failure;
    return ConnectFailureCard(
      key: key,
      error: failure,
      origin: switch (failure?.uri) {
        final uri? => OriginKey.tryOf(uri),
        null => null,
      },
      onFix: _onFix,
      describe: (settings) => FailureMessage.describe(
        l10n,
        failure: failure,
        input: failed.input,
        platform: platform,
        hasClientCertificate: settings == null
            ? null
            : settings.profile?.clientCertificate != null,
        pinned: settings?.profile?.pin != null,
      ),
    );
  }

  /// A shared link's own host that refused the app like an access proxy.
  static OriginKey? _headersFixOrigin(ServerConnectionFailure failure) =>
      switch ((connectionFixFor(failure), failure.uri)) {
        (ConnectionFix.addHeaders, final uri?) => OriginKey.tryOf(uri),
        _ => null,
      };

  @override
  void dispose() {
    _tapHold?.cancel();
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
      // An address opened from elsewhere, such as the https offer of the
      // Connection page.
      case ConnectServerConnecting(:final input, target: ConnectTarget.server)
          when input.trim() != _address.text.trim():
        _address.text = input;
      case ConnectServerFailed() ||
          ConnectServerLinkFailed() ||
          ConnectServerShareNeedsServer(addressFailed: _?):
        unawaited(HapticFeedback.heavyImpact());
      case ConnectServerAwaitingInsecureConsent(
        :final connection,
        :final httpsFailed,
      ):
        unawaited(_askForInsecureConsent(connection, httpsFailed: httpsFailed));
      case ConnectServerConnected() when widget.adding:
        unawaited(context.push(AppRoutes.addAccountServer));
      case ConnectServerConnected():
        context.go(AppRoutes.serverOverview);
      case ConnectServerShareNeedsServer(:final claimingServer):
        unawaited(HapticFeedback.heavyImpact());
        if (claimingServer != null) {
          // Without focus: a keyboard would cover the card naming both
          // hosts, and its Go would send the link before that was read.
          _addressFocus.unfocus();
          _address.text = '$claimingServer';
        } else {
          // The field holds the link, which is not the server's address.
          if (parseLinkShareUrl(_address.text) != null) _address.clear();
          // Once the field is enabled again; a disabled one takes no focus.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _addressFocus.requestFocus();
          });
        }
      case ConnectServerSharePasswordNeeded(:final serverRoot)
          when previous is! ConnectServerSharePasswordNeeded:
        unawaited(_askForSharePassword(serverRoot));
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

  Future<void> _askForSharePassword(Uri serverRoot) async {
    final outcome = await askForSharePassword(
      context,
      serverRoot: serverRoot,
      submit: (password, {required remember}) =>
          _controller.submitSharePassword(password, remember: remember),
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
  // does not include the card yet. Once for each state: a card that changes
  // its size as the address is edited leaves the view to the field.
  Future<void> _revealError() async {
    final errorContext = _errorKey.currentContext;
    final state = ref.read(connectServerControllerProvider);
    if (errorContext == null || identical(state, _revealedState)) return;
    _revealedState = state;
    final duration = reduceMotionOf(errorContext)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    await Scrollable.ensureVisible(errorContext, duration: duration);
    // Continue confirms the stored server the card names.
    if (state case ConnectServerShareNeedsServer(claimingServer: _?)) {
      final continueContext = _continueKey.currentContext;
      if (continueContext == null || !continueContext.mounted) return;
      await Scrollable.ensureVisible(
        continueContext,
        duration: duration,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  Future<void> _askForInsecureConsent(
    ServerConnection connection, {
    required bool httpsFailed,
  }) async {
    final accepted = await confirmInsecureConnection(
      context,
      rootUri: connection.rootUri,
      httpsFailed: httpsFailed,
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
    if (!widget.adding) {
      // The session and the registry each may change last.
      ref
        ..listen(previousAppProvider, _onPreviousAppChanged)
        ..listen(
          accountsProvider.select(
            (accounts) => accounts.value?.activeAccount != null,
          ),
          (_, _) => _goHomeIfKept(),
        );
    }
    final state = ref.watch(connectServerControllerProvider);
    final isConnecting = state is ConnectServerConnecting;
    final storingGuest = isConnecting && !state.cancellable;
    final previous = widget.adding
        ? null
        : ref.watch(previousAppProvider).value;
    final keeping = switch (previous?.session) {
      final PreviousAppSessionKeeping keeping => keeping,
      _ => null,
    };
    // The previous app's session is being kept: its refresh token is spent
    // once sent, so nothing here may start another sign-in meanwhile.
    final busy = isConnecting || keeping != null;
    // The record goes once an account was registered, and with it the
    // filled-in address the note speaks of.
    final note = switch (previous) {
      PreviousAppState(
        :final note?,
        record: _?,
        session: PreviousAppSessionUntried() || PreviousAppSessionLost(),
      ) =>
        note,
      _ => null,
    };
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final accounts = widget.adding
        ? ref.watch(accountsProvider).value?.accountsByRecency
        : null;
    final knownServers = widget.adding
        ? {
            for (final entry in accounts ?? const <RegisteredAccount>[])
              entry.connection.rootUri,
          }.toList()
        : previous?.record?.recentServers ?? const <Uri>[];

    return Scaffold(
      appBar: widget.adding
          ? AppBar(
              leading: storingGuest ? null : const CloseButton(),
              automaticallyImplyLeading: false,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, widget.adding ? 8 : 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: IgnorePointer(
                  ignoring: _holdingTaps,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConnectHeader(
                        title: widget.adding ? l10n.accountAdd : null,
                        tagline: widget.adding ? l10n.addAccountTagline : null,
                      ),
                      if (note != null) ...[
                        const SizedBox(height: 24),
                        PreviousAppNoteCard(note: note, signedIn: false),
                      ],
                      const SizedBox(height: 32),
                      ServerAddressField(
                        controller: _address,
                        focusNode: _addressFocus,
                        enabled: !busy,
                        onSubmitted: _submit,
                        onChanged: _onAddressChanged,
                      ),
                      ConnectionOptionsButton(
                        origin: _typedOrigin,
                        hasSettings: _typedOriginHasSettings,
                        triesHttpsFirst: _typedWithoutScheme,
                        onPressed: busy
                            ? null
                            : (origin) =>
                                  unawaited(_openConnectionOptions(origin)),
                      ),
                      if (knownServers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        KnownServers(
                          servers: knownServers,
                          enabled: !busy,
                          onSelected: _useKnownServer,
                        ),
                      ],
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topCenter,
                        onEnd: () => unawaited(_revealError()),
                        child: switch (state) {
                          ConnectServerFailed() && final failed => Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _addressFailureCard(failed, key: _errorKey),
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
                            :final claimingServer,
                            :final addressFailed,
                          ) =>
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                key: _errorKey,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Like a failed address on its own, it goes
                                  // once the field names another address.
                                  if (addressFailed != null &&
                                      _typedOrigin ==
                                          originOfTypedAddress(
                                            addressFailed.input,
                                          )) ...[
                                    _addressFailureCard(addressFailed),
                                    const SizedBox(height: 8),
                                  ],
                                  StatusCard(
                                    icon: Icons.help_outline,
                                    title: l10n.guestServerNeededTitle,
                                    body: l10n.guestServerNeededExplanation(
                                      displayHost(linkBase),
                                    ),
                                    // Only while Continue sends the link there.
                                    footnote: switch (claimingServer) {
                                      final server?
                                          when _typedOrigin ==
                                              OriginKey.tryOf(server) =>
                                        _claimedServerNote(
                                          l10n,
                                          linkBase: linkBase,
                                          server: server,
                                        ),
                                      _ => l10n.guestServerNeededSuggestion,
                                    },
                                    background:
                                        theme.colorScheme.secondaryContainer,
                                    foreground:
                                        theme.colorScheme.onSecondaryContainer,
                                    // The failure above is what is announced.
                                    liveRegion: addressFailed == null,
                                    action: Wrap(
                                      alignment: WrapAlignment.end,
                                      spacing: 8,
                                      children: [
                                        // Once an address has failed, a
                                        // settings change retries that
                                        // address, not the link's own host.
                                        if (_headersFixOrigin(failure)
                                            case final origin?
                                            when addressFailed == null)
                                          TextButton(
                                            onPressed: () => _onFix(
                                              ConnectionFix.addHeaders,
                                              origin,
                                            ),
                                            child: Text(
                                              l10n.connectionAddHeaders,
                                            ),
                                          ),
                                        TextButton(
                                          onPressed: _controller.reset,
                                          child: Text(l10n.cancel),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                          key: _continueKey,
                          isConnecting: busy,
                          onContinue: _submit,
                        ),
                      ],
                      if (state case final ConnectServerConnecting connecting)
                        PopScope(
                          canPop: connecting.cancellable,
                          // The controller lives on while the screen slides
                          // out, and an answer then would still store the
                          // guest.
                          onPopInvokedWithResult: (didPop, _) {
                            if (didPop) _controller.cancel();
                          },
                          child: _ProgressLine(
                            _connectingText(l10n, connecting),
                          ),
                        )
                      else if (keeping != null)
                        _ProgressLine(
                          l10n.previousAppSigningIn(
                            displayHost(keeping.server),
                          ),
                          key: _keepingKey,
                          onCancel: ref
                              .read(previousAppProvider.notifier)
                              .cancelKeepingSession,
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy ? null : _tryDemo,
                        child: Text(l10n.connectTryDemo),
                      ),
                      TextButton.icon(
                        onPressed: busy
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
                      if (isConnecting && !storingGuest)
                        TextButton(
                          onPressed: _controller.cancel,
                          child: Text(l10n.connectCancel),
                        ),
                      // Signed in, the Account tab's version line opens it.
                      if (!widget.adding) ...[
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: busy
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
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const new(this.text, {this.onCancel, super.key});

  final String text;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (onCancel case final onCancel?)
            TextButton(
              onPressed: onCancel,
              child: Text(context.l10n.connectCancel),
            ),
        ],
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

/// Names both hosts, with their schemes where they would read alike.
String _claimedServerNote(
  AppLocalizations l10n, {
  required Uri linkBase,
  required Uri server,
}) {
  var link = displayHost(linkBase);
  var claiming = displayHost(server);
  if (link == claiming) {
    link = '${linkBase.scheme}://$link';
    claiming = '${server.scheme}://$claiming';
  }
  return l10n.guestServerClaimed(claiming, link);
}

/// Whether [input] is a server address without `http://` or `https://`,
/// which the app tries over https first (decision log: Connections).
bool typedWithoutScheme(String input) {
  if (parseLinkShareUrl(input) != null || parseInviteLink(input) != null) {
    return false;
  }
  try {
    return !normalizeServerAddress(input).hasExplicitScheme;
  } on InvalidServerAddress {
    return false;
  }
}

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
