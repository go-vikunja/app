import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/platform/backup_exclusion.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/core/storage/draft_files.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late Directory directory;
  late DraftFiles files;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('drafts');
    addTearDown(() => directory.deleteSync(recursive: true));
    files = DraftFiles(
      directory: () async => Directory(p.join(directory.path, 'a', 'b')),
    );
  });

  test('a value comes back from its file, replaced whole, and is gone once '
      'removed', () async {
    expect(await files.getString('comment_drafts.abc'), isNull);

    await files.setString('comment_drafts.abc', '{"1":{}}');
    await files.setString('comment_drafts.abc', '{"2":{}}');
    await files.setString('description_editor.drafts', '[]');

    expect(await files.getString('comment_drafts.abc'), '{"2":{}}');
    expect(
      [
        for (final entry in directory.listSync(recursive: true))
          if (entry is File) p.basename(entry.path),
      ]..sort(),
      ['comment_drafts.abc.json', 'description_editor.drafts.json'],
    );

    await files.remove('comment_drafts.abc');
    await files.remove('comment_drafts.abc');
    expect(await files.getString('comment_drafts.abc'), isNull);
    expect(await files.getString('description_editor.drafts'), '[]');
  });

  test('a key that is not a plain name is refused', () async {
    for (final key in ['', '../x', 'a/b', '.hidden']) {
      await expectLater(
        files.setString(key, 'x'),
        throwsArgumentError,
        reason: key,
      );
    }
    expect(directory.listSync(), isEmpty);
  });

  test('the drafts live in the accounts folder, which stays out of iOS '
      'backups, beside no account', () async {
    Future<Directory> support() async => Directory('/support-marker');
    final excluded = <String>[];

    await excludeAppDataFromBackup(
      exclusion: _RecordingExclusion(excluded),
      supportDirectory: support,
      widgetsDirectory: () async => null,
    );
    final drafts = await draftsDirectory(supportDirectory: support);

    expect(p.isWithin(excluded.single, drafts.path), isTrue);
    expect(p.basename(drafts.path), contains('.'));
  });

  test('the comment and description drafts go to the draft files, never to '
      'the preferences, which iOS backs up', () async {
    final preferences = MemoryPreferencesStore();
    final drafts = MemoryPreferencesStore();
    final container = ProviderContainer.test(
      overrides: [
        preferencesStoreProvider.overrideWithValue(preferences),
        draftStoreProvider.overrideWithValue(drafts),
      ],
    );

    await container
        .read(commentDraftsProvider)
        .save(
          const CommentComposerDraft(text: 'Half written'),
          account: 'a',
          taskId: 3,
        );
    await container
        .read(descriptionDraftsProvider)
        .save(
          const DescriptionDraft(html: '<p>Half written</p>', base: ''),
          account: 'a',
          target: const TaskDescriptionTarget(3),
        );

    expect(preferences.values, isEmpty);
    expect(
      drafts.values.keys,
      unorderedEquals([CommentDrafts.keyFor('a'), DescriptionDrafts.key]),
    );
    expect(
      ProviderContainer.test().read(draftStoreProvider),
      isA<DraftFiles>(),
    );
  });
}

final class _RecordingExclusion implements BackupExclusion {
  new(this._paths);

  final List<String> _paths;

  @override
  Future<void> exclude(List<String> paths) async => _paths.addAll(paths);
}
