import 'package:flutter/widgets.dart';

/// Whether the text shows at 1.5 times its size or more, measured at body
/// size so that Android 14's nonlinear scaling counts its 150 % step: from
/// here a few layouts give the text the room of their decorations.
bool largeTextOf(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(_bodySize) >= _bodySize * 1.5;

const _bodySize = 14.0;
