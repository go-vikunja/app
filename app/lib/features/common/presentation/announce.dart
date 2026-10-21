import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

/// Has the screen reader say [message], e.g. what a tap changed.
void announce(BuildContext context, String message) => unawaited(
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  ),
);
