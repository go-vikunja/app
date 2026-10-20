// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What [query] finds on this device; stays loading while no account is
/// signed in.

@ProviderFor(searchResults)
final searchResultsProvider = SearchResultsFamily._();

/// What [query] finds on this device; stays loading while no account is
/// signed in.

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SearchResults>,
          SearchResults,
          Stream<SearchResults>
        >
    with $FutureModifier<SearchResults>, $StreamProvider<SearchResults> {
  /// What [query] finds on this device; stays loading while no account is
  /// signed in.
  SearchResultsProvider._({
    required SearchResultsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchResultsHash();

  @override
  String toString() {
    return r'searchResultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<SearchResults> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SearchResults> create(Ref ref) {
    final argument = this.argument as String;
    return searchResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchResultsHash() => r'314569b03f5d88d63e58411f0dc155a80795d01b';

/// What [query] finds on this device; stays loading while no account is
/// signed in.

final class SearchResultsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<SearchResults>, String> {
  SearchResultsFamily._()
    : super(
        retry: null,
        name: r'searchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What [query] finds on this device; stays loading while no account is
  /// signed in.

  SearchResultsProvider call(String query) =>
      SearchResultsProvider._(argument: query, from: this);

  @override
  String toString() => r'searchResultsProvider';
}

/// The search page's last query, which it shows again when it opens: a
/// project or saved filter opens in the Projects tab, which leaves it.
/// Another account starts empty.

@ProviderFor(LastSearchQuery)
final lastSearchQueryProvider = LastSearchQueryProvider._();

/// The search page's last query, which it shows again when it opens: a
/// project or saved filter opens in the Projects tab, which leaves it.
/// Another account starts empty.
final class LastSearchQueryProvider
    extends $NotifierProvider<LastSearchQuery, String> {
  /// The search page's last query, which it shows again when it opens: a
  /// project or saved filter opens in the Projects tab, which leaves it.
  /// Another account starts empty.
  LastSearchQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastSearchQueryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastSearchQueryHash();

  @$internal
  @override
  LastSearchQuery create() => LastSearchQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$lastSearchQueryHash() => r'6b7b9b5e925514f1fb8ae32ed46d07a03e94051d';

/// The search page's last query, which it shows again when it opens: a
/// project or saved filter opens in the Projects tab, which leaves it.
/// Another account starts empty.

abstract class _$LastSearchQuery extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
