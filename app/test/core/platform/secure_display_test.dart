import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';

import '../../helpers/app_lock_fakes.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
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

  test('a window that keeps itself out of captures never makes a secret '
      'hide', () async {
    var heard = 0;
    display
      ..addListener(() => heard++)
      ..hold();
    await pumpEventQueue();
    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(display.hidesSecrets, isFalse);
    expect(display.screenCaptured, isFalse);
    expect(window.changes, [true]);
    expect(heard, 0);
  });

  group('on a window that shows in captures', () {
    late _AnsweringWindow window;
    late SecureDisplay display;
    late int heard;

    setUp(() {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      window = _AnsweringWindow();
      display = SecureDisplay(window);
      addTearDown(display.dispose);
      heard = 0;
      display.addListener(() => heard++);
    });

    void lifecycle(List<AppLifecycleState> states) =>
        states.forEach(binding.handleAppLifecycleStateChanged);

    void leave() => lifecycle(const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);

    void comeBack() => lifecycle(const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);

    test('a secret hides until the window says the screen is not '
        'captured', () async {
      display.hold();
      expect(display.hidesSecrets, isTrue);
      expect(display.screenCaptured, isFalse);
      expect(heard, 0);

      window.answer(captured: false);
      await pumpEventQueue();

      expect(display.hidesSecrets, isFalse);
      expect(heard, 1);
    });

    test('a secret hides while the screen is captured and shows again '
        'after', () async {
      display.hold();
      window.answer(captured: true);
      await pumpEventQueue();
      expect(display.hidesSecrets, isTrue);
      expect(display.screenCaptured, isTrue);

      window.report(captured: false);
      await pumpEventQueue();
      expect(display.hidesSecrets, isFalse);
      expect(display.screenCaptured, isFalse);

      window.report(captured: true);
      await pumpEventQueue();
      expect(display.screenCaptured, isTrue);
      expect(heard, 3);
    });

    test('a change heard before the answer is older than it', () async {
      display.hold();
      window.report(captured: false);
      await pumpEventQueue();
      expect(display.hidesSecrets, isTrue);

      window.answer(captured: true);
      await pumpEventQueue();

      expect(display.screenCaptured, isTrue);
    });

    test('only the answer to the last change counts', () async {
      display.hold().release();
      display.hold();

      window.answer(captured: false);
      await pumpEventQueue();
      expect(display.hidesSecrets, isTrue);
      window
        ..answer(captured: false)
        ..answer(captured: true);
      await pumpEventQueue();

      expect(display.screenCaptured, isTrue);
    });

    test('nothing hides once the last hold is released', () async {
      final hold = display.hold();
      window.answer(captured: true);
      await pumpEventQueue();

      hold.release();
      window.report(captured: true);
      await pumpEventQueue();

      expect(display.hidesSecrets, isFalse);
      expect(display.screenCaptured, isFalse);
    });

    test('a window that cannot answer shows the secret rather than hide '
        'it for good', () async {
      display.hold();

      window.fail();
      await pumpEventQueue();

      expect(display.hidesSecrets, isFalse);
      expect(heard, 1);
    });

    // iOS snapshots the app for the app switcher once it has left, and a
    // capture may start while the app is away.
    test('a secret hides as soon as the app leaves, and shows again only '
        'once the window answered after the app is back', () async {
      display.hold();
      window.answer(captured: false);
      await pumpEventQueue();
      expect(display.hidesSecrets, isFalse);

      lifecycle(const [AppLifecycleState.inactive]);
      expect(display.hidesSecrets, isTrue);
      expect(display.screenCaptured, isFalse);
      expect(heard, 2);
      lifecycle(const [AppLifecycleState.hidden, AppLifecycleState.paused]);
      window.report(captured: false);
      await pumpEventQueue();
      expect(display.hidesSecrets, isTrue);

      comeBack();
      expect(window.calls, [true, true]);
      await pumpEventQueue();
      expect(display.hidesSecrets, isTrue);

      window.answer(captured: false);
      await pumpEventQueue();
      expect(display.hidesSecrets, isFalse);
      expect(heard, 3);
    });

    test('a capture that started while the app was away hides the secret '
        'once it is back', () async {
      display.hold();
      window.answer(captured: false);
      await pumpEventQueue();

      leave();
      comeBack();
      window.answer(captured: true);
      await pumpEventQueue();

      expect(display.hidesSecrets, isTrue);
      expect(display.screenCaptured, isTrue);
    });

    test('an answer that arrives while the app is away counts for '
        'nothing', () async {
      display.hold();
      lifecycle(const [AppLifecycleState.inactive]);

      window.answer(captured: false);
      await pumpEventQueue();
      expect(display.hidesSecrets, isTrue);
      expect(heard, 0);

      lifecycle(const [AppLifecycleState.resumed]);
      window.answer(captured: false);
      await pumpEventQueue();
      expect(display.hidesSecrets, isFalse);
    });

    test('the window is asked nothing when the app comes back without a '
        'secret on screen', () async {
      display.hold().release();
      window
        ..answer(captured: false)
        ..answer(captured: false);
      await pumpEventQueue();

      leave();
      comeBack();

      expect(window.calls, [true, false]);
      expect(heard, 0);
    });

    test('an answer after the display is gone tells no one', () async {
      final gone = SecureDisplay(window)
        ..addListener(() => heard++)
        ..hold()
        ..dispose();

      window.answer(captured: true);
      leave();
      comeBack();
      await pumpEventQueue();

      expect(gone.isSecure, isTrue);
      expect(heard, 0);
    });
  });
}

final class _RefusingWindow implements SecureWindow {
  @override
  Stream<bool>? get captures => null;

  @override
  Future<bool> setSecure(bool secure) async =>
      throw UnsupportedError('no window');
}

/// iOS's window, answering each change in order when told to; every call
/// in [calls].
final class _AnsweringWindow implements SecureWindow {
  final calls = <bool>[];
  final _answers = <Completer<bool>>[];
  final _captures = StreamController<bool>.broadcast();

  @override
  Stream<bool> get captures => _captures.stream;

  @override
  Future<bool> setSecure(bool secure) {
    calls.add(secure);
    final answer = Completer<bool>();
    _answers.add(answer);
    return answer.future;
  }

  void answer({required bool captured}) =>
      _answers.removeAt(0).complete(captured);

  void fail() => _answers
      .removeAt(0)
      .completeError(PlatformException(code: 'unavailable'));

  void report({required bool captured}) => _captures.add(captured);
}
