import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('a 404 without a code means the route is absent', () {
    expect(const NotFound().routeAbsent, isTrue);
    expect(const NotFound(code: 3001).routeAbsent, isFalse);
  });

  test('fixed codes', () {
    expect(const TokenRejected().code, 11);
    expect(const RefreshRaceLost().code, 16004);
    expect(const RateLimited().code, isNull);
    expect(const NetworkFailure(NetworkProblem.timeout).code, isNull);
  });

  test('a task or project is gone when deleted or in the trash', () {
    for (final code in [4002, 4040]) {
      expect(NotFound(code: code).taskGone, isTrue, reason: '$code');
      expect(NotFound(code: code).projectGone, isFalse, reason: '$code');
    }
    for (final code in [3001, 3018]) {
      expect(NotFound(code: code).projectGone, isTrue, reason: '$code');
      expect(NotFound(code: code).taskGone, isFalse, reason: '$code');
    }
    for (final failure in [
      const NotFound(),
      const NotFound(code: 4009),
      const NotFound(code: 3014),
      const TeamMemberMissing(),
    ]) {
      expect(failure.taskGone, isFalse, reason: '$failure');
      expect(failure.projectGone, isFalse, reason: '$failure');
    }
    expect(switch (const NotFound(code: 4040) as VikunjaFailure) {
      NotFound(projectGone: true) => 'project gone',
      NotFound(taskGone: true) => 'task gone',
      _ => 'other',
    }, 'task gone');
  });

  test('a missing related task is a 404 with the code the server sent for '
      'the other task, which is not the task itself gone', () {
    for (final code in [4040, 3018]) {
      final failure = RelatedTaskMissing(5, code: code);

      expect(failure.code, code);
      expect(failure.taskGone, isFalse);
      expect(failure.projectGone, isFalse);
    }
  });

  test('a missing related task is a 404 with code 4002 that names the '
      'other task', () {
    const failure = RelatedTaskMissing(5, message: 'This task does not exist');

    expect(failure, isA<NotFound>());
    expect(failure.code, 4002);
    expect(failure.taskGone, isFalse);
    expect(failure.routeAbsent, isFalse);
    expect(failure.otherTaskId, 5);
    expect(failure.message, 'This task does not exist');
    expect('$failure', 'RelatedTaskMissing(5)');
    expect(switch (failure as VikunjaFailure) {
      RelatedTaskMissing(:final otherTaskId) => 'related $otherTaskId',
      NotFound() => 'task gone',
      _ => 'other',
    }, 'related 5');
  });

  test('a file above the limit is a 413 domain error with its code', () {
    const failure = FileTooLarge(code: 4012, message: 'of 0 bytes');

    expect(failure, isA<DomainError>());
    expect(failure.statusCode, 413);
    expect(failure.code, 4012);
    expect('$failure', 'FileTooLarge(code: 4012)');
    expect(switch (failure as VikunjaFailure) {
      FileTooLarge(:final code) => 'too large $code',
      DomainError() => 'domain',
      _ => 'other',
    }, 'too large 4012');
  });

  test('a gone link share ends the session with its own reason', () {
    const failure = LinkShareGone(code: 13003, message: 'token invalid');

    expect(failure, isA<SessionEnded>());
    expect(failure.reason, SessionEndReason.linkShareGone);
    expect(failure.code, 13003);
    expect(const LinkShareGone().code, isNull);
    expect('$failure', 'LinkShareGone(code: 13003)');
    expect(switch (failure as VikunjaFailure) {
      LinkShareGone() => 'link gone',
      SessionEnded() => 'session',
      _ => 'other',
    }, 'link gone');
  });

  test('toString never includes the server message', () {
    const message = 'secret detail';
    final failures = <VikunjaFailure>[
      const TokenRejected(message: message),
      const SessionEnded(
        SessionEndReason.expired,
        code: 16003,
        message: message,
      ),
      const RefreshRaceLost(message: message),
      const OAuthFailure(
        OAuthProblem.pkceMismatch,
        code: 17006,
        message: message,
      ),
      const Forbidden(message: message),
      const NotFound(message: message),
      const RelatedTaskMissing(5, message: message),
      const ValidationFailed(
        fieldErrors: {
          'title': [message],
        },
        message: message,
      ),
      const RateLimited(message: message),
      const ServerFailure(500, message: message),
      const DomainError(400, code: 4029, message: message),
      const FileTooLarge(code: 4035, message: message),
      const LinkShareGone(code: 13003, message: message),
      const DescriptionConflict(),
      const UnexpectedResponse(418, message: message),
    ];

    for (final failure in failures) {
      expect('$failure', isNot(contains(message)), reason: '$failure');
    }
  });

  test('every failure is exhaustively matchable', () {
    String describe(VikunjaFailure failure) => switch (failure) {
      NetworkFailure() => 'network',
      TokenRejected() => 'token',
      SessionEnded() => 'session',
      RefreshRaceLost() => 'race',
      OAuthFailure() => 'oauth',
      Forbidden() => 'forbidden',
      NotFound() => 'not found',
      ValidationFailed() => 'validation',
      RateLimited() => 'rate',
      ServerFailure() => 'server',
      DomainError() => 'domain',
      DescriptionConflict() => 'description conflict',
      UnexpectedResponse() => 'unexpected',
    };

    expect(describe(const RateLimited()), 'rate');
  });

  test('only the problems the connection settings cause or fix concern '
      'them', () {
    expect(
      {
        for (final problem in NetworkProblem.values)
          if (problem.concernsConnectionSettings) problem,
      },
      {
        NetworkProblem.clientCertificate,
        NetworkProblem.cleartextBlocked,
        NetworkProblem.profileLocked,
        NetworkProblem.profileIncomplete,
        NetworkProblem.profileDamaged,
      },
    );
  });

  test('a missing team member is a not found of an existing route', () {
    const failure = TeamMemberMissing();

    expect(failure, isA<NotFound>());
    expect(failure.routeAbsent, isFalse);
    expect(failure.code, isNull);
    expect(failure.toString(), 'TeamMemberMissing');
  });
}
