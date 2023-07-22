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
    return Scaffold(
      body: Column(
        children: [
          buildSubProjectSelector(),
      ]
      ),
    appBar: AppBar(
      title: Text(widget.project.title),
    ),);
  }
  Widget buildSubProjectSelector() {
    return Container(
      height: 80,
      child:
      ListView(
        scrollDirection: Axis.horizontal,
        //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ...?widget.project.subprojects?.map((elem) =>
              InkWell(
                  onTap: () {onSelectProject(context, elem);},
                  child:
                  Container(
                      alignment: Alignment.center,
                      height: 20,
                      width: 100,
                      child:
                      Text(elem.title, overflow: TextOverflow.ellipsis,softWrap: false,)))
          ),
        ],
      ),
    );
  }
}


onSelectProject(BuildContext context, Project project) {
  Navigator.push(
      context,
      MaterialPageRoute(
        builder: (buildContext) => ProjectPage(
          project: project,
        ),
      ));
  //setState(() => _selectedDrawerIndex = index);
}