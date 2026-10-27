// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_choices.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The projects of [accountId] a widget can show, as this device has them.

@ProviderFor(widgetProjectChoices)
final widgetProjectChoicesProvider = WidgetProjectChoicesFamily._();

/// The projects of [accountId] a widget can show, as this device has them.

final class WidgetProjectChoicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Project>>,
          List<Project>,
          Stream<List<Project>>
        >
    with $FutureModifier<List<Project>>, $StreamProvider<List<Project>> {
  /// The projects of [accountId] a widget can show, as this device has them.
  WidgetProjectChoicesProvider._({
    required WidgetProjectChoicesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'widgetProjectChoicesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$widgetProjectChoicesHash();

  @override
  String toString() {
    return r'widgetProjectChoicesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Project>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Project>> create(Ref ref) {
    final argument = this.argument as String;
    return widgetProjectChoices(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WidgetProjectChoicesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$widgetProjectChoicesHash() =>
    r'665e9a0a51672d98b98b5c55258f395f1eccd3e1';

/// The projects of [accountId] a widget can show, as this device has them.

final class WidgetProjectChoicesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Project>>, String> {
  WidgetProjectChoicesFamily._()
    : super(
        retry: null,
        name: r'widgetProjectChoicesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The projects of [accountId] a widget can show, as this device has them.

  WidgetProjectChoicesProvider call(String accountId) =>
      WidgetProjectChoicesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'widgetProjectChoicesProvider';
}

@ProviderFor(widgetLabelChoices)
final widgetLabelChoicesProvider = WidgetLabelChoicesFamily._();

final class WidgetLabelChoicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Label>>,
          List<Label>,
          Stream<List<Label>>
        >
    with $FutureModifier<List<Label>>, $StreamProvider<List<Label>> {
  WidgetLabelChoicesProvider._({
    required WidgetLabelChoicesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'widgetLabelChoicesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$widgetLabelChoicesHash();

  @override
  String toString() {
    return r'widgetLabelChoicesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Label>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Label>> create(Ref ref) {
    final argument = this.argument as String;
    return widgetLabelChoices(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WidgetLabelChoicesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$widgetLabelChoicesHash() =>
    r'be6eb661f4356e36721c7bb36004dfe486891216';

final class WidgetLabelChoicesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Label>>, String> {
  WidgetLabelChoicesFamily._()
    : super(
        retry: null,
        name: r'widgetLabelChoicesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WidgetLabelChoicesProvider call(String accountId) =>
      WidgetLabelChoicesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'widgetLabelChoicesProvider';
}

@ProviderFor(widgetSavedFilterChoices)
final widgetSavedFilterChoicesProvider = WidgetSavedFilterChoicesFamily._();

final class WidgetSavedFilterChoicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SavedFilterRef>>,
          List<SavedFilterRef>,
          Stream<List<SavedFilterRef>>
        >
    with
        $FutureModifier<List<SavedFilterRef>>,
        $StreamProvider<List<SavedFilterRef>> {
  WidgetSavedFilterChoicesProvider._({
    required WidgetSavedFilterChoicesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'widgetSavedFilterChoicesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$widgetSavedFilterChoicesHash();

  @override
  String toString() {
    return r'widgetSavedFilterChoicesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<SavedFilterRef>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SavedFilterRef>> create(Ref ref) {
    final argument = this.argument as String;
    return widgetSavedFilterChoices(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WidgetSavedFilterChoicesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$widgetSavedFilterChoicesHash() =>
    r'9eaf3ac7601ef494feb2a65451403b37aed8b678';

final class WidgetSavedFilterChoicesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<SavedFilterRef>>, String> {
  WidgetSavedFilterChoicesFamily._()
    : super(
        retry: null,
        name: r'widgetSavedFilterChoicesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WidgetSavedFilterChoicesProvider call(String accountId) =>
      WidgetSavedFilterChoicesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'widgetSavedFilterChoicesProvider';
}
