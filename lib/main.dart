import 'package:background_downloader/background_downloader.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart' show HomeWidget;
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:vikunja_app/core/di/theme_provider.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/init_page.dart';
import 'package:vikunja_app/presentation/pages/home_page.dart';
import 'package:vikunja_app/presentation/pages/login/login_page.dart';
import 'package:workmanager/workmanager.dart';

import 'core/background_work.dart';

final globalSnackbarKey = GlobalKey<ScaffoldMessengerState>();
final globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  var notifDenies = await Permission.notification.isDenied;
  if (notifDenies) {
    Permission.notification.request();
  }

  try {
    if (!kIsWeb) {
      FileDownloader().configureNotification(
        running: TaskNotification('Downloading', 'file: {filename}'),
        complete: TaskNotification('Download finished', 'file: {filename}'),
        tapOpensFile: true,
        progressBar: true,
      );
    }
  } catch (e) {
    print("Failed to initialize downloader: $e");
  }
  try {
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher);
    }
  } catch (e) {
    print("Failed to initialize workmanager: $e");
  }
  try {
    await HomeWidget.registerInteractivityCallback(widgetCallback);
    print('Registered background callback');
  } catch (e) {
    print('Failed to initialise widget Callback');
  }

  var sentryEnabled = await SettingsDatasource(
    FlutterSecureStorage(),
  ).getSentryEnabled();
  if (sentryEnabled) {
    await SentryFlutter.init((options) {
      options.dsn =
          'https://a09618e3bb30e03b93233c21973df869@o1047380.ingest.us.sentry.io/4507995557134336';
      options.addIntegration(LoggingIntegration());
      options.enableLogs = true;
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
    }, appRunner: () => runApp(ProviderScope(child: VikunjaApp())));
  } else {
    runApp(ProviderScope(child: VikunjaApp()));
  }
}

class VikunjaApp extends ConsumerWidget {
  const VikunjaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final currentAppTheme = themeState.asData?.value;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Vikunja',
          theme: currentAppTheme?.getTheme(lightDynamic),
          darkTheme: currentAppTheme?.getDarkTheme(darkDynamic),
          themeMode: currentAppTheme?.getThemeMode(),
          scaffoldMessengerKey: globalSnackbarKey,
          navigatorKey: globalNavigatorKey,
          initialRoute: '/',
          routes: {
            '/': (context) => const InitPage(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomePage(),
          },
        );
      },
    );
  }
}
