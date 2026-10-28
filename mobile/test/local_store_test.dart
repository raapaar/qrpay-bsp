import 'dart:convert';
import 'dart:ffi';
import 'package:sqlite3/open.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qrpay_bsp/data/local_store.dart';
import 'package:qrpay_bsp/payment.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
    sqfliteFfiInit();
  });
  test(
    'concurrent writes survive database close and restart without losing records',
    () async {
      final dir = await Directory.systemTemp.createTemp('qrpay-db-test');
      final file = '${dir.path}/test.db';
      final first = await LocalStore.open(
        factory: databaseFactoryFfiNoIsolate,
        filename: file,
      );
      await Future.wait([
        for (var i = 0; i < 10; i++)
          first.put('activity', {'id': 'row-$i', 'amountMinor': i + 1}),
      ]);
      await first.set('history', true);
      await first.close();
      final second = await LocalStore.open(
        factory: databaseFactoryFfiNoIsolate,
        filename: file,
      );
      expect(second.items('activity').length, 10);
      expect(second.enabled('history'), isTrue);
      await second.clear();
      await second.close();
      final third = await LocalStore.open(
        factory: databaseFactoryFfiNoIsolate,
        filename: file,
      );
      expect(third.state, isEmpty);
      await third.close();
      await dir.delete(recursive: true);
    },
  );
  test(
    'transfer QR and reusable QR preserve strict schema and require amount before submit',
    () async {
      final r = PaymentRequest(
        merchantCode: 'TEST-1234',
        merchantName: 'A peer',
        amountMinor: 0,
        reference: 'DEMO-TEST',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        kind: 'transfer',
        note: 'Lunch',
      );
      final parsed = PaymentRequest.parse(r.encode());
      expect(parsed.kind, 'transfer');
      expect(parsed.amountMinor, 0);
      final session = PaymentSession()..load(r.encode());
      expect(session.canSubmit, isFalse);
      final data = jsonDecode(r.encode()) as Map<String, dynamic>;
      expect(
        () => PaymentRequest.parse(jsonEncode({...data, 'pin': '1234'})),
        throwsFormatException,
      );
      expect(
        () => PaymentRequest.parse(jsonEncode({...data, 'amountMinor': -1})),
        throwsFormatException,
      );
    },
  );
}
