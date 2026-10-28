import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';

import '../../helpers/large_screens.dart';

class _Probe extends StatefulWidget {
  const new({super.key});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: double.infinity, height: 48);
}

Future<void> _pump(WidgetTester tester, Widget body) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));

Widget _list({required double inset}) => ListView(
  padding: EdgeInsets.symmetric(horizontal: inset),
  children: [for (var i = 0; i < 40; i++) _Probe(key: ValueKey(i))],
);

void main() {
  const listBand = (left: 220.0, right: 1060.0);
  const formBand = (left: 320.0, right: 960.0);

  testWidgets('the box centres its child in the band on a large window', (
    tester,
  ) async {
    useWindow(tester, androidTabletLandscape);
    await _pump(
      tester,
      const ReadableWidth(maxWidth: ReadableWidth.list, child: _Probe()),
    );

    expectFillsBand(tester.getRect(find.byType(_Probe)), listBand);
  });

  testWidgets('the builder hands the content width and the inset to a list '
      'that keeps the whole width, so its margins scroll', (tester) async {
    useWindow(tester, androidTabletLandscape);
    double? contentWidth;
    await _pump(
      tester,
      ReadableWidth.builder(
        maxWidth: ReadableWidth.list,
        builder: (context, width, inset) {
          contentWidth = width;
          return _list(inset: inset);
        },
      ),
    );

    expect(contentWidth, 840);
    expect(tester.getRect(find.byType(Scrollable)).width, 1280);
    expectFillsBand(tester.getRect(find.byKey(const ValueKey(0))), listBand);

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.dragFrom(const Offset(110, 400), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('the slivers keep the whole width, and a notice, a remaining '
      'filler and a safe area lie in the band', (tester) async {
    useWindow(tester, androidTabletLandscape);
    tester.view.padding = const FakeViewPadding(bottom: 20 * 2);
    addTearDown(tester.view.resetPadding);
    const notice = Key('notice');
    const filler = Key('filler');
    const tail = Key('tail');
    await _pump(
      tester,
      const CustomScrollView(
        slivers: [
          SliverReadableWidth.group(
            maxWidth: ReadableWidth.form,
            slivers: [
              NoticeSliver(notice: SizedBox(key: notice, height: 40)),
              SliverSafeArea(
                top: false,
                sliver: SliverToBoxAdapter(
                  child: SizedBox(key: tail, height: 100),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: SizedBox.expand(key: filler),
              ),
            ],
          ),
        ],
      ),
    );

    expect(tester.getRect(find.byType(Scrollable)).width, 1280);
    expect(
      tester.getRect(find.byKey(notice)),
      const Rect.fromLTRB(320 + 16, 8, 960 - 16, 48),
    );
    expectFillsBand(tester.getRect(find.byKey(tail)), formBand);
    final rest = tester.getRect(find.byKey(filler));
    expectFillsBand(rest, formBand);
    expect(rest.bottom, 800);
    // The safe area's bottom inset lies between the two.
    expect(rest.top, tester.getRect(find.byKey(tail)).bottom + 20);
  });

  testWidgets('a single sliver lies in the band too', (tester) async {
    useWindow(tester, iPad11Landscape);
    await _pump(
      tester,
      const CustomScrollView(
        slivers: [
          SliverReadableWidth(
            maxWidth: ReadableWidth.list,
            sliver: SliverToBoxAdapter(child: _Probe()),
          ),
        ],
      ),
    );

    expectFillsBand(tester.getRect(find.byType(_Probe)), (
      left: 177,
      right: 1194 - 177,
    ));
  });

  for (final (name, body) in [
    ('box', const ReadableWidth(maxWidth: ReadableWidth.form, child: _Probe())),
    (
      'builder',
      ReadableWidth.builder(
        maxWidth: ReadableWidth.list,
        builder: (context, width, inset) => _list(inset: inset),
      ),
    ),
    (
      'sliver',
      const CustomScrollView(
        slivers: [
          SliverReadableWidth.group(
            maxWidth: ReadableWidth.list,
            slivers: [SliverToBoxAdapter(child: _Probe(key: ValueKey(0)))],
          ),
        ],
      ),
    ),
  ]) {
    testWidgets('the $name keeps its child, with its state, across a resize '
        'from the test surface to a tablet and back', (tester) async {
      useWindow(tester, defaultSurface);
      await _pump(tester, body);
      final probe = find.byType(_Probe).first;
      final state = tester.state(probe);
      expect(tester.getRect(probe).width, 800);

      useWindow(tester, androidTabletLandscape);
      await tester.pump();
      expect(tester.state(probe), same(state));
      expect(tester.getRect(probe).width, name == 'box' ? 640 : 840);

      useWindow(tester, defaultSurface);
      await tester.pump();
      expect(tester.state(probe), same(state));
      expect(tester.getRect(probe).width, 800);
    });
  }

  testWidgets('nothing moves on a phone in landscape or the test surface', (
    tester,
  ) async {
    for (final size in [androidLandscape, defaultSurface, iPhone]) {
      useWindow(tester, size);
      await _pump(
        tester,
        ReadableWidth.builder(
          maxWidth: ReadableWidth.form,
          builder: (context, width, inset) => _list(inset: inset),
        ),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey(0))).width,
        size.width,
        reason: sizeName(size),
      );
    }
  });

  testWidgets("a centred state's notice and content share the screen's "
      'band; without a width they use the whole width', (tester) async {
    useWindow(tester, androidTabletLandscape);
    const notice = Key('notice');
    const content = Key('content');
    await _pump(
      tester,
      const CenteredScrollView(
        maxWidth: ReadableWidth.form,
        header: SizedBox(key: notice, height: 40),
        child: SizedBox(key: content, width: double.infinity, height: 80),
      ),
    );

    expectFillsBand(tester.getRect(find.byKey(notice)), (
      left: formBand.left + 16,
      right: formBand.right - 16,
    ));
    expectFillsBand(tester.getRect(find.byKey(content)), formBand);
    expect(tester.getRect(find.byType(Scrollable)).width, 1280);

    await _pump(
      tester,
      const CenteredScrollView(
        header: SizedBox(key: notice, height: 40),
        child: SizedBox(key: content, width: double.infinity, height: 80),
      ),
    );
    expect(tester.getRect(find.byKey(content)).width, 1280);
  });
}
