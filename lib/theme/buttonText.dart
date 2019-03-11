import 'package:flutter/material.dart';
import 'package:vikunja_app/theme/constants.dart';

class VikunjaButtonText extends StatelessWidget {
  final String text;

  const VikunjaButtonText(
    this.text, {
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: vButtonTextColor, fontWeight: FontWeight.w600),
    );
  }
}
