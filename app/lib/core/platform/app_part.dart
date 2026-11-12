import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_part.g.dart';

/// The part of the app a container runs: the app itself, or a container the
/// OS started without it.
enum AppPart { app, backgroundRun, notificationAction, widgetAction }

@Riverpod(keepAlive: true)
AppPart appPart(Ref ref) => AppPart.app;
