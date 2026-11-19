import 'dart:async';

/// `Timer.new`, injectable for tests.
typedef CreateTimer = Timer Function(
  Duration duration,
  void Function() callback,
);
