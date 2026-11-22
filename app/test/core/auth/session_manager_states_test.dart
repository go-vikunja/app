import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/session_manager_states.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

const _accountId = 'a1';
const _raceLost = RefreshRaceLost(message: 'already used');

/// The value a call completed with, or the error it threw.
Future<Object?> _outcome(Future<Object?> call) =>
    call.then((value) => value, onError: (Object error) => error);

void main() {
  late DateTime now;
  late MemorySecureStore secureStore;
  late TokenStore tokenStore;
  late MemoryPreferencesStore preferences;
  late ServerClockOffsets clockOffsets;
  late List<String> refreshCalls;
  late Future<TokenSet> Function(String refreshToken) onRefresh;
  late List<SessionEnded> ended;
  late List<Duration> sleeps;

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    secureStore = MemorySecureStore();
    tokenStore = TokenStore(secureStore);
    preferences = MemoryPreferencesStore();
    clockOffsets = ServerClockOffsets(preferences);
    refreshCalls = [];
    onRefresh = (_) async => issueTokens(issuedAt: now);
    ended = [];
    sleeps = [];
  });

  SessionManager createManager({SessionDiagnostics? diagnostics}) =>
      SessionManager(
        accountId: _accountId,
        tokenStore: tokenStore,
        clockOffsets: clockOffsets,
        diagnostics: diagnostics,
        refresh: (refreshToken) {
          refreshCalls.add(refreshToken);
          return onRefresh(refreshToken);
        },
        onSessionEnded: (failure) async => ended.add(failure),
        clock: () => now,
        sleep: (duration) async => sleeps.add(duration),
      );

  Future<TokenSet> store({required Duration expiresIn}) async {
    final tokens = issueTokens(
      issuedAt: now.add(expiresIn).subtract(const Duration(minutes: 10)),
    );
    await tokenStore.write(_accountId, tokens);
    return tokens;
  }

  Future<String?> storedRefreshToken() async =>
      (await tokenStore.read(_accountId))?.refreshToken;

  group('a manager retired during a refresh', () {
    test('whose write had begun hands the stored tokens to no '
        'caller', () async {
      final stored = await store(expiresIn: Duration.zero);
      final fresh = issueTokens(issuedAt: now);
      onRefresh = (_) async => fresh;
      final writing = Completer<void>();
      final gate = Completer<void>();
      secureStore.beforeWrite = (_) {
        if (!writing.isCompleted) writing.complete();
        return gate.future;
      };
      final manager = createManager();

      final valid = _outcome(manager.validAccessToken());
      final rejected = _outcome(
        manager.refreshAfterRejection(stored.accessToken),
      );
      await writing.future;
      final retiring = manager.retire();
      gate.complete();
      await retiring;

      expect(await valid, isA<SessionEnded>());
      expect(await rejected, isNull);
      expect(await storedRefreshToken(), fresh.refreshToken);
      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(refreshCalls, [stored.refreshToken]);
      expect(ended, isEmpty);
    });

    test('whose write then failed hands the tokens to no caller and never '
        'writes them later', () async {
      final stored = await store(expiresIn: Duration.zero);
      final fresh = issueTokens(issuedAt: now);
      onRefresh = (_) async => fresh;
      final writing = Completer<void>();
      final gate = Completer<void>();
      secureStore.beforeWrite = (_) async {
        if (!writing.isCompleted) writing.complete();
        await gate.future;
        throw StateError('keystore');
      };
      final manager = createManager();

      final valid = _outcome(manager.validAccessToken());
      await writing.future;
      final retiring = manager.retire();
      gate.complete();
      await retiring;

      expect(await valid, isA<SessionEnded>());
      secureStore.beforeWrite = null;
      secureStore.operations.clear();
      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(await manager.refreshAfterRejection(fresh.accessToken), isNull);
      await expectLater(manager.refreshNow(), throwsA(isA<SessionEnded>()));
      await manager.settle();
      expect(secureStore.operations, isEmpty);
      expect(await storedRefreshToken(), stored.refreshToken);
      expect(refreshCalls, [stored.refreshToken]);
      expect(sleeps, isEmpty);
      expect(ended, isEmpty);
    });

    test('that then failed for now hands out no token that still '
        'works', () async {
      final stored = await store(expiresIn: const Duration(seconds: 30));
      final response = Completer<TokenSet>();
      onRefresh = (_) => response.future;
      final manager = createManager();

      final valid = _outcome(manager.validAccessToken());
      await pumpEventQueue();
      await manager.retire();
      response.completeError(const NetworkFailure(NetworkProblem.unreachable));

      expect(await valid, isA<SessionEnded>());
      expect(refreshCalls, [stored.refreshToken]);
      expect(ended, isEmpty);
    });
  });

  group('an ended manager', () {
    test('throws the end it recorded until it is retired, and then answers '
        'like a retired one, whatever storage holds', () async {
      await store(expiresIn: Duration.zero);
      onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.expired, code: 16003);
      final manager = createManager();
      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      await expectLater(
        manager.refreshAfterRejection('older'),
        throwsA(same(ended.single)),
      );
      await expectLater(manager.refreshNow(), throwsA(same(ended.single)));

      await manager.retire();
      await tokenStore.write(
        _accountId,
        issueTokens(issuedAt: now, sessionId: 'session-2'),
      );

      await expectLater(
        manager.validAccessToken(),
        throwsA(
          isA<SessionEnded>().having(
            (f) => f.reason,
            'reason',
            SessionEndReason.invalidRefreshToken,
          ),
        ),
      );
      expect(await manager.refreshAfterRejection('older'), isNull);
      await expectLater(
        manager.refreshNow(),
        throwsA(
          isA<SessionEnded>().having(
            (f) => f.reason,
            'reason',
            SessionEndReason.invalidRefreshToken,
          ),
        ),
      );
      expect(refreshCalls, hasLength(1));
      expect(ended, hasLength(1));
    });

    test('that new tokens brought back ends again when the server refuses '
        'them, and records that end', () async {
      final first = await store(expiresIn: Duration.zero);
      onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.expired, code: 16003);
      final manager = createManager();
      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      final restored = issueTokens(issuedAt: now.subtract(_stale));
      await tokenStore.write(_accountId, restored);
      onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.accountDisabled);

      await expectLater(
        manager.validAccessToken(),
        throwsA(
          isA<SessionEnded>().having(
            (f) => f.reason,
            'reason',
            SessionEndReason.accountDisabled,
          ),
        ),
      );
      expect(refreshCalls, [first.refreshToken, restored.refreshToken]);
      expect(ended.map((f) => f.reason), [
        SessionEndReason.expired,
        SessionEndReason.accountDisabled,
      ]);
      await expectLater(
        manager.refreshAfterRejection('older'),
        throwsA(same(ended.last)),
      );
    });
  });

  group('the note of a send (decision log: Sessions)', () {
    late SessionDiagnostics diagnostics;

    setUp(() => diagnostics = SessionDiagnostics(preferences));

    test('a race refused again within the window is put off again; once the '
        'window has passed since the first refusal, the session '
        'ends', () async {
      await store(expiresIn: Duration.zero);
      onRefresh = (_) async => throw _raceLost;
      final deferred = throwsA(
        isA<NetworkFailure>().having(
          (f) => f.cause,
          'cause',
          RefreshDeferred.race,
        ),
      );

      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        deferred,
      );
      final refusedAt = now;
      now = now.add(const Duration(seconds: 15));
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        deferred,
      );
      expect(
        (await diagnostics.refreshMarker(_accountId))!.refusedAt,
        refusedAt,
      );
      expect(ended, isEmpty);

      now = now.add(const Duration(seconds: 1));
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(ended, hasLength(1));
      expect((await diagnostics.lastEnd(_accountId))!.lostRefreshAt, isNull);
      expect(refreshCalls, hasLength(3));
    });

    test('a refresh refused after a send whose answer was lost and a server '
        'error names the lost send', () async {
      final stored = await store(expiresIn: Duration.zero);
      final lostAt = now;
      onRefresh = (_) async =>
          throw const NetworkFailure(NetworkProblem.timeout);
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );

      now = now.add(const Duration(minutes: 30));
      var calls = 0;
      onRefresh = (_) async {
        if (calls++ == 0) throw const ServerFailure(502);
        throw const SessionEnded(
          SessionEndReason.invalidRefreshToken,
          code: 16002,
        );
      };
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );
      now = now.add(const Duration(minutes: 30));
      onRefresh = (_) async => throw const SessionEnded(
        SessionEndReason.invalidRefreshToken,
        code: 16002,
      );
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      final record = (await diagnostics.lastEnd(_accountId))!;
      expect(record.failedToken, tokenFingerprint(stored.refreshToken));
      expect(record.lostRefreshAt, lostAt);
      expect(await diagnostics.refreshMarker(_accountId), isNull);
    });
  });

  group('SessionManagers.signedIn', () {
    test('starts the new manager with the tokens and the server clock of '
        'the sign-in, and retires the previous one', () async {
      const skew = Duration(minutes: 5);
      final gateway = FakeTokenGateway()
        ..onRefresh = (_) async => issueTokens(issuedAt: now.add(skew));
      final managers = SessionManagers(
        tokenStore: tokenStore,
        clockOffsets: clockOffsets,
        tokenGateway: gateway,
        connectionFor: (_) async => fullServer270(),
        markNeedsReauth: (_) async {},
        clock: () => now,
        sleep: (_) async {},
      );
      await store(expiresIn: const Duration(minutes: 5));
      final previous = managers.forAccount(_accountId);
      final signIn = issueTokens(issuedAt: now.add(skew), sessionId: 's-2');
      await tokenStore.write(_accountId, signIn);

      final manager = await managers.signedIn(
        _accountId,
        signIn,
        receivedAt: now,
      );

      expect(await clockOffsets.read(_accountId), skew);
      expect(managers.forAccount(_accountId), same(manager));
      expect(await manager.validAccessToken(), signIn.accessToken);
      await expectLater(
        previous.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(gateway.refreshedTokens, isEmpty);

      // 30 s before expiry in server time, 5.5 min on the device's clock.
      now = now.add(const Duration(minutes: 9, seconds: 30));
      await manager.validAccessToken();
      expect(gateway.refreshedTokens, [signIn.refreshToken]);
    });
  });

  group('stopAfter', () {
    const failure = SessionEnded(SessionEndReason.expired);
    const earlier = SessionEnded(SessionEndReason.accountLocked);
    final endedBy = isA<EndedStop>().having(
      (stop) => stop.failure,
      'failure',
      same(failure),
    );
    final retired = isA<RetiredStop>();

    for (final (from, event, to) in <(SessionStop?, StopEvent, Matcher)>[
      (null, const EndEvent(failure), endedBy),
      (null, const ReviveEvent(), isNull),
      (null, const RetireEvent(), retired),
      (const EndedStop(earlier), const EndEvent(failure), endedBy),
      (const EndedStop(earlier), const ReviveEvent(), isNull),
      (const EndedStop(earlier), const RetireEvent(), retired),
      (const RetiredStop(), const EndEvent(failure), retired),
      (const RetiredStop(), const ReviveEvent(), retired),
      (const RetiredStop(), const RetireEvent(), retired),
    ]) {
      test('${from?.runtimeType ?? 'live'} after ${event.runtimeType}', () {
        expect(stopAfter(from, event), to);
      });
    }
  });

  group('SendNote', () {
    final at = DateTime.utc(2026, 10, 9, 12);
    const token = 'sent';
    final written = (
      token: token,
      sentAt: at,
      sentBy: AppPart.app,
      refusedAt: null,
    );
    final lostEarlier = (
      token: token,
      sentAt: at.subtract(const Duration(minutes: 30)),
      sentBy: AppPart.backgroundRun,
      refusedAt: null,
    );
    final refusedEarlier = (
      token: token,
      sentAt: null,
      sentBy: null,
      refusedAt: at.subtract(const Duration(minutes: 5)),
    );
    final otherToken = (
      token: 'other',
      sentAt: at.subtract(const Duration(minutes: 30)),
      sentBy: AppPart.app,
      refusedAt: null,
    );

    (String, RefreshMarker?) shape(SendNote note) => switch (note) {
      Unnoted() => ('unnoted', null),
      NotedHere(:final written) => ('here', written),
      NotedEarlier(:final marker) => ('earlier', marker),
    };

    for (final (what, stored, expected)
        in <(String, RefreshMarker?, (String, RefreshMarker?))>[
          ('no marker', null, ('here', written)),
          ('the marker of another token', otherToken, ('here', written)),
          ('an earlier unanswered send', lostEarlier, ('earlier', lostEarlier)),
          ('an earlier refusal', refusedEarlier, ('earlier', refusedEarlier)),
        ]) {
      test('a send over $what notes ${expected.$1}', () {
        final note = SendNote.forSend(
          stored,
          token: token,
          at: at,
          part: AppPart.app,
        );

        expect(shape(note), expected);
      });
    }

    const SendNote unnoted = Unnoted();
    final SendNote here = NotedHere(written);
    final SendNote earlier = NotedEarlier(lostEarlier);

    for (final (from, what, step, to)
        in <
          (
            SendNote,
            String,
            SendNote Function(SendNote),
            (String, RefreshMarker?),
          )
        >[
          (unnoted, 'a 5xx', (n) => n.afterServerError, ('unnoted', null)),
          (unnoted, 'unreached', (n) => n.afterUnreached, ('unnoted', null)),
          (unnoted, 'refused', (n) => n.afterRefused, ('unnoted', null)),
          (here, 'a 5xx', (n) => n.afterServerError, ('earlier', written)),
          (here, 'unreached', (n) => n.afterUnreached, ('unnoted', null)),
          (here, 'refused', (n) => n.afterRefused, ('unnoted', null)),
          (
            earlier,
            'a 5xx',
            (n) => n.afterServerError,
            ('earlier', lostEarlier),
          ),
          (
            earlier,
            'unreached',
            (n) => n.afterUnreached,
            ('earlier', lostEarlier),
          ),
          (earlier, 'refused', (n) => n.afterRefused, ('earlier', lostEarlier)),
          (
            here,
            'a 5xx, then unreached',
            (n) => n.afterServerError.afterUnreached,
            ('earlier', written),
          ),
          (
            here,
            'a 5xx, then refused',
            (n) => n.afterServerError.afterRefused,
            ('earlier', written),
          ),
        ]) {
      test('${shape(from).$1} after $what is ${to.$1}', () {
        final after = step(from);

        expect(shape(after), to);
        // What a refusal names as the earlier send.
        expect(after.earlier, to.$1 == 'earlier' ? to.$2 : null);
      });
    }

    test('only a marker this send wrote is taken back after a send that '
        'never reached the server', () {
      expect(unnoted.wroteMarker, isFalse);
      expect(here.wroteMarker, isTrue);
      expect(earlier.wroteMarker, isFalse);
      expect(here.afterServerError.wroteMarker, isFalse);
    });

    test('names an earlier send only for its own token', () {
      expect(earlier.earlierSendOf(token), lostEarlier);
      expect(earlier.earlierSendOf('other'), isNull);
      expect(earlier.earlierSendOf(null), isNull);
      expect(here.earlierSendOf(token), isNull);
      expect(unnoted.earlierSendOf(null), isNull);
    });
  });

  group('lostRotationVerdict', () {
    final at = DateTime.utc(2026, 10, 9, 12);
    const token = 'sent';
    final window = SessionManager.raceRecheckWindow;
    SendNote refused(Duration ago, {String token = token}) => NotedEarlier((
      token: token,
      sentAt: null,
      sentBy: null,
      refusedAt: at.subtract(ago),
    ));

    for (final (what, raced, note, verdict)
        in <(String, bool, SendNote, LostRotationVerdict)>[
          ('a refusal', false, const Unnoted(), LostRotationVerdict.end),
          ('a race', true, const Unnoted(), LostRotationVerdict.defer),
          (
            'a race noted by this send',
            true,
            NotedHere((
              token: token,
              sentAt: at,
              sentBy: AppPart.app,
              refusedAt: null,
            )),
            LostRotationVerdict.defer,
          ),
          (
            'a race refused within the window',
            true,
            refused(const Duration(seconds: 15)),
            LostRotationVerdict.defer,
          ),
          (
            'a race refused at the end of the window',
            true,
            refused(window),
            LostRotationVerdict.defer,
          ),
          (
            'a race refused before the window',
            true,
            refused(const Duration(seconds: 16)),
            LostRotationVerdict.end,
          ),
          (
            'a race after a refusal of another token before the window',
            true,
            refused(const Duration(minutes: 30), token: 'other'),
            LostRotationVerdict.defer,
          ),
          (
            'a race after a send whose answer was lost',
            true,
            NotedEarlier((
              token: token,
              sentAt: at.subtract(const Duration(minutes: 30)),
              sentBy: AppPart.backgroundRun,
              refusedAt: null,
            )),
            LostRotationVerdict.defer,
          ),
          (
            'a refusal within the window',
            false,
            refused(const Duration(seconds: 1)),
            LostRotationVerdict.end,
          ),
        ]) {
      test('$what: ${verdict.name}', () {
        expect(
          lostRotationVerdict(
            note,
            raced: raced,
            token: token,
            now: at,
            window: window,
          ),
          verdict,
        );
      });
    }
  });

  group('failure classes', () {
    for (final (failure, lost, neverProcessed, transient)
        in <(VikunjaFailure, bool, bool, bool)>[
          (const RefreshRaceLost(), true, false, false),
          (
            const SessionEnded(SessionEndReason.invalidRefreshToken),
            true,
            false,
            false,
          ),
          (const SessionEnded(SessionEndReason.expired), false, false, false),
          (const RateLimited(), false, true, true),
          (const OAuthFailure(OAuthProblem.codeInvalid), false, true, false),
          (const UnexpectedResponse(401), false, true, true),
          (const UnexpectedResponse(499), false, true, true),
          (const UnexpectedResponse(502), false, false, true),
          (const UnexpectedResponse(null), false, false, true),
          (const ServerFailure(500), false, false, true),
          (const NetworkFailure(NetworkProblem.tls), false, true, true),
          (const NetworkFailure(NetworkProblem.timeout), false, false, true),
          (
            const NetworkFailure(NetworkProblem.unreachable),
            false,
            false,
            true,
          ),
          (
            const NetworkFailure(
              NetworkProblem.unreachable,
              cause: SocketException('Failed host lookup: tasks.example.com'),
            ),
            false,
            true,
            true,
          ),
          (const TokenRejected(), false, false, false),
          (const NotFound(), false, false, false),
        ]) {
      test('$failure, ${failure.runtimeType}', () {
        expect(isLostRotation(failure), lost, reason: 'lost rotation');
        expect(
          isNeverProcessed(failure),
          neverProcessed,
          reason: 'never processed',
        );
        expect(isTransientFailure(failure), transient, reason: 'transient');
      });
    }
  });

  group('restoring an ended session', () {
    SessionEndDiagnosis diagnosis(
      SessionEndCause cause, {
      String? failedToken,
      String? rotatedAwayToken,
      SessionEndResolution? resolution,
    }) => SessionEndDiagnosis(
      at: DateTime.utc(2026, 10, 9, 12),
      cause: cause,
      part: AppPart.backgroundRun,
      failedToken: failedToken,
      rotatedAwayToken: rotatedAwayToken,
      resolution: resolution,
    );

    for (final (resolution, step) in <(SessionEndResolution?, RestoreStep)>[
      (null, RestoreStep.readStorage),
      (SessionEndResolution.restored, RestoreStep.unmarkOnly),
      (SessionEndResolution.wasAlive, RestoreStep.none),
      (SessionEndResolution.orphanRevoked, RestoreStep.none),
      (SessionEndResolution.goneOnServer, RestoreStep.none),
      (SessionEndResolution.noTokens, RestoreStep.none),
      (SessionEndResolution.unknown, RestoreStep.none),
    ]) {
      test('an end resolved as ${resolution?.name} is ${step.name}', () {
        expect(
          restoreStep(
            diagnosis(SessionEndCause.refreshRejected, resolution: resolution),
          ),
          step,
        );
      });
    }

    for (final (what, ended, retries) in <(String, SessionEndDiagnosis, bool)>[
      (
        'a refusal of another token',
        diagnosis(SessionEndCause.refreshRejected, failedToken: 'failed'),
        true,
      ),
      (
        'a refusal of the stored token',
        diagnosis(SessionEndCause.refreshRejected, failedToken: 'stored'),
        false,
      ),
      (
        'a refusal that names no token',
        diagnosis(SessionEndCause.refreshRejected),
        false,
      ),
      (
        'a refusal while storage still held the token rotated away',
        diagnosis(
          SessionEndCause.refreshRejected,
          failedToken: 'failed',
          rotatedAwayToken: 'stored',
        ),
        false,
      ),
      (
        'storage that could not be read',
        diagnosis(SessionEndCause.storageUnreadable),
        true,
      ),
      (
        'storage that could not be read, holding the token rotated away',
        diagnosis(
          SessionEndCause.storageUnreadable,
          rotatedAwayToken: 'stored',
        ),
        false,
      ),
      (
        'an expired session',
        diagnosis(SessionEndCause.sessionExpired, failedToken: 'failed'),
        false,
      ),
      (
        'a disabled account',
        diagnosis(SessionEndCause.accountDisabled, failedToken: 'failed'),
        false,
      ),
      ('missing tokens', diagnosis(SessionEndCause.missingTokens), false),
    ]) {
      test('after $what, the stored tokens are '
          '${retries ? 'tried' : 'not tried'}', () {
        expect(restoreRetries(ended, 'stored'), retries);
      });
    }
  });
}

const _stale = Duration(minutes: 9, seconds: 30);
