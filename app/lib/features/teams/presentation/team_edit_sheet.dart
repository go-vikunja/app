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
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/teams/application/team_server_providers.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_failure.dart';

final _log = Logger('TeamEdit');

/// A team's name and, where the server has public teams on, whether it is
/// public; Save sends only what changed and closes with the team as
/// stored. Null when dismissed or unchanged.
Future<Team?> showTeamEditSheet(BuildContext context, {required Team team}) =>
    showPickerSheet<Team>(
      context,
      builder: (context, scrollController) =>
          TeamEditSheet(team: team, scrollController: scrollController),
    );

class TeamEditSheet extends ConsumerStatefulWidget {
  const new({required this.team, this.scrollController, super.key});

  final Team team;
  final ScrollController? scrollController;

  @override
  ConsumerState<TeamEditSheet> createState() => _TeamEditSheetState();
}

class _TeamEditSheetState extends ConsumerState<TeamEditSheet> {
  late final _name = TextEditingController(text: widget.team.name);
  late bool _isPublic = widget.team.isPublic;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  TeamChanges get _changes {
    final name = _name.text.trim();
    return TeamChanges(
      name: _name.text == widget.team.name || name == widget.team.name
          ? null
          : name,
      isPublic: _isPublic == widget.team.isPublic ? null : _isPublic,
    );
  }

  bool get _canSave =>
      !_saving && teamNameProblem(_name.text) == null && !_changes.isEmpty;

  Future<void> _save() async {
    final repository = ref.read(teamRepositoryProvider);
    if (repository == null || !_canSave) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final team = await repository.update(widget.team.id, _changes);
      if (mounted) navigator.pop(team);
    } on Object catch (error) {
      _log.warning('Saving a team failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = teamFailureText(l10n, error, TeamChange.edit);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final publicTeams = ref.watch(activeServerHasPublicTeamsProvider);
    final blank = _name.text.trim().isEmpty;
    return PopScope(
      canPop: !_saving,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerHeader(
              title: l10n.teamEdit,
              actionLabel: _saving ? l10n.teamSaving : l10n.teamSave,
              onAction: _canSave ? () => unawaited(_save()) : null,
            ),
            if (_saving) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                inputFormatters: [CodePointLimitFormatter(Team.maxNameLength)],
                decoration: InputDecoration(
                  labelText: l10n.teamNameLabel,
                  errorText: blank ? l10n.teamNameRequired : null,
                  errorMaxLines: 3,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => unawaited(_save()),
              ),
            ),
            if (publicTeams) ...[
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _isPublic,
                onChanged: _saving
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
