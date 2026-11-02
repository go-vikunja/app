import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_viewer.dart';

final _log = Logger('AttachmentImage');

sealed class AttachmentImageState {
  const new();
}

final class AttachmentImageLoading extends AttachmentImageState {
  const new();
}

final class AttachmentImageLoaded extends AttachmentImageState {
  const new(this.image);

  final AttachmentImage image;

  /// An original, which servers before 2.7.1 also send for a preview of
  /// what they cannot preview, may be no image at all; SVG is never decoded.
  bool get drawable => image.contentType.startsWith('image/') && !image.isSvg;
}

final class AttachmentImageFailed extends AttachmentImageState {
  const new(this.failure);

  final Object failure;

  /// Asking again may bring it, e.g. once the connection is back.
  bool get mayPass => attachmentImageFailureMayPass(failure);
}

/// What a failed attachment image says, as the user reads it.
String attachmentImageFailureText(AppLocalizations l10n, Object failure) =>
    switch (failure) {
      AttachmentImageTooLarge() => l10n.richTextImageUnsupported,
      NetworkFailure() => l10n.richTextImageOffline,
      _ => l10n.richTextImageFailed,
    };

/// Loads one attachment image of the active account, at [preview] size or
/// the original, and builds what is to show of it; `retry` asks again
/// after a failure that may pass. A failure the cache forgot (its Retry,
/// or the memory expired) is asked again on the next build.
class AttachmentImageLoader extends ConsumerStatefulWidget {
  const new({
    required this.taskId,
    required this.attachmentId,
    required this.preview,
    required this.builder,
    super.key,
  });

  final int taskId;
  final int attachmentId;
  final AttachmentPreviewSize? preview;
  final Widget Function(
    BuildContext context,
    AttachmentImageState state,
    VoidCallback retry,
  )
  builder;

  @override
  ConsumerState<AttachmentImageLoader> createState() =>
      _AttachmentImageLoaderState();
}

class _AttachmentImageLoaderState extends ConsumerState<AttachmentImageLoader> {
  (AttachmentImages, int, int, AttachmentPreviewSize?)? _requested;
  AttachmentImageState _state = const AttachmentImageLoading();
  var _request = 0;

  // Only a failure the cache remembered is asked again once it forgets
  // it; one it never remembered would be asked again on every build.
  var _failureRemembered = false;

  bool _remembers(AttachmentImages images) => images.remembersFailure(
    widget.taskId,
    widget.attachmentId,
    preview: widget.preview,
  );

  void _load(AttachmentImages images) {
    final key = (images, widget.taskId, widget.attachmentId, widget.preview);
    final forgotten =
        _state is AttachmentImageFailed &&
        _failureRemembered &&
        !_remembers(images);
    if (key == _requested && !forgotten) return;
    _requested = key;
    final request = ++_request;
    final cached = images.peek(
      widget.taskId,
      widget.attachmentId,
      preview: widget.preview,
    );
    if (cached != null) {
      _state = AttachmentImageLoaded(cached);
      return;
    }
    _state = const AttachmentImageLoading();
    unawaited(
      images
          .load(widget.taskId, widget.attachmentId, preview: widget.preview)
          .then<AttachmentImageState>(
            AttachmentImageLoaded.new,
            onError: (Object error) {
              _log.fine(
                'Loading an attachment image failed: '
                '${error.runtimeType}',
              );
              return AttachmentImageFailed(error);
            },
          )
          .then((state) {
            if (!mounted || request != _request) return;
            _failureRemembered =
                state is AttachmentImageFailed && _remembers(images);
            setState(() => _state = state);
          }),
    );
  }

  void _retry() {
    ref
        .read(attachmentImagesProvider)
        ?.forgetFailure(
          widget.taskId,
          widget.attachmentId,
          preview: widget.preview,
        );
    if (mounted) setState(() => _requested = null);
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(attachmentImagesProvider);
    if (images == null) {
      return widget.builder(
        context,
        AttachmentImageFailed(StateError('No account is signed in')),
        _retry,
      );
    }
    _load(images);
    return widget.builder(context, _state, _retry);
  }
}

/// Decodes no wider than the screen needs; null before the window has a
/// size.
int? decodeWidthFor(BuildContext context, {double factor = 1}) {
  final width =
      (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context) *
              factor)
          .round();
  return width > 0 ? width : null;
}

/// An attachment image inside a description or comment, at the preview
/// size; a tap shows the original full screen. What the server has no
/// preview of shows as its original, which older servers send in its place.
class InlineAttachmentImage extends StatelessWidget {
  const new({required this.attachment, this.description = '', super.key})
    : _preview = AttachmentPreviewSize.extraLarge;

