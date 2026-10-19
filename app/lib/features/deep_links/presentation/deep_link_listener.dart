import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/links/deep_link_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';

final _log = Logger('DeepLink');

/// Opens the task a link on the app's scheme names
/// (`<scheme>://task/<id or PROJ-12>[?account=<id>]`), the one that
/// started the app and the ones that arrive while it runs, through the
/// [TaskOpener] like a notification tap. A link that names no task is
/// ignored. Links are never logged.
class DeepLinkListener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  late final TaskOpener _opener;
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    _opener = ref.read(taskOpenerProvider);
    final source = ref.read(deepLinkSourceProvider);
    _links = source.links.listen(_onLink);
    unawaited(
      source.initialLink().then(
        (uri) {
          if (uri != null) _onLink(uri);
        },
        onError: (Object error) =>
            _log.fine('Could not read the start link: ${error.runtimeType}'),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    super.dispose();
  }

  void _onLink(Uri uri) {
    if (!mounted) return;
    final link = parseTaskDeepLink(uri, scheme: oauthCallbackScheme);
    if (link == null) {
      _log.fine('Ignoring a link that names no task');
      return;
    }
    _opener.request(
      () => _opener.openLink(link).catchError((Object error) {
        _log.warning('Could not open a linked task: ${error.runtimeType}');
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
