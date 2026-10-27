import 'package:vikunja_mobile/bootstrap/bootstrap.dart';

// Puts the library of the Android widget worker's entry point into the
// program; the worker starts it by library and name.
export 'package:vikunja_mobile/core/widgets/widget_entry_points.dart'
    show widgetActionsMain;

Future<void> main() => bootstrap();
