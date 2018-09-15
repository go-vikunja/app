import 'package:flutter/material.dart';

class NamespaceFragment extends StatelessWidget {
  final String namespace;

  NamespaceFragment({this.namespace});

  @override
  Widget build(BuildContext context) {
    return new Center(
        child: new Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        new Container(
          child: new Text(
            'Namespace: $namespace',
            style: Theme.of(context).textTheme.title,
          ),
        ),
        new Text('You\'ve selected a namespace!')
      ],
    ));
  }
}
