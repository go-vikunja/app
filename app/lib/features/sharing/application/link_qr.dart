import 'package:qr/qr.dart';

/// Phones scan a code up to version 10 (57 modules) from another screen
/// reliably; a longer link is shared or copied instead.
const linkQrMaxVersion = 10;

/// The QR code of [link] with medium error correction; null when it would
/// need a version above [linkQrMaxVersion].
QrImage? linkQrImage(String link) {
  final QrCode code;
  try {
    code = QrCode(payload: QrPayload.fromString(link));
  } on InputTooLongException {
    return null;
  }
  return code.typeNumber > linkQrMaxVersion ? null : QrImage(code);
}
