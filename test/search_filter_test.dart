import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/search_filter.dart';

void main() {
  group('searchLikeClause', () {
    test('returns null for empty or whitespace query', () {
      expect(searchLikeClause(''), isNull);
      expect(searchLikeClause('   '), isNull);
    });

    test('wraps multiple fields with or', () {
      expect(
        searchLikeClause('milk'),
        "(title like '%milk%' || description like '%milk%')",
      );
    });

    test('uses a single field without grouping', () {
      expect(
        searchLikeClause('milk', fields: ['title']),
        "title like '%milk%'",
      );
    });

    test('escapes quotes and backslashes', () {
      expect(
        searchLikeClause("o'clock", fields: ['title']),
        r"title like '%o\'clock%'",
      );
      expect(
        searchLikeClause(r'a\b', fields: ['title']),
        r"title like '%a\\b%'",
      );
    });
  });

  test('combineFilterClauses joins non-empty clauses', () {
    expect(
      combineFilterClauses(['done = false', '', "(title like '%a%')"]),
      "done = false && (title like '%a%')",
    );
  });
}
