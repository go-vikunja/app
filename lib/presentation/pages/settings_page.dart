import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/login/login_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return SettingsPageState();
  }
}

class SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController durationTextController = TextEditingController();

  String newestVersionTag = "";

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: settings.when(
        data: (settings) => ListView(
          children: [
            _buildUserHeader(ref, settings.user, settings.projects, context),
            Divider(),
            ListTile(
              title: Text("Theme"),
              trailing: DropdownButton<FlutterThemeMode>(
                items: [
                  DropdownMenuItem(
                    value: FlutterThemeMode.system,
                    child: Text("System"),
                  ),
                  DropdownMenuItem(
                    value: FlutterThemeMode.light,
                    child: Text("Light"),
                  ),
                  DropdownMenuItem(
                    value: FlutterThemeMode.dark,
                    child: Text("Dark"),
                  ),
                ],
                value: settings.themeMode,
                onChanged: (FlutterThemeMode? value) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .setThemeMode(value ?? FlutterThemeMode.system);
                },
              ),
            ),
            SwitchListTile(
              title: Text("Dynamic Colors"),
              value: settings.dynamicColors,
              onChanged: (bool? value) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setDynamicColors(value ?? false);
              },
            ),
            Divider(),
            CheckboxListTile(
              title: Text("Ignore Certificates"),
              value: settings.ignoreCertificates,
              onChanged: (value) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setIgnoreCertificates(value ?? false);
              },
            ),
            Divider(),
            CheckboxListTile(
              title: Text("Enable Sentry"),
              subtitle: Text(
                "Help us debug errors better and faster by sending bug reports to us directly. This is completely anonymous.",
              ),
              value: settings.sentryEnabled,
              onChanged: (value) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setSentryEnabled(value ?? false);
              },
            ),
            Divider(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Flexible(
                    child: TextField(
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      controller: durationTextController,
                      decoration: InputDecoration(
                        labelText: 'Background Refresh Interval (minutes): ',
                        helperText:
                            'Minimum: 15, Set limit of 0 for no refresh',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setRefreshInterval(
                            int.tryParse(durationTextController.value.text) ??
                                0,
                          );
                    },
                    child: Text("Save"),
                  ),
                ],
              ),
            ),
            Divider(),
            CheckboxListTile(
              title: Text("Get Version Notifications"),
              value: settings.versionNotifications,
              onChanged: (value) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setVersionNotifications(value ?? false);
              },
            ),
            TextButton(
              onPressed: () async {
                var notifGranted = await Permission.notification.isGranted;
                if (notifGranted) {
                  ref.read(notificationProvider)?.sendTestNotification();
                } else {
                  var status = await Permission.notification.request();
                  if (status.isGranted) {
                    ref.read(notificationProvider)?.sendTestNotification();
                  } else if (status.isPermanentlyDenied) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("No notification permission!")),
                    );
                  }
                }
              },
              child: Text("Send test notification"),
            ),
            TextButton(
              onPressed: () async {
                var newestVersion = await ref
                    .read(versionRepositoryProvider)
                    .getLatestVersionTag();
                setState(() {
                  newestVersion = newestVersion;
                });
              },
              child: Text("Check for latest version"),
            ),
            Text(
              settings.currentVersion.isNotEmpty
                  ? "Current version: ${settings.currentVersion}"
                  : "Current version: -",
            ),
            Text(
              newestVersionTag.isNotEmpty
                  ? "Latest version: $newestVersionTag"
                  : "",
            ),
            Divider(),
            TextButton(
              onPressed: () {
                ref.read(settingsRepositoryProvider).saveServer(null);
                ref.read(settingsRepositoryProvider).saveUserToken(null);

                Navigator.of(context).popUntil((route) => route.isFirst);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (buildContext) => LoginPage()),
                );
              },
              child: Text("Logout"),
            ),
          ],
        ),
        error: (err, _) => VikunjaErrorWidget(error: err),
        loading: () => const LoadingWidget(),
      ),
    );
  }

  Widget _buildUserHeader(
    WidgetRef ref,
    User user,
    List<Project> projects,
    BuildContext context,
  ) {
    return Column(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text(
            user.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          accountEmail: Text(
            user.username,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          currentAccountPicture: CircleAvatar(
            backgroundImage: user.username != ""
                ? NetworkImage(
                    user.avatarUrl(ref.read(clientProviderProvider).base),
                    headers: ref.read(clientProviderProvider).headers,
                  )
                : null,
          ),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/graphics/hypnotize.png"),
              repeat: ImageRepeat.repeat,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.secondaryContainer,
                BlendMode.multiply,
              ),
            ),
          ),
        ),
        ListTile(
          title: Text("Default List"),
          trailing: DropdownButton<int>(
            items: [
              DropdownMenuItem(value: 0, child: Text("None")),
              ...projects.map(
                (e) => DropdownMenuItem(value: e.id, child: Text(e.title)),
              ),
            ],
            value:
                projects.firstWhereOrNull(
                      (element) =>
                          element.id == user.settings?.default_project_id,
                    ) !=
                    null
                ? user.settings?.default_project_id
                : 0,
            onChanged: (int? value) {
              if (value != null && user.settings != null) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setDefaultProject(value);
              }
            },
          ),
        ),
      ],
    );
  }
}
