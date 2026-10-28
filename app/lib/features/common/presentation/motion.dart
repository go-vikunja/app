import 'package:material_ui/material_ui.dart';

/// Whether the app jumps instead of animating a scroll or a sheet: Android's
/// "Remove animations" or iOS's Reduce Motion. iOS sets only the latter,
/// which `MediaQueryData` does not carry, and scroll animations ignore the
/// former.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) == true ||
    View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
