import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/theme/button.dart';
import 'package:vikunja_app/theme/buttonText.dart';

class NamespaceEditPage extends StatefulWidget {
  final Namespace namespace;

  NamespaceEditPage({this.namespace}) : super(key: Key(namespace.toString()));

  @override
  State<StatefulWidget> createState() => _NamespaceEditPageState();
}

class _NamespaceEditPageState extends State<NamespaceEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String _name, _description;

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Namespace'),
      ),
      body: Builder(
        builder: (BuildContext context) => SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: TextFormField(
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      initialValue: widget.namespace.title,
                      onSaved: (name) => _name = name,
                      validator: (name) {
                        if (name.length < 3 || name.length > 250) {
                          return 'The name needs to have between 3 and 250 characters.';
                        }
                        return null;
                      },
                      decoration: new InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: TextFormField(
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      initialValue: widget.namespace.description,
                      onSaved: (description) => _description = description,
                      validator: (description) {
                        if (description.length > 1000) {
                          return 'The description can have a maximum of 1000 characters.';
                        }
                        return null;
                      },
                      decoration: new InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Builder(
                      builder: (context) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: FancyButton(
                            onPressed: !_loading
                                ? () {
                                    if (_formKey.currentState.validate()) {
                                      Form.of(context).save();
                                      _saveNamespace(context);
                                    }
                                  }
                                : null,
                            child: _loading
                                ? CircularProgressIndicator()
                                : VikunjaButtonText('Save'),
                          ))),
                ]),
          ),
        ),
      ),
    );
  }

  _saveNamespace(BuildContext context) async {
    setState(() => _loading = true);
    // FIXME: is there a way we can update the namespace without creating a new namespace object?
    //  aka updating the existing namespace we got from context (setters?)
    Namespace updatedNamespace = Namespace(
        id: widget.namespace.id,
        title: _name,
        description: _description,
        owner: widget.namespace.owner);

    VikunjaGlobal.of(context)
        .namespaceService
        .update(updatedNamespace)
        .then((_) {
      setState(() => _loading = false);
      Scaffold.of(context).showSnackBar(SnackBar(
        content: Text('The namespace was updated successfully!'),
      ));
    }).catchError((err) {
      setState(() => _loading = false);
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: ' + err.toString()),
          action: SnackBarAction(
              label: 'CLOSE',
              onPressed: Scaffold.of(context).hideCurrentSnackBar),
        ),
      );
    });
  }
}
