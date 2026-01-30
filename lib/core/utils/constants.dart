import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vikunja_app/domain/entities/version.dart';

var supportedServerVersion = Version(1, 0, 0);

const vPrimary = Color(0xFF0c86ff);
const vLabelLight = Color(0xFFf2f2f2);
const vLabelDark = Color(0xFF4a4a4a);

const vStandardVerticalPadding = EdgeInsets.symmetric(vertical: 5.0);

var vDateFormatLong = DateFormat(
  "EEEE, MMMM d, yyyy 'at' H:mm",
); //TODO locale dependent
var vDateFormatShort = DateFormat("d MMM yyyy, H:mm"); //TODO locale dependent

String repo = "https://github.com/go-vikunja/app/releases/latest";
