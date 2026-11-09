import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';

/// Whether tasks should be displayed hierarchically (subtasks grouped under
/// their parent). Defaults to [false] (flat list) until the stored value is
/// loaded from secure storage.
final hierarchicalDisplayProvider =
    AsyncNotifierProvider<HierarchicalDisplayNotifier, bool>(
      HierarchicalDisplayNotifier.new,
    );

class HierarchicalDisplayNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final repo = ref.read(settingsRepositoryProvider);
    return repo.getHierarchicalTaskDisplay();
  }

  Future<void> set(bool value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setHierarchicalTaskDisplay(value);
    state = AsyncData(value);
  }
}
