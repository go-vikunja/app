import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/team_repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/form_parts.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/form_parts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/teams/application/team_server_providers.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_failure.dart';

final _log = Logger('NewTeam');

/// Asks for a new team's name (and whether it is public, where the server
/// has public teams on), creates it and calls [onCreated] with it. The
/// sheet can be dragged shut while it waits: [onCreated] then still gets
/// the team, or the refusal is a snackbar.
Future<void> showNewTeamSheet(
  BuildContext context, {
  required ValueChanged<Team> onCreated,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showPickerSheet<void>(
    context,
    builder: (context, scrollController) => NewTeamSheet(
      scrollController: scrollController,
      messenger: messenger,
      onCreated: onCreated,
    ),
  );
}

class NewTeamSheet extends ConsumerStatefulWidget {
  const new({
    required this.onCreated,
    required this.messenger,
    this.scrollController,
    super.key,
  });

  final ValueChanged<Team> onCreated;
  final ScaffoldMessengerState messenger;
  final ScrollController? scrollController;

  @override
  ConsumerState<NewTeamSheet> createState() => _NewTeamSheetState();
}

class _NewTeamSheetState extends ConsumerState<NewTeamSheet> {
  final _name = TextEditingController();
  var _isPublic = false;
  var _edited = false;
  var _creating = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final repository = ref.read(teamRepositoryProvider);
    if (teamNameProblem(_name.text) != null) {
      setState(() => _edited = true);
      return;
    }
    if (repository == null || _creating) return;
    final l10n = context.l10n;
    final publicTeams = ref.read(activeServerHasPublicTeamsProvider);
    final onCreated = widget.onCreated;
    final messenger = widget.messenger;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final team = await repository.create(
        NewTeam(
          name: _name.text.trim(),
          isPublic: publicTeams ? _isPublic : null,
        ),
      );
      if (mounted) Navigator.of(context).pop();
      onCreated(team);
    } on Object catch (error) {
      _log.warning('Creating a team failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      final text = teamFailureText(l10n, error, TeamChange.create);
      if (!mounted) {
        showFailureAfterClose(messenger, text);
        return;
      }
      setState(() {
        _creating = false;
        _error = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final publicTeams = ref.watch(activeServerHasPublicTeamsProvider);
    final blank = _name.text.trim().isEmpty;
    return PopScope(
      canPop: !_creating,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerHeader(
              title: l10n.teamNewTitle,
              actionLabel: _creating ? l10n.teamCreating : l10n.teamCreate,
              onAction: blank || _creating ? null : () => unawaited(_create()),
            ),
            if (_creating) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _name,
                autofocus: true,
                enabled: !_creating,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                inputFormatters: [CodePointLimitFormatter(Team.maxNameLength)],
                decoration: InputDecoration(
                  labelText: l10n.teamNameLabel,
                  errorText: _edited && blank ? l10n.teamNameRequired : null,
                  errorMaxLines: 3,
                ),
                onChanged: (_) => setState(() => _edited = true),
                onSubmitted: (_) => unawaited(_create()),
              ),
            ),
            if (publicTeams) ...[
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _isPublic,
                onChanged: _creating
                    ? null
                    : (value) => setState(() => _isPublic = value),
                title: Text(l10n.teamPublicLabel),
                subtitle: Text(l10n.teamPublicHelp),
              ),
            ],
            if (_error case final error?) FormErrorText(error),
          ],
        ),
      ),
    );
  }
}
