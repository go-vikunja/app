import 'dart:io';

import '../helpers/source_sites.dart';
import 'guest_action_inventory.dart';

/// A declaration in `app/lib` that uses something on the watch list.
final class GuestActionSite {
  const new({required this.key, required this.locations});

  /// `<path under lib> <enclosing declaration>`; stable when lines move.
  final String key;

  /// Each provider and call of the watch list it uses, with the
  /// `<path under lib>:<line>` of each use, for the failure message.
  final Map<String, List<String>> locations;

  Set<String> get names => locations.keys.toSet();
}

RegExp _named(Map<String, List<String>> watched) =>
    RegExp('\\b(${watched.values.expand((names) => names).join('|')})\\b');

final RegExp _provider = _named(guestWatchedProviders);
final RegExp _featureProvider = _named(guestWatchedFeatureProviders);

final String _calls = guestWatchedCalls.values
    .expand((names) => names)
    .join('|');

/// An instance's call or tear-off; a type's member of the same name, such
/// as `TrashAction.restoreTask`, is not one.
final RegExp _call = RegExp(
  r'(?<!(?:^|[^\w$])[_$]*[A-Z][\w$]*)\.'
  '($_calls)\\b',
);

/// A call or tear-off on `this`, as in a mixin, an extension or a subclass;
/// a declaration of the name, such as a method's or an enum value's, is not
/// one.
final RegExp _ownCall = RegExp('(?<![\\w\$.])($_calls)\\b');

/// A use inside the declaration of a watched provider is that provider's
/// own wiring; its readers are sites themselves. The declaration around
/// the use is the provider's only when the annotation is right above it
/// and the `.g.dart` beside it generates the provider from it: a widget
/// or a function of the provider's name is no provider.
bool _declaresWatchedProvider(Directory lib, SourceSite use) {
  final (declared, provider, isClass) = switch (use.enclosing.split('.')) {
    [final function] => (function, '${function}Provider', false),
    [final notifier, 'build'] => (
      notifier,
      '${notifier[0].toLowerCase()}${notifier.substring(1)}Provider',
      true,
    ),
    _ => (null, '', false),
  };
  if (declared == null || !_watched.contains(provider)) return false;
  final generated = File(
    '${lib.path}/${use.path.replaceFirst(RegExp(r'\.dart$'), '.g.dart')}',
  );
  if (!generated.existsSync() ||
      !RegExp(
        '^@ProviderFor\\(${RegExp.escape(declared)}\\)\\s*'
        'final ${RegExp.escape(provider)} =',
        multiLine: true,
      ).hasMatch(generated.readAsStringSync())) {
    return false;
  }
  final lines = File('${lib.path}/${use.path}').readAsLinesSync();
  for (var at = use.line - 1; at > 0; at--) {
    final declares = isClass
        ? _class.firstMatch(lines[at])?.group(1) == declared
        : declaresTopLevel(lines[at], declared);
    if (declares) return _annotation.hasMatch(lines[at - 1]);
  }
  return false;
}

final _annotation = RegExp(r'^@(?:riverpod$|Riverpod\()');
final _class = RegExp(r'^(?:[a-z]+ )*class ([A-Za-z_$][\w$]*)');

final Set<String> _watched = {
  for (final names in guestWatchedProviders.values) ...names,
};

/// Every declaration under [lib] that uses a watched provider, or, under
/// `features/`, a watched feature provider or call; in file order.
List<GuestActionSite> scanGuestActionSites(Directory lib) {
  bool inFeatures(String path) => path.startsWith('features/');
  final uses =
      [
        ...scanSourceSites(lib, _provider),
        ...scanSourceSites(lib, _featureProvider, include: inFeatures),
        ...scanSourceSites(lib, _call, include: inFeatures),
        ...scanSourceSites(lib, _ownCall, include: inFeatures, skip: declares),
      ]..sort(
        (a, b) => a.path == b.path ? a.line - b.line : a.path.compareTo(b.path),
      );
  final sites = <String, GuestActionSite>{};
  for (final use in uses) {
    if (_declaresWatchedProvider(lib, use)) continue;
    final key = '${use.path} ${use.enclosing}';
    sites
        .putIfAbsent(key, () => GuestActionSite(key: key, locations: {}))
        .locations
        .putIfAbsent(use.name, () => [])
        .add(use.location);
  }
  return [...sites.values]..sort((a, b) => a.key.compareTo(b.key));
}

/// Each listed site whose watched names differ from the names its entry
/// in [inventory] decides: a name it adds as `+name at <locations>`, one
/// it no longer uses as `-name`.
List<String> undecidedUses(
  List<GuestActionSite> sites,
  Map<String, GuestActionEntry> inventory,
) => [
  for (final site in sites)
    if (inventory[site.key] case (_, :final uses)
        when !_sameNames(site.names, uses))
      [
        site.key,
        for (final name in site.names.difference(uses))
          '+$name at ${site.locations[name]!.join(', ')}',
        for (final name in uses.difference(site.names)) '-$name',
      ].join(' '),
];

bool _sameNames(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

final _guestCheck = RegExp(
  r'\b(activeAccountIsGuestProvider|accountIsGuestProvider|isLinkShare)\b',
);

/// Whether the file at [path] under [lib] asks whether an account is a
/// guest outside a comment.
bool checksForGuests(Directory lib, String path) {
  final file = File('${lib.path}/$path');
  if (!file.existsSync()) return false;
  return file.readAsLinesSync().any(
    (line) => !line.trimLeft().startsWith('//') && _guestCheck.hasMatch(line),
  );
}
