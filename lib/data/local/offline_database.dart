import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:vikunja_app/data/local/offline_codec.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/user.dart';

class OfflineMutation {
  final int id;
  final String op;
  final Map<String, dynamic> payload;

  OfflineMutation({required this.id, required this.op, required this.payload});
}

class OfflineDatabase {
  OfflineDatabase({Database? database}) : _injected = database;

  final Database? _injected;
  Database? _db;

  Future<Database> get _database async {
    if (_injected != null) return _injected;
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'vikunja_offline.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE cached_tasks (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE cached_projects (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE cached_user (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE mutations (id INTEGER PRIMARY KEY AUTOINCREMENT, op TEXT NOT NULL, payload TEXT NOT NULL)',
        );
      },
    );
    return _db!;
  }

  Future<void> close() async {
    if (_injected == null) {
      await _db?.close();
      _db = null;
    }
  }

  Future<bool> hasSnapshot() async {
    final db = await _database;
    final user = await db.query('cached_user', limit: 1);
    if (user.isEmpty) return false;
    final tasks = await db.rawQuery('SELECT COUNT(*) AS c FROM cached_tasks');
    final projects = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM cached_projects',
    );
    final taskCount = tasks.first['c'] as int? ?? 0;
    final projectCount = projects.first['c'] as int? ?? 0;
    return taskCount > 0 || projectCount > 0;
  }

  Future<void> saveUser(User user) async {
    final db = await _database;
    await db.insert('cached_user', {
      'id': user.id,
      'json': jsonEncode(userToCache(user)),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<User?> loadUser() async {
    final db = await _database;
    final rows = await db.query('cached_user', limit: 1);
    if (rows.isEmpty) return null;
    return userFromCache(jsonDecode(rows.first['json'] as String));
  }

  Future<void> upsertTask(Task task) async {
    final db = await _database;
    await db.insert('cached_tasks', {
      'id': task.id,
      'json': jsonEncode(taskToCache(task)),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertTasks(List<Task> tasks) async {
    final db = await _database;
    final batch = db.batch();
    for (final task in tasks) {
      batch.insert('cached_tasks', {
        'id': task.id,
        'json': jsonEncode(taskToCache(task)),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTask(int id) async {
    final db = await _database;
    await db.delete('cached_tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<Task?> getTask(int id) async {
    final db = await _database;
    final rows = await db.query(
      'cached_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return taskFromCache(jsonDecode(rows.first['json'] as String));
  }

  Future<List<Task>> allTasks() async {
    final db = await _database;
    final rows = await db.query('cached_tasks');
    return rows
        .map((row) => taskFromCache(jsonDecode(row['json'] as String)))
        .toList();
  }

  Future<List<Task>> tasksByProject(int projectId) async {
    final tasks = await allTasks();
    return tasks.where((task) => task.projectId == projectId).toList();
  }

  Future<List<Task>> tasksByFilter(String filter) async {
    final tasks = await allTasks();
    return tasks.where((task) => taskMatchesFilter(task, filter)).toList();
  }

  Future<void> upsertProject(Project project) async {
    final db = await _database;
    await db.insert('cached_projects', {
      'id': project.id,
      'json': jsonEncode(projectToCache(project)),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertProjects(List<Project> projects) async {
    final db = await _database;
    final batch = db.batch();
    for (final project in projects) {
      batch.insert('cached_projects', {
        'id': project.id,
        'json': jsonEncode(projectToCache(project)),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Project>> allProjects() async {
    final db = await _database;
    final rows = await db.query('cached_projects');
    return rows
        .map((row) => projectFromCache(jsonDecode(row['json'] as String)))
        .toList();
  }

  Future<int> nextLocalId(String table) async {
    final db = await _database;
    final rows = await db.rawQuery('SELECT MIN(id) AS m FROM $table');
    final min = rows.first['m'] as int?;
    if (min == null || min >= 0) return -1;
    return min - 1;
  }

  Future<int> enqueue(String op, Map<String, dynamic> payload) async {
    final db = await _database;
    return db.insert('mutations', {'op': op, 'payload': jsonEncode(payload)});
  }

  Future<List<OfflineMutation>> pending() async {
    final db = await _database;
    final rows = await db.query('mutations', orderBy: 'id ASC');
    return rows
        .map(
          (row) => OfflineMutation(
            id: row['id'] as int,
            op: row['op'] as String,
            payload:
                jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<int> pendingCount() async {
    final db = await _database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM mutations');
    return rows.first['c'] as int? ?? 0;
  }

  Future<void> deleteMutation(int id) async {
    final db = await _database;
    await db.delete('mutations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMutationsForTask(int taskId) async {
    final pending = await this.pending();
    for (final mutation in pending) {
      final payload = mutation.payload;
      final task = payload['task'];
      final id = payload['id'] ?? (task is Map ? task['id'] : null);
      if (id == taskId) {
        await deleteMutation(mutation.id);
      }
    }
  }

  Future<void> remapId({
    required String kind,
    required int from,
    required int to,
  }) async {
    final db = await _database;
    if (kind == 'task') {
      final task = await getTask(from);
      if (task != null) {
        await deleteTask(from);
        await upsertTask(task.copyWith(id: to));
      }
    } else if (kind == 'project') {
      final projects = await allProjects();
      for (final project in projects.where((p) => p.id == from)) {
        await db.delete('cached_projects', where: 'id = ?', whereArgs: [from]);
        await upsertProject(project.copyWith(id: to));
      }
      final tasks = await allTasks();
      for (final task in tasks.where((t) => t.projectId == from)) {
        await upsertTask(task.copyWith(projectId: to));
      }
    }

    final pending = await this.pending();
    for (final mutation in pending) {
      final payload = _remapPayload(mutation.payload, kind, from, to);
      await db.update(
        'mutations',
        {'payload': jsonEncode(payload)},
        where: 'id = ?',
        whereArgs: [mutation.id],
      );
    }
  }

  Map<String, dynamic> _remapPayload(
    Map<String, dynamic> payload,
    String kind,
    int from,
    int to,
  ) {
    final copy = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    if (kind == 'task') {
      if (copy['id'] == from) copy['id'] = to;
      final task = copy['task'];
      if (task is Map && task['id'] == from) {
        task['id'] = to;
      }
    } else if (kind == 'project') {
      if (copy['projectId'] == from) copy['projectId'] = to;
      if (copy['id'] == from) copy['id'] = to;
      final project = copy['project'];
      if (project is Map && project['id'] == from) {
        project['id'] = to;
      }
      final task = copy['task'];
      if (task is Map && task['project_id'] == from) {
        task['project_id'] = to;
      }
    }
    return copy;
  }
}
