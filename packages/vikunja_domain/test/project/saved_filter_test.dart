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

  test('as an update of what an edit started from, leaves unchanged what '
      'equals that start', () {
    const start = SavedFilterDraft(
      title: 'Urgent',
      description: 'What burns',
      filter: ViewFilter(
        filter: 'priority >= 4',
        search: 'fire',
        sortBy: ['due_date'],
        orderBy: ['asc'],
      ),
    );
    const edited = SavedFilterDraft(
      title: ' Urgent ',
      description: 'What burns',
      filter: ViewFilter(
        filter: 'priority >= 4 ',
        search: 'fire',
        sortBy: ['due_date'],
        orderBy: ['asc'],
        includeNulls: true,
      ),
      isFavorite: true,
    );

    expect(edited.changedFrom(start).unchanged, {
      SavedFilterDraftField.title,
      SavedFilterDraftField.description,
      SavedFilterDraftField.filterText,
      SavedFilterDraftField.search,
      SavedFilterDraftField.sort,
    });
    expect(
      const SavedFilterDraft(
        title: 'Burning',
        filter: ViewFilter(
          filter: 'priority = 5',
          sortBy: ['due_date'],
          orderBy: ['desc'],
        ),
      ).changedFrom(start).unchanged,
      {SavedFilterDraftField.includeNulls, SavedFilterDraftField.isFavorite},
    );
    expect(edited.changedFrom(start), isNot(edited));
    expect(edited.changedFrom(start), edited.changedFrom(start));
    expect(
      edited.changedFrom(start).hashCode,
      edited.changedFrom(start).hashCode,
    );
    expect(
      start.changedFrom(start).unchanged,
      SavedFilterDraftField.values.toSet(),
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
