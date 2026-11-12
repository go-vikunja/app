import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/source_sites.dart';
import 'guest_action_inventory.dart';
import 'guest_action_sites.dart';
import 'guest_gates_test.dart' show closedToGuests;

void main() {
  final lib = Directory('lib');

  test('every use of what a guest cannot use is gated for guests or open '
      'to them with a reason, so a new action has to decide', () {
    final sites = scanGuestActionSites(lib);
    final found = {for (final site in sites) site.key};
    final unlisted = [
      for (final site in sites)
        if (!guestActionInventory.containsKey(site.key)) _describe(site),
    ];
    final stale = [
      for (final key in guestActionInventory.keys)
        if (!found.contains(key)) key,
    ];
    final undecided = undecidedUses(sites, guestActionInventory);
    final unchecked = [
      for (final MapEntry(:key, value: (decision, uses: _))
          in guestActionInventory.entries)
        if (decision case Gated(:final checkIn))
          for (final file in checkIn.isEmpty ? [_pathOf(key)] : checkIn)
            if (!checksForGuests(lib, file)) '$key -> $file',
    ];
    final notClosed = [
      for (final MapEntry(:key, value: (decision, uses: _))
          in guestActionInventory.entries)
        if (decision case BehindClosedRoutes(:final routes))
          for (final route in routes)
            if (!closedToGuests.containsKey(route)) '$key -> $route',
    ];
    final blank = [
      for (final MapEntry(:key, value: (decision, uses: _))
          in guestActionInventory.entries)
        if (switch (decision) {
          Gated(:final how) => how.trim().isEmpty,
          BehindClosedRoutes(:final routes) => routes.isEmpty,
          Open(:final why) => why.trim().isEmpty,
        })
          key,
    ];

    expect(
      unlisted,
      isEmpty,
      reason:
          'add each site to guestActionInventory in '
          'test/app/guest_action_inventory.dart: Gated(how) when a guest '
          'check in its file, or in checkIn where the action is offered, '
          'keeps guests from it; BehindClosedRoutes when only routes closed '
          'to guests reach it; Open(why) when guests may use it. A provider '
          'that only passes a watched one on goes onto guestWatchedProviders '
          'instead',
    );
    expect(
      stale,
      isEmpty,
      reason:
          'entries of no site in guestActionInventory: remove them, or '
          'rename them after their declaration',
    );
    expect(
      undecided,
      isEmpty,
      reason:
          "listed sites whose watched names differ from their entry's uses: "
          'decide a new name (+) for guests as for a new site, in its '
          'declaration or in the entry, then put it into uses; take a name '
          'it no longer uses (-) out',
    );
    expect(
      unchecked,
      isEmpty,
      reason:
          'gated sites whose file shows no check of activeAccountIsGuest, '
          'accountIsGuest or isLinkShare',
    );
    expect(
      notClosed,
      isEmpty,
      reason: 'routes not in closedToGuests in test/app/guest_gates_test.dart',
    );
    expect(blank, isEmpty, reason: 'decisions without a reason');
  });

  test('the scan names each declaration apart, and skips a watched '
      "provider's use only inside the annotated declaration it is generated "
      'from', () {
    final probe = Directory.systemTemp.createTempSync('guest_sites');
    addTearDown(() => probe.deleteSync(recursive: true));
    void write(String path, String text) => (File(
      '${probe.path}/$path',
    )..createSync(recursive: true)).writeAsStringSync(text);
    write('core/providers.dart', r'''
@riverpod
Stream<int> unreadActivityCount(Ref ref) =>
    ref.watch(activityRepositoryProvider)!.watchUnreadCount();

@Riverpod(keepAlive: true)
class AccountSettings extends _$AccountSettings {
  @override
  Future<Settings> build() => ref.watch(accountSettingsRepositoryProvider).load();
}
''');
    write('core/providers.g.dart', '''
@ProviderFor(unreadActivityCount)
final unreadActivityCountProvider = UnreadActivityCountProvider._();

@ProviderFor(AccountSettings)
final accountSettingsProvider =
    AccountSettingsProvider._();
''');
    write('features/probe.dart', r'''
class UnreadActivityCount extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) =>
      Text('${ref.watch(unreadActivityCountProvider)}');
}

extension type ProbeId(int value) {
  void go() => ref.read(teamRepositoryProvider);
}

mixin class ProbeMixin {
  void go() => ref.read(teamRepositoryProvider);
}

extension on WidgetRef {
  void go() => read(teamRepositoryProvider);
}

extension on WidgetRef {
  void go() => read(teamRepositoryProvider);
}

class Probe {
  Probe() : x = ref.read(teamRepositoryProvider);

  factory Probe.make() => Probe._(ref.read(teamRepositoryProvider));
}
''');

    expect(
      [for (final site in scanGuestActionSites(probe)) site.key],
      [
        'features/probe.dart Probe.make',
        'features/probe.dart Probe.new',
        'features/probe.dart ProbeId.go',
        'features/probe.dart ProbeMixin.go',
        'features/probe.dart UnreadActivityCount.build',
        'features/probe.dart extension on WidgetRef #2.go',
        'features/probe.dart extension on WidgetRef.go',
      ],
    );
  });

  test('a watched name that comes into a listed declaration is undecided '
      "until its entry's uses take it, and one that leaves it too", () {
    final probe = Directory.systemTemp.createTempSync('guest_uses');
    addTearDown(() => probe.deleteSync(recursive: true));
    final file = File('${probe.path}/features/probe.dart')
      ..createSync(recursive: true);
    const key = 'features/probe.dart _ProbeState._addToTask';
    List<String> undecided(String body, Set<String> uses) {
      file.writeAsStringSync('class _ProbeState {\n$body}\n');
      return undecidedUses(scanGuestActionSites(probe), {
        key: (const Open('a task edit'), uses: uses),
      });
    }

    const listed = '''
  Future<void> _addToTask(TaskRepository repository, int id) async {
    await repository.updateDescription(id, 'shared');
  }
''';
    const withCall = '''
  Future<void> _addToTask(TaskRepository repository, int id) async {
    await repository.updateDescription(id, 'shared');
    await repository.setFavorite(id, favorite: true);
  }
''';
    const withProvider = '''
  Future<void> _addToTask(TaskRepository repository, int id) async {
    await repository.updateDescription(id, 'shared');
    ref.read(trashRepositoryProvider);
  }
''';
    const decided = {'updateDescription'};

    expect(undecided(listed, decided), isEmpty);
    expect(undecided(withCall, decided), [
      '$key +setFavorite at features/probe.dart:4',
    ]);
    expect(undecided(withProvider, decided), [
      '$key +trashRepositoryProvider at features/probe.dart:4',
    ]);
    expect(undecided(withCall, {...decided, 'setFavorite'}), isEmpty);
    expect(undecided(listed, {...decided, 'setFavorite'}), [
      '$key -setFavorite',
    ]);
  });

  test('the watch list names providers and calls that exist, so a rename '
      'cannot drop one from it', () {
    final declared = <String>{};
    final provider = RegExp(r'^final (\w+Provider) =', multiLine: true);
    final method = RegExp(r'^  [\w<>?, ]+ (\w+)\(', multiLine: true);
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith('.g.dart')) {
        declared.addAll([
          for (final match in provider.allMatches(file.readAsStringSync()))
            match.group(1)!,
        ]);
      }
    }
    for (final file in sourceFiles(lib)) {
      if (file.path.contains('/core/repositories/')) {
        declared.addAll([
          for (final match in method.allMatches(file.readAsStringSync()))
            match.group(1)!,
        ]);
      }
    }
    final watched = [
      for (final names in guestWatchedProviders.values) ...names,
      for (final names in guestWatchedFeatureProviders.values) ...names,
      for (final names in guestWatchedCalls.values) ...names,
    ];

    expect(
      [
        for (final name in watched)
          if (!declared.contains(name)) name,
      ],
      isEmpty,
      reason:
          'watched names with no generated provider in lib or no method in '
          'lib/core/repositories: rename them on the watch list',
    );
    expect(watched.toSet(), hasLength(watched.length));
  });
}

String _pathOf(String key) => key.substring(0, key.indexOf(' '));

String _describe(GuestActionSite site) {
  final uses = [
    for (final MapEntry(:key, :value) in site.locations.entries)
      '$key at ${value.join(', ')}',
  ];
  return '${site.key} (${uses.join('; ')})';
}
