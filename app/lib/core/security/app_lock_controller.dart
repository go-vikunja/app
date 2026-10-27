import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/platform/recents_screenshots.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'app_lock_controller.g.dart';

final _log = Logger('AppLock');

enum AppLockError {
  /// Too many failed attempts; the system offers the screen lock when it
  /// can.
  lockedOut,

  /// An earlier prompt that never answered still holds the system's
  /// prompt, until the app is closed completely.
  promptStuck,
  unavailable,
}

enum AppLockNotice {
  /// The device lost its screen lock, so the app lock was turned off.
  turnedOffWithoutScreenLock,
}

@immutable
final class AppLockState {
  const new({
    this.enabled = false,
    this.locked = false,
    this.authenticating = false,
    this.covered = false,
    this.error,
    this.notice,
  });

  /// The lock is on: in the settings, or because they could not be read.
  final bool enabled;
  final bool locked;

  /// The system prompt is up.
  final bool authenticating;

  /// The privacy cover for the app switcher, while the app is inactive.
  final bool covered;

  /// Of the last unlock attempt.
  final AppLockError? error;

  /// Shown once, then dismissed through [AppLockController.dismissNotice].
  final AppLockNotice? notice;

  static const _unchanged = Object();

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    bool? authenticating,
    bool? covered,
    Object? error = _unchanged,
    Object? notice = _unchanged,
  }) => AppLockState(
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    authenticating: authenticating ?? this.authenticating,
    covered: covered ?? this.covered,
    error: identical(error, _unchanged) ? this.error : error as AppLockError?,
    notice: identical(notice, _unchanged)
        ? this.notice
        : notice as AppLockNotice?,
  );

  @override
  bool operator ==(Object other) =>
      other is AppLockState &&
      other.enabled == enabled &&
      other.locked == locked &&
      other.authenticating == authenticating &&
      other.covered == covered &&
      other.error == error &&
      other.notice == notice;

  @override
  int get hashCode =>
      Object.hash(enabled, locked, authenticating, covered, error, notice);

  @override
  String toString() =>
      'AppLockState(enabled: $enabled, locked: $locked, '
      'authenticating: $authenticating, covered: $covered, error: $error, '
      'notice: $notice)';
}

/// The app lock: a gate over the UI, not encryption. Locked on every cold
/// start while it is on, and again when the app was out of sight for the
/// chosen time (wall clock, so deep sleep counts). Bootstrap listens.
@Riverpod(keepAlive: true)
class AppLockController extends _$AppLockController {
  /// How long the app stays in front before it prompts on its own: Android
  /// drops a prompt that reaches it after the activity saved its state,
  /// without ever answering.
  static const promptSettle = Duration(milliseconds: 300);

  /// How long after the return from a prompt that hid the app its answer
  /// may still come (the PIN screen's comes just after the resume); a
  /// prompt silent for longer counts as cancelled.
  static const answerGrace = Duration(seconds: 2);

  /// A return this soon after a prompt ended unsuccessfully out of sight is
  /// part of that prompt (its PIN screen) and does not prompt again.
  static const _promptLoopWindow = Duration(seconds: 3);

  late DateTime Function() _now;
  late AppExcursions _excursions;
  LockAfter _lockAfter = const PrivacySettings().lockAfter;
  var _settingsKnown = false;
  var _visible = true;
  DateTime? _hiddenAt;
  var _authenticating = false;

  /// The first hide while the prompt runs, and the last show after it.
  DateTime? _hiddenDuringPromptAt;
  DateTime? _shownDuringPromptAt;

  /// Ends the running prompt as cancelled when it never answers.
  Completer<DeviceAuthResult>? _giveUp;
  Timer? _answerGraceTimer;
  DateTime? _promptEndedOutOfSightAt;
  Timer? _settleTimer;

  /// The next show of a locked app prompts once.
  var _promptOnShow = false;

  /// The next resume prompts once.
  var _promptPending = false;

