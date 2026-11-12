import 'dart:io';

import '../helpers/source_sites.dart';

/// The calls that open a dialog, a sheet, a picker or a menu, or a page
/// pushed with the Navigator, which the route walk does not see.
final RegExp overlayCall = RegExp(
  r'\b(showAdaptiveDialog|showDialog|showModalBottomSheet|showCupertinoSheet'
  '|showReadableCupertinoSheet|showCupertinoModalPopup|showDatePicker'
  '|showTimePicker|showMenu'
  '|MenuAnchor|PopupMenuButton|MaterialPageRoute|CupertinoPageRoute'
  r'|PageRouteBuilder)\b\s*(?:<.*?>)?\(',
);

/// One call of [overlayCall] in `app/lib`.
final class OverlaySite {
  const new({required this.key, required this.location});

  /// `<path under lib> <enclosing declaration> <call>`, with `#2` and on
  /// for a repeated call in one declaration; stable when lines move.
  final String key;

  /// `<path under lib>:<line>`, for the failure message.
  final String location;
}

/// Every overlay call under [lib], in file order. The app's own presenter
/// around one of the calls is declared, not called.
List<OverlaySite> scanOverlaySites(Directory lib) {
  final counts = <String, int>{};
  final sites = <OverlaySite>[];
  for (final site in scanSourceSites(
    lib,
    overlayCall,
    skip: declaresTopLevel,
  )) {
    final base = '${site.path} ${site.enclosing} ${site.name}';
    final count = counts[base] = (counts[base] ?? 0) + 1;
    sites.add(
      OverlaySite(
        key: count == 1 ? base : '$base#$count',
        location: site.location,
      ),
    );
  }
  return sites;
}
