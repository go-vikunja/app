import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';

import '../../helpers/app_lock_fakes.dart';

void main() {
  late FakeSecureWindow window;
  late SecureDisplay display;

  setUp(() {
    window = FakeSecureWindow();
    display = SecureDisplay(window);
  });

  test('a hold secures the window until it is released', () {
    final hold = display.hold();
    expect(window.secure, isTrue);

    hold.release();

    expect(window.secure, isFalse);
    expect(window.changes, [true, false]);
  });

  test('the window stays secure until the last hold is released', () {
    final first = display.hold();
    final second = display.hold();

    first.release();
    expect(window.secure, isTrue);
    second.release();

    expect(window.secure, isFalse);
    expect(window.changes, [true, false]);
  });

  test('releasing a hold twice counts once', () {
    final first = display.hold();
    display.hold();

    first
      ..release()
      ..release();

    expect(display.isSecure, isTrue);
    expect(window.secure, isTrue);
  });

  test('a released hold keeps the window secure while always is on', () {
    display.setAlways(true);
    display.hold().release();

    expect(window.secure, isTrue);
    expect(window.changes, [true]);
  });

  test('turning always off keeps the window secure while a hold is '
      'unreleased', () {
    final hold = display.hold();
    display
      ..setAlways(true)
      ..setAlways(false);
    expect(window.secure, isTrue);

    hold.release();

    expect(window.secure, isFalse);
    expect(window.changes, [true, false]);
  });

  test('a window that refuses the flag fails no caller', () async {
    final refusing = SecureDisplay(_RefusingWindow());

    refusing.hold().release();
    await pumpEventQueue();

    expect(refusing.isSecure, isFalse);
  });
}

final class _RefusingWindow implements SecureWindow {
  @override
  Future<void> setSecure(bool secure) async =>
      throw UnsupportedError('no window');
}
