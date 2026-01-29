import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';

class TaskBottomSheet extends StatefulWidget {
  final Task task;
  final bool showInfo;
  final bool loading;
  final Function onEdit;

  const TaskBottomSheet({
    super.key,
    required this.task,
    required this.onEdit,
    this.loading = false,
    this.showInfo = false,
  });

  @override
  TaskBottomSheetState createState() => TaskBottomSheetState();
}

class TaskBottomSheetState extends State<TaskBottomSheet> {
  final double propertyPadding = 10.0;

  TaskBottomSheetState();

  String priorityToStringLocalized(BuildContext context, int? priority) {
    if (priority == null) return AppLocalizations.of(context).priorityUnset;
    switch (priority) {
      case 0:
        return AppLocalizations.of(context).priorityUnset;
      case 1:
        return AppLocalizations.of(context).priorityLow;
      case 2:
        return AppLocalizations.of(context).priorityMedium;
      case 3:
        return AppLocalizations.of(context).priorityHigh;
      case 4:
        return AppLocalizations.of(context).priorityUrgent;
      case 5:
        return AppLocalizations.of(context).priorityDoNow;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 10, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Text(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      widget.task.title,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onEdit();
                    },
                    icon: Icon(Icons.edit),
                  ),
                ],
              ),
              SizedBox(height: propertyPadding),
              Wrap(
                spacing: 10,
                children: widget.task.labels.map((Label label) {
                  return LabelWidget(label: label);
                }).toList(),
              ),

              // description with html rendering
              Text(
                AppLocalizations.of(context).description,
                style: theme.textTheme.titleLarge,
              ),
              SizedBox(height: propertyPadding),
              Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                child: HtmlWidget(
                  widget.task.description.isNotEmpty
                      ? widget.task.description
                      : AppLocalizations.of(context).noDescription,
                ),
              ),
              SizedBox(height: propertyPadding),
              // Due date
              Row(
                children: [
                  Icon(Icons.access_time),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(
                    widget.task.hasDueDate
                        ? widget.task.dueDate!.toLocal().formatShort()
                        : AppLocalizations.of(context).noDueDate,
                  ),
                ],
              ),
              SizedBox(height: propertyPadding),
              // start date
              Row(
                children: [
                  Icon(Icons.play_arrow_rounded),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(
                    widget.task.hasStartDate
                        ? widget.task.startDate!.toLocal().formatShort()
                        : AppLocalizations.of(context).noStartDate,
                  ),
                ],
              ),
              SizedBox(height: propertyPadding),
              // end date
              Row(
                children: [
                  Icon(Icons.stop_rounded),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(
                    widget.task.hasEndDate
                        ? widget.task.endDate!.toLocal().formatShort()
                        : AppLocalizations.of(context).noEndDate,
                  ),
                ],
              ),
              SizedBox(height: propertyPadding),
              // priority
              Row(
                children: [
                  Icon(Icons.priority_high),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(
                    widget.task.priority != null
                        ? priorityToStringLocalized(
                            context,
                            widget.task.priority,
                          )
                        : AppLocalizations.of(context).noPriority,
                  ),
                ],
              ),
              SizedBox(height: propertyPadding),
              // progress
              Row(
                children: [
                  Icon(Icons.percent),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(
                    widget.task.percentDone != null
                        ? "${(widget.task.percentDone! * 100).toInt()}%"
                        : AppLocalizations.of(context).percentUnset,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
