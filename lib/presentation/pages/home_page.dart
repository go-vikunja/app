import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:vikunja_app/presentation/pages/project/project_list_page.dart';
import 'package:vikunja_app/presentation/pages/settings_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  int _selectedDrawerIndex = 0, _previousDrawerIndex = 0;
  Widget? drawerItem;

  List<Widget> widgets = [TaskListPage(), ProjectListPage(), SettingsPage()];

  List<NavigationDestination> navbarItems = [
    NavigationDestination(icon: Icon(Icons.home), label: "Home"),
    NavigationDestination(icon: Icon(Icons.list), label: "Projects"),
    NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
  ];

  @override
  void initState() {
    super.initState();

    initNotifications();

    var settings = ref.read(settingsControllerProvider);
    settings.whenData((settings) {
      if (settings.versionNotifications) {
        postVersionCheckSnackbar();
      }
    });

    tz.initializeTimeZones();
  }

  Future<void> initNotifications() async {
    var notifGranted = await Permission.notification.isGranted;
    if (notifGranted) {
      NotificationHandler notificationClass = NotificationHandler();
      await notificationClass.initNotifications();
      ref.read(notificationProvider.notifier).set(notificationClass);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDrawerIndex != _previousDrawerIndex || drawerItem == null) {
      drawerItem = _getDrawerItemWidget(_selectedDrawerIndex);
    }

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        destinations: navbarItems,
        selectedIndex: _selectedDrawerIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedDrawerIndex = index;
          });
        },
      ),
      body: drawerItem,
    );
  }

  Widget _getDrawerItemWidget(int pos) {
    _previousDrawerIndex = pos;
    return widgets[pos];
  }

  Future<void> postVersionCheckSnackbar() async {
    var latestVersionTag = await ref
        .read(versionRepositoryProvider)
        .getLatestVersionTag();
    ref.read(versionRepositoryProvider).isUpToDate().then((value) {
      if (!value) {
        // not up to date
        SnackBar snackBar = SnackBar(
          content: Text("New version available: $latestVersionTag"),
          action: SnackBarAction(
            label: "View on Github",
            onPressed: () => launchUrl(
              Uri.parse(repo),
              mode: LaunchMode.externalApplication,
            ),
          ),
        );
        globalSnackbarKey.currentState?.showSnackBar(snackBar);
      }
    });
  }
}
