import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/widgets/button.dart';

class ProjectEditPage extends ConsumerStatefulWidget {
  final Project project;
  final bool displayDoneTask;

  const ProjectEditPage({
    super.key,
    required this.project,
    required this.displayDoneTask,
  });

  @override
  ProjectEditPageState createState() => ProjectEditPageState();
}

class ProjectEditPageState extends ConsumerState<ProjectEditPage> {
  final _formKey = GlobalKey<FormState>();

  String? title;
  String? description;
  bool? displayDoneTask;

  @override
  void initState() {
    displayDoneTask = widget.displayDoneTask;

    super.initState();
  }

  @override
  Widget build(BuildContext ctx) {
    final l10n = AppLocalizations.of(ctx);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProjectTitle)),
      body: Builder(
        builder: (BuildContext context) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: TextFormField(
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  initialValue: widget.project.title,
                  validator: (title) {
                    if (title == null) {
                      return l10n.title;
                    }

                    if (title.isEmpty || title.length > 250) {
                      return 'The title needs to have between 1 and 250 characters.';
                    }

                    return null;
                  },
                  onSaved: (value) {
                    title = value;
                  },
                  decoration: InputDecoration(
                    labelText: l10n.title,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: TextFormField(
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  initialValue: widget.project.description,
                  validator: (description) {
                    if (description == null) return null;
                    if (description.length > 1000) {
                      return 'The description can have a maximum of 1000 characters.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    description = value;
                  },
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: CheckboxListTile(
                  value: displayDoneTask,
                  title: Text(l10n.showDoneTasks),
                  onChanged: (value) {
                    value ??= false;

                    setState(() {
                      displayDoneTask = value;
                    });
                  },
                ),
              ),
              Builder(
                builder: (context) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: FancyButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState?.save();
                        _saveProject(ref, widget.project);
                      }
                    },
                    child: Text(l10n.save),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProject(WidgetRef ref, Project project) async {
    if (_formKey.currentState?.validate() == true) {
      _formKey.currentState?.save();

      project.title = title!;
      project.description = description!;

      var success = await ref
          .read(projectControllerProvider(project).notifier)
          .updateProject(project);

      var context = ref.context;
      final loc = AppLocalizations.of(context);
      if (success && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.projectUpdatedSuccess)));

        Navigator.of(context).pop();

        await ref
            .read(projectControllerProvider(project).notifier)
            .setDisplayDoneTasks(displayDoneTask!);
      } else if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.projectUpdateError)));
      }
    }
  }
}