  @override
  AppLockState build() {
    _now = ref.watch(clockProvider);
    _excursions = ref.watch(appExcursionsProvider);
    final lifecycle = AppLifecycleListener(
      onInactive: _onInactive,
      onHide: _onHide,
      onShow: _onShow,
      onResume: _onResume,
    );
    ref.onDispose(() {
      lifecycle.dispose();
      _settleTimer?.cancel();
      _answerGraceTimer?.cancel();
    });
    final excursionEnds = _excursions.ended.listen(_onExcursionEnded);
    ref.onDispose(excursionEnds.cancel);
    ref.listen(privacySettingsControllerProvider, (_, next) {
      if (next.value case final stored?) _onSettings(stored);
    });
    _visible = switch (WidgetsBinding.instance.lifecycleState) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      _ => false,
    };
    _hiddenAt = null;
    _authenticating = false;
    _hiddenDuringPromptAt = null;
    _shownDuringPromptAt = null;
    _promptEndedOutOfSightAt = null;
    _promptOnShow = false;
    if (ref.read(privacySettingsControllerProvider).value case final stored?) {
      _settingsKnown = true;
      _lockAfter = stored.settings.lockAfter;
      final enabled = stored.effective.appLock;
      _promptPending = enabled;
      if (enabled) _promptWhenSettled();
      return AppLockState(enabled: enabled, locked: enabled);
    }
    // Locked until the settings say otherwise.
    _settingsKnown = false;
    _promptPending = false;
    return const AppLockState(enabled: true, locked: true);
  }

  /// Whether the UI must wait, with the time out of sight evaluated now:
  /// a link or a notification tap can arrive before the app's show event.
  bool isLockedNow() {
    if (!_visible && !_authenticating) _lockIfDue();
    return state.locked;
  }

  /// Runs [action] without locking when the app goes out of sight for it,
  /// up to [AppExcursions.cap]. Nested and overlapping calls count.
  Future<T> excursion<T>(Future<T> Function() action) =>
      _excursions.run(action);

  /// Prompts for the device's screen lock or biometrics. A device that no
  /// longer has a screen lock turns the app lock off, with a notice.
  Future<void> unlock() async {
    if (!state.locked || _authenticating) return;
    final l10n = ref.read(deviceAppLocalizationsProvider);
    final result = await _authenticate(
      DeviceAuthPrompt.forReason(l10n, l10n.appLockPromptReason),
    );
    if (!ref.mounted) return;
    switch (result) {
      case DeviceAuthResult.success:
        _promptPending = false;
        state = state.copyWith(locked: false, covered: false, error: null);
      case DeviceAuthResult.cancelled:
        break;
      case DeviceAuthResult.lockedOut:
        state = state.copyWith(error: AppLockError.lockedOut);
      case DeviceAuthResult.inProgress:
        state = state.copyWith(error: AppLockError.promptStuck);
      case DeviceAuthResult.unavailable:
        state = state.copyWith(error: AppLockError.unavailable);
      case DeviceAuthResult.noCredentials:
        // Removing the screen lock takes the device credential, so this
        // helps no attacker; failing closed would strand the owner.
        await _storeAppLock(enabled: false);
        if (!ref.mounted) return;
        _promptPending = false;
        state = state.copyWith(
          enabled: false,
          locked: false,
          covered: false,
          error: null,
          notice: AppLockNotice.turnedOffWithoutScreenLock,
        );
    }
  }

  /// Turns the lock on or off once the device's screen lock or biometrics
  /// confirm it; off also when the device has no screen lock any more.
  /// Throws when the settings cannot be stored.
  Future<DeviceAuthResult> setAppLock({
    required bool enabled,
    required DeviceAuthPrompt prompt,
  }) async {
    if (_authenticating) return DeviceAuthResult.cancelled;
    final result = await _authenticate(prompt);
    if (!ref.mounted) return result;
    if (result == DeviceAuthResult.success ||
        (!enabled && result == DeviceAuthResult.noCredentials)) {
      await ref
          .read(privacySettingsControllerProvider.notifier)
          .change((settings) => settings.copyWith(appLock: enabled));
    }
    return result;
  }

  void dismissNotice() {
    if (state.notice != null) state = state.copyWith(notice: null);
  }

  void _onSettings(StoredPrivacySettings stored) {
    _lockAfter = stored.settings.lockAfter;
    final enabled = stored.effective.appLock;
    if (!_settingsKnown) {
      _settingsKnown = true;
      if (!enabled) {
        state = state.copyWith(
          enabled: false,
          locked: false,
          covered: false,
          error: null,
        );
        return;
      }
      state = state.copyWith(enabled: true);
      if (state.locked) {
        _promptPending = true;
        _scheduleAutoPrompt();
      }
      return;
    }
    if (enabled == state.enabled) return;
    // Turned on right after a successful prompt: unlocked until the next
    // hide.
    state = enabled
        ? state.copyWith(enabled: true)
        : state.copyWith(
            enabled: false,
            locked: false,
            covered: false,
            error: null,
          );
  }

  Future<DeviceAuthResult> _authenticate(DeviceAuthPrompt prompt) async {
    _authenticating = true;
    _hiddenDuringPromptAt = null;
    _shownDuringPromptAt = null;
    final giveUp = _giveUp = Completer<DeviceAuthResult>();
    state = state.copyWith(authenticating: true, covered: false, error: null);
    DeviceAuthResult result;
    try {
      result = await Future.any([
        ref.read(deviceAuthenticatorProvider).authenticate(prompt),
        giveUp.future,
      ]);
    } on Object catch (error) {
      _log.warning('Authentication failed: ${error.runtimeType}');
      result = DeviceAuthResult.unavailable;
    }
    _answerGraceTimer?.cancel();
    _answerGraceTimer = null;
    _giveUp = null;
    _authenticating = false;
    final hiddenAt = _hiddenDuringPromptAt;
    final shownAt = _shownDuringPromptAt;
    _hiddenDuringPromptAt = null;
    _shownDuringPromptAt = null;
    if (!ref.mounted) return result;
    state = state.copyWith(authenticating: false);
    // The system's PIN screen hides the app below Android 11, so after a
    // success the time out of sight was the prompt's.
    if (hiddenAt != null && result != DeviceAuthResult.success) {
      _afterPromptOutOfSight(hiddenAt, shownAt);
    }
    return result;
  }

  /// The app went out of sight during a prompt that then failed: that time
  /// counts like any other from the first hide, but locking for it does not
  /// prompt at once, so a cancelled prompt cannot bring itself back.
  void _afterPromptOutOfSight(DateTime hiddenAt, DateTime? shownAt) {
    if (!_visible) {
      _hiddenAt = hiddenAt;
      _promptOnShow = true;
      _promptEndedOutOfSightAt = _now();
      _lockIfDue();
      return;
    }
    final elapsed = (shownAt ?? _now()).difference(hiddenAt);
    if (state.enabled &&
        !state.locked &&
        (elapsed.isNegative || elapsed >= _lockAfter.duration)) {
      state = state.copyWith(locked: true, error: null);
    }
  }

  /// Back in front from a prompt that hid the app: an answer that has not
  /// come within [answerGrace] never will.
  void _awaitAnswer() {
    _answerGraceTimer?.cancel();
    _answerGraceTimer = Timer(answerGrace, () {
      _answerGraceTimer = null;
      final giveUp = _giveUp;
      if (giveUp == null || giveUp.isCompleted) return;
      _log.info('Gave up on a prompt that did not answer');
      giveUp.complete(DeviceAuthResult.cancelled);
    });
  }

  Future<void> _storeAppLock({required bool enabled}) async {
    try {
      await ref
          .read(privacySettingsControllerProvider.notifier)
          .change((settings) => settings.copyWith(appLock: enabled));
    } on Object catch (error) {
      _log.warning('Could not store the app lock: ${error.runtimeType}');
    }
  }

  void _onInactive() {
    _visible = true;
    _cover();
  }

  void _onHide() {
    _visible = false;
    if (_authenticating) {
      _hiddenDuringPromptAt ??= _now();
      _answerGraceTimer?.cancel();
      _answerGraceTimer = null;
      return;
    }
    _hiddenAt = _now();
    _promptOnShow = true;
    _promptEndedOutOfSightAt = null;
    _cover();
    // With "immediately" the first frame back is already locked.
    if (_lockAfter == LockAfter.immediately) _lockIfDue();
  }

  void _onShow() {
    _visible = true;
    if (_authenticating) {
      if (_hiddenDuringPromptAt != null) _shownDuringPromptAt = _now();
      return;
    }
    final wasLocked = state.locked;
    _lockIfDue();
    _hiddenAt = null;
    if (wasLocked && _promptOnShow) _promptPending = true;
    _promptOnShow = false;
    if (_returnsFromPrompt()) _promptPending = false;
    _promptEndedOutOfSightAt = null;
    _uncover();
  }

  bool _returnsFromPrompt() {
    final endedAt = _promptEndedOutOfSightAt;
    return endedAt != null && _now().difference(endedAt) < _promptLoopWindow;
  }

  void _onResume() {
    _visible = true;
    _uncover();
    if (_authenticating) {
      if (_hiddenDuringPromptAt != null) _awaitAnswer();
      return;
    }
    _scheduleAutoPrompt();
  }

  void _onExcursionEnded(DateTime startedAt) {
    if (_visible || _authenticating) return;
    final now = _now();
    final elapsed = now.difference(startedAt);
    _hiddenAt = elapsed >= AppExcursions.cap || elapsed.isNegative
        ? startedAt
        : now;
    _promptOnShow = true;
    _lockIfDue();
  }

  void _cover() {
    if (!state.enabled || _authenticating) return;
    // There the system leaves the app out of Recents itself; a cover would
    // only blank the app whenever it loses focus (the shade, split screen).
    if (ref.read(recentsHiddenNativelyProvider)) return;
    if (_excursions.active && _outOfSightSince() == null) return;
    if (!state.covered) state = state.copyWith(covered: true);
  }

  void _uncover() {
    if (state.covered) state = state.copyWith(covered: false);
  }

  void _lockIfDue() {
    if (!state.enabled || state.locked) return;
    final since = _outOfSightSince();
    if (since == null) return;
    final elapsed = _now().difference(since);
    if (elapsed.isNegative || elapsed >= _lockAfter.duration) {
      state = state.copyWith(locked: true, error: null);
      _promptPending = true;
      _scheduleAutoPrompt();
    }
  }

  DateTime? _outOfSightSince() {
    if (!_excursions.active) return _hiddenAt;
    final startedAt = _excursions.startedAt!;
    final elapsed = _now().difference(startedAt);
    return elapsed >= AppExcursions.cap || elapsed.isNegative
        ? startedAt
        : null;
  }

  void _scheduleAutoPrompt() {
    if (!_promptPending || !_settingsKnown || !state.locked) return;
    _promptWhenSettled();
  }

  /// Only once the app has stayed resumed for [promptSettle]: the biometric
  /// prompt before the resume risks fragment state errors on Android, and
  /// Face ID fails while the app is inactive.
  void _promptWhenSettled() {
    if (_authenticating) return;
    final binding = WidgetsBinding.instance;
    if (binding.lifecycleState != AppLifecycleState.resumed) return;
    _promptPending = false;
    _settleTimer?.cancel();
    _settleTimer = Timer(promptSettle, () {
      _settleTimer = null;
      if (!_mayPromptNow()) return;
      unawaited(
        binding.endOfFrame.then((_) async {
          if (_mayPromptNow()) await unlock();
        }),
      );
    });
  }

  /// When the app left meanwhile, the next resume prompts instead.
  bool _mayPromptNow() {
    if (!ref.mounted || !state.locked || _authenticating) return false;
    final resumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!resumed) _promptPending = true;
    return resumed;
  }
}
