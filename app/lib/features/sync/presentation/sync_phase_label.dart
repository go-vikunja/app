import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

String syncPhaseLabel(AppLocalizations l10n, SyncPhase phase) =>
    switch (phase) {
      SyncPhase.account => l10n.syncPhaseAccount,
      SyncPhase.projects => l10n.syncPhaseProjects,
      SyncPhase.labels => l10n.syncPhaseLabels,
      SyncPhase.tasks => l10n.syncPhaseTasks,
      SyncPhase.archivedTasks => l10n.syncPhaseArchivedTasks,
      SyncPhase.delta => l10n.syncPhaseDelta,
      SyncPhase.reconcile => l10n.syncPhaseReconcile,
      SyncPhase.finishing => l10n.syncPhaseFinishing,
    };
