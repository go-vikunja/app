import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_message.dart';
import 'package:vikunja_mobile/features/home/presentation/description_conflict_sheet.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_problem_message.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// The changes the server refused for good, each with Retry and Discard;
/// a description also changed on the web with a comparison of both
/// versions, which offers to keep either. Nothing while there are none.
class SyncProblemsSection extends ConsumerWidget {
  const new({required this.entry, super.key});

  final RegisteredAccount entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problems =
        ref.watch(syncProblemsProvider).unwrapPrevious().value ?? const [];
    if (problems.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(clockTickProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.accountSyncProblems,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          for (final problem in problems)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ProblemCard(
                key: ValueKey(problem.operationId),
                problem: problem,
                now: now,
                serverRoot: entry.connection.rootUri,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProblemCard extends ConsumerStatefulWidget {
  const new({
    required this.problem,
    required this.now,
    required this.serverRoot,
    super.key,
  });

  final SyncProblem problem;
  final DateTime now;
  final Uri serverRoot;

  @override
  ConsumerState<_ProblemCard> createState() => _ProblemCardState();
}

class _ProblemCardState extends ConsumerState<_ProblemCard> {
  bool _busy = false;

  /// Discard, and Use the web's, read the task from the server first; when
  /// that fails the card stays and a snackbar says why.
  Future<void> _discard() => _readingFromServer(
    (repository) => repository.discardSyncProblem(widget.problem.operationId),
  );

  Future<void> _useWebDescription() => _readingFromServer(
    (repository) => repository.useWebDescription(widget.problem.operationId),
  );

  Future<void> _readingFromServer(
    Future<void> Function(TaskRepository repository) action,
  ) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    setState(() => _busy = true);
    try {
      await action(repository);
    } on Object catch (error) {
      if (mounted) _showReadFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showReadFailure(Object error) {
    final message = describeDataFailure(
      context.l10n,
      error,
      serverRoot: widget.serverRoot,
      platform: Theme.of(context).platform,
      stale: true,
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message.explanation)));
  }

  /// Reads the server's description and shows it next to the queued one;
  /// Keep mine then overwrites exactly that one.
  Future<void> _compareDescriptions() async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    final operationId = widget.problem.operationId;
    setState(() => _busy = true);
    final String? web;
    try {
      web = await repository.webDescription(operationId);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showReadFailure(error);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final choice = await showDescriptionConflictSheet(
      context,
      mine: widget.problem.changes?.description ?? '',
      web: web,
    );
    if (!mounted) return;
    switch ((choice, web)) {
      case (DescriptionChoice.mine, final String overwritten):
        await _resending(
          (repository) => repository.keepMyDescription(
            operationId,
            webDescription: overwritten,
          ),
        );
      case (DescriptionChoice.web, _):
        await _useWebDescription();
      case _:
        break;
    }
  }

  /// The outbox reports the outcome through the problems and the count.
  Future<void> _retry() => _resending(
    (repository) => repository.retrySyncProblem(widget.problem.operationId),
  );

  Future<void> _resending(
    Future<void> Function(TaskRepository repository) action,
  ) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    setState(() => _busy = true);
    try {
      await action(repository);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final problem = widget.problem;
    final enabled = !_busy && ref.watch(taskRepositoryProvider) != null;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: colors.onErrorContainer,
    );
    return StatusCard(
      icon: Icons.sync_problem,
      title: problem.taskTitle,
      body: describeSyncProblem(l10n, problem),
      footnote: isJustNow(problem.failedAt, now: widget.now)
          ? l10n.syncProblemFailedJustNow
          : l10n.syncProblemFailedAt(
              formatRelativeTime(l10n, problem.failedAt, now: widget.now),
            ),
      background: colors.errorContainer,
      foreground: colors.onErrorContainer,
      action: Wrap(
        spacing: 4,
        alignment: WrapAlignment.end,
        children: switch (problem.failure) {
          DescriptionConflict() => [
            TextButton.icon(
              onPressed: enabled
                  ? () => unawaited(_compareDescriptions())
                  : null,
              style: buttonStyle,
              icon: const Icon(Icons.compare_arrows),
              label: Text(l10n.syncProblemCompare),
            ),
          ],
          _ => [
            TextButton(
              onPressed: enabled ? () => unawaited(_discard()) : null,
              style: buttonStyle,
              child: Text(l10n.syncProblemDiscard),
            ),
            if (_retryable(problem))
              TextButton.icon(
                onPressed: enabled ? () => unawaited(_retry()) : null,
                style: buttonStyle,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
          ],
        },
      ),
    );
  }
}

/// An upload whose stored copy is gone fails again at once.
bool _retryable(SyncProblem problem) =>
    problem.kind != OutboxOperationKind.uploadAttachment ||
    uploadProblemReason(problem.failure) != UploadProblemReason.fileMissing;
