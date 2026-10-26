import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';

/// The views a link can open, in the web's order: every kind, since the
/// link opens on the web.
List<ProjectView> linkViewChoices(Project? project) =>
    sortedViews(project?.views ?? const []);

/// [viewId] while it is still one of [views], else the first of them, as
/// the web's share table defaults; null for a project without views.
int? linkViewIdFor(List<ProjectView> views, int? viewId) {
  if (views.isEmpty) return null;
  return views.any((view) => view.id == viewId) ? viewId : views.first.id;
}

/// The web address of [share] on the account's frontend, opening
/// [viewId]. It carries the share's secret: never log it.
Uri linkShareUriFor(AccountLinkBases bases, LinkShare share, {int? viewId}) =>
    linkShareUrl(
      base: webFrontendBase(
        serverRoot: bases.serverRoot,
        frontendUrl: bases.frontendUrl,
      ),
      hash: share.hash,
      viewId: viewId,
    );
