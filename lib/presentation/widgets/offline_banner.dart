import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/offline/offline_controller.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(offlineControllerProvider);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (!status.isOffline &&
        !status.showFlush &&
        !status.isFlushing &&
        status.flushError == null) {
      return const SizedBox.shrink();
    }

    final Color background;
    final IconData icon;
    final String label;
    if (status.isOffline) {
      background = scheme.tertiaryContainer;
      icon = Icons.cloud_off;
      label = l10n.offlineMode;
    } else if (status.isFlushing) {
      background = scheme.secondaryContainer;
      icon = Icons.cloud_sync;
      label = l10n.flushingChanges;
    } else if (status.flushError != null) {
      background = scheme.errorContainer;
      icon = Icons.error_outline;
      label = l10n.flushFailed(status.flushError!);
    } else {
      background = scheme.primaryContainer;
      icon = Icons.cloud_upload_outlined;
      label = l10n.pendingChanges(status.pendingCount);
    }

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (status.isOffline)
                TextButton(
                  onPressed: () async {
                    final ok = await ref
                        .read(offlineControllerProvider.notifier)
                        .tryGoOnline();
                    if (ok) {
                      ref.invalidate(taskPageControllerProvider);
                      ref.invalidate(projectsControllerProvider);
                    }
                  },
                  child: Text(l10n.tryOnline),
                ),
              if (status.showFlush)
                FilledButton.tonal(
                  onPressed: () async {
                    final ok = await ref
                        .read(offlineControllerProvider.notifier)
                        .flush();
                    if (ok) {
                      ref.invalidate(taskPageControllerProvider);
                      ref.invalidate(projectsControllerProvider);
                    }
                  },
                  child: Text(l10n.flushChanges),
                ),
              if (status.isFlushing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
