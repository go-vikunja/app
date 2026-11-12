import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/external_link.dart';
import 'package:vikunja_mobile/features/common/presentation/motion.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/connection/presentation/browser_leg_hint.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_settings_action.dart';
import 'package:vikunja_mobile/features/onboarding/application/browser_sign_in_method.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/application/web_auth_pages.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/legal_links.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/motd_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/overview_actions.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_features_section.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_header.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/sign_in_methods_section.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/support_status_card.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_failure_message.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

class ServerOverviewScreen extends ConsumerStatefulWidget {
  const new({this.adding = false, super.key});

  /// Pushed over the connect screen of another account, which "Use a
  /// different server" returns to.
  final bool adding;

  @override
  ConsumerState<ServerOverviewScreen> createState() =>
      _ServerOverviewScreenState();
}

class _ServerOverviewScreenState extends ConsumerState<ServerOverviewScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSignInChanged(SignInState? previous, SignInState next) {
    switch (next) {
      case SignInSucceeded(:final isNewAccount, :final wasActive):
        if (!isNewAccount) {
          final l10n = context.l10n;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  wasActive
                      ? l10n.addAccountAlreadyActive
                      : l10n.addAccountAlreadyAdded,
                ),
              ),
            );
        }
        // The router sends an account that has not synced yet on to its
        // first sync.
        context.go(AppRoutes.home);
      case SignInFailed():
        unawaited(HapticFeedback.heavyImpact());
        // The error card is the first item of the list.
        if (_scrollController.hasClients) {
          if (reduceMotionOf(context)) {
            _scrollController.jumpTo(0);
          } else {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        }
      case SignInIdle() || SignInSettling() || SignInInProgress():
        break;
    }
  }

  void _continueToSignIn(ServerConnection connection) => unawaited(
    ref
        .read(signInControllerProvider.notifier)
        .signIn(connection, confirm: browserLegConfirmation(context, ref)),
  );

  // The web's login page links to its registration form and comes back
  // here once the account exists. A sign-in page on another host and what
  // the browser meets despite the connection settings go into the same
  // question.
  void _createAccount(ServerConnection connection) {
    final l10n = context.l10n;
    final profiles = ref.read(networkProfilesProvider);
    Future<bool> confirm(BrowserLeg leg) async {
      final otherHost = leg.otherHost;
      final hint = await browserLegHint(
        l10n,
        profiles,
        leg.connection,
        sayOtherHost: otherHost == null,
      );
      if (!mounted) return false;
      return await confirmAdaptive(
        context,
        title: l10n.overviewCreateAccount,
        body: [
          if (otherHost != null) otherSignInHostWarning(l10n, otherHost),
          l10n.overviewCreateAccountHint,
          if (hint != null) hint.asText(l10n),
        ].join('\n\n'),
        confirmLabel: l10n.continueToSignIn,
      );
    }

    unawaited(
      ref
          .read(signInControllerProvider.notifier)
          .signIn(connection, confirm: confirm),
    );
  }

  void _dropSettling() {
    if (ref.read(signInControllerProvider) is SignInSettling) {
      ref.read(signInControllerProvider.notifier).reset();
    }
  }

  void _openPasswordReset(ServerConnection connection) => unawaited(
    openExternalOrSay(context, ref, passwordResetPageUri(connection)),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(signInControllerProvider, _onSignInChanged);
    final connection = ref.watch(currentServerProvider);
    // Briefly null while this route animates out after the server was reset.
    if (connection == null) return const Scaffold();

    final signIn = ref.watch(signInControllerProvider);
    final isSigningIn = signIn is SignInInProgress;
    final isSettling = signIn is SignInSettling;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isSupported = connection.capabilities.isSupported;
    final signInMethod = browserSignInMethodFor(connection);
    final motd = connection.info.motd.trim();
    final legal = connection.info.legal;
    // On short screens (landscape phones), or with text so large that the
    // buttons grow as tall, a pinned bar would leave only a strip for the
    // content, so the actions scroll with it instead.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final pinActions =
        MediaQuery.sizeOf(context).height >=
        WindowLayout.mediumHeightFrom * math.max(1, textScale);
    final actions = OverviewActions(
      canSignIn: signInMethod != null,
      isSigningIn: isSigningIn,
      isSettling: isSettling,
      onContinue: () => _continueToSignIn(connection),
      onUseDifferentServer: () {
        _dropSettling();
        widget.adding ? context.pop() : context.go(AppRoutes.connect);
      },
      onCreateAccount: signInMethod?.offersRegistration ?? false
          ? () => _createAccount(connection)
          : null,
      onForgotPassword: signInMethod?.offersPasswordReset ?? false
          ? () => _openPasswordReset(connection)
          : null,
      registrationNeedsInvitation:
          signInMethod?.registrationNeedsInvitation ?? false,
    );

    // Once the browser has returned, the code is being exchanged and the
    // account stored; leaving now would strand a half-finished sign-in.
    // The wait for an earlier sign-out before the browser opens may be
    // left, which drops the sign-in.
    return PopScope(
      canPop: !isSigningIn,
      // Over the shell, which keeps the sign-in state alive, a failure here
      // would otherwise show up on the active account's Account tab. Only
      // a failure: the router also pops this page, during a build, once a
      // sign-in has succeeded.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _dropSettling();
        if (widget.adding &&
            ref.read(signInControllerProvider) is SignInFailed) {
          ref.read(signInControllerProvider.notifier).reset();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // Shown disabled rather than hidden, so the title does not jump and
          // the arrow does not look like it works.
          leading: isSigningIn
              ? IconButton(
                  onPressed: null,
                  icon: const BackButtonIcon(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                )
              : null,
          title: ScreenTitle(l10n.overviewTitle),
        ),
        body: SafeArea(
          top: false,
          bottom: !pinActions,
          child: ReadableWidth.builder(
            maxWidth: ReadableWidth.form,
            builder: (_, _, inset) => ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16 + inset, 8, 16 + inset, 24),
              children: [
                if (signIn case SignInFailed(
                  :final error,
                  :final serverRoot,
                )) ...[
                  ConnectionErrorCard(
                    message: describeSignInFailure(
                      l10n,
                      error,
                      serverRoot: serverRoot,
                      platform: theme.platform,
                    ),
                    action: ConnectionSettingsAction.appliesTo(error)
                        ? ConnectionSettingsAction(
                            error: error,
                            serverRoot: serverRoot,
                            foreground: theme.colorScheme.onErrorContainer,
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],
                ServerHeader(connection: connection),
                const SizedBox(height: 20),
                SupportStatusCard(connection: connection),
                if (motd.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  MotdCard(message: motd),
                ],
                if (signInMethod != null) ...[
                  const SizedBox(height: 24),
                  SignInMethodsSection(method: signInMethod),
                ],
                if (isSupported) ...[
                  const SizedBox(height: 24),
                  ServerFeaturesSection(connection: connection),
                ],
                if (LegalLinksRow.hasAny(legal)) ...[
                  const SizedBox(height: 16),
                  LegalLinksRow(links: legal),
                ],
                if (!pinActions) ...[const SizedBox(height: 24), actions],
              ],
            ),
          ),
        ),
        bottomNavigationBar: pinActions
            ? Material(
                color: theme.colorScheme.surfaceContainer,
                child: ReadableWidth(
                  maxWidth: ReadableWidth.form,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: actions,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
