import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/network/client_certificate.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';

final _log = Logger('CertificateFile');

sealed class PickedCertificateFile {
  const new();
}

final class CertificateFileCancelled extends PickedCertificateFile {
  const new();
}

final class CertificateFileTooLarge extends PickedCertificateFile {
  const new();
}

final class CertificateFileUnreadable extends PickedCertificateFile {
  const new();
}

final class CertificateFileRead extends PickedCertificateFile {
  const new({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// A PKCS#12 or PEM file from the document picker, read into memory. The
/// picker's copy in the cache is deleted whatever happens, so a client
/// certificate never stays behind outside secure storage. Throws when the
/// picker could not open. The Android picker filters no types, so only
/// the caller's check of the bytes tells what the file is.
Future<PickedCertificateFile> pickCertificateFile(
  AttachmentPicker picker,
) async {
  final picked = await picker.pickFiles(
    maxBytes: maxClientCertificateBytes,
    multiple: false,
  );
  try {
    if (picked.tooLarge.isNotEmpty) return const CertificateFileTooLarge();
    final file = picked.files.firstOrNull;
    if (file == null) {
      return picked.failed.isEmpty
          ? const CertificateFileCancelled()
          : const CertificateFileUnreadable();
    }
    final bytes = await File(file.path).readAsBytes();
    if (bytes.length > maxClientCertificateBytes) {
      return const CertificateFileTooLarge();
    }
    return CertificateFileRead(name: file.name, bytes: bytes);
  } on FileSystemException catch (error) {
    _log.info('A picked certificate file was unreadable: ${error.runtimeType}');
    return const CertificateFileUnreadable();
  } finally {
    for (final file in picked.files) {
      try {
        await File(file.path).delete();
      } on FileSystemException catch (error) {
        _log.info('A picked copy was not deleted: ${error.runtimeType}');
      }
    }
  }
}
