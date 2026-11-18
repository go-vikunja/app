import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';

/// A builder for `showDatePicker` and `showTimePicker` that starts the
/// calendar grid on [firstDayOfWeekIndex] (0 = Sunday) and shows the clock
/// in 24 or 12 hours as [use24HourFormat] says; null keeps the device
/// locale's choice. It also gives the picker back the framework's dialog
/// width, which the app caps for its other dialogs on large windows: the
/// landscape pickers are wider than the cap.
TransitionBuilder pickerFormatsBuilder({
  int? firstDayOfWeekIndex,
  bool? use24HourFormat,
}) {
  return (context, child) {
    final theme = Theme.of(context);
    Widget wrapped = Theme(
      data: theme.copyWith(
        dialogTheme: theme.dialogTheme.copyWith(
          constraints: ReadableWidth.defaultDialogConstraints,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
    if (firstDayOfWeekIndex == null && use24HourFormat == null) return wrapped;
    // The time picker reads the hour format from both: the dial from the
    // localizations, the typed hours and field sizes from the media query.
    if (use24HourFormat != null) {
      wrapped = MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: use24HourFormat),
        child: wrapped,
      );
    }
    return Localizations.override(
      context: context,
      delegates: [
        _MaterialLocalizationsDelegate(
          firstDayOfWeekIndex: firstDayOfWeekIndex,
          use24HourFormat: use24HourFormat,
        ),
      ],
      child: wrapped,
    );
  };
}

/// Material's texts in the app's language for any locale of it, with that
/// locale's dates, numbers, first day of the week and date input hint.
/// Material's own regional texts, like en_GB's British spelling and de_CH's
/// capitals, would not match the app's.
const LocalizationsDelegate<MaterialLocalizations>
appMaterialLocalizationsDelegate = _MaterialLocalizationsDelegate();

final class _MaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const new({this.firstDayOfWeekIndex, this.use24HourFormat});

  final int? firstDayOfWeekIndex;
  final bool? use24HourFormat;

  // Material's class of each language has to be extended by name. A
  // shipped language missing here would get Material's regional texts and
  // in the pickers its locale's week start and clock, not the account's; a
  // test asks for every shipped one.
  static const Map<String, _LocalizationsFactory> _languages = {
    'en': _EnglishLocalizations.new,
    'de': _GermanLocalizations.new,
  };

  @override
  bool isSupported(Locale locale) =>
      _languages.containsKey(locale.languageCode);

  // The global delegate's load initializes intl's date data for the locale
  // and stays synchronous, so the picker never shows an empty frame. Its
  // translation for the region has the region's date hint.
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate
          .load(locale)
          .then(
            (regional) => _languages[locale.languageCode]!(
              _Formats(locale.toString()),
              regional: regional,
              firstDayOfWeek: firstDayOfWeekIndex,
              use24Hour: use24HourFormat,
            ),
          );

  @override
  bool shouldReload(_MaterialLocalizationsDelegate old) =>
      old.firstDayOfWeekIndex != firstDayOfWeekIndex ||
      old.use24HourFormat != use24HourFormat;
}

typedef _LocalizationsFactory = MaterialLocalizations Function(
  _Formats formats, {
  required MaterialLocalizations regional,
  required int? firstDayOfWeek,
  required bool? use24Hour,
});

/// The formats `GlobalMaterialLocalizations.delegate` builds: the
/// locale's where intl has them, else its language's.
final class _Formats {
  new(String locale)
    : fullYear = intl.DateFormat.y(locale),
      compactDate = intl.DateFormat.yMd(locale),
      shortDate = intl.DateFormat.yMMMd(locale),
      mediumDate = intl.DateFormat.MMMEd(locale),
      longDate = intl.DateFormat.yMMMMEEEEd(locale),
      yearMonth = intl.DateFormat.yMMMM(locale),
      shortMonthDay = intl.DateFormat.MMMd(locale),
      decimal = intl.NumberFormat.decimalPattern(locale),
      twoDigitZeroPadded = intl.NumberFormat('00', locale);

  final intl.DateFormat fullYear;
  final intl.DateFormat compactDate;
  final intl.DateFormat shortDate;
  final intl.DateFormat mediumDate;
  final intl.DateFormat longDate;
  final intl.DateFormat yearMonth;
  final intl.DateFormat shortMonthDay;
  final intl.NumberFormat decimal;
  final intl.NumberFormat twoDigitZeroPadded;
}

/// Without the account's, the first day of the week is the region's: the
/// language's class reads it from the long date's symbols.
mixin _AppOverrides on GlobalMaterialLocalizations {
  MaterialLocalizations get regional;
  int? get firstDayOfWeek;
  bool? get use24Hour;

  @override
  int get firstDayOfWeekIndex => firstDayOfWeek ?? super.firstDayOfWeekIndex;

  @override
  String get dateHelpText => regional.dateHelpText;

  @override
  TimeOfDayFormat timeOfDayFormat({bool alwaysUse24HourFormat = false}) =>
      switch (use24Hour) {
        true => TimeOfDayFormat.HH_colon_mm,
        false => TimeOfDayFormat.h_colon_mm_space_a,
        // The device's switch already holds the region's default; the
        // regional clock would override a 12-hour choice (en_GB's is HH:mm).
        null => super.timeOfDayFormat(
          alwaysUse24HourFormat: alwaysUse24HourFormat,
        ),
      };
}

final class _EnglishLocalizations extends MaterialLocalizationEn
    with _AppOverrides {
  new(
    _Formats formats, {
    required this.regional,
    required this.firstDayOfWeek,
    required this.use24Hour,
  }) : super(
         fullYearFormat: formats.fullYear,
         compactDateFormat: formats.compactDate,
         shortDateFormat: formats.shortDate,
         mediumDateFormat: formats.mediumDate,
         longDateFormat: formats.longDate,
         yearMonthFormat: formats.yearMonth,
         shortMonthDayFormat: formats.shortMonthDay,
         decimalFormat: formats.decimal,
         twoDigitZeroPaddedFormat: formats.twoDigitZeroPadded,
       );

  @override
  final MaterialLocalizations regional;

  @override
  final int? firstDayOfWeek;

  @override
  final bool? use24Hour;
}

final class _GermanLocalizations extends MaterialLocalizationDe
    with _AppOverrides {
  new(
    _Formats formats, {
    required this.regional,
    required this.firstDayOfWeek,
    required this.use24Hour,
  }) : super(
         fullYearFormat: formats.fullYear,
         compactDateFormat: formats.compactDate,
         shortDateFormat: formats.shortDate,
         mediumDateFormat: formats.mediumDate,
         longDateFormat: formats.longDate,
         yearMonthFormat: formats.yearMonth,
         shortMonthDayFormat: formats.shortMonthDay,
         decimalFormat: formats.decimal,
         twoDigitZeroPaddedFormat: formats.twoDigitZeroPadded,
       );

  @override
  final MaterialLocalizations regional;

  @override
  final int? firstDayOfWeek;

  @override
  final bool? use24Hour;
}
