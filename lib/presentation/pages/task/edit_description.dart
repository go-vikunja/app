import 'package:html_editor_enhanced/html_editor.dart';

import 'package:flutter/material.dart';

class EditDescription extends StatefulWidget {
  final String? initialText;
  EditDescription({required this.initialText});
  @override
  EditDescriptionState createState() => EditDescriptionState();
}

class EditDescriptionState extends State<EditDescription> {
  HtmlEditorController controller = HtmlEditorController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Description'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () {
              print(controller.getText());
              Navigator.pop(context, controller.getText());
            },
          )
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
