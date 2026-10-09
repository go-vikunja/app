import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/onboarding/application/browser_sign_in.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/legal_links.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/motd_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/overview_actions.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_features_section.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_header.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/sign_in_methods_section.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/support_status_card.dart';

class ServerOverviewScreen extends ConsumerWidget {
  const new({super.key});

  static const _shortViewportHeight = 480.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(currentServerProvider);
    // Briefly null while this route animates out after the server was reset.
    if (connection == null) return const Scaffold();

    final l10n = context.l10n;
    final isSupported = connection.capabilities.isSupported;
    final browserSignIn = browserSignInFor(connection);
    final motd = connection.info.motd.trim();
    final legal = connection.info.legal;
    // On short screens (landscape phones) a pinned bar would leave only a
    // strip for the content, so the actions scroll with it instead.
    final pinActions =
        MediaQuery.sizeOf(context).height >= _shortViewportHeight;
    final actions = OverviewActions(
      canSignIn: browserSignIn != null,
      onContinue: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.signInComingSoon))),
      onUseDifferentServer: () => context.go(AppRoutes.connect),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.overviewTitle)),
      body: SafeArea(
        top: false,
        bottom: !pinActions,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ServerHeader(connection: connection),
            const SizedBox(height: 20),
            SupportStatusCard(connection: connection),
            if (motd.isNotEmpty) ...[
              const SizedBox(height: 16),
              MotdCard(message: motd),
            ],
            if (browserSignIn != null) ...[
              const SizedBox(height: 24),
              SignInMethodsSection(browserSignIn: browserSignIn),
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
      bottomNavigationBar: pinActions
          ? Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: actions,
              ),
            )
          : null,
    );
  }
}
