import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';

enum HeaderAction {
  setLimit,
  changeTitle,
  doneColumn,
  defaultColumn,
  collapseColumn,
  deleteColumn,
  addTask;
}

class BucketHeader extends StatelessWidget {
  final Bucket bucket;
  final bool isDoneColumn;
  final bool isDefaultColumn;
  final Function(HeaderAction) onAction;

  const BucketHeader(
      this.bucket, this.isDoneColumn, this.isDefaultColumn, this.onAction,
      {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          if (isDoneColumn)
            const Icon(
              Icons.done_all,
              color: Colors.green,
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              bucket.title,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (bucket.limit != 0)
            Text("${bucket.tasks.length}/${bucket.limit}",
                style: bucket.tasks.length > bucket.limit
                    ? Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.red, fontWeight: FontWeight.bold)
                    : Theme.of(context).textTheme.titleSmall),
          IconButton(
            tooltip: 'Add task',
            icon: const Icon(Icons.add),
            onPressed: () {
              onAction(HeaderAction.addTask);
            },
          ),
          _buildMenu()
        ],
      ),
    );
  }

  PopupMenuButton<String> _buildMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (String item) {},
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        buildPopupMenuItem("Change name", HeaderAction.changeTitle),
        buildPopupMenuItem(
            'Limit: ${bucket.limit == 0 ? "Not set" : bucket.limit}',
            HeaderAction.setLimit),
        buildPopupMenuItem(
          "Done Column",
          HeaderAction.doneColumn,
          Icons.done_all,
          isDoneColumn ? Colors.green : null,
        ),
        buildPopupMenuItem(
          "Default Column",
          HeaderAction.defaultColumn,
          Icons.grid_on,
          isDefaultColumn ? Colors.blue : null,
        ),
        buildPopupMenuItem(
          "Collapse column",
          HeaderAction.collapseColumn,
          Icons.keyboard_double_arrow_up,
        ),
        buildPopupMenuItem(
          "Delete",
          HeaderAction.deleteColumn,
          Icons.delete,
        ),
      ],
    );
  }

  PopupMenuItem<String> buildPopupMenuItem(String title, HeaderAction action,
      [IconData? icon, Color? iconColor]) {
    return PopupMenuItem<String>(
      onTap: () {
        onAction(action);
      },
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: iconColor),
        title: Text(title),
      ),
    );
  }
}
