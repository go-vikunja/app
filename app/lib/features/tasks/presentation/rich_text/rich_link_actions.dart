import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';

/// A tap on [href] in the active account's rich text: a task of the
/// account goes to [openTask]; a web page or another app's link to the
/// system, and [showMessage] says so when nothing can open it.
Future<void> openRichTextLink(
  WidgetRef ref,
  String href, {
  required void Function(int taskId) openTask,
  required void Function(String Function(AppLocalizations l10n) text)
  showMessage,
}) async {
  final bases = ref.read(activeLinkBasesProvider);
  final target = bases == null ? null : linkTargetOf(href, bases);
  switch (target) {
    case TaskLinkTarget(:final taskId):
      openTask(taskId);
    case ExternalLinkTarget(:final uri):
      final opener = ref.read(externalLinkOpenerProvider);
      if (!await opener.open(uri)) showMessage((l10n) => l10n.linkCannotOpen);
    case null:
      showMessage((l10n) => l10n.linkCannotOpen);
  }
}
