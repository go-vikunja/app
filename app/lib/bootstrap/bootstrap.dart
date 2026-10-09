import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureLogging();
  final clientIdentity = await ClientIdentity.load();
  runApp(
    ProviderScope(
      overrides: [clientIdentityProvider.overrideWithValue(clientIdentity)],
      child: const VikunjaApp(),
    ),
  );
}
