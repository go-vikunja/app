import 'package:flutter/material.dart';

class FancyAppBar extends StatelessWidget {
  final String title;
  final double barHeight = 80.0;

  FancyAppBar(this.title);

  @override
  Widget build(BuildContext context) {
    return new Container(
      height: barHeight,
      width: double.infinity,
      decoration: new BoxDecoration(color: Colors.blue),
      child: new Padding(
        padding: EdgeInsets.symmetric(vertical: 38, horizontal: 10),
        child: new Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFamily: 'Quicksand',
                fontSize: 21)),
      ),
    );
  }
}

/*
Usage:
return new Scaffold(
      body: new Column(
        children: <Widget>[
          new FancyAppBar('Login to Vikunja'),
        ],
      ),
    );
 */
