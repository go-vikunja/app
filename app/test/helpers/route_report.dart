import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The platform reporting the current route list back, as Android does when
/// the app is opened again: go_router rebuilds the list, and the futures of
/// earlier pushes never finish.
Future<void> reportRouteFromPlatform(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  final info = router.routeInformationParser.restoreRouteInformation(
    router.routerDelegate.currentConfiguration,
  )!;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {
        'location': info.uri.toString(),
        'state': info.state,
      }),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}
