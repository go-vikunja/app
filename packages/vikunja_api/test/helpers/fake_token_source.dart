import 'package:vikunja_api/vikunja_api.dart';

/// Hands out [current] and, after a rejection, [nextAfterRejection].
final class FakeTokenSource implements AccessTokenSource {
  new({required this.current, this.nextAfterRejection});

  String current;
  String? nextAfterRejection;
  Exception? validAccessTokenFailure;
  Exception? refreshFailure;

  int validAccessTokenCalls = 0;
  final rejectedTokens = <String>[];

  @override
  Future<String> validAccessToken() async {
    validAccessTokenCalls++;
    if (validAccessTokenFailure case final failure?) throw failure;
    return current;
  }

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async {
    rejectedTokens.add(rejectedToken);
    if (refreshFailure case final failure?) throw failure;
    final next = nextAfterRejection;
    if (next != null) current = next;
    return next;
  }
}
