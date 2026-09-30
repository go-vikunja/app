import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';

part 'widget_refresher_provider.g.dart';

typedef WidgetRefresher = Future<void> Function();

/// Re-renders every placed widget instance with fresh data from the server.
///
/// Controllers call this after a successful task mutation so the home-screen
/// widget never shows a stale list. Injectable to keep controllers testable.
@riverpod
WidgetRefresher widgetRefresher(Ref ref) {
  return updateWidget;
}
