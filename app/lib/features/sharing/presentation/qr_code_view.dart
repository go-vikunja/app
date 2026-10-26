import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:qr/qr.dart';

/// A QR code dark on white with its quiet zone, in light and dark mode
/// alike, since scanners expect it; as wide as the room allows up to
/// [maxSize], each module a whole number of device pixels so that no seams
/// show between them.
class QrCodeView extends StatelessWidget {
  const new({
    required this.image,
    required this.semanticsLabel,
    this.maxSize = 320,
    super.key,
  });

  final QrImage image;
  final String semanticsLabel;
  final double maxSize;

  static const quietZoneModules = 4;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final modules = image.moduleCount + 2 * quietZoneModules;
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = math.min(constraints.maxWidth, maxSize);
        final pixelsPerModule = math.max(
          (room * devicePixelRatio / modules).floor(),
          1,
        );
        final side = pixelsPerModule * modules / devicePixelRatio;
        return Semantics(
          image: true,
          label: semanticsLabel,
          child: SizedBox.square(
            dimension: side,
            child: CustomPaint(painter: _QrPainter(image)),
          ),
        );
      },
    );
  }
}

class _QrPainter extends CustomPainter {
  new(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final count = image.moduleCount;
    final unit = size.shortestSide / (count + 2 * QrCodeView.quietZoneModules);
    final dark = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    const offset = QrCodeView.quietZoneModules;
    for (var row = 0; row < count; row++) {
      var column = 0;
      while (column < count) {
        if (!image.isDark(row, column)) {
          column++;
          continue;
        }
        final start = column;
        while (column < count && image.isDark(row, column)) {
          column++;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            (offset + start) * unit,
            (offset + row) * unit,
            (column - start) * unit,
            unit,
          ),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
