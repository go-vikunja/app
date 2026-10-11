import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'label_providers.g.dart';

/// Every label the account can attach, by title; stays loading without an
/// account.
@riverpod
Stream<List<Label>> allLabels(Ref ref) =>
    ref.watch(labelRepositoryProvider)?.watchAll() ?? const Stream.empty();
