import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
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
}
