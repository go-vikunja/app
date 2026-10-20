import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart' hide PickedFile;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/attachments/application/channel_document_picker.dart';

/// [AttachmentPicker] through file_selector (the document picker; on
/// Android the app's own [documents] instead) and image_picker (the photo
/// picker and the camera).
final class PluginAttachmentPicker implements AttachmentPicker {
  new({this.documents, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final ChannelDocumentPicker? documents;
  final DateTime Function() _now;

  static const _images = XTypeGroup(
    label: 'images',
    mimeTypes: ['image/*'],
    uniformTypeIdentifiers: ['public.image'],
  );

  // file_selector copies whatever was picked; one above the limit is
  // refused when it is queued.
  @override
  Future<PickedFiles> pickFiles({
    required int maxBytes,
    bool imagesOnly = false,
    bool multiple = true,
  }) async {
    if (documents case final documents?) {
      return await documents.pick(
        maxBytes: maxBytes,
        imagesOnly: imagesOnly,
        multiple: multiple,
      );
    }
    final groups = imagesOnly ? const [_images] : const <XTypeGroup>[];
    final files = multiple
        ? await openFiles(acceptedTypeGroups: groups)
        : [?await openFile(acceptedTypeGroups: groups)];
    return PickedFiles(files: files.map(_picked).toList());
  }

  // Without the full metadata the photo picker needs no library permission
  // on iOS.
  @override
  Future<List<PickedFile>> pickPhotos({
    bool imagesOnly = false,
    bool multiple = true,
  }) async {
    final picker = ImagePicker();
    final List<XFile> files;
    if (imagesOnly) {
      files = multiple
          ? await picker.pickMultiImage(requestFullMetadata: false)
          : [
              ?await picker.pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              ),
            ];
    } else {
      files = multiple
          ? await picker.pickMultipleMedia(requestFullMetadata: false)
          : [?await picker.pickMedia(requestFullMetadata: false)];
    }
    return files.map(_picked).toList();
  }

  @override
  Future<PickedFile?> takePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return PickedFile(
      path: file.path,
      name: cameraFileName(file.path, takenAt: _now()),
      mimeType: file.mimeType ?? mediaTypeOf(file.path),
    );
  }

  static PickedFile _picked(XFile file) => PickedFile(
    path: file.path,
    name: file.name,
    mimeType: file.mimeType ?? mediaTypeOf(file.path),
  );
}

/// A camera shot's name the way cameras write it, `IMG_20261020_143005.jpg`,
/// instead of the picker's random temporary name.
String cameraFileName(String path, {required DateTime takenAt}) {
  final extension = p.extension(path);
  return 'IMG_${DateFormat('yyyyMMdd_HHmmss').format(takenAt)}'
      '${extension.isEmpty ? '.jpg' : extension.toLowerCase()}';
}

/// The type of a photo or video by its extension, for pickers that name
/// none: the icon of a queued file needs it.
String? mediaTypeOf(String path) => switch (p.extension(path).toLowerCase()) {
  '.jpg' || '.jpeg' => 'image/jpeg',
  '.png' => 'image/png',
  '.gif' => 'image/gif',
  '.webp' => 'image/webp',
  '.bmp' => 'image/bmp',
  '.heic' => 'image/heic',
  '.heif' => 'image/heif',
  '.mp4' => 'video/mp4',
  '.mov' => 'video/quicktime',
  '.3gp' => 'video/3gpp',
  '.webm' => 'video/webm',
  '.mkv' => 'video/x-matroska',
  _ => null,
};
