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
  }
}
