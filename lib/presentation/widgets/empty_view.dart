import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyView(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 96),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
