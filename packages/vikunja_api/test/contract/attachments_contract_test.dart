@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Per API version, uploads through the port and reads them back, downloads
// to disk (whole and resumed with a range), deletes, sets and clears the
// cover and runs into the cover a delete leaves behind, and writes into an
// archived project. One user for the whole file.
const _pace = Duration(milliseconds: 500);
const int _mebibyte = 1024 * 1024;

// A 1x1 PNG that Go's image package decodes.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);
const _unicodeName = 'Ünïcødé 日本 ü.txt';
const _text = 'Contract notes, plain text.\n';

/// The status of each answer, for telling a resumed download from a full
/// one.
final class _Statuses extends Interceptor {
  final List<(String?, int?)> rangesAndStatuses = [];

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    rangesAndStatuses.add((
      response.requestOptions.headers['Range'] as String?,
      response.statusCode,
    ));
    handler.next(response);
  }
}

void main() {
  group('attachments on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;
        late Directory temp;
        late int projectId;
        late int archivedTaskId;
        late int archivedAttachmentId;

        Future<T> paced<T>(Future<T> Function() write) async {
          final result = await despiteWriteRaces(write);
          await Future<void>.delayed(_pace);
          return result;
        }

        ({VikunjaReadClient reads, VikunjaWriteClient writes}) clients(
          ApiVersion apiVersion, {
          Interceptor? statuses,
        }) {
          final only = onlyVersion(connection, apiVersion);
          final authenticated = createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
            interceptors: [?statuses],
          );
          return (
            reads: createReadClient(dio: authenticated, connection: only),
            writes: createWriteClient(dio: authenticated, connection: only),
          );
        }

        Future<TaskAttachment> upload(
          AttachmentsWritePort port,
          int taskId,
          String name,
          List<int> bytes,
        ) => paced(
          () => port.upload(
            taskId,
            fileName: name,
            bytes: Stream.value(bytes),
            length: bytes.length,
            timeout: const Duration(minutes: 2),
          ),
        );

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          expect(connection.info.taskAttachmentsEnabled, isTrue);
          expect(connection.info.maxFileSizeBytes, 20 * _mebibyte);
          user = await registerAndLogin(dio, connection);
          temp = Directory.systemTemp.createTempSync('rurana_attachments');

          final v2 = clients(ApiVersion.v2).writes;
          projectId = (await paced(
            () => v2.projects.create(const NewProject(title: 'Attachments')),
          )).id;
          final archived = await paced(
            () => v2.projects.create(const NewProject(title: 'Archived')),
          );
          archivedTaskId = (await paced(
            () => v2.tasks.create(
              NewTask(projectId: archived.id, title: 'In an archived project'),
            ),
          )).id;
          archivedAttachmentId = (await upload(
            v2.attachments,
            archivedTaskId,
            'kept.txt',
            utf8.encode(_text),
          )).id;
          await paced(
            () => v2.projects.update(
              archived.id,
              const ProjectChanges(isArchived: true),
            ),
          );
        });

        tearDownAll(() async {
          dio.close(force: true);
          temp.deleteSync(recursive: true);
        });

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            late VikunjaReadClient reads;
            late AttachmentsWritePort attachments;
            late TasksWritePort tasks;
            final statuses = _Statuses();

            Future<int> newTask(String title) async => (await paced(
              () => tasks.create(NewTask(projectId: projectId, title: title)),
            )).id;

            Future<TaskDetails> details(int taskId) =>
                patiently(() => reads.tasks.readDetails(taskId));

            setUpAll(() {
              expect(connection.apiVersions, contains(apiVersion));
              final (reads: read, :writes) = clients(
                apiVersion,
                statuses: statuses,
              );
              reads = read;
              attachments = writes.attachments;
              tasks = writes.tasks;
            });

            test('uploads a PNG, a text file under a unicode name and an empty '
                'file, as the task read lists them', () async {
              final taskId = await newTask('Uploads');

              final png = await upload(
                attachments,
                taskId,
                'pixel.png',
                _pixel,
              );
              final text = await upload(
                attachments,
                taskId,
                _unicodeName,
                utf8.encode(_text),
              );
              final empty = await upload(
                attachments,
                taskId,
                'empty.txt',
                const [],
              );

              expect(
                (png.taskId, png.name, png.mime, png.size),
                (taskId, 'pixel.png', 'image/png', _pixel.length),
              );
              expect(png.createdBy?.id, user.id);
              expect(png.created, isNotNull);
              expect(text.name, _unicodeName);
              expect(text.mime, startsWith('text/plain'));
              expect(text.size, utf8.encode(_text).length);
              expect(empty.size, 0);
              expect(
                (await details(taskId)).attachments,
                unorderedEquals([png, text, empty]),
              );
            });

            test('a file one MiB above the limit is FileTooLarge 4012 and '
                'leaves nothing behind', () async {
              final taskId = await newTask('Too large');

              await expectLater(
                upload(
                  attachments,
                  taskId,
                  'large.bin',
                  Uint8List(21 * _mebibyte),
                ),
                throwsA(
                  isA<FileTooLarge>().having((f) => f.code, 'code', 4012),
                ),
              );
              expect((await details(taskId)).attachments, isEmpty);
            });

            test('downloads the original byte for byte and resumes a part '
                'with a range', () async {
              final taskId = await newTask('Downloads');
              final random = Random(26);
              final binary = Uint8List.fromList([
                for (var i = 0; i < 256 * 1024; i++) random.nextInt(256),
              ]);
              final blob = await upload(
                attachments,
                taskId,
                'random.bin',
                binary,
              );
              final text = await upload(
                attachments,
                taskId,
                _unicodeName,
                utf8.encode(_text),
              );
              final directory =
                  '${temp.path}/${apiVersion.pathSegment}/$taskId';
              final blobFile = File('$directory/random.bin');
              final textFile = File('$directory/notes.txt');
              File('${textFile.path}.part')
                ..createSync(recursive: true)
                ..writeAsBytesSync(utf8.encode(_text).sublist(0, 9));
              statuses.rangesAndStatuses.clear();

              await patiently(
                () => reads.attachments.download(
                  taskId,
                  blob.id,
                  target: blobFile,
                ),
              );
              await patiently(
                () => reads.attachments.download(
                  taskId,
                  text.id,
                  target: textFile,
                ),
              );

              expect(blobFile.readAsBytesSync(), binary);
              expect(textFile.readAsStringSync(), _text);
              expect(File('${textFile.path}.part').existsSync(), isFalse);
              expect(statuses.rangesAndStatuses, [
                (null, 200),
                ('bytes=9-', 206),
              ]);
            });

            test('deletes, and a second delete counts as done', () async {
              final taskId = await newTask('Deletes');
              final kept = await upload(attachments, taskId, 'keep.txt', [1]);
              final gone = await upload(attachments, taskId, 'gone.txt', [2]);

              await paced(() => attachments.delete(taskId, gone.id));
              await paced(() => attachments.delete(taskId, gone.id));

              expect((await details(taskId)).attachments, [kept]);
              await expectLater(
                patiently(
                  () => reads.attachments.download(
                    taskId,
                    gone.id,
                    target: File('${temp.path}/gone.txt'),
                  ),
                ),
                throwsA(isA<NotFound>().having((f) => f.code, 'code', 4011)),
              );
            });

            test('the cover is set and cleared; deleting it leaves the id '
                'behind, which refuses a title edit with 4020 until the edit '
                'clears it', () async {
              final taskId = await newTask('Cover');
              final cover = await upload(
                attachments,
                taskId,
                'pixel.png',
                _pixel,
              );

              await paced(
                () => tasks.update(
                  taskId,
                  TaskChanges(coverImageAttachmentId: cover.id),
                ),
              );
              expect((await details(taskId)).coverImageAttachmentId, cover.id);
              await paced(
                () => tasks.update(
                  taskId,
                  const TaskChanges(coverImageAttachmentId: 0),
                ),
              );
              expect((await details(taskId)).coverImageAttachmentId, 0);

              await paced(
                () => tasks.update(
                  taskId,
                  TaskChanges(coverImageAttachmentId: cover.id),
                ),
              );
              await paced(() => attachments.delete(taskId, cover.id));
              expect((await details(taskId)).coverImageAttachmentId, cover.id);
              const edit = TaskChanges(title: 'Edited after the delete');
              await expectLater(
                paced(() => tasks.update(taskId, edit)),
                throwsA(
                  isA<DomainError>()
                      .having((f) => f.statusCode, 'status', 400)
                      .having((f) => f.code, 'code', 4020),
                ),
              );
              final edited = await paced(
                () => tasks.update(
                  taskId,
                  edit.merge(const TaskChanges(coverImageAttachmentId: 0)),
                ),
              );

              expect(edited.title, 'Edited after the delete');
              expect((await details(taskId)).coverImageAttachmentId, 0);
            });

            test('an archived project refuses upload and delete with 3008 '
                'and still downloads', () async {
              Matcher archived() => throwsA(
                isA<DomainError>()
                    .having((f) => f.statusCode, 'status', 412)
                    .having((f) => f.code, 'code', 3008),
              );

              await expectLater(
                upload(attachments, archivedTaskId, 'refused.txt', [1]),
                archived(),
              );
              await expectLater(
                paced(
                  () =>
                      attachments.delete(archivedTaskId, archivedAttachmentId),
                ),
                archived(),
              );
              final target = File(
                '${temp.path}/archived-${apiVersion.pathSegment}.txt',
              );
              await patiently(
                () => reads.attachments.download(
                  archivedTaskId,
                  archivedAttachmentId,
                  target: target,
                ),
              );
              expect(target.readAsStringSync(), _text);
            });
          });
        }
      });
    }
  });
}
