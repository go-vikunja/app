import 'dart:async';
import 'package:home_widget/home_widget.dart';

Future<void> registerHomeWidgetCallback(FutureOr<void> Function(Uri?) callback) async {
  await HomeWidget.registerInteractivityCallback(callback);
}

Future<void> saveHomeWidgetData(String key, String value) async {
  await HomeWidget.saveWidgetData(key, value);
}

Future<void> updateHomeWidget({required String name, required String qualifiedAndroidName}) async {
  await HomeWidget.updateWidget(name: name, qualifiedAndroidName: qualifiedAndroidName);
}
