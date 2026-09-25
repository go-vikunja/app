import 'package:home_widget/home_widget.dart';

/// Read/write access to the shared data store the native home-screen widget
/// reads from, plus a trigger to re-render the widget.
///
/// This is the seam that keeps the widget update pipeline testable without a
/// device: production code passes a [HomeWidgetPluginStore], tests inject an
/// in-memory implementation.
abstract class HomeWidgetStore {
  Future<T?> read<T>(String key);

  Future<void> write(String key, Object? value);

  Future<void> rerenderWidget();
}

/// Production implementation backed by the home_widget plugin.
class HomeWidgetPluginStore implements HomeWidgetStore {
  const HomeWidgetPluginStore();

  @override
  Future<T?> read<T>(String key) => HomeWidget.getWidgetData<T>(key);

  @override
  Future<void> write(String key, Object? value) =>
      HomeWidget.saveWidgetData(key, value);

  @override
  Future<void> rerenderWidget() => HomeWidget.updateWidget(
    name: 'AppWidget',
    qualifiedAndroidName: 'io.vikunja.app.widget.AppWidgetReciever',
  );
}
