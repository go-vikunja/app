import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/filters/application/filter_syntax.dart';

/// The engine's refusal in the user's words, by its code and the field and
/// value it names, the field spelled as the builder suggests it: the
/// server's message is English and quotes the rewritten filter.
String filterErrorText(
  AppLocalizations l10n,
  FilterError error,
) => switch (error) {
  FilterError(code: FilterError.invalidField, :final field?) =>
    l10n.filterErrorUnknownFieldNamed(field),
  FilterError(code: FilterError.invalidField) => l10n.filterErrorUnknownField,
  FilterError(code: FilterError.invalidComparator) => l10n.filterErrorOperator,
  FilterError(code: FilterError.invalidValue, field: 'labels', :final value?) =>
    l10n.filterErrorLabelValue(value),
  FilterError(
    code: FilterError.invalidValue,
    field: 'project_id',
    :final value?,
  ) =>
    l10n.filterErrorProjectValue(value),
  FilterError(code: FilterError.invalidValue, :final field?, :final value?) =>
    l10n.filterErrorFieldValue(value, suggestedFilterFieldName(field)),
  FilterError(code: FilterError.invalidValue) => l10n.filterErrorValue,
  FilterError(code: FilterError.invalidExpression) => l10n.filterErrorSyntax,
  FilterError(code: FilterError.tooComplex) => l10n.filterErrorTooComplex,
  _ => l10n.filterErrorInvalid,
};
