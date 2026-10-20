import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';

/// The system pickers without a platform: [files], [photos] and [camera]
/// are what the user picks (empty or null: cancelled), [tooLargeFiles] the
/// files the document picker leaves uncopied, [failure] is thrown instead
/// while set. Every call is recorded in [calls] (`files`, `photos`,
/// `camera`, with ` images` and ` single` when asked so), the limit of
/// each document pick in [maxBytes].
final class FakeAttachmentPicker implements AttachmentPicker {
  List<PickedFile> files = [];
  List<String> tooLargeFiles = [];
  List<PickedFile> photos = [];
  PickedFile? camera;
  Exception? failure;
  final List<String> calls = [];
  final List<int> maxBytes = [];

  Override get providerOverride =>
      attachmentPickerProvider.overrideWithValue(this);

  @override
  Future<PickedFiles> pickFiles({
    required int maxBytes,
    bool imagesOnly = false,
    bool multiple = true,
  }) async {
    this.maxBytes.add(maxBytes);
    _record('files', imagesOnly: imagesOnly, multiple: multiple);
    return PickedFiles(
      files: multiple ? files : files.take(1).toList(),
      tooLarge: tooLargeFiles,
    );
  }

  @override
  Future<List<PickedFile>> pickPhotos({
    bool imagesOnly = false,
    bool multiple = true,
  }) async {
    _record('photos', imagesOnly: imagesOnly, multiple: multiple);
    return multiple ? photos : photos.take(1).toList();
  }

  @override
  Future<PickedFile?> takePhoto() async {
    _record('camera', imagesOnly: false, multiple: true);
    return camera;
  }

  void _record(
    String call, {
    required bool imagesOnly,
    required bool multiple,
  }) {
    calls.add(
      [call, if (imagesOnly) 'images', if (!multiple) 'single'].join(' '),
    );
    if (failure case final failure?) throw failure;
  }
}
