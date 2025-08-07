import 'package:flutter/material.dart';

class FancyButton extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback? onPressed;
  final Widget child;

  const FancyButton({
    Key? key,
    required this.child,
    this.width = double.infinity,
    this.height = 35,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: SizedBox(
        width: width,
        child: Center(child: child),
      ),
    );
  }
}
