import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:vikunja_app/presentation/manager/theme_model.dart';
import 'package:vikunja_app/presentation/pages/home.dart';
import 'package:vikunja_app/presentation/pages/login/login.dart';
import 'package:workmanager/workmanager.dart';

class IgnoreCertHttpOverrides extends HttpOverrides {
  bool ignoreCerts = false;

  IgnoreCertHttpOverrides(bool _ignore) {
    ignoreCerts = _ignore;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => ignoreCerts;
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  if (kIsWeb) {
    return;
  }
  Workmanager().executeTask((task, inputData) async {
    print(
        "Native called background task: $task"); //simpleTask will be emitted here.
    if (task == "update-tasks" && inputData != null) {
      Client client = Client(null,
          token: inputData["client_token"], base: inputData["client_base"]);
      tz.initializeTimeZones();
      var datasource = SettingsDatasource(FlutterSecureStorage());
      var ignoreCertificates = await datasource.getIgnoreCertificates();

      print("ignoring: $ignoreCertificates");
      client.reloadIgnoreCerts(ignoreCertificates);

      TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));
      NotificationClass nc = NotificationClass();
      await nc.notificationInitializer();
      return nc
          .scheduleDueNotifications(taskService)
          .then((value) => Future.value(true));
    } else if (task == "refresh-token") {
      final FlutterSecureStorage _storage = new FlutterSecureStorage();

      var currentUser = await _storage.read(key: 'currentUser');
      if (currentUser == null) {
        return Future.value(true);
      }
      var token = await _storage.read(key: currentUser);

      var base = await _storage.read(key: '${currentUser}_base');
      if (token == null || base == null) {
        return Future.value(true);
      }
      Client client = Client(null);
      client.configure(token: token, baseUrl: base);
      // load new token from server to avoid expiration
      String? newToken = await UserDataSource(client).getToken();
      if (newToken != null) {
        _storage.write(key: currentUser, value: newToken);
      }
      return Future.value(true);
    } else {
      return Future.value(true);
    }
  });
}

final globalSnackbarKey = GlobalKey<ScaffoldMessengerState>();
final globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });
  try {
    if (!kIsWeb) {
      await FlutterDownloader.initialize();
    }
  } catch (e) {
    print("Failed to initialize downloader: $e");
  }
  try {
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    }
  } catch (e) {
    print("Failed to initialize workmanager: $e");
  }
  runApp(ProviderScope(
    child: VikunjaGlobal(
      child: new VikunjaApp(
        home: HomePage(),
        key: UniqueKey(),
        navkey: globalNavigatorKey,
      ),
      login: new VikunjaApp(
        home: LoginPage(),
        key: UniqueKey(),
      ),
    ),
  ));
}

ThemeModel themeModel = ThemeModel();

class VikunjaApp extends ConsumerWidget {
  final Widget home;
  final GlobalKey<NavigatorState>? navkey;
  bool sentyInitialized = false;

  VikunjaApp({Key? key, required this.home, this.navkey}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var settings = ref.watch(settingsControllerProvider);

    return settings.when(
        data: (settings) =>
            DynamicColorBuilder(builder: (lightTheme, darkTheme) {
              themeModel.themeMode = settings.themeMode;
              themeModel.dynamicColors = settings.dynamicColors;

              if (settings.sentryEnabled) {
                if (!sentyInitialized) {
                  sentyInitialized = true;
                  print("sentry enabled");
                  SentryFlutter.init((options) {
                    options.dsn =
                        'https://a09618e3bb30e03b93233c21973df869@o1047380.ingest.us.sentry.io/4507995557134336';
                    options.tracesSampleRate = 1.0;
                    options.profilesSampleRate = 1.0;
                  }).then((_) {
                    FlutterError.onError = (details) async {
                      print("sending to sentry");
                      await Sentry.captureException(
                        details.exception,
                        stackTrace: details.stack,
                      );
                      FlutterError.presentError(details);
                    };
                    PlatformDispatcher.instance.onError = (error, stack) {
                      print("sending to sentry (platform)");
                      Sentry.captureException(error, stackTrace: stack);
                      FlutterError.presentError(
                          FlutterErrorDetails(exception: error, stack: stack));
                      return false;
                    };
                  });
                }

                return SentryWidget(
                    child: buildMaterialApp(lightTheme, darkTheme));
              } else {
                sentyInitialized = false;
              }

              return buildMaterialApp(lightTheme, darkTheme);
            }),
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()));
  }

  Widget buildMaterialApp(ColorScheme? lightTheme, ColorScheme? darkTheme) {
    return MaterialApp(
      title: 'Vikunja',
      theme: themeModel.getTheme(lightTheme, darkTheme),
      darkTheme: themeModel.getDarkTheme(darkTheme),
      scaffoldMessengerKey: globalSnackbarKey,
      navigatorKey: navkey,
      // <= this
      home: this.home,
    );
  }
}
