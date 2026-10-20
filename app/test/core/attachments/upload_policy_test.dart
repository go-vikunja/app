import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';

void main() {
  test("the server's limit, else its default", () {
    expect(
      maxUploadBytesOf(
        const ServerInfo(version: null, maxFileSizeBytes: 1048576),
      ),
      1048576,
    );
    expect(
      maxUploadBytesOf(const ServerInfo(version: null)),
      defaultMaxUploadBytes,
    );
    expect(
      maxUploadBytesOf(const ServerInfo(version: null, maxFileSizeBytes: 0)),
      defaultMaxUploadBytes,
    );
  });

  test("never above the app's own ceiling", () {
    expect(appMaxUploadBytes, 50 * 1024 * 1024);
    for (final serverLimit in [appMaxUploadBytes, 500 << 20, 1 << 30]) {
      expect(
        maxUploadBytesOf(
          ServerInfo(version: null, maxFileSizeBytes: serverLimit),
        ),
        appMaxUploadBytes,
      );
    }
  });

  test('an upload gets at least a minute, more for a large file, at most four '
      'minutes', () {
    expect(uploadTimeoutFor(0), const Duration(minutes: 1));
    expect(uploadTimeoutFor(32 * 1024 * 60), const Duration(seconds: 90));
    expect(uploadTimeoutFor(defaultMaxUploadBytes), maxUploadTimeout);
    expect(maxUploadTimeout, lessThan(const Duration(minutes: 5)));
  });

  test('the reasons of a failed upload', () {
    final cases = <VikunjaFailure, UploadProblemReason>{
      const FileTooLarge(code: 4012): UploadProblemReason.tooLarge,
      const FileTooLarge(code: 4035): UploadProblemReason.tooLarge,
      const DomainError(400, code: 4012): UploadProblemReason.tooLarge,
      const DomainError(412, code: 3008): UploadProblemReason.projectArchived,
      const NotFound(): UploadProblemReason.attachmentsDisabled,
      const NotFound(code: 4002): UploadProblemReason.taskGone,
      const Forbidden(code: 1): UploadProblemReason.noPermission,
      const UnexpectedResponse(null, message: uploadFileMissingMessage):
          UploadProblemReason.fileMissing,
      const NetworkFailure(NetworkProblem.timeout):
          UploadProblemReason.timedOut,
      const UnexpectedResponse(500): UploadProblemReason.other,
      const ValidationFailed(): UploadProblemReason.other,
    };
    for (final MapEntry(key: failure, value: reason) in cases.entries) {
      expect(uploadProblemReason(failure), reason, reason: '$failure');
    }
  });
}
