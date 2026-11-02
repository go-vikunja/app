import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/location_removal.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/features/attachments/application/channel_document_picker.dart';
import 'package:vikunja_mobile/features/attachments/application/plugin_attachment_picker.dart';

part 'attachment_picker.g.dart';

/// A file the user picked, as a copy the picker made in the app's cache,
/// which the app may move or delete. [name] is what the other app or the
/// photo library calls it.
@immutable
final class PickedFile {
  const new({required this.path, required this.name, this.mimeType});

  final String path;
  final String name;
  final String? mimeType;
}

/// What a pick came to: the copies, and by name the files left uncopied
/// because they are above the limit or could not be read.
@immutable
final class PickedFiles {
  const new({
    this.files = const [],
    this.tooLarge = const [],
    this.failed = const [],
  });

  final List<PickedFile> files;
  final List<String> tooLarge;
  final List<String> failed;

  bool get isEmpty => files.isEmpty && tooLarge.isEmpty && failed.isEmpty;
}

enum AttachmentSource { files, photos, camera }

/// The system's pickers; none of them needs a permission on Android. Each
/// answers nothing when the user cancels, and throws when the picker could
/// not open (no camera, a denied permission on iOS).
abstract interface class AttachmentPicker {
  /// Any files from the system's document picker, or only images; one
  /// known to be above [maxBytes] is not copied.
  Future<PickedFiles> pickFiles({
    required int maxBytes,
    bool imagesOnly = false,
    bool multiple = true,
  });

  /// Photos and videos from the photo picker, or only photos.
  Future<List<PickedFile>> pickPhotos({
    bool imagesOnly = false,
    bool multiple = true,
  });

  Future<PickedFile?> takePhoto();
}

extension PickFrom on AttachmentPicker {
  Future<PickedFiles> pick(
    AttachmentSource source, {
    required int maxBytes,
    bool imagesOnly = false,
    bool multiple = true,
  }) async => switch (source) {
    AttachmentSource.files => await pickFiles(
      maxBytes: maxBytes,
      imagesOnly: imagesOnly,
      multiple: multiple,
    ),
    AttachmentSource.photos => PickedFiles(
      files: await pickPhotos(imagesOnly: imagesOnly, multiple: multiple),
    ),
    AttachmentSource.camera => PickedFiles(files: [?await takePhoto()]),
  };
}

@Riverpod(keepAlive: true)
AttachmentPicker attachmentPicker(Ref ref) {
  final excursions = ref.watch(appExcursionsProvider);
  return PluginAttachmentPicker(
    documents: defaultTargetPlatform == TargetPlatform.android
        ? ChannelDocumentPicker(excursions: excursions)
        : null,
    excursions: excursions,
    locations: switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => PlatformLocationRemoval(),
      _ => null,
    },
  );
}
