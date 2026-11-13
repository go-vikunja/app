import 'package:flutter/services.dart';

/// `MainActivity`'s channel, and on iOS the `AppDelegate`'s, registered
/// only on the UI engine.
const deviceChannel = MethodChannel('io.vikunja.app/device');
