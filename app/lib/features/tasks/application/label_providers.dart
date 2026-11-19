import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'label_providers.g.dart';

/// Every label the account can attach, by title; stays loading without an
/// account.
@riverpod
Stream<List<Label>> allLabels(Ref ref) =>
    ref.watch(labelRepositoryProvider)?.watchAll() ?? const Stream.empty();

/// One label, followed to the server id once a label created here is
/// answered; null while it is not here.
@riverpod
Stream<Label?> labelById(Ref ref, int id) =>
    ref.watch(labelRepositoryProvider)?.watchLabel(id) ?? const Stream.empty();

/// The labels with a change the server does not have yet.
@riverpod
Stream<Set<int>> pendingLabelIds(Ref ref) =>
    ref.watch(labelRepositoryProvider)?.watchPendingIds() ??
    const Stream.empty();

/// Every temporary label id with the server id its label got.
@riverpod
Stream<Map<int, int>> labelRemaps(Ref ref) =>
    ref.watch(labelRepositoryProvider)?.watchRemaps() ?? const Stream.empty();
