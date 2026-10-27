import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/connection/application/certificate_file.dart';

import '../../helpers/attachment_picker_fake.dart';
import '../../helpers/connection_fakes.dart';
import '../../helpers/tls_fixtures.dart';

void main() {
  late Directory directory;
  late FakeAttachmentPicker picker;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('picked');
    picker = FakeAttachmentPicker();
  });

  tearDown(() => directory.delete(recursive: true));

  test('reads one file of at most 64 KB and deletes the copy', () async {
    final copy = pickedCopyOf('client.p12', directory: directory);
    picker.files = [copy];

    final picked = await pickCertificateFile(picker);

    expect(picker.calls, ['files single']);
    expect(picker.maxBytes, [64 * 1024]);
    expect(
      picked,
      isA<CertificateFileRead>()
          .having((file) => file.name, 'name', 'client.p12')
          .having((file) => file.bytes, 'bytes', tlsFixture('client.p12')),
    );
    expect(File(copy.path).existsSync(), isFalse);
  });

  test('a cancelled pick reads nothing', () async {
    expect(await pickCertificateFile(picker), isA<CertificateFileCancelled>());
  });

  test('a file the picker left uncopied is too large', () async {
    picker.tooLargeFiles = ['huge.p12'];

    expect(await pickCertificateFile(picker), isA<CertificateFileTooLarge>());
  });

  test('a copy above the limit is refused and deleted too', () async {
    final copy = File('${directory.path}/big.p12');
    await copy.writeAsBytes(List.filled(64 * 1024 + 1, 1));
    picker.files = [PickedFile(path: copy.path, name: 'big.p12')];

    expect(await pickCertificateFile(picker), isA<CertificateFileTooLarge>());
    expect(copy.existsSync(), isFalse);
  });

  test('a copy that cannot be read is unreadable', () async {
    picker.files = [
      PickedFile(path: '${directory.path}/missing.p12', name: 'missing.p12'),
    ];

    expect(await pickCertificateFile(picker), isA<CertificateFileUnreadable>());
  });

  test('a picker that cannot open throws, leaving nothing behind', () async {
    picker.failure = Exception('no picker');

    await expectLater(pickCertificateFile(picker), throwsException);
  });
}
