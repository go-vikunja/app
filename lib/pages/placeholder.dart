import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: EdgeInsets.only(top: 32.0),
              child: Text(
                'Welcome to Vikunja',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Please select a namespace by tapping the  ☰  icon.',
                  style: Theme.of(context).textTheme.titleMedium),
            )
          ],
        ),
      ),
    );
  }
}
