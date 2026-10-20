@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Per API version, the port creates a saved filter, reads it, replaces it
// (also unchanged), favourites it, and deletes it twice; the project list
// names it with the saved filter's `updated` to the second, and every
// change moves that. Refused filters fail with the server's codes.
const _pace = Duration(milliseconds: 500);

void main() {
  group('saved filters on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          user = await registerAndLogin(dio, connection);
        });

        tearDownAll(() => dio.close(force: true));

        for (final apiVersion in ApiVersion.values) {
          test('${apiVersion.pathSegment}: create, read, replace, favourite '
              'and delete round-trip, the project list follows', () async {
            final only = onlyVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            final port = createWriteClient(
              dio: authenticated,
              connection: only,
            ).savedFilters;
            final reads = createReadClient(
              dio: authenticated,
              connection: only,
            );
            Future<T> paced<T>(Future<T> Function() write) async {
              final result = await despiteWriteRaces(write);
              await Future<void>.delayed(_pace);
              return result;
            }

            Future<Project> listed(int pseudoProjectId) async =>
                (await patiently(() => reads.projects.listAll()))
                    .singleWhere((project) => project.id == pseudoProjectId);

            void expectListedLike(Project project, SavedFilter filter) {
              expect(project.title, filter.title);
              expect(project.isFavorite, filter.isFavorite);
              expect(
                project.updated!.millisecondsSinceEpoch ~/ 1000,
                filter.updated!.millisecondsSinceEpoch ~/ 1000,
              );
            }

            const draft = SavedFilterDraft(
              title: 'Urgent open',
              description: 'Open and urgent',
              filter: ViewFilter(
                filter: 'done = false && priority >= 3',
                sortBy: ['due_date'],
                orderBy: ['asc'],
                includeNulls: true,
              ),
            );
            final created = await paced(() => port.create(draft));
            expect(created.title, draft.title);
            expect(created.description, draft.description);
            expect(created.filter, draft.filter);

            final read = await patiently(
              () => reads.savedFilters.read(created.id),
            );
            expect(read.filter, draft.filter);
            expect(read.title, draft.title);
            expectListedLike(await listed(created.pseudoProjectId), read);

            const replacement = SavedFilterDraft(
              title: 'This week',
              filter: ViewFilter(filter: 'due_date < now/w+1w'),
            );
            final replaced = await paced(
              () => port.update(created.id, replacement),
            );
            expect(replaced.title, 'This week');
            expect(replaced.description, '');
            expect(replaced.filter, replacement.filter);
            expect(replaced.updated!.isAfter(read.updated!), isTrue);
            final unchanged = await paced(
              () => port.update(created.id, replacement),
            );
            expect(unchanged.filter, replacement.filter);

            final favourite = await paced(
              () => port.setFavorite(created.id, favorite: true),
            );
            expect(favourite.isFavorite, isTrue);
            expect(favourite.filter, replacement.filter);
            final stored = await port.read(created.id);
            expect(stored.isFavorite, isTrue);
            expect(stored.title, 'This week');
            expectListedLike(await listed(created.pseudoProjectId), stored);

            await paced(() => port.delete(created.id));
            await paced(() => port.delete(created.id));
            await expectLater(
              port.read(created.id),
              throwsA(isA<NotFound>().having((f) => f.code, 'code', 11001)),
            );
          });

          test('${apiVersion.pathSegment}: the server refuses filters with '
              'its codes', () async {
            final only = onlyVersion(connection, apiVersion);
            final port = createWriteClient(
              dio: createAuthenticatedDio(
                base: dio,
                connection: only,
                tokens: StaticJwt(user.jwt),
              ),
              connection: only,
            ).savedFilters;
            for (final (filter, code) in [
              ('dueDate < now', 4016),
              ('done = yes', 4019),
              ('done = true &&', 4024),
            ]) {
              await expectLater(
                despiteWriteRaces(
                  () => port.create(
                    SavedFilterDraft(
                      title: 'Refused',
                      filter: ViewFilter(filter: filter),
                    ),
                  ),
                ),
                throwsA(isA<DomainError>().having((f) => f.code, 'code', code)),
                reason: filter,
              );
              await Future<void>.delayed(_pace);
            }
          });
        }
      });
    }
  });
}
