import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

part 'widget_choices.g.dart';

/// The projects of [accountId] a widget can show, as this device has them.
@riverpod
Stream<List<Project>> widgetProjectChoices(Ref ref, String accountId) =>
    ref.watch(accountProjectRepositoryProvider(accountId)).watchAll();

@riverpod
Stream<List<Label>> widgetLabelChoices(Ref ref, String accountId) =>
    ref.watch(accountLabelRepositoryProvider(accountId)).watchAll();

@riverpod
Stream<List<SavedFilterRef>> widgetSavedFilterChoices(
  Ref ref,
  String accountId,
) => ref.watch(accountProjectRepositoryProvider(accountId)).watchSavedFilters();
