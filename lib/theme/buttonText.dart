import 'package:flutter/material.dart';

class VikunjaButtonText extends StatelessWidget {
  final String text;

  const VikunjaButtonText(
    this.text, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(text);
    return Text(
      text,
      style: TextStyle(
          color: Theme.of(context).primaryTextTheme.labelMedium?.color,
          fontWeight: FontWeight.w600),
    );
  }
}
