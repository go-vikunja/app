import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/load_queue.dart';
import 'package:vikunja_mobile/core/auth/failed_without_token.dart';
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

  /// The cache answers only images it can draw; another [AttachmentImages]
  /// may still answer an original that is no image, and SVG is never
  /// decoded.
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
      AttachmentNotAnImage() => l10n.richTextImageUnsupported,
      _ when failedOnTheNetwork(failure) => l10n.richTextImageOffline,
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
    this.queued = false,
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

  /// Waits its turn among the inline images, a few of which load at a time.
  final bool queued;

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

  late final LoadQueue _queue;
  QueuedLoad<AttachmentImage>? _turn;

  @override
  void initState() {
    super.initState();
    _queue = ref.read(inlineImageQueueProvider);
  }

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
    _turn?.cancel();
    _turn = null;
    final (_, taskId, attachmentId, preview) = key;
    final cached = images.peek(taskId, attachmentId, preview: preview);
    if (cached != null) {
      _state = AttachmentImageLoaded(cached);
      return;
    }
    _state = const AttachmentImageLoading();
    final Future<AttachmentImage> loading;
    if (widget.queued && !_remembers(images)) {
      final turn = _turn = _queue.add(
        (cancel) =>
            images.load(taskId, attachmentId, preview: preview, cancel: cancel),
      );
      loading = turn.result;
    } else {
      loading = images.load(taskId, attachmentId, preview: preview);
    }
    unawaited(
      loading
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
  void dispose() {
    _turn?.cancel();
    super.dispose();
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
/// size, loaded in its turn; a tap shows the original full screen. One
/// past the text's share, or one the server has no preview of that its
/// task's list does not name as a small image, waits for a tap on Load
/// image; a file the list names as no image is never asked for.
class InlineAttachmentImage extends ConsumerStatefulWidget {
  const new({
    required this.attachment,
    this.description = '',
    this.listed,
    this.deferred = false,
    super.key,
  });

  final AttachmentRef attachment;

  /// The image's alt text or title; may be empty.
  final String description;

  /// The attachment as its task's list names it; null when there is no
  /// list or it is not on it.
  final TaskAttachment? listed;

  /// Past the share of the text's images that load by themselves.
  final bool deferred;

  @override
  ConsumerState<InlineAttachmentImage> createState() =>
      _InlineAttachmentImageState();
}

class _InlineAttachmentImageState extends ConsumerState<InlineAttachmentImage> {
  static const _maxHeight = 400.0;

  /// The user tapped Load image.
  var _asked = false;

  void _ask() => setState(() => _asked = true);

  String _label(AppLocalizations l10n) =>
      widget.description.isNotEmpty ? widget.description : l10n.richTextImage;

  @override
  void didUpdateWidget(InlineAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A tap loads that one image, not another the text puts here later.
    if (oldWidget.attachment != widget.attachment) _asked = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const xl = AttachmentPreviewSize.extraLarge;
    final AttachmentRef(taskId: t, attachmentId: a) = widget.attachment;
    final images = ref.watch(attachmentImagesProvider);
    final label = _label(l10n);
    if (widget.listed case final listed? when listsNoImage(listed)) {
      return _ImageNotice(
        text: l10n.richTextImageUnsupported,
        icon: Icons.image_not_supported_outlined,
      );
    }
    if (widget.deferred && !_asked && images?.peek(t, a, preview: xl) == null) {
      return _LoadImageNotice(label: label, onTap: _ask);
    }
    return AttachmentImageLoader(
      taskId: t,
      attachmentId: a,
      preview: xl,
      queued: true,
      builder: (context, state, retry) => switch (state) {
        AttachmentImageFailed(:final failure)
            when isNoAttachmentPreview(failure) =>
          _asked ||
                  originalStandsIn(widget.listed) ||
                  images?.peek(t, a) != null
              ? AttachmentImageLoader(
                  taskId: t,
                  attachmentId: a,
                  preview: null,
                  queued: true,
                  builder: _shown,
                )
              : _LoadImageNotice(label: label, onTap: _ask),
        _ => _shown(context, state, retry),
      },
    );
  }

  Widget _shown(
    BuildContext context,
    AttachmentImageState state,
    VoidCallback retry,
  ) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final attachment = widget.attachment;
    final label = _label(l10n);
    void open() => unawaited(
      showAttachmentImage(
        context,
        taskId: attachment.taskId,
        attachmentId: attachment.attachmentId,
        description: widget.description,
      ),
    );
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
      AttachmentImageFailed(:final failure) => _ImageNotice(
        text: attachmentImageFailureText(l10n, failure),
        icon: switch (failure) {
          _ when failedOnTheNetwork(failure) => Icons.cloud_off_outlined,
          AttachmentImageTooLarge() ||
          AttachmentNotAnImage() => Icons.image_not_supported_outlined,
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
  }
}

/// Stands in for an attachment image the app does not load by itself; a
/// tap loads it.
class _LoadImageNotice extends StatelessWidget {
  const new({required this.label, required this.onTap});

  /// The image's description, else "Image".
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      label: label,
      hint: l10n.richTextLoadImage,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
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
                    l10n.richTextLoadImage,
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
