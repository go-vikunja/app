import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

void main() {
  // attachmentPreview.test.ts of the web, in its order.
  group('the web vectors', () {
    test('canPreviewPdf', () {
      expect(canPreviewPdf('doc.pdf', 'application/pdf'), isTrue);
      expect(canPreviewPdf('evil.pdf', 'text/html'), isFalse);
      expect(canPreviewPdf('doc.pdf', 'APPLICATION/PDF'), isTrue);
      expect(canPreviewPdf('doc.txt', 'application/pdf'), isFalse);
    });

    test('canPreviewImage', () {
      expect(canPreviewImage('pic.png', 'image/png'), isTrue);
      expect(canPreviewImage('evil.png', 'text/html'), isFalse);
      expect(canPreviewImage('evil.jpg', 'image/svg+xml'), isFalse);
    });

    test('canPreviewAudio', () {
      expect(canPreviewAudio('audio/mpeg'), isTrue);
      expect(canPreviewAudio('audio/ogg'), isTrue);
      expect(canPreviewAudio('AUDIO/MPEG'), isTrue);
      expect(canPreviewAudio('text/html'), isFalse);
    });

    test('canPreviewVideo', () {
      expect(canPreviewVideo('video/mp4'), isTrue);
      expect(canPreviewVideo('video/webm'), isTrue);
      expect(canPreviewVideo('video/x-matroska'), isTrue);
      expect(canPreviewVideo('video/ogg'), isTrue);
      expect(canPreviewVideo('VIDEO/MP4'), isTrue);
      expect(canPreviewVideo('text/plain'), isFalse);
      expect(canPreviewVideo('audio/ogg'), isFalse);
    });

    test('attachmentPreviewKind', () {
      expect(
        attachmentPreviewKind('pic.png', 'image/png'),
        AttachmentPreviewKind.image,
      );
      expect(
        attachmentPreviewKind('doc.pdf', 'application/pdf'),
        AttachmentPreviewKind.pdf,
      );
      expect(
        attachmentPreviewKind('clip.mp4', 'video/mp4'),
        AttachmentPreviewKind.video,
      );
      expect(attachmentPreviewKind('notes.txt', 'text/plain'), isNull);
      expect(attachmentPreviewKind('memo.mp3', 'audio/mpeg'), isNull);
    });
  });

  test('every image extension, any case; the mime the server sniffed', () {
    for (final name in ['a.jpeg', 'a.JPG', 'a.png', 'a.Bmp', 'a.gif']) {
      expect(canPreviewImage(name, 'image/png'), isTrue, reason: name);
    }
    expect(canPreviewImage('a.webp', 'image/webp'), isFalse);
    expect(canPreviewImage('a.svg', 'image/svg+xml'), isFalse);
    expect(canPreviewImage('spoof.png', 'text/plain; charset=utf-8'), isFalse);
    expect(canPreviewImage('png', 'image/png'), isFalse);
  });

  test('humanSize like getHumanSize', () {
    final cases = <int, String>{
      0: '0 B',
      1: '1 B',
      1024: '1024 B',
      1025: '1 KB',
      1536: '1.5 KB',
      1048576: '1024 KB',
      1048577: '1 MB',
      1500000: '1.43 MB',
      123456789: '117.74 MB',
      1610612736: '1.5 GB',
      1099511627776: '1024 GB',
      1099511627777: '1 TB',
      // The web has no unit beyond TB and prints "undefined"; this stays
      // in TB.
      1125899906842625: '1024 TB',
      5629499534213120: '5120 TB',
      -5: '0 B',
    };
    for (final MapEntry(key: bytes, value: expected) in cases.entries) {
      expect(humanSize(bytes), expected, reason: '$bytes');
    }
  });

  test('humanSize writes the value with the given number format', () {
    final written = <num>[];
    String comma(num value) {
      written.add(value);
      return '$value'.replaceAll('.', ',');
    }

    expect(humanSize(3456789, formatNumber: comma), '3,3 MB');
    expect(humanSize(2048, formatNumber: comma), '2 KB');
    expect(written, [3.3, 2]);
    expect(written.last, isA<int>());
  });

  test('humanSize rounds half up to two decimals', () {
    expect(humanSize(1029), '1 KB');
    expect(humanSize(1034), '1.01 KB');
    expect(humanSize(1152), '1.13 KB');
    expect(humanSize(2560), '2.5 KB');
  });
}
