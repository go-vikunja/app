import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class BucketLimitDialog extends StatelessWidget {
  final Bucket bucket;
  final _controller = TextEditingController();

  BucketLimitDialog({super.key, required this.bucket});

  @override
  Widget build(BuildContext context) {
    if (_controller.text.isEmpty) _controller.text = '${bucket.limit}';
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.bucketLimitTitle(bucket.title)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: l10n.limitLabel,
                    helperText: l10n.noLimitHelper,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onSubmitted: (text) =>
                      Navigator.of(context).pop(int.parse(text)),
                ),
              ),
              Column(
                children: <Widget>[
                  IconButton(
                    onPressed: () =>
                        _controller.text = '${int.parse(_controller.text) + 1}',
                    icon: Icon(Icons.expand_less),
                  ),
                  IconButton(
                    onPressed: () {
                      final limit = int.parse(_controller.text);
                      _controller.text = '${limit == 0 ? 0 : (limit - 1)}';
                    },
                    icon: Icon(Icons.expand_more),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: <TextButton>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(0),
          child: Text(l10n.removeLimit),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(int.parse(_controller.text)),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}