  const new _original({required this.attachment, required this.description})
    : _preview = null;

  final AttachmentRef attachment;

  /// The image's alt text or title; may be empty.
  final String description;
  final AttachmentPreviewSize? _preview;

  static const _maxHeight = 400.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return AttachmentImageLoader(
      taskId: attachment.taskId,
      attachmentId: attachment.attachmentId,
      preview: _preview,
      builder: (context, state, retry) {
        void open() => unawaited(
          showAttachmentImage(
            context,
            taskId: attachment.taskId,
            attachmentId: attachment.attachmentId,
            description: description,
          ),
        );
        final label = description.isNotEmpty ? description : l10n.richTextImage;
        return switch (state) {
          AttachmentImageLoaded(:final image) when state.drawable => Semantics(
            image: true,
            button: true,
            label: label,
            hint: l10n.richTextShowImage,
            excludeSemantics: true,
            onTap: open,
            child: GestureDetector(
              onTap: open,
              child: ConstrainedBox(
                // A tap target also while the image decodes.
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                  maxHeight: _maxHeight,
                ),
                child: Image.memory(
                  image.bytes,
                  cacheWidth: decodeWidthFor(context),
                  fit: BoxFit.contain,
                  alignment: AlignmentDirectional.centerStart,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => _ImageNotice(
                    text: l10n.richTextImageUnsupported,
                    icon: Icons.image_not_supported_outlined,
                  ),
                ),
              ),
            ),
          ),
          AttachmentImageLoaded() => _ImageNotice(
            text: l10n.richTextImageUnsupported,
            icon: Icons.image_not_supported_outlined,
          ),
          AttachmentImageFailed(:final failure)
              when _preview != null && isNoAttachmentPreview(failure) =>
            InlineAttachmentImage._original(
              attachment: attachment,
              description: description,
            ),
          AttachmentImageFailed(:final failure) => _ImageNotice(
            text: attachmentImageFailureText(l10n, failure),
            icon: switch (failure) {
              NetworkFailure() => Icons.cloud_off_outlined,
              AttachmentImageTooLarge() => Icons.image_not_supported_outlined,
              _ => Icons.broken_image_outlined,
            },
            onRetry: state.mayPass ? retry : null,
          ),
          AttachmentImageLoading() => Semantics(
            image: true,
            label: label,
            child: Container(
              width: 160,
              height: 120,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
          ),
        };
      },
    );
  }
}

/// Why an image does not show; a tap asks again when [onRetry] is set.
class _ImageNotice extends StatelessWidget {
  const new({
    required this.text,
    this.icon = Icons.broken_image_outlined,
    this.onRetry,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final notice = Container(
      constraints: BoxConstraints(minHeight: onRetry == null ? 0 : 48),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.refresh, size: 20, color: colors.primary),
          ],
        ],
      ),
    );
    if (onRetry == null) return notice;
    return Semantics(
      button: true,
      label: text,
      hint: context.l10n.retry,
      excludeSemantics: true,
      onTap: onRetry,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(8),
          child: notice,
        ),
      ),
    );
  }
}

/// A square preview for the attachments list; an icon until it has loaded
/// and when there is none to draw.
class AttachmentThumbnail extends StatelessWidget {
  const new({
    required this.taskId,
    required this.attachmentId,
    required this.fallbackIcon,
    this.size = 48,
    super.key,
  });

  final int taskId;
  final int attachmentId;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) => AttachmentImageLoader(
    taskId: taskId,
    attachmentId: attachmentId,
    preview: AttachmentPreviewSize.medium,
    builder: (context, state, _) {
      final icon = AttachmentIcon(icon: fallbackIcon, size: size);
      return switch (state) {
        AttachmentImageLoaded(:final image) when state.drawable => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            image.bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context) * 2)
                .round(),
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) => icon,
          ),
        ),
        _ => icon,
      };
    },
  );
}

class AttachmentIcon extends StatelessWidget {
  const new({required this.icon, this.size = 48, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: colors.onSecondaryContainer),
    );
  }
}

/// An image on another site, which the app never loads by itself: a link
/// that names the site and opens the image in the browser.
class ExternalImagePlaceholder extends StatelessWidget {
  const new({required this.url, required this.onOpen, super.key});

  final Uri url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = l10n.richTextImageFrom(url.host);
    return Semantics(
      link: true,
      label: text,
      hint: l10n.richTextOpensInBrowser,
      excludeSemantics: true,
      onTap: onOpen,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
