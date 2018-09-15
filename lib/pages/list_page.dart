import 'package:flutter/material.dart';

class ListPage extends StatefulWidget {
  final String listName;

  ListPage({this.listName}) : super(key: Key(listName));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: new Text(widget.listName),
      ),
      body: Center(
        child: RaisedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Go back")),
      ),
    );
  }
}
