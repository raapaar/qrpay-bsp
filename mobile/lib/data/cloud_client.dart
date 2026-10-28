import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'local_store.dart';

class CloudClient {
  final LocalStore store;
  final FlutterSecureStorage vault;
  CloudClient(this.store, {this.vault = const FlutterSecureStorage()});
  static const fields = [
    'displayName',
    'budget',
    'activity',
    'qrs',
    'feedback',
    'goals',
    'bankLabel',
    'simLabel',
  ];
  bool busy = false;
  Uri uri(String route) {
    final value = Uri.parse(store.setting('server'));
    if (value.scheme != 'https' ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.query.isNotEmpty ||
        value.fragment.isNotEmpty) {
      throw const FormatException(
        'Enter an HTTPS server address without credentials or query parameters.',
      );
    }
    return value.replace(
      path: '${value.path.replaceFirst(RegExp(r"/+$"), "")}/api/$route',
    );
  }

  Future<Map<String, dynamic>> call(
    String route, {
    Map<String, dynamic>? data,
    bool auth = true,
  }) async {
    final token = auth ? await vault.read(key: 'qrpay-api-token') : null;
    if (auth &&
        await vault.read(key: 'qrpay-api-server') != store.setting('server')) {
      throw StateError(
        'Server changed. Sign out and sign in to the new server first.',
      );
    }
    if (auth && token == null) {
      throw StateError('Sign in to your app account first.');
    }
    final response = await http
        .post(
          uri(route),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data ?? {}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.bodyBytes.length > 4 * 1024 * 1024) {
      throw StateError('Server response is too large.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw StateError(body['error'] as String? ?? 'Server request failed.');
    }
    return body;
  }

  Future<void> signIn(
    String username,
    String password, {
    bool register = false,
  }) async {
    final result = await call(
      register ? 'register' : 'login',
      auth: false,
      data: {'username': username.trim(), 'password': password},
    );
    await vault.write(key: 'qrpay-api-token', value: result['token'] as String);
    await vault.write(key: 'qrpay-api-server', value: store.setting('server'));
    await store.set('account', username.trim());
    await store.set('revision', 0);
    await store.set('cloudConsent', false);
  }

  Future<void> signOut() async {
    try {
      await call('logout');
    } catch (_) {
      /* Local sign-out still completes. */
    }
    await vault.delete(key: 'qrpay-api-token');
    await store.set('account', '');
    await store.set('cloudConsent', false);
    await store.set('revision', 0);
  }

  Future<void> sync() async {
    if (busy || !store.enabled('cloudConsent')) {
      return;
    }
    busy = true;
    try {
      // Backup records only. There is deliberately no payment submission API.
      final snapshot = {
        for (final key in fields)
          if (store.state.containsKey(key)) key: store.state[key],
      };
      final result = await call(
        'sync',
        data: {
          'revision': store.state['revision'] ?? 0,
          'snapshot': snapshot,
          'requestId': newId(),
        },
      );
      await store.set('revision', result['revision']);
      await store.set(
        'lastSync',
        DateTime.now().toLocal().toString().substring(0, 16),
      );
      await store.set('syncError', '');
    } catch (_) {
      await store.set(
        'syncError',
        'Sync pending. Check the server, sign-in or cloud backup conflict.',
      );
      rethrow;
    } finally {
      busy = false;
    }
  }

  Future<void> restore() async {
    final result = await call('restore');
    final data = Map<String, dynamic>.from(result['snapshot'] as Map);
    for (final key in fields) {
      await store.set(
        key,
        data[key] ??
            (['activity', 'qrs', 'feedback', 'goals'].contains(key) ? [] : ''),
      );
    }
    await store.set('revision', result['revision']);
  }

  Future<void> deleteAccount() async {
    await call('delete-account');
    await vault.delete(key: 'qrpay-api-token');
    await store.clear();
  }
}
