import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

/// How the web names a project on screen: the Favorites pseudo project and
/// the server's default names (exact, case-sensitive matches) translated,
/// any other title as is. Only for display; matching, defaults and storage
/// keep the server's title.
String projectDisplayTitle(
  AppLocalizations l10n,
  String title, {
  int? projectId,
}) {
  if (projectId == Project.favoritesId) return l10n.projectFavouritesTitle;
  return switch (title) {
    'Inbox' => l10n.projectInboxTitle,
    'My Open Tasks' => l10n.savedFilterMyOpenTasks,
    _ => title,
  };
}

extension ProjectDisplayTitle on Project {
  String displayTitle(AppLocalizations l10n) =>
      projectDisplayTitle(l10n, title, projectId: id);
}
