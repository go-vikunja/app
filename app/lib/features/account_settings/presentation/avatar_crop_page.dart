import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/account_settings/application/square_avatar.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/app_bar_text_action.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';

final _log = Logger('AvatarCrop');

/// The picked photo in a square the user moves and zooms, which becomes the
/// avatar, as the web crops it before the upload (the server keeps any
/// shape). Upload gives the square as a PNG to [onUpload]; once it is done
/// the page closes with true, and when it throws the page stays with the
/// reason.
class AvatarCropPage extends StatefulWidget {
  const new({required this.source, required this.onUpload, super.key});

  final Uint8List source;
  final Future<void> Function(Uint8List png) onUpload;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  ui.Image? _image;
  var _unusable = false;
  var _uploading = false;
  String? _error;
  TransformationController _transform = TransformationController();
  double? _viewportSide;

  @override
  void initState() {
    super.initState();
    unawaited(_decode());
  }

  @override
  void dispose() {
    _image?.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final image = await decodeAvatarSource(widget.source);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } on Object catch (error) {
      _log.info('The picked photo could not be decoded: ${error.runtimeType}');
      if (mounted) setState(() => _unusable = true);
    }
  }

  /// A new viewport side starts again from the middle of the photo, with a
  /// new controller: the viewer listens to the old one until it rebuilds.
  void _fit(double side, ui.Image image) {
    if (side == _viewportSide) return;
    _viewportSide = side;
    final cover = side / math.min(image.width, image.height);
    final old = _transform;
    _transform = TransformationController(
      Matrix4.translationValues(
        -(image.width * cover - side) / 2,
        -(image.height * cover - side) / 2,
        0,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _upload() async {
    final image = _image;
    final side = _viewportSide;
    if (image == null || side == null || _uploading) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final announcer = Announcer.of(context);
    setState(() {
      _uploading = true;
      _error = null;
    });
    String? error;
    Uint8List? png;
    try {
      png = await encodeSquareAvatar(
        image,
        cropInViewport(
          transform: _transform.value,
          viewportSide: side,
          imageWidth: image.width,
          imageHeight: image.height,
        ),
      );
    } on Object catch (failure) {
      _log.warning('Preparing the avatar failed: ${failure.runtimeType}');
      error = l10n.avatarImageUnusable;
    }
    if (png != null) {
      try {
        await widget.onUpload(png);
      } on Object catch (failure) {
        error = avatarUploadFailureText(l10n, failure);
      }
    }
    if (!mounted) return;
    if (error == null) {
      navigator.pop(true);
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
    announcer.say(error);
    setState(() {
      _uploading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final image = _image;
    return PopScope(
      canPop: !_uploading,
      child: Scaffold(
        appBar: AppBar(
          title: ScreenTitle(l10n.avatarCropTitle),
          actions: [
            AppBarTextAction(
              onPressed: image == null || _uploading
                  ? null
                  : () => unawaited(_upload()),
              child: Text(
                _uploading ? l10n.avatarUploading : l10n.avatarCropUpload,
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: _uploading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(4),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        body: SafeArea(
          child: switch ((image, _unusable)) {
            (_, true) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.avatarImageUnusable,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            (final image?, _) => LayoutBuilder(
              builder: (context, constraints) {
                final side = math.max<double>(
                  64,
                  math.min(
                    constraints.maxWidth - 32,
                    constraints.maxHeight * 0.6,
                  ),
                );
                _fit(side, image);
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Semantics(
                      image: true,
                      label: l10n.avatarCropTitle,
                      child: _SquareViewer(
                        image: image,
                        side: side,
                        transform: _transform,
                        enabled: !_uploading,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.avatarCropHint,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_error case final error?)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  error,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            _ => Center(child: LoadingPlaceholder(label: l10n.avatarCropTitle)),
          },
        ),
      ),
    );
  }
}

/// The photo covering a square of [side] at the lowest zoom, so the square
/// is never left partly empty; a circle shows the part the app draws.
class _SquareViewer extends StatelessWidget {
  const new({
    required this.image,
    required this.side,
    required this.transform,
    required this.enabled,
  });

  final ui.Image image;
  final double side;
  final TransformationController transform;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cover = side / math.min(image.width, image.height);
    // Never closer than 128 of the photo's pixels across the square.
    final maxZoom = math
        .max(1, math.min(8, math.min(image.width, image.height) / 128))
        .toDouble();
    return SizedBox.square(
      dimension: side,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: transform,
            constrained: false,
            minScale: 1,
            maxScale: maxZoom,
            panEnabled: enabled,
            scaleEnabled: enabled,
            child: SizedBox(
              width: image.width * cover,
              height: image.height * cover,
              child: RawImage(image: image, fit: BoxFit.fill),
            ),
          ),
          const IgnorePointer(child: CustomPaint(painter: _CircleGuide())),
        ],
      ),
    );
  }
}

class _CircleGuide extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Path()..addOval(rect);
    canvas
      ..drawPath(
        Path.combine(PathOperation.difference, Path()..addRect(rect), circle),
        Paint()..color = const Color(0x66000000),
      )
      ..drawPath(
        circle,
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_CircleGuide oldDelegate) => false;
}
