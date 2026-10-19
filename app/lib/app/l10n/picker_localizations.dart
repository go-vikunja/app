import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';

/// A builder for `showDatePicker` and `showTimePicker` that starts the
/// calendar grid on [firstDayOfWeekIndex] (0 = Sunday) and shows the clock
/// in 24 or 12 hours as [use24HourFormat] says; null keeps the device
/// locale's choice, and with both null nothing is wrapped.
TransitionBuilder? pickerFormatsBuilder({
  int? firstDayOfWeekIndex,
  bool? use24HourFormat,
}) {
  if (firstDayOfWeekIndex == null && use24HourFormat == null) return null;
  return (context, child) {
    var wrapped = child ?? const SizedBox.shrink();
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
        _PickerMaterialLocalizationsDelegate(
          firstDayOfWeekIndex: firstDayOfWeekIndex,
          use24HourFormat: use24HourFormat,
        ),
      ],
      child: wrapped,
    );
  };
}

final class _PickerMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const new({this.firstDayOfWeekIndex, this.use24HourFormat});

  final int? firstDayOfWeekIndex;
  final bool? use24HourFormat;

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'de';

  // The global delegate's load initializes intl's date data for the locale
  // and stays synchronous, so the picker never shows an empty frame.
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate
          .load(locale)
          .then((_) => _localizationsFor(locale.languageCode));

  MaterialLocalizations _localizationsFor(String language) {
    final formats = _Formats(language);
    return language == 'de'
        ? _GermanPickerLocalizations(
            formats,
            firstDayOfWeek: firstDayOfWeekIndex,
            use24Hour: use24HourFormat,
          )
        : _EnglishPickerLocalizations(
            formats,
            firstDayOfWeek: firstDayOfWeekIndex,
            use24Hour: use24HourFormat,
          );
  }

  @override
  bool shouldReload(_PickerMaterialLocalizationsDelegate old) =>
      old.firstDayOfWeekIndex != firstDayOfWeekIndex ||
      old.use24HourFormat != use24HourFormat;
}

/// The formats `GlobalMaterialLocalizations.delegate` builds for a
/// language intl knows.
final class _Formats {
  new(String language)
    : fullYear = intl.DateFormat.y(language),
      compactDate = intl.DateFormat.yMd(language),
      shortDate = intl.DateFormat.yMMMd(language),
      mediumDate = intl.DateFormat.MMMEd(language),
      longDate = intl.DateFormat.yMMMMEEEEd(language),
      yearMonth = intl.DateFormat.yMMMM(language),
      shortMonthDay = intl.DateFormat.MMMd(language),
      decimal = intl.NumberFormat.decimalPattern(language),
      twoDigitZeroPadded = intl.NumberFormat('00', language);

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

mixin _PickerOverrides on GlobalMaterialLocalizations {
  int? get firstDayOfWeek;
  bool? get use24Hour;

  @override
  int get firstDayOfWeekIndex => firstDayOfWeek ?? super.firstDayOfWeekIndex;

  @override
  TimeOfDayFormat timeOfDayFormat({bool alwaysUse24HourFormat = false}) =>
      switch (use24Hour) {
        true => TimeOfDayFormat.HH_colon_mm,
        false => TimeOfDayFormat.h_colon_mm_space_a,
        null => super.timeOfDayFormat(
          alwaysUse24HourFormat: alwaysUse24HourFormat,
        ),
      };
}

final class _EnglishPickerLocalizations extends MaterialLocalizationEn
    with _PickerOverrides {
  new(_Formats formats, {required this.firstDayOfWeek, required this.use24Hour})
    : super(
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
  final int? firstDayOfWeek;

  @override
  final bool? use24Hour;
}

final class _GermanPickerLocalizations extends MaterialLocalizationDe
    with _PickerOverrides {
  new(_Formats formats, {required this.firstDayOfWeek, required this.use24Hour})
    : super(
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
  final int? firstDayOfWeek;

  @override
  final bool? use24Hour;
}
