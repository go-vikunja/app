import 'package:flutter/material.dart';

class FancyAppBar extends StatelessWidget {
  final String title;
  final double barHeight = 80.0;

  FancyAppBar(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: barHeight,
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.blue),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 10),
        child: Text(title,
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
return Scaffold(
      body: Column(
        children: <Widget>[
          FancyAppBar('Login to Vikunja'),
        ],
      ),
    );
 */
