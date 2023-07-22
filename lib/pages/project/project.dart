import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/project.dart';

class ProjectPage extends StatefulWidget {
  final Project project;

  ProjectPage({required this.project})
      : super(key: Key(project.id.toString()));

  @override
  _ProjectPageState createState() => new _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold();
  }

}