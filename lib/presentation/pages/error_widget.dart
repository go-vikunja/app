import 'package:flutter/material.dart';

class VikunjaErrorWidget extends StatelessWidget {
  final Function()? onRetry;
  final Object error;

  const VikunjaErrorWidget({required this.error, this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 80),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 32.0,
              ),
              child: getErrorWidget(context, error),
            ),
            SizedBox(height: 32),
            if (onRetry != null)
              ElevatedButton(
                onPressed: () {
                  onRetry?.call();
                },
                child: Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget getErrorWidget(BuildContext context, Object error) {
    if (error is String) {
      return Text(error, style: Theme.of(context).textTheme.titleLarge);
    }

    return Text(
      error.toString(),
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}
