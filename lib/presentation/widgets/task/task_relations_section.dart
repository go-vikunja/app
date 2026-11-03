import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/offline/offline_controller.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/task/relation_kind_ui.dart';

class TaskRelationsSection extends ConsumerStatefulWidget {
  final Task task;

  const TaskRelationsSection({super.key, required this.task});

  @override
  ConsumerState<TaskRelationsSection> createState() =>
      _TaskRelationsSectionState();
}

class _TaskRelationsSectionState extends ConsumerState<TaskRelationsSection> {
  late Map<RelationKind, List<Task>> _related;
  RelationKind? _kind;
  Task? _selected;
  bool _busy = false;
  Timer? _debounce;
  Completer<Iterable<Task>>? _lastCompleter;

  @override
  void initState() {
    super.initState();
    _related = {
      for (final entry in widget.task.relatedTasks.entries)
        entry.key: List<Task>.from(entry.value),
    };
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offline = ref.watch(offlineIsOfflineProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.relatedTasks,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (offline)
            Text(
              l10n.relationsOnlineOnly,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            _buildAddRow(l10n),
          if (_related.values.every((tasks) => tasks.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.relationNoneYet,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final kind in RelationKind.selectable)
            if ((_related[kind] ?? const []).isNotEmpty)
              _buildKindGroup(l10n, kind, _related[kind]!),
        ],
      ),
    );
  }

  Widget _buildAddRow(AppLocalizations l10n) {
    return Column(
      children: [
        Autocomplete<Task>(
          displayStringForOption: (task) =>
              '${task.identifier.isNotEmpty ? '${task.identifier} ' : ''}${task.title}',
          optionsBuilder: (value) {
            if (value.text.trim().isEmpty) {
              return const Iterable<Task>.empty();
            }
            if (_debounce?.isActive ?? false) {
              _debounce!.cancel();
              _lastCompleter?.complete(const Iterable<Task>.empty());
            }
            final completer = Completer<Iterable<Task>>();
            _lastCompleter = completer;
            _debounce = Timer(const Duration(milliseconds: 400), () async {
              final response = await ref
                  .read(taskRepositoryProvider)
                  .search(value.text.trim());
              if (completer.isCompleted) return;
              if (!response.isSuccessful) {
                completer.complete(const Iterable<Task>.empty());
                return;
              }
              completer.complete(
                response.toSuccess().body.where(
                  (task) => task.id != widget.task.id,
                ),
              );
            });
            return completer.future;
          },
          onSelected: (task) {
            setState(() => _selected = task);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: l10n.relationSearch,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<RelationKind>(
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: l10n.relationSelectKind,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final kind in RelationKind.selectable)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(kind.label(l10n)),
                    ),
                ],
                onChanged: (kind) => setState(() => _kind = kind),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : () => _add(l10n),
              child: Text(l10n.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKindGroup(
    AppLocalizations l10n,
    RelationKind kind,
    List<Task> tasks,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kind.label(l10n), style: Theme.of(context).textTheme.labelLarge),
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(kind.icon, color: kind.tint),
              title: Text(
                task.title,
                style: task.done
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: task.identifier.isEmpty ? null : Text(task.identifier),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskEditPage(task: task)),
                );
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.relationDelete,
                onPressed: _busy ? null : () => _delete(kind, task, l10n),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _add(AppLocalizations l10n) async {
    final kind = _kind;
    final other = _selected;
    if (kind == null) {
      _snack(l10n.relationSelectKind);
      return;
    }
    if (other == null) {
      _snack(l10n.relationTaskRequired);
      return;
    }
    setState(() => _busy = true);
    final response = await ref
        .read(taskRepositoryProvider)
        .addRelation(taskId: widget.task.id, otherTaskId: other.id, kind: kind);
    if (!mounted) return;
    if (!response.isSuccessful) {
      setState(() => _busy = false);
      _snack(_error(response, l10n));
      return;
    }
    await _reload();
  }

  Future<void> _delete(
    RelationKind kind,
    Task other,
    AppLocalizations l10n,
  ) async {
    setState(() => _busy = true);
    final response = await ref
        .read(taskRepositoryProvider)
        .deleteRelation(
          taskId: widget.task.id,
          otherTaskId: other.id,
          kind: kind,
        );
    if (!mounted) return;
    if (!response.isSuccessful) {
      setState(() => _busy = false);
      _snack(_error(response, l10n));
      return;
    }
    await _reload();
  }

  Future<void> _reload() async {
    final response = await ref
        .read(taskRepositoryProvider)
        .getTask(widget.task.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected = null;
      if (response.isSuccessful) {
        final body = response.toSuccess().body;
        _related = {
          for (final entry in body.relatedTasks.entries)
            entry.key: List<Task>.from(entry.value),
        };
        widget.task.relatedTasks = body.relatedTasks;
      }
    });
  }

  String _error(Response<Object> response, AppLocalizations l10n) {
    if (response.isError) {
      return response.toError().error['message']?.toString() ??
          l10n.relationAddError;
    }
    if (response.isException) {
      return response.toException().message;
    }
    return l10n.relationAddError;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
