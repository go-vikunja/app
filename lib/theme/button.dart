import 'package:flutter/material.dart';
import 'package:vikunja_app/theme/constants.dart';

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
    return ElevatedButton(onPressed: onPressed, child: child);
    return Padding(
        padding: vStandardVerticalPadding,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? vButtonShadowDark
                  : vButtonShadow,
              offset: Offset(-5, 5),
              blurRadius: 10,
            ),
          ]),
          child: Material(
            borderRadius: BorderRadius.circular(3),
            color: Theme.of(context).colorScheme.primary,
            child: InkWell(
                onTap: onPressed,
                child: Center(
                  child: child,
                )),
          ),
        ));
  }
}
