import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('saved filter n is pseudo project -n - 1, and back', () {
    const filter = SavedFilter(id: 13, title: 'Mine', filter: ViewFilter());

    expect(filter.pseudoProjectId, -14);
    expect(SavedFilter.pseudoProjectIdOf(1), -2);
    expect(SavedFilter.idOfPseudoProject(-14), 13);
    expect(SavedFilter.idOfPseudoProject(-2), 1);
    expect(SavedFilter.idOfPseudoProject(Project.favoritesId), isNull);
    expect(SavedFilter.idOfPseudoProject(5), isNull);
  });

  test('saved filters and drafts are equal by value', () {
    final updated = DateTime.utc(2026, 10, 20);
    SavedFilter filter({String text = 'done = false'}) => SavedFilter(
      id: 1,
      title: 'Open',
      filter: ViewFilter(filter: text),
      updated: updated,
    );

    expect(filter(), filter());
    expect(filter().hashCode, filter().hashCode);
    expect(filter(), isNot(filter(text: 'done = true')));
    expect(
      const SavedFilterDraft(
        title: 'Open',
        filter: ViewFilter(filter: 'a'),
      ),
      const SavedFilterDraft(
        title: 'Open',
        filter: ViewFilter(filter: 'a'),
      ),
    );
    expect(
      const SavedFilterDraft(title: 'Open', filter: ViewFilter()),
      isNot(
        const SavedFilterDraft(
          title: 'Open',
          filter: ViewFilter(),
          isFavorite: true,
        ),
      ),
    );
  });

  test('toString leaves out the user text', () {
    const draft = SavedFilterDraft(
      title: 'Secret plans',
      description: 'more secrets',
      filter: ViewFilter(filter: 'title like secret'),
      isFavorite: true,
    );
    const filter = SavedFilter(
      id: 4,
      title: 'Secret plans',
      filter: ViewFilter(filter: 'title like secret'),
    );

    expect('$draft', isNot(contains('ecret')));
    expect('$filter', 'SavedFilter(4)');
  });
}
