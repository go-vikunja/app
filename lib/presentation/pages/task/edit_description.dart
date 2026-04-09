import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:html_editor_enhanced/html_editor.dart';

class EditDescription extends StatefulWidget {
  final String? initialText;

  const EditDescription({super.key, required this.initialText});

  @override
  EditDescriptionState createState() => EditDescriptionState();
}

class EditDescriptionState extends State<EditDescription> {
  HtmlEditorController controller = HtmlEditorController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).editDescriptionTitle),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              var txt = await controller.getText();
              if (!context.mounted) return;
              Navigator.pop(context, txt);
            },
          ),
        ],
      ),
      body: HtmlEditor(
        controller: controller,
        htmlEditorOptions: HtmlEditorOptions(
          hint: "Your text here...",
          initialText: widget.initialText,
        ),
      ),
    );
  }
}
