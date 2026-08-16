import 'dart:developer' as developer;

import 'package:background_downloader/background_downloader.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart' show HomeWidget;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/core/di/theme_provider.dart';
import 'package:vikunja_app/core/network/sentry_network_filter.dart';
import 'package:vikunja_app/core/di/locale_provider.dart';
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

  // Shared settings datasource for reading app settings
  final settingsDatasource = SettingsDatasource(FlutterSecureStorage());

  try {
    if (!kIsWeb) {
      final overrideCode = await settingsDatasource.getLocaleOverride();
      final effectiveLocale = (overrideCode != null && overrideCode.isNotEmpty)
          ? Locale(overrideCode)
          : WidgetsBinding.instance.platformDispatcher.locale;
      final loc = await AppLocalizations.delegate.load(effectiveLocale);
      FileDownloader().configureNotification(
        running: TaskNotification(loc.downloading, '${loc.file}: {filename}'),
        complete: TaskNotification(
          loc.downloadFinished,
          '${loc.file}: {filename}',
        ),
        tapOpensFile: true,
        progressBar: true,
      );
    }
  } catch (e) {
    developer.log("Failed to initialize downloader: $e");
  }
  try {
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher);
    }
  } catch (e) {
    developer.log("Failed to initialize workmanager: $e");
  }
  try {
    await HomeWidget.registerInteractivityCallback(widgetCallback);
    developer.log('Registered background callback');
  } catch (e) {
    developer.log('Failed to initialise widget Callback');
  }

  var sentryEnabled = await settingsDatasource.getSentryEnabled();
  if (sentryEnabled) {
    await SentryFlutter.init((options) {
      options.dsn =
          'https://a09618e3bb30e03b93233c21973df869@o1047380.ingest.us.sentry.io/4507995557134336';
      options.addIntegration(LoggingIntegration());
      options.enableLogs = true;
      options.tracesSampleRate = 1.0;
      // ignore: experimental_member_use
      options.profilesSampleRate = 1.0;
      // Drop expected transient network-connectivity failures (device offline,
      // host unreachable, DNS/timeout/connection-reset). ok_http surfaces these
      // as ClientExceptions wrapping OkHttp/Java IOExceptions; this restores the
      // noise filtering the cronet_http client had for Chromium net::ERR_ codes.
      options.beforeSend = (event, hint) {
        if (isIgnoredNetworkError(event.throwable)) return null;
        return event;
      };
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
        final localeState = ref.watch(localeOverrideProvider);
        final overrideLocale = localeState.asData?.value;
        return MaterialApp(
          title: 'Vikunja',
          theme: currentAppTheme?.getTheme(lightDynamic),
          darkTheme: currentAppTheme?.getDarkTheme(darkDynamic),
          themeMode: currentAppTheme?.getThemeMode(),
          scaffoldMessengerKey: globalSnackbarKey,
          navigatorKey: globalNavigatorKey,
          // When overrideLocale is null, Flutter falls back to system locale.
          locale: overrideLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          initialRoute: '/',
          routes: {
            '/': (context) => const InitPage(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const HomePage(),
          },
          builder: (context, child) {
            final locale = Localizations.localeOf(context);
            Intl.defaultLocale = locale.toString();
            initializeDateFormatting(locale.toString());
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
