import 'package:flutter/material.dart';

class PlaceholderFragment extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Container(
        padding: EdgeInsets.only(left: 16.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Container(
              padding: EdgeInsets.only(top: 32.0),
              child: new Text(
                'Welcome to Vikunja',
                style: Theme.of(context).textTheme.headline,
              ),
            ),
            new Text('Please select a namespace by clicking the  ☰  icon.',
                style: Theme.of(context).textTheme.subhead),
          ],
        ));
  }
}
