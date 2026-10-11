import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

/// A screen over the shell that belongs to the account that was active when
/// it opened. After a switch it shows nothing while it animates out, so a
/// task id of one account is never looked up in another account's data.
class AccountBoundScreen extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AccountBoundScreen> createState() => _AccountBoundScreenState();
}

class _AccountBoundScreenState extends ConsumerState<AccountBoundScreen> {
  late final String? _accountId = ref.read(activeAccountIdProvider);

  @override
  Widget build(BuildContext context) {
    final activeAccountId = ref.watch(activeAccountIdProvider);
    if (activeAccountId != _accountId) return const Scaffold();
    return widget.child;
  }
}
