import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// Overridden in tests that need a fixed "now".
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;
