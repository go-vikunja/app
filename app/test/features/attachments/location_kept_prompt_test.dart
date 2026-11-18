import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/attachments/presentation/location_kept_prompt.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('picked');
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  PickedFile picked(String name, {bool keptLocation = false}) {
    final path = p.join(directory.path, name);
    File(path).writeAsStringSync(name);
    return PickedFile(path: path, name: name, keptLocation: keptLocation);
  }

  test('with no one to ask, a file that kept its location is left out and '
      'its copy deleted; the others go', () async {
    final kept = picked('kept.jpg', keptLocation: true);
    final clean = picked('clean.jpg');

    final files = await withoutUnwantedLocations(null, [kept, clean]);

    expect(files, [clean]);
    expect(File(kept.path).existsSync(), isFalse);
    expect(File(clean.path).existsSync(), isTrue);
  });

  test('files that all lost their location go without a question', () async {
    final files = [picked('a.jpg'), picked('b.pdf')];

    expect(await withoutUnwantedLocations(null, files), files);
  });
}
