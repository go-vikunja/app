import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/core/avatar/avatar_cache.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAj'
  'CB0C8AAAAASUVORK5CYII=',
);

AvatarImage _image(List<int> bytes) =>
    AvatarImage(bytes: Uint8List.fromList(bytes), contentType: 'image/png');

void main() {
  group('evict', () {
    test('forgets every size of the user and asks again', () async {
      var version = 1;
      final requests = <(String, int)>[];
      final cache = AvatarCache((username, size) async {
        requests.add((username, size));
        return _image([..._png, version]);
      });
      await cache.load('anna', 32);
      await cache.load('anna', 64);
      await cache.load('ben', 32);

      version = 2;
      cache.evict('anna');

      expect(cache.peek('anna', 32), isNull);
      expect(cache.peek('anna', 64), isNull);
      expect(cache.peek('ben', 32), isNotNull);
      expect((await cache.load('anna', 32)).bytes!.last, 2);
      expect(requests, [('anna', 32), ('anna', 64), ('ben', 32), ('anna', 32)]);
    });

    test('an answer that was on its way is not kept, and a later load does '
        'not join it', () async {
      final answers = <Completer<AvatarImage>>[];
      final cache = AvatarCache((username, size) {
        final answer = Completer<AvatarImage>();
        answers.add(answer);
        return answer.future;
      });

      final old = cache.load('anna', 32);
      cache.evict('anna');
      final fresh = cache.load('anna', 32);
      answers[0].complete(_image([..._png, 1]));
      await old;
      expect(cache.peek('anna', 32), isNull);

      answers[1].complete(_image([..._png, 2]));
      expect((await fresh).bytes!.last, 2);
      expect(cache.peek('anna', 32)?.bytes!.last, 2);
      expect(answers, hasLength(2));
    });

    test('a failure that may pass is asked again at once', () async {
      var fail = true;
      var requests = 0;
      final cache = AvatarCache((username, size) async {
        requests++;
        if (fail) throw const NetworkFailure(NetworkProblem.unreachable);
        return _image(_png);
      });
      expect((await cache.load('anna', 32)).bytes, isNull);

      fail = false;
      cache.evict('anna');

      expect((await cache.load('anna', 32)).bytes, isNotNull);
      expect(requests, 2);
    });

    test('bumps the generation and announces the user', () async {
      final cache = AvatarCache((username, size) async => _image(_png));
      final evicted = <String>[];
      final subscription = cache.evictions.listen(evicted.add);
      addTearDown(subscription.cancel);

      expect(cache.generationOf('anna'), 0);
      cache
        ..evict('anna')
        ..evict('anna');

      expect(cache.generationOf('anna'), 2);
      expect(cache.generationOf('ben'), 0);
      expect(evicted, ['anna', 'anna']);
    });
  });

  group('noteUpdated', () {
    test('remembers the first time, evicts when it changes, and not for the '
        'time an evict named', () async {
      final cache = AvatarCache((username, size) async => _image(_png));
      final first = DateTime.utc(2026, 10, 20, 9);
      final second = first.add(const Duration(minutes: 1));
      final third = second.add(const Duration(minutes: 1));

      cache
        ..noteUpdated('anna', first)
        ..noteUpdated('anna', first);
      expect(cache.generationOf('anna'), 0);

      cache.noteUpdated('anna', second);
      expect(cache.generationOf('anna'), 1);

      cache
        ..evict('anna', updated: third)
        ..noteUpdated('anna', third);
      expect(cache.generationOf('anna'), 2);
    });
  });

  test('avatarGeneration follows the evictions of its user', () async {
    final cache = AvatarCache((username, size) async => _image(_png));
    final container = ProviderContainer(
      overrides: [accountAvatarCacheProvider.overrideWith((ref, _) => cache)],
    );
    addTearDown(container.dispose);
    final generations = <int>[];
    container.listen(
      avatarGenerationProvider('account', 'anna'),
      (_, next) => generations.add(next),
      fireImmediately: true,
    );

    cache
      ..evict('ben')
      ..evict('anna');
    await pumpEventQueue();

    expect(generations, [0, 1]);
  });

  group('on disk', () {
    const offline = NetworkFailure(NetworkProblem.unreachable);
    late Directory folder;
    late DateTime now;

    ImageDiskCache disk() => ImageDiskCache(() async => folder);

    List<String> files() =>
        folder.existsSync() ? [...folder.listSync().map((f) => f.path)] : [];

    setUp(() {
      folder = Directory.systemTemp.createTempSync('avatar_disk_test');
      addTearDown(() => folder.deleteSync(recursive: true));
      now = DateTime.utc(2026, 11, 19, 12);
    });

    test('an avatar from the server is shown offline after a restart, and '
        'asked for again once the retry is due', () async {
      final online = disk();
      await AvatarCache(
        (username, size) async => _image(_png),
        disk: online,
      ).load('anna', 32);
      await online.flush();

      var requests = 0;
      var reachable = false;
      final cache = AvatarCache(
        (username, size) async {
          requests++;
          if (!reachable) throw offline;
          return _image([..._png, 2]);
        },
        disk: disk(),
        now: () => now,
      );
      final kept = await cache.load('anna', 32);

      expect(kept.bytes, _png);
      expect(cache.peek('anna', 32)?.bytes, _png);
      expect((await cache.load('anna', 64)).bytes, isNull);

      reachable = true;
      now = now.add(cache.retryAfter);
      expect(cache.peek('anna', 32), isNull);
      expect((await cache.load('anna', 32)).bytes!.last, 2);
      expect(requests, 3);
    });

    test('an SVG answer drops the avatar kept before; a missing user drops '
        'it without reading it', () async {
      final online = disk();
      final first = AvatarCache(
        (username, size) async => _image(_png),
        disk: online,
      );
      await first.load('anna', 32);
      await first.load('ben', 32);
      await online.flush();
      expect(files(), hasLength(2));

      final cache = AvatarCache((username, size) async {
        if (username == 'ben') throw const NotFound(code: 1005);
        return AvatarImage(
          bytes: Uint8List.fromList(utf8.encode('<svg/>')),
          contentType: 'image/svg+xml',
        );
      }, disk: online);

      expect((await cache.load('anna', 32)).bytes, isNull);
      expect((await cache.load('ben', 32)).bytes, isNull);
      await online.flush();
      expect(files(), isEmpty);
    });

    test("evict drops every size of the user's avatar on disk, and an "
        'answer on its way is not kept', () async {
      final online = disk();
      final answer = Completer<AvatarImage>();
      final cache = AvatarCache((username, size) {
        if (size == 128) return answer.future;
        return Future.value(_image(_png));
      }, disk: online);
      await cache.load('anna', 32);
      await cache.load('anna', 64);
      await cache.load('ben', 32);
      final late = cache.load('anna', 128);

      cache.evict('anna');
      answer.complete(_image(_png));
      await late;
      await online.flush();

      expect(files(), hasLength(1));
      final offlineCache = AvatarCache(
        (username, size) async => throw offline,
        disk: disk(),
      );
      expect((await offlineCache.load('anna', 32)).bytes, isNull);
      expect((await offlineCache.load('ben', 32)).bytes, _png);
    });

    test('usernames of any kind are kept apart', () async {
      final usernames = ['anna', 'Anna', '../anna', 'ä nna@x', 'a' * 300];
      final online = disk();
      final cache = AvatarCache(
        (username, size) async =>
            _image([..._png, usernames.indexOf(username)]),
        disk: online,
      );
      for (final username in usernames) {
        await cache.load(username, 32);
      }
      await online.flush();

      final offlineCache = AvatarCache(
        (username, size) async => throw offline,
        disk: disk(),
      );
      for (final (index, username) in usernames.indexed) {
        expect((await offlineCache.load(username, 32)).bytes!.last, index);
      }
      expect(files(), hasLength(usernames.length));
    });

    Future<void> keepAnna(ImageDiskCache online) async {
      await AvatarCache(
        (username, size) async => _image(_png),
        disk: online,
      ).load('anna', 32);
      await online.flush();
    }

    test('the kept avatar stands in for every failure that may pass: a '
        'server error, an unexpected answer, a session problem', () async {
      final online = disk();
      await keepAnna(online);

      for (final failure in [
        const ServerFailure(502),
        const UnexpectedResponse(200, message: 'not an image: text/html'),
        const SessionEnded(SessionEndReason.expired),
        const TokenRejected(),
      ]) {
        final cache = AvatarCache(
          (username, size) async => throw failure,
          disk: disk(),
          now: () => now,
        );
        expect((await cache.load('anna', 32)).bytes, _png, reason: '$failure');
        expect(cache.untilRetry('anna', 32), cache.retryAfter);
      }
    });

    test('an answer that is no image, such as a login page in front of the '
        'server, is no new avatar: the kept one stays and stands in', () async {
      final online = disk();
      await keepAnna(online);
      final cache = AvatarCache(
        (username, size) async => AvatarImage(
          bytes: Uint8List.fromList(utf8.encode('<html>Sign in</html>')),
          contentType: 'text/html',
        ),
        disk: online,
        now: () => now,
      );

      expect((await cache.load('anna', 32)).bytes, _png);
      await online.flush();

      expect(files(), hasLength(1));
      expect(cache.untilRetry('anna', 32), cache.retryAfter);
    });

    test('an evict while the kept avatar is being read drops what was '
        'read', () async {
      await keepAnna(disk());
      final gate = Completer<int?>();
      final held = ImageDiskCache(
        () async => folder,
        pixelsOf: (_) => gate.future,
      );
      final blocking = held.write(
        'other',
        AttachmentImage(bytes: Uint8List(1), contentType: 'image/png'),
      );
      final cache = AvatarCache(
        (username, size) async => throw offline,
        disk: held,
      );

      final loading = cache.load('anna', 32);
      await Future<void>.delayed(Duration.zero);
      cache.evict('anna');
      gate.complete(1);
      await blocking;

      expect((await loading).bytes, isNull);
      expect(cache.peek('anna', 32), isNull);
    });
  });
}
