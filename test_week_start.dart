/// Test script to verify weekStart save/load on Vikunja server.
/// Run: dart run test_week_start.dart
import 'dart:convert';
import 'dart:io';

const server = 'http://100.119.139.93:3456';
const username = 'arb';
const password = 'Vikunja2026!';

Future<void> main() async {
  final client = HttpClient();

  // Step 1: Login
  print('=== Step 1: Login ===');
  final loginReq = await client.postUrl(Uri.parse('$server/api/v1/login'));
  loginReq.headers.set('Content-Type', 'application/json');
  loginReq.write(jsonEncode({'username': username, 'password': password}));
  final loginResp = await loginReq.close();
  final loginBody = jsonDecode(await loginResp.transform(utf8.decoder).join());
  final token = loginBody['token'] as String;
  print('OK - Token: ${token.substring(0, 10)}...');

  // Step 2: Read current weekStart
  print('\n=== Step 2: Read current weekStart ===');
  final userReq = await client.getUrl(Uri.parse('$server/api/v1/user'));
  userReq.headers.set('Authorization', 'Bearer $token');
  final userResp = await userReq.close();
  final userBody = jsonDecode(await userResp.transform(utf8.decoder).join());
  final originalWeekStart = userBody['settings']['week_start'] as int;
  print('Current week_start: $originalWeekStart');

  // Test values: 0 (Sun), 1 (Mon), 6 (Sat)
  final testValues = [0, 1, 6];
  final dayNames = {0: 'Sunday', 1: 'Monday', 6: 'Saturday'};
  final results = <String, bool>{};

  for (final testVal in testValues) {
    print('\n=== Set weekStart=$testVal (${dayNames[testVal]}) ===');

    // Build settings payload from current settings
    final settingsBody = Map<String, dynamic>.from(userBody['settings']);
    settingsBody['week_start'] = testVal;

    // Save
    final saveReq = await client.postUrl(Uri.parse('$server/api/v1/user/settings/general'));
    saveReq.headers.set('Content-Type', 'application/json');
    saveReq.headers.set('Authorization', 'Bearer $token');
    saveReq.write(jsonEncode(settingsBody));
    final saveResp = await saveReq.close();
    print('Save HTTP: ${saveResp.statusCode}');
    await saveResp.drain();

    // Read back
    final verifyReq = await client.getUrl(Uri.parse('$server/api/v1/user'));
    verifyReq.headers.set('Authorization', 'Bearer $token');
    final verifyResp = await verifyReq.close();
    final verifyBody = jsonDecode(await verifyResp.transform(utf8.decoder).join());
    final saved = verifyBody['settings']['week_start'] as int;
    final pass = saved == testVal;
    results['$testVal (${dayNames[testVal]})'] = pass;
    print('Read back: $saved - ${pass ? "PASS" : "FAIL"}');
  }

  // Restore original
  print('\n=== Restore original: $originalWeekStart ===');
  final restoreBody = Map<String, dynamic>.from(userBody['settings']);
  restoreBody['week_start'] = originalWeekStart;
  final restoreReq = await client.postUrl(Uri.parse('$server/api/v1/user/settings/general'));
  restoreReq.headers.set('Content-Type', 'application/json');
  restoreReq.headers.set('Authorization', 'Bearer $token');
  restoreReq.write(jsonEncode(restoreBody));
  final restoreResp = await restoreReq.close();
  await restoreResp.drain();
  print('Restored: ${restoreResp.statusCode}');

  // Summary
  print('\n========== RESULTS ==========');
  for (final entry in results.entries) {
    print('${entry.key}: ${entry.value ? "PASS" : "FAIL"}');
  }
  final allPass = results.values.every((v) => v);
  print('\nOverall: ${allPass ? "ALL PASS" : "SOME FAILED"}');

  client.close();
}
