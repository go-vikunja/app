import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';

void main() {
  test(
    'an original stands in by itself only for an image the list names, of at '
    'most 8 MiB',
    () {
      TaskAttachment listed(String mime, int size) =>
          TaskAttachment(id: 1, taskId: 1, name: 'a', mime: mime, size: size);
      const eight = 8 * 1024 * 1024;

      expect(maxStandInBytes, eight);
      expect(originalStandsIn(listed('image/png', eight)), isTrue);
      expect(originalStandsIn(listed('image/png', eight + 1)), isFalse);
      expect(originalStandsIn(listed('IMAGE/JPEG; x=y', 300)), isTrue);
      expect(originalStandsIn(listed('image/svg+xml', 300)), isFalse);
      expect(
        originalStandsIn(listed('application/octet-stream', 300)),
        isFalse,
      );
      expect(originalStandsIn(listed('', 300)), isFalse);
      expect(originalStandsIn(listed('image/png', 0)), isFalse);
      expect(originalStandsIn(null), isFalse);
    },
  );

  test('a listing names a file as no image only by a type other than a '
      'drawable image; one without a type names nothing', () {
    TaskAttachment listed(String mime) =>
        TaskAttachment(id: 1, taskId: 1, name: 'a', mime: mime, size: 9);

    for (final mime in ['application/pdf', 'text/plain', 'image/svg+xml']) {
      expect(listsNoImage(listed(mime)), isTrue, reason: mime);
    }
    for (final mime in [
      'image/png',
      'IMAGE/HEIC; x=y',
      '',
      'application/octet-stream',
      'not a type',
    ]) {
      expect(listsNoImage(listed(mime)), isFalse, reason: mime);
    }
    expect(maxImagesByThemselves, 10);
  });

  test('an answer that is no image cannot pass, nor can a missing preview; a '
      'page or a redirect in its place may', () {
    expect(
      attachmentImageFailureMayPass(const AttachmentNotAnImage()),
      isFalse,
    );
    expect(
      attachmentImageFailureMayPass(const AttachmentImagePageInstead()),
      isTrue,
    );
    for (final status in [301, 302, 307, 308]) {
      expect(
        attachmentImageFailureMayPass(UnexpectedResponse(status)),
        isTrue,
        reason: '$status',
      );
    }
    expect(
      attachmentImageFailureMayPass(
        const UnexpectedResponse(
          200,
          message: 'a body larger than 26214400 bytes',
        ),
      ),
      isFalse,
    );
    expect(
      attachmentImageFailureMayPass(const UnexpectedResponse(null)),
      isFalse,
    );
    expect(
      attachmentImageFailureMayPass(const DomainError(422, code: 4038)),
      isFalse,
    );
    expect(attachmentImageFailureMayPass(const NotFound(code: 4011)), isFalse);
    expect(attachmentImageFailureMayPass(const Forbidden()), isFalse);
    expect(
      attachmentImageFailureMayPass(const AttachmentImageTooLarge()),
      isFalse,
    );
    expect(
      attachmentImageFailureMayPass(
        const NetworkFailure(NetworkProblem.unreachable),
      ),
      isTrue,
    );
  });
}
