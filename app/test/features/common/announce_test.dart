import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';

import '../../helpers/announcer_region.dart';

void main() {
  const pageKey = Key('page');

  /// A page under the announcer's host, or without one with [host] false.
  Future<void> pump(WidgetTester tester, {bool host = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: host ? (context, child) => AnnouncerHost(child: child!) : null,
        home: const Scaffold(key: pageKey, body: Text('Page')),
      ),
    );
    await tester.pumpAndSettle();
  }

  BuildContext page(WidgetTester tester) => tester.element(find.byKey(pageKey));

  String? regionLabel(WidgetTester tester) => announcerRegion(tester)?.label;

  testWidgets('where the platform announces, it is asked and the live '
      'region stays empty', (tester) async {
    await pump(tester);

    announce(page(tester), 'Saved');
    await tester.pumpAndSettle();

    expect(tester.takeAnnouncements(), [isAccessibilityAnnouncement('Saved')]);
    expect(regionLabel(tester), '');
  });

  testWidgets('where it cannot, as on Android, the live region says it: a '
      'node a screen reader cannot focus or tap', (tester) async {
    useLiveRegionAnnouncements(tester);
    await pump(tester);

    announce(page(tester), 'Saved');
    await tester.pump();

    expect(tester.takeAnnouncements(), isEmpty);
    final region = announcerRegion(tester)!;
    expect(region.label, 'Saved');
    final data = region.getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    expect(data.flagsCollection.isAccessibilityFocusBlocked, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(region.rect.isEmpty, isFalse);
  });

  testWidgets('the same message twice is said twice: the label empties for '
      'a frame in between', (tester) async {
    useLiveRegionAnnouncements(tester);
    await pump(tester);
    final labels = <String?>[];
    Future<void> frame() async {
      await tester.pump();
      labels.add(regionLabel(tester));
    }

    announce(page(tester), 'Copied');
    await frame();
    announce(page(tester), 'Copied');
    await frame();
    await frame();
    announce(page(tester), 'Deleted');
    await frame();

    expect(labels, ['Copied', '', 'Copied', 'Deleted']);
  });

  testWidgets('the live region empties after a while, so a region built '
      'again later says nothing stale', (tester) async {
    useLiveRegionAnnouncements(tester);
    await pump(tester);

    announce(page(tester), 'Saved');
    await tester.pump();
    await tester.pump(AnnouncerHost.clearAfter - const Duration(seconds: 1));
    expect(regionLabel(tester), 'Saved');
    await tester.pump(const Duration(seconds: 1));
    expect(regionLabel(tester), '');
  });

  testWidgets('a later message starts the wait again', (tester) async {
    useLiveRegionAnnouncements(tester);
    await pump(tester);

    announce(page(tester), 'Saved');
    await tester.pump(const Duration(seconds: 3));
    announce(page(tester), 'Deleted');
    await tester.pump(const Duration(seconds: 3));
    expect(regionLabel(tester), 'Deleted');
    await tester.pump(AnnouncerHost.clearAfter);
    expect(regionLabel(tester), '');
  });

  for (final platformAnnounces in [true, false]) {
    final how = platformAnnounces ? 'the platform' : 'the live region';
    testWidgets('an announcer taken before its page closed still speaks, '
        'through $how', (tester) async {
      if (!platformAnnounces) useLiveRegionAnnouncements(tester);
      await pump(tester);
      final announcer = Announcer.of(page(tester));

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => AnnouncerHost(child: child!),
          home: const Scaffold(body: Text('Another page')),
        ),
      );
      expect(find.byKey(pageKey), findsNothing);
      announcer.say('Uploaded');
      await tester.pump();

      if (platformAnnounces) {
        expect(tester.takeAnnouncements(), [
          isAccessibilityAnnouncement('Uploaded'),
        ]);
      } else {
        expect(tester.takeAnnouncements(), isEmpty);
        expect(regionLabel(tester), 'Uploaded');
      }
    });
  }

  testWidgets('without a host the platform is asked anyway', (tester) async {
    useLiveRegionAnnouncements(tester);
    await pump(tester, host: false);

    announce(page(tester), 'Saved');
    await tester.pump();

    expect(tester.takeAnnouncements(), [isAccessibilityAnnouncement('Saved')]);
    expect(announcerRegion(tester), isNull);
  });

  group('a message a text field already shows as its error', () {
    testWidgets('is announced where the platform announces', (tester) async {
      await pump(tester);

      Announcer.of(page(tester)).say('Taken', onlyIfPlatformAnnounces: true);
      await tester.pump();

      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement('Taken'),
      ]);
    });

    testWidgets('is left to the field where it cannot', (tester) async {
      useLiveRegionAnnouncements(tester);
      await pump(tester);

      Announcer.of(page(tester)).say('Taken', onlyIfPlatformAnnounces: true);
      await tester.pump();
      await tester.pump();

      expect(tester.takeAnnouncements(), isEmpty);
      expect(regionLabel(tester), '');
    });
  });

  testWidgets('the live region is painted over the routes, so an open '
      'dialog leaves it in the tree', (tester) async {
    useLiveRegionAnnouncements(tester);
    await pump(tester);
    showDialog<void>(
      context: page(tester),
      builder: (context) => const AlertDialog(content: Text('A dialog')),
    ).ignore();
    await tester.pumpAndSettle();

    announce(tester.element(find.text('A dialog')), 'Saved');
    await tester.pump();

    expect(regionLabel(tester), 'Saved');
    expect(find.semantics.byLabel('Page'), findsNothing);
  });
}
