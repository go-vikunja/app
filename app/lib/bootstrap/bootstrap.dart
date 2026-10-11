import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';

final _log = Logger('Bootstrap');

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureLogging();
  final clientIdentity = await ClientIdentity.load();
  final container = ProviderContainer(
    overrides: [clientIdentityProvider.overrideWithValue(clientIdentity)],
  );
  try {
    // Behind the native launch screen, so the router starts on its first
    // real screen instead of animating it in over the empty splash route.
    final accounts = await container.read(accountsProvider.future);
    if (accounts.activeAccount case final entry?) {
      // The shell or the first-sync screen: decided by the stored sync state.
      await firstSyncStatus(
        container,
        entry.id,
      ).timeout(const Duration(seconds: 5));
    }
  } on Object catch (error) {
    _log.severe('Could not load the local state: ${error.runtimeType}');
  }
  runApp(
    UncontrolledProviderScope(container: container, child: const VikunjaApp()),
  );
}
